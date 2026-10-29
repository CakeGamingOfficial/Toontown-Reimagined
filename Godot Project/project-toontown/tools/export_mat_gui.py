"""Crop the Make a Toon name panel and the yellow dialog cards from the original GUI."""
from __future__ import annotations

import sys
from pathlib import Path

from panda3d.core import Filename, GeomNode, GeomVertexReader, Loader, NodePath, Texture, TextureAttrib, getModelPath, loadPrcFileData

import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "toons" / "gui"
SOURCES = [
    "phase_3/models/gui/tt_m_gui_mat_nameShop.bam",
    "phase_3/models/gui/dialog_box_gui.bam",
    "phase_3/models/gui/dialog_box_buttons_gui.bam",
]


def load_model(relative: str) -> NodePath:
    loaded = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(ASSETS / relative)))
    if loaded is None:
        raise RuntimeError(f"missing {relative}")
    return NodePath(loaded)


def card_png(card: NodePath) -> bytes | None:
    node = card.node()
    if not isinstance(node, GeomNode) or node.getNumGeoms() == 0:
        return None
    state = node.getGeomState(0)
    attrib = state.getAttrib(TextureAttrib.getClassSlot())
    if attrib is None or attrib.getNumOnStages() == 0:
        return None
    source = attrib.getOnTexture(attrib.getOnStage(0))
    tex = Texture()
    filename = source.getFullpath()
    if filename.empty():
        filename = source.getFilename()
    if filename.empty() or not tex.read(filename):
        if not source.hasRamImage():
            return None
        tex = source
    if not tex.hasRamImage():
        return None
    raw = bytes(tex.getRamImageAs("RGBA"))
    width = tex.getXSize()
    height = tex.getYSize()
    if len(raw) != width * height * 4:
        return None
    vdata = node.getGeom(0).getVertexData()
    if not vdata.hasColumn("texcoord"):
        return exporter.encode_rgba_png(raw, width, height)
    reader = GeomVertexReader(vdata, "texcoord")
    us = []
    vs = []
    for row in range(vdata.getNumRows()):
        reader.setRow(row)
        u, v = reader.getData2()
        us.append(u)
        vs.append(v)
    pad = 1
    x0 = max(int(min(us) * width) - pad, 0)
    x1 = min(int(max(us) * width) + pad + 1, width)
    y0 = max(int(min(vs) * height) - pad, 0)
    y1 = min(int(max(vs) * height) + pad + 1, height)
    if x1 <= x0 or y1 <= y0:
        return exporter.encode_rgba_png(raw, width, height)
    cropped = bytearray()
    row_bytes = width * 4
    for y in range(y0, y1):
        start = y * row_bytes + x0 * 4
        cropped.extend(raw[start:start + (x1 - x0) * 4])
    return exporter.encode_rgba_png(bytes(cropped), x1 - x0, y1 - y0)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT.mkdir(parents=True, exist_ok=True)
    for relative in SOURCES:
        model = load_model(relative)
        cards = model.findAllMatches("**/+GeomNode")
        for index in range(cards.getNumPaths()):
            card = cards.getPath(index)
            png = card_png(card)
            if png is None:
                print("no image", card.getName())
                continue
            target = OUT / f"{exporter.sanitize(card.getName())}.png"
            target.write_bytes(png)
            print("card", target.name, len(png))
        model.removeNode()
    return 0


if __name__ == "__main__":
    sys.exit(main())
