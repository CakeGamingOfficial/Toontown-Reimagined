"""Export the doodle and the pet shop cards from the original phase_4 assets.

TT_pets-mod is one skinned geom per part. Each frame is skinned in Panda, then
stored as Godot Y-up positions so the pet can walk without a skin shader.
"""
from __future__ import annotations

import json
import struct
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import (
    Filename,
    GeomNode,
    GeomVertexReader,
    Mat4,
    PNMImage,
    Point3,
    Texture,
    TextureAttrib,
    TexMatrixAttrib,
    Vec3,
    getModelPath,
    loadPrcFileData,
)

loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
loadPrcFileData("", "default-model-extension .bam")

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
getModelPath().prependDirectory(ASSETS)

from direct.actor.Actor import Actor
from direct.showbase.ShowBase import ShowBase

import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "pets"
MAPS = OUT / "maps"
GUI = OUT / "gui"
NAME_MASTER = Path(str(Filename(ASSETS, "phase_3/etc/PetNameMasterEnglish.txt").toOsSpecific()))

CLIPS = ("happy", "neutral", "walk", "run")
ANIM = {
    "happy": "phase_4/models/char/TT_pets-neutralHappy.bam",
    "neutral": "phase_4/models/char/TT_pets-neutral.bam",
    "walk": "phase_5.5/models/char/TT_pets-walk.bam",
    "run": "phase_5.5/models/char/TT_pets-run.bam",
    "sad": "phase_4/models/char/TT_pets-neutral_sad.bam",
    "sadwalk": "phase_5.5/models/char/TT_pets-sadwalk.bam",
    "walkHappy": "phase_5.5/models/char/TT_pets-walkHappy.bam",
    "jump": "phase_5/models/char/TT_pets-jump.bam",
    "toBeg": "phase_5/models/char/TT_pets-intoBeg.bam",
    "beg": "phase_5/models/char/TT_pets-beg.bam",
    "fromBeg": "phase_5/models/char/TT_pets-begOut.bam",
    "playDead": "phase_5/models/char/TT_pets-playdead.bam",
    "fromPlayDead": "phase_5/models/char/TT_pets-deadend.bam",
    "rollover": "phase_5/models/char/TT_pets-rollover.bam",
    "backflip": "phase_5/models/char/TT_pets-backflip.bam",
    "dance": "phase_5/models/char/TT_pets-heal.bam",
    "speak": "phase_5/models/char/TT_pets-speak.bam",
    "eat": "phase_5.5/models/char/TT_pets-eat.bam",
    "swallow": "phase_5.5/models/char/TT_pets-swallow.bam",
}
# Idle and trick loops are long. Every other frame still reads as the original.
STRIDE = {
    "happy": 2, "neutral": 2, "walk": 1, "run": 1,
    "sad": 2, "sadwalk": 1, "walkHappy": 1,
    "jump": 1, "toBeg": 1, "beg": 2, "fromBeg": 1,
    "playDead": 2, "fromPlayDead": 1, "rollover": 2,
    "backflip": 2, "dance": 2, "speak": 1, "eat": 2, "swallow": 1,
}

BODY_TYPES = ["dots", "threeStripe", "tigerStripe", "tummy", "turtle", "giraffe", "leopard"]
BODY_WEIGHTS = {
    "2000": {"threeStripe": 50, "tummy": 30, "dots": 20},
    "1000": {"threeStripe": 35, "tummy": 30, "dots": 20, "tigerStripe": 15},
    "5000": {"threeStripe": 15, "tummy": 20, "dots": 20, "tigerStripe": 20, "turtle": 15},
    "4000": {"threeStripe": 10, "tummy": 15, "dots": 30, "tigerStripe": 25, "turtle": 20},
    "3000": {"threeStripe": 5, "tummy": 10, "dots": 20, "tigerStripe": 25, "turtle": 25, "giraffe": 15},
    "9000": {"threeStripe": 5, "tummy": 5, "dots": 15, "tigerStripe": 20, "turtle": 25, "giraffe": 20, "leopard": 10},
}
# PetConstants.ZoneToCostRange. The hood ids are the ones the pet shop door uses.
ZONE_COST = {
    "2000": [100, 500],
    "1000": [600, 1700],
    "5000": [1000, 2500],
    "4000": [1500, 3000],
    "3000": [2500, 4000],
    "9000": [3000, 5000],
}

GUI_MODELS = (
    "AdoptReturnSell",
    "AdoptPet",
    "ReturnPet",
    "PetShopInterface",
    "PetNamePanel",
)


def body_rarity() -> list[float]:
    weight = {name: 0.0 for name in BODY_TYPES}
    total = 0.0
    for zone in BODY_WEIGHTS.values():
        for name, value in zone.items():
            weight[name] += value
            total += value
    lowest = min(weight.values())
    span = total - lowest
    return [round((weight[name] - lowest) / span, 6) for name in BODY_TYPES]


def skin_points(geom_node: GeomNode) -> list[tuple[Point3, tuple[float, float]]]:
    posed: list[tuple[Point3, tuple[float, float]]] = []
    for geom_index in range(geom_node.getNumGeoms()):
        geom = geom_node.getGeom(geom_index)
        vdata = geom.getVertexData()
        table = vdata.getTransformBlendTable()
        positions = exporter.read_column(vdata, "vertex", exporter.copy3)
        uvs = exporter.read_column(vdata, "texcoord", exporter.copy2) if vdata.hasColumn("texcoord") else []
        blends = []
        if table is not None and vdata.hasColumn("transform_blend"):
            reader = GeomVertexReader(vdata, "transform_blend")
            for row in range(vdata.getNumRows()):
                reader.setRow(row)
                blends.append(reader.getData1i())
        matrices = {}
        if table is not None:
            for index in range(table.getNumBlends()):
                blend = table.getBlend(index)
                matrices[index] = []
                for slot in range(blend.getNumTransforms()):
                    matrix = Mat4()
                    blend.getTransform(slot).getMatrix(matrix)
                    matrices[index].append((matrix, blend.getWeight(slot)))
        state = geom_node.getGeomState(geom_index)
        tex_matrix = None
        tex_attrib = state.getAttrib(TextureAttrib.getClassSlot())
        if tex_attrib is not None and tex_attrib.getNumOnStages() > 0:
            stage = tex_attrib.getOnStage(0)
            matrix_attrib = state.getAttrib(TexMatrixAttrib.getClassSlot())
            if matrix_attrib is not None and matrix_attrib.hasStage(stage):
                tex_matrix = matrix_attrib.getTransform(stage).getMat()
        for index in exporter.triangle_indices(geom):
            point = Point3(*positions[index])
            if index < len(blends) and blends[index] in matrices:
                mixed = Point3(0, 0, 0)
                for matrix, weight in matrices[blends[index]]:
                    mixed += matrix.xformPoint(point) * weight
                point = mixed
            point = exporter.Z_UP_TO_Y_UP.xformPoint(point)
            if uvs:
                u, v = uvs[index]
                if tex_matrix is not None:
                    transformed = tex_matrix.xform(Vec3(u, v, 1))
                    u, v = transformed.x, transformed.y
                uv = (u, 1.0 - v)
            else:
                uv = (0.0, 0.0)
            posed.append((point, uv))
    return posed


def part_name(node_path) -> str:
    name = node_path.getName()
    if name:
        return name
    return "extra"


def texture_name(node_path) -> str:
    texture = part_texture(node_path)
    if texture is None or not texture.hasFilename():
        return ""
    return Path(texture.getFilename().getBasename()).name


def part_texture(node_path):
    node = node_path.node()
    if node.getNumGeoms() == 0:
        return None
    state = node.getGeomState(0)
    attrib = state.getAttrib(TextureAttrib.getClassSlot())
    if attrib is None or attrib.getNumOnStages() == 0:
        return None
    return attrib.getOnTexture(attrib.getOnStage(0))


def _save_part_texture(node_path) -> None:
    texture = part_texture(node_path)
    if texture is None:
        return
    name = "palette.png"
    if texture.hasFilename():
        name = Path(texture.getFilename().getBasename()).name
    copy_texture(texture, MAPS / name)


def copy_texture(texture: Texture, dest: Path) -> None:
    if dest.exists():
        return
    image = PNMImage()
    if not texture.store(image):
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    image.write(Filename.fromOsSpecific(str(dest)))


def copy_named_maps() -> None:
    folder = Path(str(Filename(ASSETS, "phase_4/maps").toOsSpecific()))
    MAPS.mkdir(parents=True, exist_ok=True)
    for path in folder.glob("Bean*.png"):
        target = MAPS / path.name
        if not target.exists():
            target.write_bytes(path.read_bytes())
    for path in folder.glob("bean*.png"):
        target = MAPS / path.name
        if not target.exists():
            target.write_bytes(path.read_bytes())


def write_names() -> int:
    rows = []
    for line in NAME_MASTER.read_text(encoding="latin-1").splitlines():
        text = line.strip()
        if not text or text.startswith("#"):
            continue
        first = text.find("*")
        second = text.find("*", first + 1)
        if first < 0 or second < 0:
            continue
        rows.append({
            "id": int(text[:first]),
            "gender": int(text[first + 1:second]),
            "name": text[second + 1:].strip(),
        })
    (OUT / "names.json").write_text(json.dumps(rows, separators=(",", ":")), encoding="utf-8")
    return len(rows)


def write_catalog() -> None:
    catalog = {
        "bodies": BODY_TYPES,
        "body_weights": BODY_WEIGHTS,
        "body_rarity": body_rarity(),
        "heads": ["feathers"],
        "ears": ["horns", "antennae", "dogEars", "catEars", "rabbitEars"],
        "noses": ["clownNose", "dogNose", "ovalNose", "pigNose"],
        "tails": ["catTail", "longTail", "birdTail", "bunnyTail"],
        "generic_colors": [0, 1, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25],
        "specific_colors": [0, 1, 3, 5, 6, 7, 8, 9, 10, 11, 12, 16, 17, 18, 23, 24, 25],
        "specific_bodies": ["turtle", "giraffe", "leopard"],
        "colors": [
            [1.0, 1.0, 1.0, 1.0],
            [0.96875, 0.691406, 0.699219, 1.0],
            [0.933594, 0.265625, 0.28125, 1.0],
            [0.863281, 0.40625, 0.417969, 1.0],
            [0.710938, 0.234375, 0.4375, 1.0],
            [0.570312, 0.449219, 0.164062, 1.0],
            [0.640625, 0.355469, 0.269531, 1.0],
            [0.996094, 0.695312, 0.511719, 1.0],
            [0.832031, 0.5, 0.296875, 1.0],
            [0.992188, 0.480469, 0.167969, 1.0],
            [0.996094, 0.898438, 0.320312, 1.0],
            [0.996094, 0.957031, 0.597656, 1.0],
            [0.855469, 0.933594, 0.492188, 1.0],
            [0.550781, 0.824219, 0.324219, 1.0],
            [0.242188, 0.742188, 0.515625, 1.0],
            [0.304688, 0.96875, 0.402344, 1.0],
            [0.433594, 0.90625, 0.835938, 1.0],
            [0.347656, 0.820312, 0.953125, 1.0],
            [0.191406, 0.5625, 0.773438, 1.0],
            [0.558594, 0.589844, 0.875, 1.0],
            [0.285156, 0.328125, 0.726562, 1.0],
            [0.460938, 0.378906, 0.824219, 1.0],
            [0.546875, 0.28125, 0.75, 1.0],
            [0.726562, 0.472656, 0.859375, 1.0],
            [0.898438, 0.617188, 0.90625, 1.0],
            [0.7, 0.7, 0.8, 1.0],
        ],
        "eye_colors": [
            [0.29, 0.29, 0.69, 1.0],
            [0.49, 0.49, 0.99, 1.0],
            [0.69, 0.49, 0.29, 1.0],
            [0.99, 0.69, 0.49, 1.0],
            [0.29, 0.69, 0.29, 1.0],
            [0.49, 0.99, 0.49, 1.0],
        ],
        "scales": [0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2],
        "zone_cost": ZONE_COST,
        "body_textures": {
            "dots": "BeanbodyDots6.png",
            "threeStripe": "Beanbody3stripes6.png",
            "tigerStripe": "BeanbodyZebraStripes6.png",
            "turtle": "BeanbodyTurtle.png",
            "giraffe": "BeanbodyGiraffe1.png",
            "leopard": "BeanbodyLepord2.png",
            "tummy": "BeanbodyTummy6.png",
        },
        "foot_textures": {
            "normal": "BeanFoot6.png",
            "turtle": "BeanFootTurttle.png",
            "giraffe": "BeanFootYellow3.png",
            "leopard": "BeanFootYellow3.png",
        },
        "ear_textures": {
            "catEars": "BeanCatEar6.png",
            "rabbitEars": "BeanBunnyEar6.png",
        },
        "exotic_ears": {
            "catEars": "BeanCatEar3Yellow.png",
            "rabbitEars": "BeanBunnyEar6.png",
        },
        "tail_textures": {
            "catTail": "beanCatTail6.png",
            "longTail": "BeanLongTail6.png",
        },
        "giraffe_tail": "BeanLongTailGiraffe.png",
        "leopard_tail": "BeanLongTailLepord.png",
        "eyes": {
            "boy": "BeanEyeBoys2.png",
            "boy_blink": "BeanEyeBoysBlink.png",
            "girl": "BeanEyeGirlsNew.png",
            "girl_blink": "BeanEyeGirlsBlinkNew.png",
        },
    }
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=1), encoding="utf-8")


def export_pet(base: ShowBase) -> None:
    present = {}
    for clip, path in ANIM.items():
        full = Path(str(Filename(ASSETS, path).toOsSpecific()))
        if full.exists():
            present[clip] = path
        else:
            print("missing", path)
    global CLIPS
    CLIPS = tuple(clip for clip in ANIM.keys() if clip in present)
    actor = Actor("phase_4/models/char/TT_pets-mod.bam", present)
    parts = []
    for node_path in actor.findAllMatches("**"):
        if not node_path.node().isOfType(GeomNode.getClassType()):
            continue
        name = part_name(node_path)
        if "shadow" in name.lower():
            continue
        _save_part_texture(node_path)
        parts.append((name, node_path))
    # Pose once so the blend tables exist, then record UVs from that pose.
    character = actor.find("**/+Character")
    actor.pose("happy", 0)
    character.node().forceUpdate()
    uv_sets = {}
    for name, node_path in parts:
        posed = skin_points(node_path.node())
        uv_sets[name] = [round(value, 5) for _point, uv in posed for value in uv]
        print(name, "verts", len(posed), "tex", texture_name(node_path))
    clips = {name: {} for name, _node in parts}
    for clip in CLIPS:
        control = actor.getAnimControl(clip)
        frames = control.getNumFrames()
        step = STRIDE[clip]
        used = list(range(0, frames, step))
        print(clip, "frames", len(used), "of", frames)
        for frame in used:
            control.pose(frame)
            character.node().forceUpdate()
            for name, node_path in parts:
                posed = skin_points(node_path.node())
                flat = clips[name].setdefault(clip, [])
                for point, _uv in posed:
                    flat.extend((round(point.x, 4), round(point.y, 4), round(point.z, 4)))
    meta = {"parts": [], "clips": list(CLIPS)}
    blob = bytearray()
    for name, _node in parts:
        entry = {"name": name, "uv": uv_sets[name], "frames": {}}
        for clip in CLIPS:
            entry["frames"][clip] = len(clips[name][clip]) // (len(uv_sets[name]) // 2) // 3
            entry.setdefault("offset", {})
            entry["offset"][clip] = len(blob) // 4
            for value in clips[name][clip]:
                blob.extend(struct.pack("<f", value))
        meta["parts"].append(entry)
    (OUT / "doodle_parts.json").write_text(json.dumps(meta), encoding="utf-8")
    (OUT / "doodle_clips.bin").write_bytes(blob)
    sample = clips["body"]["walk"]
    print("walk sample", sample[:3], sample[len(sample) // 2:len(sample) // 2 + 3])
    print("clips", len(blob))


def export_cards() -> None:
    GUI.mkdir(parents=True, exist_ok=True)
    cards = {}
    for model_name in GUI_MODELS:
        model = base.loader.loadModel(f"phase_4/models/gui/{model_name}")
        found = []
        for node_path in model.findAllMatches("**"):
            node = node_path.node()
            if not node.isOfType(GeomNode.getClassType()):
                continue
            if node.getNumGeoms() == 0:
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
            positions = exporter.read_column(vdata, "vertex", exporter.copy3)
            uvs = exporter.read_column(vdata, "texcoord", exporter.copy2) if vdata.hasColumn("texcoord") else []
            triangles = exporter.triangle_indices(geom)
            if len(triangles) < 3 or not uvs:
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
            # PNMImage row 0 is the top. Panda v=0 is the bottom.
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
            card = f"{model_name}_{label}_{len(found)}"
            crop.write(Filename.fromOsSpecific(str(GUI / f"{card}.png")))
            found.append({
                "name": label,
                "file": f"{card}.png",
                "x": round((min(xs) + max(xs)) * 0.5, 4),
                "z": round((min(zs) + max(zs)) * 0.5, 4),
                "w": round(max(xs) - min(xs), 4),
                "h": round(max(zs) - min(zs), 4),
            })
        cards[model_name] = found
        print(model_name, len(found))
        model.removeNode()
    (GUI / "cards.json").write_text(json.dumps(cards, indent=1), encoding="utf-8")


ShowBase()
OUT.mkdir(parents=True, exist_ok=True)
copy_named_maps()
print("names", write_names())
write_catalog()
export_pet(base)
export_cards()
print("done")
