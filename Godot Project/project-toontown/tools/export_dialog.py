"""Crop the original acknowledge dialog and its OK button into PNGs."""
from __future__ import annotations

from pathlib import Path

from panda3d.core import (
    Filename,
    GeomNode,
    GeomVertexReader,
    Loader,
    NodePath,
    PNMImage,
    Texture,
    TextureAttrib,
    getModelPath,
    loadPrcFileData,
)

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
DEST = Path(__file__).resolve().parents[1] / "assets" / "gui" / "tutorial" / "dialog"


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def texture_on(node: NodePath):
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
        source = tex.getFilename()
        if source.empty() or not loaded.read(source):
            full = tex.getFullpath()
            if full.empty() or not loaded.read(full):
                raise RuntimeError(path.name + " texture did not load")
        tex = loaded
    image = PNMImage()
    if not tex.store(image):
        raise RuntimeError(path.name + " store failed")
    width = image.getXSize()
    height = image.getYSize()
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
    if us:
        u0, u1 = min(us), max(us)
        v0, v1 = min(vs), max(vs)
    else:
        u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
    # Panda images are top-down once stored. Texture V grows up, so flip it.
    x0 = max(0, min(width - 1, int(u0 * width)))
    x1 = max(x0 + 1, min(width, int(round(u1 * width))))
    y_top = max(0, min(height - 1, int((1.0 - v1) * height)))
    y_bot = max(y_top + 1, min(height, int(round((1.0 - v0) * height))))
    cropped = PNMImage(x1 - x0, y_bot - y_top, image.getNumChannels(), image.getMaxval())
    cropped.copySubImage(image, 0, 0, x0, y_top, x1 - x0, y_bot - y_top)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not cropped.write(Filename.from_os_specific(str(path))):
        raise RuntimeError("write failed " + str(path))
    print("card", path.name, cropped.getXSize(), cropped.getYSize(), flush=True)


def dump(relative: str) -> NodePath:
    root = load(relative)
    print("MODEL", relative, flush=True)
    for child in root.findAllMatches("**"):
        kind = "geom" if child.node().isOfType(GeomNode.getClassType()) else child.node().getType().getName()
        print(" ", child.getName(), kind, flush=True)
    return root


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    box = dump("phase_3/models/gui/dialog_box_gui.bam")
    buttons = dump("phase_3/models/gui/dialog_box_buttons_gui.bam")
    crop_card(box, DEST / "dialog_box.png")
    for name in ("ChtBx_OKBtn_UP", "ChtBx_OKBtn_DN", "ChtBx_OKBtn_Rllvr"):
        node = buttons.find("**/" + name)
        if node.isEmpty():
            print("missing", name, flush=True)
            continue
        crop_card(node, DEST / (name + ".png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
