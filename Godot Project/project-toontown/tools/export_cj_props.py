"""Export the Lawbot scale and gavel. The scale is assembled the way loadScaleNew does."""
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

import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cog_hq"

loadPrcFileData("", "model-cache-dir")
getModelPath().prependDirectory(Filename.from_os_specific(str(RESOURCES)))


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(RESOURCES / relative)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def write(model: NodePath, name: str) -> None:
    root = NodePath(Path(name).stem)
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(Path(name).stem)
    dest = OUT / name
    dest.write_bytes(payload)
    print("wrote", name, len(payload), flush=True)


def assemble_scale(model: NodePath) -> NodePath:
    beam = model.find("**/scaleBeam")
    defense = model.find("**/defensePan")
    prosecution = model.find("**/prosecutionPan")
    defense_at = model.find("**/DefenseLocator").getBounds().getCenter()
    prosecution_at = model.find("**/ProsecutionLocator").getBounds().getCenter()
    stand_at = model.find("**/StandLocator1").getBounds().getCenter()
    defense.setPos(defense_at)
    defense.reparentTo(beam)
    prosecution.setPos(prosecution_at)
    prosecution.reparentTo(beam)
    beam.setPos(stand_at)
    return model


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "props":
        write(load("phase_5/models/props/lawbook.bam"), "lawbook.glb")
        write(load("phase_11/models/lawbotHQ/JuryBoxChair.bam"), "jury_chair.glb")
        return
    write(assemble_scale(load("phase_11/models/lawbotHQ/scale.bam")), "lawbot_scale.glb")
    write(load("phase_11/models/lawbotHQ/LB_gavel.bam"), "lawbot_gavel.glb")


if __name__ == "__main__":
    main()
