"""Crop the minigame rules panel and the green Play button."""
from __future__ import annotations

import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, PNMImage, getModelPath, loadPrcFileData

import export_purchase_gui as cards
import export_toon_idle as idle


OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "rules"


def load(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename(idle.ASSETS, relative))
    if node is None:
        print("missing", relative)
        return None
    return NodePath(node)


def describe(found: NodePath) -> None:
    geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
    if geom.isEmpty():
        print(found.getName(), "no geom")
        return
    box = geom.getTightBounds()
    if box is None:
        print(found.getName(), "no bounds")
        return
    low, high = box
    print(
        found.getName(),
        "size",
        round(high.x - low.x, 4),
        round(high.z - low.z, 4),
        "center",
        round((low.x + high.x) * 0.5, 4),
        round((low.z + high.z) * 0.5, 4),
    )


def punch_panel(image: PNMImage) -> None:
    """The card is painted on a gray page. Clear only the page outside the frame."""
    width = image.getXSize()
    height = image.getYSize()
    image.addAlpha()
    card = [[False] * width for _row in range(height)]
    for y in range(height):
        for x in range(width):
            # addAlpha starts every pixel clear, so the card itself has to be marked opaque.
            image.setAlpha(x, y, 1.0)
            red = image.getRed(x, y)
            green = image.getGreen(x, y)
            blue = image.getBlue(x, y)
            white = min(red, green, blue) > 0.82
            yellow = red > 0.55 and green > 0.45 and blue < 0.55 and red + green > blue * 2.2
            frame = blue > red + 0.04 and blue > 0.35
            card[y][x] = white or yellow or frame
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
        if x < 0 or y < 0 or x >= width or y >= height or seen[y][x] or card[y][x]:
            continue
        seen[y][x] = True
        image.setAlpha(x, y, 0.0)
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))


def punch_button(image: PNMImage) -> None:
    """Inventory buttons sit on black. Black is the transparent margin."""
    image.addAlpha()
    for y in range(image.getYSize()):
        for x in range(image.getXSize()):
            image.setAlpha(x, y, max(image.getRed(x, y), image.getGreen(x, y), image.getBlue(x, y)))


def crop(found: NodePath) -> None:
    describe(found)
    tex = found.findTexture("*")
    geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
    box = cards.uv_bounds(geom)
    if tex is None or box is None:
        print("  no crop")
        return
    image = PNMImage()
    if not tex.store(image):
        return
    u0, v0, u1, v1 = box
    x0 = max(int(u0 * image.getXSize()), 0)
    x1 = min(int(u1 * image.getXSize()) + 1, image.getXSize())
    y0 = max(int((1.0 - v1) * image.getYSize()), 0)
    y1 = min(int((1.0 - v0) * image.getYSize()) + 1, image.getYSize())
    cropped = PNMImage(max(x1 - x0, 1), max(y1 - y0, 1))
    cropped.copySubImage(image, 0, 0, x0, y0, cropped.getXSize(), cropped.getYSize())
    if found.getName() == "minigame-rules-panel":
        punch_panel(cropped)
    else:
        punch_button(cropped)
    path = OUT / f"{found.getName()}.png"
    cropped.write(Filename.from_os_specific(str(path)))
    print("  wrote", path.name, cropped.getXSize(), cropped.getYSize())


def walk(node: NodePath, depth: int = 0) -> None:
    if depth < 3:
        print("  " * depth + node.getName())
    for child in node.getChildren():
        walk(child, depth + 1)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    rules = load("phase_4/models/gui/minigame_rules_gui.bam")
    if rules is not None:
        walk(rules)
        panel = rules.find("**/minigame-rules-panel")
        if not panel.isEmpty():
            crop(panel)
    buttons = load("phase_3.5/models/gui/inventory_gui.bam")
    if buttons is not None:
        for name in ("InventoryButtonUp", "InventoryButtonDown", "InventoryButtonRollover"):
            found = buttons.find("**/" + name)
            if not found.isEmpty():
                crop(found)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
