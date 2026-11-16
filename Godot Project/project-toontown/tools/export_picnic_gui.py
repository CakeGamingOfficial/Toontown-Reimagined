"""Crop the picnic game menu buttons and the how-to page cards.

GameMenu uses phase_6/models/golf/picnic_game_menu.bam. ChineseTutorial uses
checker_tutorial.bam. CheckersTutorial uses regularchecker_tutorial.bam.
"""

import json
import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, GeomNode, PNMImage, Point3, TextureAttrib, getModelPath, loadPrcFileData

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "picnic"
MODELS = (
    "picnic_game_menu",
    "checker_tutorial",
    "regularchecker_tutorial",
)


def export_model(model_name: str) -> list:
    model = base.loader.loadModel("phase_6/models/golf/%s.bam" % model_name)
    if model is None:
        raise SystemExit("missing " + model_name)
    found = []
    for node_path in model.findAllMatches("**"):
        node = node_path.node()
        if not node.isOfType(GeomNode.getClassType()) or node.getNumGeoms() == 0:
            continue
        state = node.getGeomState(0)
        attrib = state.getAttrib(TextureAttrib.getClassSlot())
        if attrib is None or attrib.getNumOnStages() == 0:
            continue
        texture = attrib.getOnTexture(attrib.getOnStage(0))
        image = PNMImage()
        if texture is None or not texture.store(image):
            continue
        geom = node.getGeom(0)
        vdata = geom.getVertexData()
        if not vdata.hasColumn("texcoord"):
            continue
        positions = exporter.read_column(vdata, "vertex", exporter.copy3)
        uvs = exporter.read_column(vdata, "texcoord", exporter.copy2)
        triangles = exporter.triangle_indices(geom)
        if len(triangles) < 3:
            continue
        net = node_path.getMat(model)
        xs = []
        zs = []
        us = []
        vs = []
        for index in triangles:
            point = net.xformPoint(Point3(*positions[index]))
            xs.append(point.x)
            zs.append(point.z)
            us.append(uvs[index][0])
            vs.append(uvs[index][1])
        u0, u1 = max(0.0, min(us)), min(1.0, max(us))
        v0, v1 = max(0.0, min(vs)), min(1.0, max(vs))
        width = image.getXSize()
        height = image.getYSize()
        x0 = int(u0 * (width - 1))
        x1 = int(u1 * (width - 1))
        y0 = int((1.0 - v1) * (height - 1))
        y1 = int((1.0 - v0) * (height - 1))
        if x1 <= x0 or y1 <= y0:
            continue
        crop = PNMImage(x1 - x0 + 1, y1 - y0 + 1, image.getNumChannels())
        crop.copySubImage(image, 0, 0, x0, y0, crop.getXSize(), crop.getYSize())
        parts = []
        walk = node_path
        while not walk.isEmpty() and walk != model:
            part = walk.getName()
            if part and part not in parts:
                parts.append(part)
            walk = walk.getParent()
        label = "_".join(reversed(parts)) or "card"
        card = "%s_%s_%d" % (model_name, label, len(found))
        crop.write(Filename.fromOsSpecific(str(OUT / ("%s.png" % card))))
        found.append({
            "name": label,
            "file": "%s.png" % card,
            "x": round((min(xs) + max(xs)) * 0.5, 4),
            "z": round((min(zs) + max(zs)) * 0.5, 4),
            "w": round(max(xs) - min(xs), 4),
            "h": round(max(zs) - min(zs), 4),
        })
        print(card, found[-1]["w"], found[-1]["h"], crop.getXSize(), crop.getYSize())
    model.removeNode()
    return found


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cards = {}
    for name in MODELS:
        cards[name] = export_model(name)
    (OUT / "cards.json").write_text(json.dumps(cards, indent=1), encoding="utf-8")


loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
getModelPath().prependDirectory(ASSETS)
from direct.showbase.ShowBase import ShowBase
ShowBase()
main()
print("done")
