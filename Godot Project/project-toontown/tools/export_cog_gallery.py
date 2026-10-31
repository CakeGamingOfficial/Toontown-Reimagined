"""Export the Cog Gallery page: suit heads, the wooden frame, and the cards.

SuitPage builds that page from phase_3.5/models/gui/suitpage_frame, suitpage_gui,
and the suitA/B/C head models. want-new-cogs is off, so the heads come from
suitA-heads, suitB-heads, and suitC-heads. A replaced head texture is baked
on here the same way Suit.generateHead does.
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
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import (
    Filename,
    GeomVertexReader,
    NodePath,
    PNMImage,
    TexturePool,
    Vec4,
    getModelPath,
    loadPrcFileData,
)

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "assets" / "gui" / "shticker" / "gallery"
HEADS = ROOT / "assets" / "cogs" / "heads"

SUIT_A = "phase_4/models/char/suitA-heads.bam"
SUIT_B = "phase_4/models/char/suitB-heads.bam"
SUIT_C = "phase_3.5/models/char/suitC-heads.bam"

# Suit.generateSuit order, which is suitHeadTypes. Texture paths use the
# head model's phase, matching generateHead.
GALLERY = (
    ("f", SUIT_C, ("flunky", "glasses"), ""),
    ("p", SUIT_B, ("pencilpusher",), ""),
    ("ym", SUIT_A, ("yesman",), ""),
    ("mm", SUIT_C, ("micromanager",), ""),
    ("ds", SUIT_B, ("beancounter",), ""),
    ("hh", SUIT_A, ("headhunter",), ""),
    ("cr", SUIT_C, ("flunky",), "phase_3.5/maps/corporate-raider.png"),
    ("tbc", SUIT_A, ("bigcheese",), ""),
    ("bf", SUIT_C, ("tightwad",), "phase_3.5/maps/bottom-feeder.png"),
    ("b", SUIT_B, ("movershaker",), "phase_4/maps/blood-sucker.png"),
    ("dt", SUIT_A, ("twoface",), "phase_4/maps/double-talker.png"),
    ("ac", SUIT_B, ("ambulancechaser",), ""),
    ("bs", SUIT_A, ("backstabber",), ""),
    ("sd", SUIT_B, ("telemarketer",), "phase_4/maps/spin-doctor.png"),
    ("le", SUIT_A, ("legaleagle",), ""),
    ("bw", SUIT_A, ("bigwig",), ""),
    ("sc", SUIT_C, ("coldcaller",), ""),
    ("pp", SUIT_A, ("pennypincher",), ""),
    ("tw", SUIT_C, ("tightwad",), ""),
    ("bc", SUIT_B, ("beancounter",), ""),
    ("nc", SUIT_A, ("numbercruncher",), ""),
    ("mb", SUIT_C, ("moneybags",), ""),
    ("ls", SUIT_B, ("loanshark",), ""),
    ("rb", SUIT_A, ("yesman",), "phase_4/maps/robber-baron.png"),
    ("cc", SUIT_C, ("coldcaller",), ""),
    ("tm", SUIT_B, ("telemarketer",), ""),
    ("nd", SUIT_A, ("numbercruncher",), "phase_4/maps/name-dropper.png"),
    ("gh", SUIT_C, ("gladhander",), ""),
    ("ms", SUIT_B, ("movershaker",), ""),
    ("tf", SUIT_A, ("twoface",), ""),
    ("m", SUIT_A, ("twoface",), "phase_4/maps/mingler.png"),
    ("mh", SUIT_A, ("yesman",), ""),
)

# Cold Caller tints the head. Suit.generateSuit sets this before generateHead.
COLD_CALLER = Vec4(0.25, 0.35, 1.0, 1.0)


def uv_bounds(np: NodePath):
    geom_np = np if np.node().isGeomNode() else np.find("**/+GeomNode")
    if geom_np.isEmpty():
        return None
    vdata = geom_np.node().getGeom(0).getVertexData()
    reader = GeomVertexReader(vdata, "texcoord")
    if not vdata.hasColumn("texcoord"):
        return None
    u0 = v0 = 9.0
    u1 = v1 = -9.0
    while not reader.isAtEnd():
        point = reader.getData2()
        u0 = min(u0, point.x)
        u1 = max(u1, point.x)
        v0 = min(v0, point.y)
        v1 = max(v1, point.y)
    return u0, v0, u1, v1


def crop(np: NodePath, dest: Path) -> None:
    tex = np.findTexture("*")
    if tex is None:
        print("no texture", dest.name, flush=True)
        return
    bounds = uv_bounds(np)
    image = PNMImage()
    if not tex.store(image):
        print("store failed", dest.name, flush=True)
        return
    if bounds is None:
        x0, y0 = 0, 0
        x1, y1 = image.getXSize(), image.getYSize()
    else:
        u0, v0, u1, v1 = bounds
        x0 = max(int(u0 * image.getXSize()), 0)
        x1 = min(int(u1 * image.getXSize()) + 1, image.getXSize())
        # Panda v=0 is the bottom of the image. PNMImage y=0 is the top.
        y0 = max(int((1.0 - v1) * image.getYSize()), 0)
        y1 = min(int((1.0 - v0) * image.getYSize()) + 1, image.getYSize())
    channels = 4 if image.hasAlpha() else 3
    cropped = PNMImage(max(x1 - x0, 1), max(y1 - y0, 1), channels)
    cropped.copySubImage(image, 0, 0, x0, y0, cropped.getXSize(), cropped.getYSize())
    dest.parent.mkdir(parents=True, exist_ok=True)
    cropped.write(Filename.from_os_specific(str(dest)))
    print(dest.name, cropped.getXSize(), cropped.getYSize(), "alpha" if channels == 4 else "rgb", flush=True)


def write_head(root: NodePath, code: str) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path = HEADS / f"{code}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(writer.pack(code))
    print(f"{code} meshes={writer.mesh_count}", flush=True)


def export_gui() -> None:
    frame = idle.load_model("phase_3.5/models/gui/suitpage_frame.bam")
    crop(frame.find("**/frame"), GUI / "frame.png")
    for name in ("corp_icon", "legal_icon", "money_icon", "sales_icon"):
        crop(frame.find("**/" + name), GUI / f"{name}.png")
    gui = idle.load_model("phase_3.5/models/gui/suitpage_gui.bam")
    crop(gui.find("**/card"), GUI / "card.png")
    for index in range(1, 33):
        crop(gui.find("**/shadow%d" % index), GUI / ("shadow_%d.png" % index))
    gear = idle.load_model("phase_3.5/models/gui/sos_textures.bam")
    crop(gear.find("**/gui_gear"), GUI / "tab_gear.png")


def export_heads() -> None:
    cache: dict[str, NodePath] = {}
    for code, bam, nodes, texture in GALLERY:
        if bam not in cache:
            cache[bam] = idle.load_model(bam)
        model = cache[bam]
        root = NodePath(code)
        root.setMat(exporter.Z_UP_TO_Y_UP)
        tex = TexturePool.loadTexture(Filename(idle.ASSETS, texture)) if texture else None
        if texture and tex is None:
            print("missing texture", texture, flush=True)
        kept = 0
        for node_name in nodes:
            piece = model.find("**/" + node_name)
            if piece.isEmpty():
                print("missing head", node_name, flush=True)
                continue
            # attachSuitHead yaws the head 180 so it faces the book camera.
            copied = piece.copyTo(root)
            copied.setHpr(180, 0, 0)
            if tex is not None:
                copied.setTexture(tex, 1)
            if code == "cc":
                copied.setColor(COLD_CALLER)
            kept += 1
        if kept:
            write_head(root, code)


def main() -> None:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    export_gui()
    export_heads()


if __name__ == "__main__":
    main()
