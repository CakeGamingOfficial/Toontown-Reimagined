"""Export KartShop_Interior the way DistributedKartShopInterior does.

The room is phase_6/models/karting/KartShop_Interior. Both practical doors
and the four npc origins stay. Collision helpers stay out of the file.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import CollisionNode, Filename, Loader, NodePath, getModelPath, loadPrcFileData

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_gag_shop as shop
import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "interiors" / "kart_shop" / "kart_shop.glb"


def hide_helpers(root: NodePath) -> None:
    matches = root.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        name = path.getName()
        low = name.lower()
        if (
            "collision" in low
            or low.startswith("coll-")
            or low.startswith("coll_")
            or low.endswith("_c")
            or "trigger" in low
        ):
            path.hide()
        if path.node().isOfType(CollisionNode.getClassType()):
            path.hide()


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)
    interior = shop.load_model("phase_6/models/karting/KartShop_Interior.bam")
    interior.setName("KartShop")
    hide_helpers(interior)
    low, high = interior.getTightBounds()
    print(
        "bounds",
        tuple(round(v, 2) for v in low),
        tuple(round(v, 2) for v in high),
    )
    root = NodePath("KartShop")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    shop.write_glb(root, OUT, "KartShop")
    return 0


if __name__ == "__main__":
    sys.exit(main())
