"""Crop the original SpeedChat button, arrow, and emotion icon.

Uses stock Panda. These GUI bams do not need the Toontown DNA loader.
"""
from __future__ import annotations

import os
import struct
import sys
import zlib
from pathlib import Path

BIN = r"C:\Panda3D-1.10.16-x64\bin"
os.environ["PATH"] = BIN + os.pathsep + os.environ.get("PATH", "")

from panda3d.core import (  # noqa: E402
    Filename,
    GeomNode,
    GeomVertexReader,
    Loader,
    NodePath,
    Texture,
    TextureAttrib,
    getModelPath,
    loadPrcFileData,
)

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "speedchat"


def encode_rgba_png(raw: bytes, width: int, height: int) -> bytes:
    row_bytes = width * 4

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    rows = bytearray()
    for y in range(height - 1, -1, -1):
        rows.append(0)
        start = y * row_bytes
        rows.extend(raw[start:start + row_bytes])
    return b"".join([
        b"\x89PNG\r\n\x1a\n",
        chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(bytes(rows), 6)),
        chunk(b"IEND", b""),
    ])


def texture_on(node: NodePath) -> Texture | None:
    geom_node = node.node()
    if geom_node.isOfType(GeomNode.getClassType()):
        for index in range(geom_node.getNumGeoms()):
            attrib = geom_node.getGeomState(index).getAttrib(TextureAttrib.getClassSlot())
            if attrib is not None and attrib.getNumOnStages() > 0:
                return attrib.getOnTexture(attrib.getOnStage(0))
    attrib = node.getNetState().getAttrib(TextureAttrib.getClassSlot())
    if attrib is None or attrib.getNumOnStages() == 0:
        return None
    return attrib.getOnTexture(attrib.getOnStage(0))


def crop_card(node: NodePath, path: Path) -> None:
    geom_node = node.node()
    if not geom_node.isOfType(GeomNode.getClassType()):
        found = node.find("**/+GeomNode")
        if found.isEmpty():
            raise RuntimeError(path.name + " has no geometry")
        node = found
        geom_node = node.node()
    tex = texture_on(node)
    if tex is None:
        raise RuntimeError(path.name + " has no texture")
    if not tex.hasRamImage():
        loaded = Texture()
        filename = tex.getFullpath()
        if filename.empty():
            filename = tex.getFilename()
        if not loaded.read(filename):
            raise RuntimeError(path.name + " texture did not load")
        tex = loaded
    raw = bytes(tex.getRamImageAs("RGBA"))
    width = tex.getXSize()
    height = tex.getYSize()
    us = []
    vs = []
    for geom_index in range(geom_node.getNumGeoms()):
        vdata = geom_node.getGeom(geom_index).getVertexData()
        if not vdata.hasColumn("texcoord"):
            continue
        reader = GeomVertexReader(vdata, "texcoord")
        for row in range(vdata.getNumRows()):
            reader.setRow(row)
            u, v = reader.getData2()
            us.append(u)
            vs.append(v)
        break
    u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
    if us:
        u0, u1 = min(us), max(us)
        v0, v1 = min(vs), max(vs)
    x0 = max(0, min(width - 1, int(u0 * width)))
    x1 = max(x0 + 1, min(width, int(round(u1 * width))))
    y0 = max(0, min(height - 1, int(v0 * height)))
    y1 = max(y0 + 1, min(height, int(round(v1 * height))))
    cropped_w = x1 - x0
    cropped_h = y1 - y0
    rows = bytearray()
    for y in range(y0, y1):
        start = (y * width + x0) * 4
        rows.extend(raw[start:start + cropped_w * 4])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encode_rgba_png(bytes(rows), cropped_w, cropped_h))
    print(f"card {path.name} {cropped_w}x{cropped_h}", flush=True)


def cards(relative: str, names: tuple[str, ...]) -> None:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    model = NodePath(node)
    print(relative)
    for name in names:
        found = model.find("**/" + name)
        if found.isEmpty():
            print("missing", name)
            continue
        crop_card(found, OUT / f"{name}.png")


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    cards("phase_3.5/models/gui/chat_input_gui.bam", ("ChtBx_ChtBtn_UP", "ChtBx_ChtBtn_DN", "ChtBx_ChtBtn_RLVR"))
    cards("phase_3.5/models/gui/speedChatGui.bam", ("chatArrow", "emotionIcon"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
