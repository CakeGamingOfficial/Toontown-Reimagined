"""Crop the DirectGui dialog card used by the minigame score panels."""
from __future__ import annotations

import os
import sys
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import Filename, Loader, NodePath, PNMImage, getModelPath, loadPrcFileData

import export_purchase_gui as cards
import export_toon_idle as idle

OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "minigames"


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    node = Loader.getGlobalPtr().loadSync(Filename(idle.ASSETS, "phase_3/models/gui/dialog_box_gui.bam"))
    if node is None:
        print("missing dialog")
        return 1
    model = NodePath(node)

    def walk(found: NodePath, depth: int = 0) -> None:
        if depth < 3:
            print("  " * depth + found.getName())
        for child in found.getChildren():
            walk(child, depth + 1)

    walk(model)
    found = model.find("**/+GeomNode")
    if found.isEmpty():
        print("no geom")
        return 1
    print("geom", found.getName())
    geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
    box = geom.getTightBounds()
    if box is not None:
        low, high = box
        print("bounds", round(high.x - low.x, 4), round(high.z - low.z, 4))
    tex = found.findTexture("*")
    bounds = cards.uv_bounds(geom)
    print("uv", bounds)
    image = PNMImage()
    if tex is None or not tex.store(image) or bounds is None:
        print("no image")
        return 1
    u0, v0, u1, v1 = bounds
    x0 = max(int(u0 * image.getXSize()), 0)
    x1 = min(int(u1 * image.getXSize()) + 1, image.getXSize())
    y0 = max(int((1.0 - v1) * image.getYSize()), 0)
    y1 = min(int((1.0 - v0) * image.getYSize()) + 1, image.getYSize())
    cropped = PNMImage(max(x1 - x0, 1), max(y1 - y0, 1))
    cropped.copySubImage(image, 0, 0, x0, y0, cropped.getXSize(), cropped.getYSize())
    cropped.addAlpha()
    for y in range(cropped.getYSize()):
        for x in range(cropped.getXSize()):
            cropped.setAlpha(x, y, 1.0)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "dialog_box.png"
    cropped.write(Filename.from_os_specific(str(path)))
    print("wrote", cropped.getXSize(), cropped.getYSize())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
