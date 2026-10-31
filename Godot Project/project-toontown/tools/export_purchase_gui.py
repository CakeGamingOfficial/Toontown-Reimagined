"""Save the trolley purchase-screen cards from purchase_gui.bam."""
from __future__ import annotations

import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, GeomVertexReader, Loader, NodePath, PNMImage, getModelPath, loadPrcFileData

import export_toon_idle as idle


def uv_bounds(found: NodePath):
    u0 = v0 = 1.0
    u1 = v1 = 0.0
    seen = False
    geom_node = found.node()
    if not geom_node.isGeomNode():
        return None
    for geom_index in range(geom_node.getNumGeoms()):
        vdata = geom_node.getGeom(geom_index).getVertexData()
        if not vdata.hasColumn("texcoord"):
            continue
        reader = GeomVertexReader(vdata, "texcoord")
        while not reader.isAtEnd():
            point = reader.getData2f()
            u0 = min(u0, point.x)
            v0 = min(v0, point.y)
            u1 = max(u1, point.x)
            v1 = max(v1, point.y)
            seen = True
    if not seen:
        return None
    return (u0, v0, u1, v1)


OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "purchase"
NAMES = (
    "**/Goofys_Sign",
    "**/Jar",
    "**/PurchScrn_BTN_UP",
    "**/PurchScrn_BTN_DN",
    "**/PurchScrn_BTN_RLVR",
)


def _punch_white(image: PNMImage) -> None:
    """The jar is painted on a white page. Clear only the page outside the glass."""
    width = image.getXSize()
    height = image.getYSize()
    image.addAlpha()
    page = [[False] * width for _row in range(height)]
    for y in range(height):
        for x in range(width):
            image.setAlpha(x, y, 1.0)
            red = image.getRed(x, y)
            green = image.getGreen(x, y)
            blue = image.getBlue(x, y)
            page[y][x] = min(red, green, blue) > 0.90 and max(red, green, blue) - min(red, green, blue) < 0.08
    seen = [[False] * width for _row in range(height)]
    stack: list[tuple[int, int]] = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= width or y >= height or seen[y][x] or not page[y][x]:
            continue
        seen[y][x] = True
        image.setAlpha(x, y, 0.0)
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    node = Loader.getGlobalPtr().loadSync(Filename(idle.ASSETS, "phase_4/models/gui/purchase_gui.bam"))
    if node is None:
        print("missing purchase_gui")
        return 1
    model = NodePath(node)
    OUT.mkdir(parents=True, exist_ok=True)
    for search in NAMES:
        found = model.find(search)
        print(search, "empty" if found.isEmpty() else found.getName())
        if found.isEmpty():
            continue
        tex = found.findTexture("*")
        if tex is None:
            print("  no texture")
            continue
        geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
        bounds = uv_bounds(geom if not geom.isEmpty() else found)
        print("  uv", bounds, tex.getXSize(), tex.getYSize())
        if bounds is None:
            continue
        image = PNMImage()
        if not tex.store(image):
            print("  store failed")
            continue
        u0, v0, u1, v1 = bounds
        x0 = max(int(u0 * image.getXSize()), 0)
        x1 = min(int(u1 * image.getXSize()) + 1, image.getXSize())
        # Panda v=0 is the bottom of the image. PNMImage y=0 is the top.
        y0 = max(int((1.0 - v1) * image.getYSize()), 0)
        y1 = min(int((1.0 - v0) * image.getYSize()) + 1, image.getYSize())
        channels = 4 if image.hasAlpha() else 3
        cropped = PNMImage(max(x1 - x0, 1), max(y1 - y0, 1), channels)
        cropped.copySubImage(image, 0, 0, x0, y0, cropped.getXSize(), cropped.getYSize())
        if found.getName() == "Jar":
            _punch_white(cropped)
        path = OUT / f"{found.getName()}.png"
        cropped.write(Filename.from_os_specific(str(path)))
        print("  wrote", path.name, cropped.getXSize(), cropped.getYSize())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
