"""Export the jellybean-bank movie.

DistributedBank.__takeOutToonJar plays the toon clip "bank" (the
jellybeanJar animation) while Toon.getJar grows in the right hand.
Legs carry the hips. Torsos also carry the head and the right-hand joint
the jar is parented to. Only dogs have a head clip, and that clip is the ears.
"""
from __future__ import annotations

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
JAR = "phase_5.5/models/estate/jellybeanJar.bam"


def _bank_joints(part: str) -> tuple[str, ...]:
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head", "def_joint_right_hold")


def export_bodies() -> None:
    idle.joint_names = _bank_joints
    for name, model, _neutral in idle.PARTS:
        try:
            idle.export_part(name, model, idle.anim_path(model, "phase_5.5", "_jellybeanJar.bam"), "bank")
        except RuntimeError as error:
            print("skip", name, error, flush=True)


def export_ears() -> None:
    for code, prefix in ears.HEADS.items():
        try:
            ears.export_ears(code, prefix, "bank", "phase_5.5", "_jellybeanJar.bam")
        except RuntimeError as error:
            print("skip", code, error, flush=True)


def export_jar() -> None:
    model = idle.load_model(JAR)
    if model is None:
        raise RuntimeError("missing jellybean jar")
    writer = exporter.GltfWriter()
    writer.add_node(model, None)
    PROPS.mkdir(parents=True, exist_ok=True)
    path = PROPS / "jellybean_jar.glb"
    path.write_bytes(writer.pack("JellybeanJar"))
    print(f"jar meshes={writer.mesh_count} bytes={path.stat().st_size}", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    export_jar()
    export_bodies()
    export_ears()
    return 0


if __name__ == "__main__":
    sys.exit(main())
