"""Export the estate garden mounds, flowers, gag-tree stages, and one statue."""
from __future__ import annotations

import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "estate" / "garden"
RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")

MODELS = [
    "dirt_mound.bam",
    "sand_mound.bam",
    "garden_slab.bam",
    "seedling.bam",
    "daisy.bam",
    "tulip.bam",
    "carnation.bam",
    "lily.bam",
    "narcissi.bam",
    "pansy.bam",
    "petunia.bam",
    "rose.bam",
    "gag_tree_stages.bam",
    "garden_mickey_shovel.bam",
]


def load_prop(name: str):
    relative = "phase_5.5/models/estate/" + name
    model = idle.load_model(relative)
    if model is not None:
        return model
    path = RESOURCES / "phase_5.5" / "models" / "estate" / name
    node = idle.Loader.getGlobalPtr().loadSync(idle.Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path)
        return None
    return idle.NodePath(node)


def export_one(name: str) -> None:
    model = load_prop(name)
    if model is None:
        return
    root = NodePath(name.replace(".bam", ""))
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path = OUT / (name.replace(".bam", "") + ".glb")
    path.write_bytes(writer.pack(root.getName()))
    names = []

    def walk(node: NodePath) -> None:
        names.append(node.getName())
        for child in node.getChildren():
            walk(child)

    walk(model)
    print(f"{path.name} meshes={writer.mesh_count} nodes={len(names)} bytes={path.stat().st_size}", flush=True)
    print("  ", ", ".join(names[:24]), flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    source = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
    idle.ASSETS = Filename.from_os_specific(str(source))
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in MODELS:
        export_one(name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
