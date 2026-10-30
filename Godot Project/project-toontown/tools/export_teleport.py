"""Export the teleport throw and the portable hole.

Toon.getTeleportOutTrack plays the toon clip "teleport" and the portal clip
"hole" together for 3.4 seconds. The portal is one joint, scale_portal, so the
hole file stores that joint instead of baking vertices. getTeleportInTrack
plays "jump" from 0.45 seconds; that full jump is saved as "leap" so it does
not replace the standing hop already stored as "jump".
"""
from __future__ import annotations

import json
import shutil
import sys
import types
from pathlib import Path

# Stock Panda has no toontown DNA module. The clip bake does not need it.
_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, getModelPath, loadPrcFileData

import export_dog_ears as ears
import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT / "assets" / "props"
SFX = ROOT / "assets" / "audio" / "sfx"
PORTAL_MODEL = "phase_3.5/models/props/portal-mod.bam"
PORTAL_ANIM = "phase_3.5/models/props/portal-chan.bam"
SOUND = "phase_3.5/audio/sfx/AV_teleport.ogg"


def _teleport_joints(part: str) -> tuple[str, ...]:
    # The throw parents the hole to the right hand. Legs only carry the hips.
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head", "def_joint_right_hold")


def export_portal() -> None:
    root = idle.load_model(PORTAL_MODEL)
    if root is None:
        raise RuntimeError("missing portal")
    joint = root.find("**/scale_portal")
    if joint.isEmpty():
        raise RuntimeError("portal has no scale_portal joint")
    control, rate = idle.bind_anim(root, PORTAL_ANIM)
    frame_count = control.getNumFrames()
    character = root.find("**/+Character")
    bundle = character.node().getBundle(0)
    # The glb is the bind-pose mesh. The joint channel is applied on top.
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    PROPS.mkdir(parents=True, exist_ok=True)
    model_path = PROPS / "portal.glb"
    model_path.write_bytes(writer.pack("portal"))
    matrices = []
    saved = idle.snapshot(root)
    for frame in range(frame_count):
        idle.restore(root, saved)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        mat = joint.getTransform(joint.getParent()).getMat()
        matrices.append([mat.getCell(row, col) for row in range(4) for col in range(4)])
    clip = {
        "frames": frame_count,
        "fps": rate,
        "joint": "scale_portal",
        "matrices": matrices,
    }
    clip_path = PROPS / "portal_hole.json"
    clip_path.write_text(json.dumps(clip), encoding="utf-8")
    print(
        f"portal frames={frame_count} rate={rate:.1f} "
        f"glb={model_path.stat().st_size} clip={clip_path.stat().st_size}",
        flush=True,
    )


def export_bodies() -> None:
    idle.joint_names = _teleport_joints
    jobs = (
        ("teleport", "phase_3.5", "_teleport.bam"),
        ("leap", "phase_3.5", "_jump.bam"),
    )
    for name, model, _neutral in idle.PARTS:
        for suffix, phase, ending in jobs:
            try:
                idle.export_part(name, model, idle.anim_path(model, phase, ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    jobs = (
        ("teleport", "phase_3.5", "_teleport.bam"),
        ("leap", "phase_3.5", "_jump.bam"),
    )
    for code, prefix in ears.HEADS.items():
        for suffix, phase, ending in jobs:
            try:
                ears.export_ears(code, prefix, suffix, phase, ending)
            except RuntimeError as error:
                print("skip", code, suffix, error, flush=True)


def copy_sound() -> None:
    source = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets") / SOUND
    if not source.exists():
        print("missing sfx", SOUND, flush=True)
        return
    SFX.mkdir(parents=True, exist_ok=True)
    dest = SFX / source.name
    shutil.copyfile(source, dest)
    print("sfx", dest.name, dest.stat().st_size, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    export_portal()
    export_bodies()
    export_ears()
    copy_sound()
    return 0


if __name__ == "__main__":
    sys.exit(main())
