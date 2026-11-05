"""Export the Cashbot HQ yard trains.

CashbotHQExterior runs four Train actors. The locomotive and the three car
bodies are phase_10 cogHQ models. Collision nodes are hidden; the yard script
puts one box around the cars it spawns.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import CollisionNode, Filename, Loader, NodePath, getModelPath, loadPrcFileData

loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
loadPrcFileData("", "default-model-extension .bam")

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "cog_hq" / "trains"
MODELS = (
    "phase_10/models/cogHQ/CashBotLocomotive.bam",
    "phase_10/models/cogHQ/CashBotBoxCar.bam",
    "phase_10/models/cogHQ/CashBotTankCar.bam",
    "phase_10/models/cogHQ/CashBotFlatCar.bam",
)


def hide_collision(root: NodePath) -> None:
    matches = root.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        if path.node().isOfType(CollisionNode.getClassType()):
            path.hide()


def main() -> int:
    getModelPath().prependDirectory(ASSETS)
    loader = Loader.getGlobalPtr()
    OUT.mkdir(parents=True, exist_ok=True)
    for relative in MODELS:
        loaded = loader.loadSync(Filename(relative))
        if loaded is None:
            raise RuntimeError("missing " + relative)
        node = NodePath(loaded)
        hide_collision(node)
        low, high = node.getTightBounds()
        print(relative, "bounds", tuple(round(v, 2) for v in low), tuple(round(v, 2) for v in high))
        root = NodePath(node.getName())
        root.setMat(exporter.Z_UP_TO_Y_UP)
        node.copyTo(root)
        writer = exporter.GltfWriter()
        writer.add_node(root, None)
        dest = OUT / f"{node.getName()}.glb"
        dest.write_bytes(writer.pack(node.getName()))
        print("wrote", dest.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
