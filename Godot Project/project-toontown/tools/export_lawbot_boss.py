"""Export the Lawbot Chief Justice from the shared boss body and his own head and torso."""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

PANDA = Path(r"C:\Panda3D-1.10.16-x64")
os.environ["PATH"] = str(PANDA / "bin") + os.pathsep + os.environ.get("PATH", "")
if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_make_a_toon as toon_export
import export_sellbot_vp as vp
import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "lawbot_cj.glb"

loadPrcFileData("", "model-cache-dir")
getModelPath().prependDirectory(Filename.from_os_specific(str(RESOURCES)))


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(RESOURCES / relative)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def try_pose(model: NodePath, relative: str) -> None:
    try:
        vp.pose(model, relative)
    except Exception as exc:
        print("pose skipped", relative, exc)


def main() -> None:
    legs = load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = load("phase_11/models/char/lawbotBoss-torso-zero.bam")
    head = load("phase_11/models/char/lawbotBoss-head-zero.bam")
    treads = load("phase_9/models/char/bossCog-treads.bam")
    try_pose(legs, "phase_9/models/char/bossCog-legs-Ff_neutral.bam")
    try_pose(torso, "phase_9/models/char/bossCog-torso-Ff_neutral.bam")
    try_pose(head, "phase_9/models/char/bossCog-head-Ff_neutral.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    if pelvis.isEmpty() or neck.isEmpty() or axle.isEmpty():
        raise RuntimeError("missing pelvis, joint34, or axle")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    legs.setH(180)
    vp._hinge(legs, "joint_doorFront", "DoorFront", (0, 0, -80))
    vp._hinge(legs, "joint_doorRear", "DoorRear", (0, 0, 80))
    toon_export.bake_skinning(legs)
    root = NodePath("LawbotCJ")
    legs.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(writer.pack("LawbotCJ"))
    print("wrote", OUT, "meshes", writer.mesh_count, "bytes", OUT.stat().st_size)


if __name__ == "__main__":
    main()
