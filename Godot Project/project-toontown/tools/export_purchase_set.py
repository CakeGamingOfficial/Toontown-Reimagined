"""Export the trolley purchase backdrop and the purchase-panel cards.

Purchase.enterReward stands the toon on the Toontown Central street. enterPurchase
swaps that for the phase 3.5 toon interior and the PurchasePanel inventory.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, PNMImage, Texture, getModelPath, loadPrcFileData

import export_minigames as games
import export_purchase_gui as cards
import export_toon_idle as idle
import export_toontown_central as exporter


GUI = Path(__file__).resolve().parents[1] / "assets" / "gui" / "purchase"


def load(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename(idle.ASSETS, relative))
    if node is None:
        print("missing", relative, flush=True)
        return None
    return NodePath(node)


def tint(node: NodePath, texture: str, color: tuple[float, float, float]) -> None:
    if node.isEmpty():
        print("missing paint", node, flush=True)
        return
    image = Texture()
    if image.read(Filename(idle.ASSETS, texture)):
        node.setTexture(image, 1)
    node.setColorScale(color[0], color[1], color[2], 1)


def place(root: NodePath, node: NodePath, name: str, pos, hpr=(0, 0, 0), scale=(1, 1, 1)) -> None:
    node.setName(name)
    node.setPosHprScale(pos[0], pos[1], pos[2], hpr[0], hpr[1], hpr[2], scale[0], scale[1], scale[2])
    node.reparentTo(root)


def bounds(found: NodePath) -> None:
    geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
    box = geom.getTightBounds() if not geom.isEmpty() else None
    if box is None:
        print(found.getName(), "no bounds", flush=True)
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
        flush=True,
    )


def crop(model: NodePath, search: str) -> None:
    found = model.find(search)
    if found.isEmpty():
        print("missing", search, flush=True)
        return
    bounds(found)
    tex = found.findTexture("*")
    geom = found if found.node().isGeomNode() else found.find("**/+GeomNode")
    box = cards.uv_bounds(geom)
    if tex is None or box is None:
        print("  no crop", search, flush=True)
        return
    image = PNMImage()
    if not tex.store(image):
        return
    u0, v0, u1, v1 = box
    x0 = max(int(u0 * image.getXSize()), 0)
    x1 = min(int(u1 * image.getXSize()) + 1, image.getXSize())
    y0 = max(int((1.0 - v1) * image.getYSize()), 0)
    y1 = min(int((1.0 - v0) * image.getYSize()) + 1, image.getYSize())
    channels = 4 if image.hasAlpha() else 3
    cropped = PNMImage(max(x1 - x0, 1), max(y1 - y0, 1), channels)
    cropped.copySubImage(image, 0, 0, x0, y0, cropped.getXSize(), cropped.getYSize())
    path = GUI / f"{found.getName()}.png"
    cropped.write(Filename.from_os_specific(str(path)))
    print("  wrote", path.name, cropped.getXSize(), cropped.getYSize(), flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    GUI.mkdir(parents=True, exist_ok=True)
    purchase = load("phase_4/models/gui/purchase_gui.bam")
    if purchase is not None:
        crop(purchase, "**/PurchasePanel")
        for name in ("Goofys_Sign", "Jar", "PurchScrn_BTN_UP"):
            found = purchase.find("**/" + name)
            if not found.isEmpty():
                bounds(found)
    clock = load("phase_3.5/models/gui/clock_gui.bam")
    if clock is not None:
        crop(clock, "**/alarm_clock")
    inventory = load("phase_3.5/models/gui/inventory_gui.bam")
    if inventory is not None:
        bounds(inventory.find("**/InventoryRow"))
    root = NodePath("purchase_set")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior = load("phase_3.5/models/modules/toon_interior.bam")
    if interior is not None:
        tint(interior.find("**/random_tc1_TI_wallpaper"), "phase_3.5/maps/wall_paper_a5.png", (0.8, 0.67, 0.549))
        tint(interior.find("**/random_tc1_TI_wallpaper_border"), "phase_3.5/maps/wall_paper_a5.png", (0.8, 0.67, 0.549))
        tint(interior.find("**/random_tc1_TI_wainscotting"), "phase_3.5/maps/wall_paper_b4.png", (0.473, 0.675, 0.488))
        place(root, interior, "Interior", (0.0, 5.0, -1.0))
    building = "phase_3.5/models/modules/TT_A1.bam"
    for name, pos in (
        ("Foreground", (12.5, -20.0, -5.5)),
        ("BackgroundL", (-12.5, -25.0, -5.0)),
        ("BackgroundR", (20.0, -25.0, -5.0)),
    ):
        model = load(building)
        if model is not None:
            place(root, model, name, pos, (180, 0, 0))
    streets = load("phase_3.5/models/modules/street_modules.bam")
    if streets is not None:
        sidewalk = streets.find("**/street_sidewalk_40x40")
        if not sidewalk.isEmpty():
            sidewalk = sidewalk.copyTo(NodePath())
            sidewalk.setColorScale(0.9, 0.6, 0.4, 1)
            place(root, sidewalk, "Sidewalk", (-20.0, -25.0, -5.5))
    doors = load("phase_4/models/modules/doors.bam")
    if doors is not None:
        door = doors.find("**/door_single_square_ur_door")
        if not door.isEmpty():
            door = door.copyTo(NodePath())
            door.setColorScale(1.0, 0.8, 0.0, 1)
            place(root, door, "Door", (0.0, -16.75, -5.5), (180, 0, 0), (1.5, 1.5, 2.0))
    games.write_root(root, "purchase_set")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
