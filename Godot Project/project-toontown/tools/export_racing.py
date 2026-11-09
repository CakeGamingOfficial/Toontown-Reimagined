"""Export Goofy Speedway racing the way DistributedRace and Kart do.

Tracks keep curve_forward and curve_reverse, the lap markers, and the
start_pos locators. Kart bodies and hood, trunk, and wheel accessories
are the phase_6 karting models. Rim and decal maps are copied as-is.
"""
from __future__ import annotations

import json
import math
import re
import shutil
import struct
import sys
import types
from pathlib import Path

from panda3d.core import CollisionNode, Filename, NodePath, Point3, getModelPath, loadPrcFileData

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_gag_shop as shop
import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown\Original Toontown Assets\Game Assets"
)
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parents[1] / "Original Toontown Assets" / "Source Code"
OUT = ROOT / "assets" / "racing"
SPEEDWAY = ROOT / "assets" / "neighborhoods" / "goofy_speedway" / "goofy_speedway.glb"
SAMPLES = 500

TRACKS = (
    ("RT_SpeedwayA", "speedway_a"),
    ("RT_SpeedwayB", "speedway_b"),
    ("RT_RuralB", "rural_b"),
    ("RT_RuralB2", "rural_b2"),
    ("RT_UrbanA", "urban_a"),
    ("RT_UrbanB", "urban_b"),
)

KARTS = (
    (0, "phase_6/models/karting/Kart1_Final.bam", "kart_0"),
    (1, "phase_6/models/karting/Kart2_Final.bam", "kart_1"),
    (2, "phase_6/models/karting/Kart3_Final.bam", "kart_2"),
)


def godot_point(point) -> list[float]:
    converted = exporter.Z_UP_TO_Y_UP.xform(point)
    return [round(converted.x, 3), round(converted.y, 3), round(converted.z, 3)]


def heading_of(node: NodePath, space: NodePath) -> float:
    quat = node.getQuat(space)
    forward = quat.getForward()
    converted = exporter.Z_UP_TO_Y_UP.xformVec(forward)
    if converted.x * converted.x + converted.z * converted.z < 1e-8:
        return 0.0
    return round(math.degrees(math.atan2(-converted.x, -converted.z)), 2)


def hide_helpers(root: NodePath) -> None:
    matches = root.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        if path.node().isOfType(CollisionNode.getClassType()):
            path.hide()


def sample_curve(geom: NodePath, name: str) -> list[list[float]]:
    curve_np = geom.find("**/" + name)
    if curve_np.isEmpty():
        print("missing", name)
        return []
    curve = curve_np.node()
    if hasattr(curve, "getCurve"):
        curve = curve.getCurve()
    points: list[list[float]] = []
    max_t = curve.getMaxT()
    for index in range(SAMPLES):
        local = Point3(0, 0, 0)
        curve.getPoint(index / float(SAMPLES) * (max_t - 1e-6), local)
        placed = geom.getRelativePoint(curve_np, local)
        points.append(godot_point(placed))
    print(name, curve.getClassType().getName() if hasattr(curve, "getClassType") else type(curve), "samples", len(points))
    return points


def marker(geom: NodePath, name: str) -> dict:
    node = geom.find("**/" + name)
    if node.isEmpty():
        return {}
    return {"pos": godot_point(node.getPos(geom)), "heading": heading_of(node, geom)}


def export_track(bam_name: str, slug: str) -> dict:
    geom = shop.load_model("phase_6/models/karting/%s.bam" % bam_name)
    geom.setName(slug)
    hide_helpers(geom)
    record = {
        "model": "res://assets/racing/tracks/%s.glb" % slug,
        "forward": sample_curve(geom, "curve_forward"),
        "reverse": sample_curve(geom, "curve_reverse"),
        "lap_start": marker(geom, "lap_start"),
        "lap_start_rev": marker(geom, "lap_start_rev"),
        "lap_middle": marker(geom, "lap_middle"),
        "starts": [],
    }
    found = geom.findAllMatches("**/start_pos*")
    for index in range(found.getNumPaths()):
        node = found.getPath(index)
        record["starts"].append({"name": node.getName(), "pos": godot_point(node.getPos(geom)), "heading": heading_of(node, geom)})
    root = NodePath(slug)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    geom.copyTo(root)
    shop.write_glb(root, OUT / "tracks" / ("%s.glb" % slug), slug)
    return record


def export_model(relative: str, dest: Path, scene_name: str) -> None:
    geom = shop.load_model(relative)
    geom.setName(scene_name)
    hide_helpers(geom)
    root = NodePath(scene_name)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    geom.copyTo(root)
    shop.write_glb(root, dest, scene_name)


def copy_maps() -> None:
    source = Path(str(Filename(ASSETS, "phase_6/maps").toOsSpecific()))
    dest = OUT / "maps"
    dest.mkdir(parents=True, exist_ok=True)
    for path in source.iterdir():
        name = path.name
        if name.startswith("kart") or name.startswith("boost_arrow"):
            shutil.copy2(path, dest / name)


def copy_audio() -> None:
    dest = OUT / "audio"
    dest.mkdir(parents=True, exist_ok=True)
    wanted = (
        "phase_6/audio/bgm/GS_Race_SS.ogg",
        "phase_6/audio/bgm/GS_Race_RR.ogg",
        "phase_6/audio/bgm/GS_Race_CC.ogg",
        "phase_6/audio/sfx/KART_Appear.ogg",
        "phase_6/audio/sfx/KART_raceStart1.ogg",
        "phase_6/audio/sfx/KART_turboStart.ogg",
        "phase_6/audio/sfx/KART_turboLoop.ogg",
        "phase_6/audio/sfx/KART_Engine_loop_0.ogg",
    )
    for relative in wanted:
        source = Path(str(Filename(ASSETS, relative).toOsSpecific()))
        if source.exists():
            shutil.copy2(source, dest / source.name)
        else:
            print("missing audio", relative)


def string_dict(text: str, name: str) -> dict[int, str]:
    match = re.search(name + r" = \{", text)
    if match is None:
        return {}
    found: dict[int, str] = {}
    for key, value in re.findall(r"(\d+)\s*:\s*'([^']*)'", text[match.start():match.start() + 8000]):
        found[int(key)] = value
    return found


def catalog() -> dict:
    dna = (SOURCE / "toontown" / "racing" / "KartDNA.py").read_text(encoding="utf-8")
    localizer = (SOURCE / "toontown" / "toonbase" / "TTLocalizerEnglish.py").read_text(encoding="utf-8")
    kart_names = string_dict(localizer, "KartDNA_KartNames")
    acc_names = string_dict(localizer, "KartDNA_AccNames")
    karts = []
    for body, model, cost in re.findall(
        r"(\d+):\s*\(kNames\[\d+\],\s*'([^']+)',\s*(\d+),",
        dna,
    ):
        karts.append({"id": int(body), "name": kart_names.get(int(body), "Kart"), "model": model, "cost": int(cost)})
    accessories = []
    for acc_id, local_id, model, cost, tex, attach in re.findall(
        r"(\d+):\s*\(aNames\[(\d+)\],\s*'([^']+)',\s*(InvalidEntry|\d+),\s*'([^']+)'(?:,\s*'([^']+)')?",
        dna,
    ):
        accessories.append({
            "id": int(acc_id),
            "name": acc_names.get(int(local_id), local_id),
            "model": model,
            "cost": -1 if cost == "InvalidEntry" else int(cost),
            "tex": tex,
            "attach": attach,
            "kind": "model" if model.endswith("ww_0") or "accessory_" in model or "/karting/" in model else "rim",
        })
    for acc_id, local_id, number, cost, pattern in re.findall(
        r"(\d+):\s*\(aNames\[(\d+)\],\s*(\d+),\s*(\d+),\s*'([^']+)'\)",
        dna,
    ):
        accessories.append({
            "id": int(acc_id),
            "name": acc_names.get(int(local_id), local_id),
            "decal": int(number),
            "cost": int(cost),
            "pattern": pattern,
            "kind": "decal",
        })
    for acc_id, local_id, color, cost in re.findall(
        r"(\d+):\s*\(aNames\[(\d+)\],\s*VBase4\(([^)]+)\),\s*(\d+)\)",
        dna,
    ):
        parts = [float(piece.strip()) for piece in color.split(",")]
        accessories.append({
            "id": int(acc_id),
            "name": acc_names.get(int(local_id), local_id),
            "color": parts,
            "cost": int(cost),
            "kind": "color",
        })
    accessories.sort(key=lambda item: int(item["id"]))
    return {"karts": karts, "accessories": accessories}


def glb_nodes(path: Path) -> list[dict]:
    data = path.read_bytes()
    length, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise RuntimeError("glb json chunk missing")
    payload = json.loads(data[20:20 + length])
    nodes = payload["nodes"]
    world: dict[int, list[list[float]]] = {}

    def compose(parent: list[list[float]], local: list[float]) -> list[list[float]]:
        # glTF stores a column-major matrix. Column 3 is the translation.
        out = [[0.0, 0.0, 0.0, 0.0] for _ in range(4)]
        for column in range(4):
            for row in range(4):
                out[row][column] = sum(parent[row][k] * local[column * 4 + k] for k in range(4))
        return out

    def walk(index: int, parent: list[list[float]]) -> None:
        node = nodes[index]
        local = node.get("matrix", [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
        if "matrix" not in node:
            t = node.get("translation", [0, 0, 0])
            local = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, t[0], t[1], t[2], 1]
        here = compose(parent, local)
        world[index] = here
        for child in node.get("children", []):
            walk(child, here)

    identity = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    for index in payload["scenes"][0]["nodes"]:
        walk(index, identity)
    found = []
    for index, node in enumerate(nodes):
        name = node.get("name", "")
        low = name.lower()
        if not any(token in low for token in ("racing_pad", "viewing_pad", "starting_block", "leaderboard")):
            continue
        mat = world[index]
        # Local +Y is the original forward. The speedway root already turned Z-up into Y-up.
        forward_x = mat[0][1]
        forward_z = mat[2][1]
        heading = 0.0
        if forward_x * forward_x + forward_z * forward_z > 1e-8:
            heading = round(math.degrees(math.atan2(-forward_x, -forward_z)), 2)
        found.append({
            "name": name,
            "pos": [round(mat[0][3], 3), round(mat[1][3], 3), round(mat[2][3], 3)],
            "heading": heading,
        })
    return found


def export_icon() -> None:
    model = shop.load_model("phase_3.5/models/gui/sos_textures.bam")
    card = model.find("**/kartIcon")
    if card.isEmpty():
        print("kart icon missing")
        return
    texture = card.findTexture("*")
    if texture is None:
        print("kart icon has no texture")
        return
    dest = OUT / "maps" / "kart_icon.png"
    if texture.write(Filename.from_os_specific(str(dest))):
        print("wrote", dest.name)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    curves = {}
    for bam_name, slug in TRACKS:
        curves[slug] = export_track(bam_name, slug)
    (OUT / "tracks" / "curves.json").write_text(json.dumps(curves), encoding="utf-8")
    for _body, relative, slug in KARTS:
        export_model(relative, OUT / "karts" / ("%s.glb" % slug), slug)
    book = catalog()
    for item in book["accessories"]:
        model = str(item.get("model", ""))
        if "/karting/accessory_" not in model:
            continue
        slug = "acc_%d" % int(item["id"])
        export_model(model + ".bam", OUT / "accessories" / ("%s.glb" % slug), slug)
        item["file"] = "res://assets/racing/accessories/%s.glb" % slug
    (OUT / "catalog.json").write_text(json.dumps(book), encoding="utf-8")
    copy_maps()
    copy_audio()
    export_icon()
    pads = glb_nodes(SPEEDWAY)
    (OUT / "speedway.json").write_text(json.dumps(pads, indent=1), encoding="utf-8")
    print("pads", len(pads))
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "pads":
        pads = glb_nodes(SPEEDWAY)
        (OUT / "speedway.json").write_text(json.dumps(pads, indent=1), encoding="utf-8")
        for item in pads:
            if "starting_block" not in item["name"]:
                print(item["name"], item["pos"], item["heading"])
    else:
        sys.exit(main())
