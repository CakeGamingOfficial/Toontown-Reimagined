"""Export the catalog-phone movie.

DistributedPhone.takePhoneInterval walks the toon in, plays takePhone, then
loops phoneNeutral. Hang-up plays phoneBack. The handset is prop_phone, and
each body size has its own phoneOut, takePhone, phoneNeutral, and phoneBack.
"""
from __future__ import annotations

import struct
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

import export_dog_ears as ears
import export_toon_idle as idle


ROOT = Path(__file__).resolve().parents[1]
CLIPS = ROOT / "assets" / "props" / "phone_clips.bin"
SIZES = ("ss", "sm", "sl", "ms", "mm", "ml", "ls", "lm", "ll")
ANIMS = ("phoneOut", "takePhone", "phoneNeutral", "phoneBack")
TOON_ANIMS = (
    ("takePhone", "_takePhone.bam"),
    ("phoneNeutral", "_phoneNeutral.bam"),
    ("phoneBack", "_phoneBack.bam"),
)


def _phone_joints(part: str) -> tuple[str, ...]:
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head", "def_joint_left_hold")


def export_bodies() -> None:
    idle.joint_names = _phone_joints
    for suffix, ending in TOON_ANIMS:
        for name, model, _neutral in idle.PARTS:
            try:
                idle.export_part(name, model, idle.anim_path(model, "phase_5.5", ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    for suffix, ending in TOON_ANIMS:
        for code, prefix in ears.HEADS.items():
            try:
                ears.export_ears(code, prefix, suffix, "phase_5.5", ending)
            except RuntimeError as error:
                print("skip", code, suffix, error, flush=True)


def _locals(root: NodePath, names: list[str]) -> list[list[float]]:
    found = []
    for name in names:
        node = root.find("**/" + name)
        if node.isEmpty():
            found.append([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
            continue
        mat = node.getTransform(node.getParent()).getMat()
        found.append([mat.getCell(row, col) for row in range(4) for col in range(4)])
    return found


def export_handset() -> None:
    from direct.actor.Actor import Actor
    from direct.showbase.ShowBase import ShowBase

    ShowBase(windowType="none")
    blob = bytearray(b"PHONE1\0")
    blob += struct.pack("<I", len(SIZES))
    for size in SIZES:
        anims = {
            anim: f"phase_5.5/models/estate/prop_phone-{size.upper()}_{anim}.bam"
            for anim in ANIMS
        }
        actor = Actor("phase_5.5/models/estate/prop_phone-mod.bam", anims)
        names = []
        for path in actor.findAllMatches("**"):
            name = path.getName()
            if name.startswith("joint_") or name.startswith("Curve"):
                names.append(name)
        names = sorted(set(names))
        bind = _locals(actor, names)
        encoded = size.encode("utf-8")
        blob += struct.pack("<H", len(encoded))
        blob += encoded
        blob += struct.pack("<I", len(names))
        for index, name in enumerate(names):
            raw = name.encode("utf-8")
            blob += struct.pack("<H", len(raw))
            blob += raw
            blob += struct.pack("<16f", *bind[index])
        blob += struct.pack("<I", len(ANIMS))
        for anim in ANIMS:
            control = actor.getAnimControl(anim)
            frames = control.getNumFrames() if control else 0
            raw = anim.encode("utf-8")
            blob += struct.pack("<H", len(raw))
            blob += raw
            blob += struct.pack("<I", frames)
            posed = []
            for frame in range(frames):
                actor.pose(anim, frame)
                posed.append(_locals(actor, names))
            for joint in range(len(names)):
                for frame in posed:
                    blob += struct.pack("<16f", *frame[joint])
            print(f"phone {size} {anim} frames={frames} joints={len(names)}", flush=True)
        actor.cleanup()
        actor.removeNode()
    CLIPS.parent.mkdir(parents=True, exist_ok=True)
    CLIPS.write_bytes(blob)
    print(f"wrote {CLIPS} bytes={CLIPS.stat().st_size}", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    if which in ("", "toon"):
        export_bodies()
        export_ears()
    if which in ("", "phone"):
        export_handset()
    hand = NodePath("receiver")
    hand.setPosHpr(0.0906813, 0.380375, 0.1, 32.41, 70.68, 137.04)
    mat = hand.getMat()
    print("hand", [round(mat.getCell(row, col), 6) for row in range(4) for col in range(4)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
