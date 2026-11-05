"""Export the Bossbot HQ golf cart.

DistributedCogKart loads phase_12 Coggolf_cart3 and parks three of them on
the country club. Collision nodes stay out of the mesh; the scene adds one box.
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
OUT = ROOT / "assets" / "cog_hq" / "cog_golf_cart.glb"
MODEL = "phase_12/models/bossbotHQ/Coggolf_cart3.bam"


def hide_collision(root: NodePath) -> None:
    matches = root.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        if path.node().isOfType(CollisionNode.getClassType()):
            path.hide()


def main() -> int:
    getModelPath().prependDirectory(ASSETS)
    loader = Loader.getGlobalPtr()
    loaded = loader.loadSync(Filename(MODEL))
    if loaded is None:
        raise RuntimeError("missing " + MODEL)
    node = NodePath(loaded)
    hide_collision(node)
    low, high = node.getTightBounds()
    print("bounds", tuple(round(v, 3) for v in low), tuple(round(v, 3) for v in high))
    names = []
    matches = node.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        name = matches.getPath(index).getName()
        if name and name not in names:
            names.append(name)
    print("names", ", ".join(names))
    root = NodePath("CogGolfCart")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    node.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(writer.pack("CogGolfCart"))
    print("wrote", OUT.name, OUT.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
