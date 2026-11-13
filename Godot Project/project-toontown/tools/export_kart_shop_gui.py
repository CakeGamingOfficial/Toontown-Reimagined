"""Crop the Kart Shop clerk panels from the phase_6 GUI models.

KartShopGui builds every page from these bams. Each card keeps the center
and size it has in the model, in Panda's Z-up space.
"""
from __future__ import annotations

import json
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, GeomNode, PNMImage, Point3, TextureAttrib, getModelPath, loadPrcFileData
from direct.showbase.ShowBase import ShowBase

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "kart_shop"
MODELS = (
    "Kart_MainMenuPanel",
    "BuyKartPanel",
    "ReturnKartPanel",
    "BoughtKartPanel",
    "ConfirmBuyKartPanel",
    "BuyAccessoryPanel",
    "BoughtAccessoryPanel",
    "ConfirmBuyAccessory",
)


def export_cards() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cards = {}
    for model_name in MODELS:
        model = base.loader.loadModel("phase_6/models/gui/%s.bam" % model_name)
        if model is None:
            print("missing", model_name)
            continue
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
            label = node_path.getName()
            walk = node_path
            while label == "" and not walk.getParent().isEmpty() and walk != model:
                walk = walk.getParent()
                label = walk.getName()
            if not label:
                label = "card"
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
        cards[model_name] = found
        print(model_name, len(found), flush=True)
        model.removeNode()
    (OUT / "cards.json").write_text(json.dumps(cards, indent=1), encoding="utf-8")


loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
getModelPath().prependDirectory(ASSETS)
ShowBase()
export_cards()
print("done")
