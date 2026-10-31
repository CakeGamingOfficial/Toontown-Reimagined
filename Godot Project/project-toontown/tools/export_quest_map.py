"""Bake the street quest-map cards, the open and close button, and the arrow.

QuestMap loads phase_4/models/questmap/%s_maps and questmap_gui. Each street
card is its own texture. The four button states share questmaps_palette.
"""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, PNMImage, loadPrcFileData

ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "questmap"
loadPrcFileData("", "model-path " + Filename.from_os_specific(str(ASSETS)).get_fullpath())

MAPS = [
    "phase_4/models/questmap/toontown_central_maps.bam",
    "phase_4/models/questmap/donalds_dock_maps.bam",
    "phase_4/models/questmap/minnies_melody_land_maps.bam",
    "phase_4/models/questmap/the_burrrgh_maps.bam",
    "phase_4/models/questmap/daisys_garden_maps.bam",
    "phase_4/models/questmap/donalds_dreamland_maps.bam",
]


def load_model(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(ASSETS / relative)))
    if node is None:
        print("missing", relative)
        return None
    return NodePath(node)


def write_texture(tex, path: Path) -> None:
    image = PNMImage()
    if not tex.store(image):
        print("store failed", path.name)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    image.write(Filename.from_os_specific(str(path)))
    print("wrote", path.name, image.get_x_size(), image.get_y_size())


def bake_card(tex, u0: float, v0: float, u1: float, v1: float, path: Path, size: int = 128) -> None:
    source = PNMImage()
    tex.store(source)
    card = PNMImage(size, size, 4)
    card.alpha_fill(0)
    width = source.get_x_size()
    height = source.get_y_size()
    for y in range(size):
        # Card top is the high v corner. PNMImage row 0 is the top of the file.
        v = v1 + (v0 - v1) * ((y + 0.5) / size)
        for x in range(size):
            u = u0 + (u1 - u0) * ((x + 0.5) / size)
            sx = min(max(int(u * width), 0), width - 1)
            sy = min(max(int((1.0 - v) * height), 0), height - 1)
            card.set_xel(x, y, source.get_xel(sx, sy))
            card.set_alpha(x, y, source.get_alpha(sx, sy))
    path.parent.mkdir(parents=True, exist_ok=True)
    card.write(Filename.from_os_specific(str(path)))
    print("baked", path.name)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for relative in MAPS:
        root = load_model(relative)
        if root is None:
            continue
        for tex in root.find_all_textures():
            write_texture(tex, OUT / f"{tex.get_name()}.png")
    gui = load_model("phase_4/models/questmap/questmap_gui.bam")
    if gui is None:
        return
    palette = None
    for tex in gui.find_all_textures():
        if tex.get_name() == "tt_t_gui_qst_arrow":
            write_texture(tex, OUT / "tt_t_gui_qst_arrow.png")
        else:
            palette = tex
    cards = {
        "tt_t_gui_qst_mapClose": (0.0078125, 0.507813, 0.4921875, 0.992188),
        "tt_t_gui_qst_mapOpen": (0.507813, 0.507813, 0.992188, 0.992188),
        "tt_t_gui_qst_mapTryToClose": (0.0078125, 0.0078125, 0.4921875, 0.4921875),
        "tt_t_gui_qst_mapTryToOpen": (0.507813, 0.0078125, 0.992188, 0.4921875),
    }
    if palette is not None:
        for name, bounds in cards.items():
            bake_card(palette, bounds[0], bounds[1], bounds[2], bounds[3], OUT / f"{name}.png")
    party = load_model("phase_4/models/parties/schtickerbookHostingGUI.bam")
    if party is None:
        return
    marker = None
    for tex in party.find_all_textures():
        if tex.get_name() == "parties_stickerbook_palette_2tmla_1":
            marker = tex
    if marker is not None:
        bake_card(
            marker,
            0.515625,
            0.51810604,
            0.73288643,
            0.734375,
            OUT / "startPartyButton_inactive.png",
            64,
        )


if __name__ == "__main__":
    main()
