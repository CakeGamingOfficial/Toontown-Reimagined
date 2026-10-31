"""Bake a toon-shop interior for every playground street building.

DistributedToonInterior.setup picks a TI_room with random.Random seeded by the
interior zone (street zone - street zone % 100 + 500 + block). The same
generator fills random_* props and colors, then chooses the round door color.
Shopkeepers are the NPCToons who stand in that zone, in npc-id order.
"""
from __future__ import annotations

import json
import random
import re
import sys
import types
from pathlib import Path

from panda3d.core import (
    CollisionNode,
    Filename,
    Loader,
    NodePath,
    Vec4,
    getModelPath,
    loadPrcFileData,
)
from panda3d.core import TexturePool

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

_otp = types.ModuleType("otp")
_avatar = types.ModuleType("otp.avatar")
_avatar_dna = types.ModuleType("otp.avatar.AvatarDNA")


class _AvatarDNA:
    pass


_avatar_dna.AvatarDNA = _AvatarDNA
sys.modules["otp"] = _otp
sys.modules["otp.avatar"] = _avatar
sys.modules["otp.avatar.AvatarDNA"] = _avatar_dna
sys.path.insert(0, r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")
import toontown.toon.ToonDNA as toon_dna

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "interiors" / "shops"
INTERIOR_DNA = Path(str(Filename(ASSETS, "phase_3.5/dna/storage_interior.dna").toOsSpecific()))
NPC_SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\toon\NPCToons.py")
NAMES_SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\toonbase\TTLocalizerEnglish.py")

# HoodHierarchy streets. The DNA file is the one TownLoader loads for that zone.
STREETS = (
    (1100, "phase_6/dna/donalds_dock_1100.dna"),
    (1200, "phase_6/dna/donalds_dock_1200.dna"),
    (1300, "phase_6/dna/donalds_dock_1300.dna"),
    (2100, "phase_5/dna/toontown_central_2100.dna"),
    (2200, "phase_5/dna/toontown_central_2200.dna"),
    (2300, "phase_5/dna/toontown_central_2300.dna"),
    (3100, "phase_8/dna/the_burrrgh_3100.dna"),
    (3200, "phase_8/dna/the_burrrgh_3200.dna"),
    (3300, "phase_8/dna/the_burrrgh_3300.dna"),
    (4100, "phase_6/dna/minnies_melody_land_4100.dna"),
    (4200, "phase_6/dna/minnies_melody_land_4200.dna"),
    (4300, "phase_6/dna/minnies_melody_land_4300.dna"),
    (5100, "phase_8/dna/daisys_garden_5100.dna"),
    (5200, "phase_8/dna/daisys_garden_5200.dna"),
    (5300, "phase_8/dna/daisys_garden_5300.dna"),
    (9100, "phase_8/dna/donalds_dreamland_9100.dna"),
    (9200, "phase_8/dna/donalds_dreamland_9200.dna"),
)
DOOR_CATALOGS = (
    "phase_3.5/models/modules/doors_practical.bam",
    "phase_4/models/modules/doors.bam",
    "phase_6/models/modules/DD_doors_practical.bam",
    "phase_8/models/modules/DL_doors_practical.bam",
)
SWING_DOORS = (
    "door_double_square_ur",
    "door_double_wood_ur",
    "door_double_curved_ur",
    "door_double_curvedDL_ur",
    "door_double_pillars_ur",
    "door_double_round_ur",
    "door_double_clothesshop_ur",
)
# storage.dna stores the clothes-shop door under a shorter node name.
DOOR_NODE = {
    "door_double_clothesshop_ur": "door_double_clothshop",
}
SKIP_TYPES = {"hq", "gagshop", "petshop", "kartshop"}
WAINSCOT = [(0.8, 0.5, 0.3, 1.0), (0.699, 0.586, 0.473, 1.0), (0.473, 0.699, 0.488, 1.0)]
WALLPAPER = [(1.0, 1.0, 0.7, 1.0), (0.8, 1.0, 0.7, 1.0), (0.4, 0.5, 0.4, 1.0), (0.5, 0.7, 0.6, 1.0)]
FLOOR = [(0.746, 1.0, 0.477, 1.0), (1.0, 0.684, 0.477, 1.0)]
CREAM = (1.0, 1.0, 0.7, 1.0)
# ToonInteriorColors gives Toontown Central one extra brown door. Every other
# playground's TI_door list is only the cream.
BROWN = (0.8, 0.5, 0.3, 1.0)
DOOR_COLORS = [CREAM, BROWN]
SURFACE = {
    "TI_wainscotting": WAINSCOT,
    "TI_wallpaper": WALLPAPER,
    "TI_wallpaper_border": WALLPAPER,
    "TI_floor": FLOOR,
    "TI_door": DOOR_COLORS,
}


def load_model(relative: str) -> NodePath:
    path = relative if relative.endswith(".bam") else relative + ".bam"
    node = Loader.getGlobalPtr().loadSync(Filename(path))
    if node is None:
        node = Loader.getGlobalPtr().loadSync(Filename(relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def door_colors_for(street: int) -> list:
    if 2000 <= street < 3000:
        return [CREAM, BROWN]
    return [CREAM]


def parse_catalog(text: str) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    kept = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
    textures: dict[str, list[str]] = {}
    models: dict[str, list[str]] = {}
    for category, _code, path in re.findall(
        r'store_texture\s*\[\s*"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"',
        kept,
        flags=re.S,
    ):
        textures.setdefault(category, []).append(path)
    for path, category, _code in re.findall(
        r'model\s+"([^"]+)"\s*\[\s*store_node\s*\[\s*"([^"]+)"\s+"([^"]+)"',
        kept,
        flags=re.S,
    ):
        models.setdefault(category, []).append(path)
    return textures, models


def buildings_in(street: int, relative: str) -> list[dict]:
    text = Path(str(Filename(ASSETS, relative).toOsSpecific())).read_text(encoding="utf-8")
    found = []
    for match in re.finditer(
        r'(landmark_building|anim_building)\s+"tb(\d+):([^"]+)"\s*\[',
        text,
    ):
        kind, block_text, dna_name = match.group(1), match.group(2), match.group(3)
        body = _bracket_body(text, match.end())
        building_type = ""
        typed = re.search(r'building_type\s*\[\s*"([^"]+)"\s*\]', body)
        if typed:
            building_type = typed.group(1)
        if building_type in SKIP_TYPES or "hq" in dna_name.lower():
            continue
        title = ""
        titled = re.search(r'title\s*\[\s*"([^"]*)"\s*\]', body)
        if titled:
            title = titled.group(1)
        block = int(block_text)
        zone = street - street % 100 + 500 + block
        found.append({
            "street": street,
            "block": block,
            "zone": zone,
            "kind": kind,
            "title": title,
            "npcs": [],
        })
    return found


def _bracket_body(text: str, start: int) -> str:
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "[":
            depth += 1
        elif text[index] == "]":
            depth -= 1
        index += 1
    return text[start:index]


def npc_names() -> dict[int, str]:
    text = NAMES_SOURCE.read_text(encoding="utf-8")
    names = {}
    for npc_id, name in re.findall(r"(?m)^\s*(\d+):\s*'([^']*)'", text):
        names[int(npc_id)] = name
    return names


def shopkeepers(zones: set[int], names: dict[int, str]) -> dict[int, list[dict]]:
    text = NPC_SOURCE.read_text(encoding="utf-8")
    grouped: dict[int, list[dict]] = {}
    for match in re.finditer(r"(?m)^\s*(\d+):\s*\((\d+),", text):
        npc_id = int(match.group(1))
        zone = int(match.group(2))
        if zone not in zones:
            continue
        rest = text[match.end():]
        nxt = re.search(r"(?m)^\s*\d+:\s*\(", rest)
        body = rest[:nxt.start()] if nxt else rest[:1500]
        random_dna = re.search(r"'r'\s*,\s*'([mf])'", body)
        if random_dna:
            dna = _random_npc_dna(npc_id, random_dna.group(1))
        else:
            dna = _dna_tuple(body)
        if dna is None or len(dna) < 14:
            print("skip npc", npc_id, "zone", zone, "unparsed dna")
            continue
        gender = str(dna[3])
        grouped.setdefault(zone, []).append({
            "id": npc_id,
            "name": names.get(npc_id, "Shopkeeper"),
            "gender": gender,
            "dna": dna[:14],
        })
    for zone in grouped:
        grouped[zone].sort(key=lambda row: int(row["id"]))
    return grouped


def _random_npc_dna(npc_id: int, gender: str) -> list:
    # NPCToons.getRandomDNA seeds ToonDNA.newToonRandom with the npc id.
    toon = toon_dna.ToonDNA()
    toon.newToonRandom(npc_id, gender, 1)
    return list(toon.asTuple())


def _dna_tuple(chunk: str) -> list | None:
    start = chunk.find("(")
    if start < 0:
        return None
    depth = 0
    for index in range(start, len(chunk)):
        if chunk[index] == "(":
            depth += 1
        elif chunk[index] == ")":
            depth -= 1
            if depth == 0:
                body = chunk[start + 1:index]
                values = []
                for text, number in re.findall(r"'([^']*)'|(-?\d+)", body):
                    values.append(text if text != "" else int(number))
                return values
    return None


def hide_helpers(root: NodePath) -> None:
    matches = root.findAllMatches("**")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        name = path.getName().lower()
        if (
            "collision" in name
            or name.startswith("coll-")
            or name.startswith("coll_")
            or "ceiling_coll" in name
            or "trigger" in name
        ):
            path.hide()
        if path.node().isOfType(CollisionNode.getClassType()):
            path.hide()


def style_pieces(door: NodePath) -> None:
    for child in list(door.getChildren()):
        name = child.getName()
        renamed = ""
        if name.endswith("_hole_left"):
            renamed = "doorFrameHoleLeft"
        elif name.endswith("_hole_right"):
            renamed = "doorFrameHoleRight"
        elif name.endswith("_left"):
            renamed = "leftDoor"
        elif name.endswith("_right"):
            renamed = "rightDoor"
        elif name.endswith("_flat"):
            renamed = "door_flat"
        if renamed:
            child.setName(renamed)
        if "trigger" in name.lower() or child.node().isOfType(CollisionNode.getClassType()):
            child.hide()


def pick(rng: random.Random, choices: list[str], cache: dict[str, NodePath], kind: str):
    chosen = choices[rng.randint(0, len(choices) - 1)]
    if kind == "texture":
        return chosen
    if chosen not in cache:
        cache[chosen] = load_model(chosen)
    return cache[chosen]


def replace_random(interior: NodePath, zone_id: int, rng: random.Random, textures, models, cache) -> None:
    matches = interior.findAllMatches("**/random_???_*")
    for index in range(matches.getNumPaths()):
        node = matches.getPath(index)
        name = node.getName()
        if len(name) < 12:
            continue
        key1 = name[7]
        key2 = name[8]
        category = name[11:]
        placed = node
        if key1 == "m":
            paths = models.get(category, [])
            if not paths:
                continue
            model = pick(rng, paths, cache, "model")
            placed = model.copyTo(node)
            hide_helpers(placed)
            if key2 == "r":
                replace_random(placed, zone_id, rng, textures, models, cache)
        elif key1 == "t":
            paths = textures.get(category, [])
            if not paths:
                continue
            relative = pick(rng, paths, cache, "texture")
            texture = TexturePool.loadTexture(Filename(relative))
            if texture is None:
                continue
            node.setTexture(texture, 100)
            placed = node
        if key2 == "c" and category in SURFACE:
            if category in ("TI_wallpaper", "TI_wallpaper_border"):
                rng.seed(zone_id)
            color = rng.choice(SURFACE[category])
            placed.setColorScale(Vec4(*color))


def place_door(interior: NodePath, rng: random.Random, door_colors: list) -> None:
    catalog = load_model("phase_3.5/models/modules/doors_practical.bam")
    source = catalog.find("**/door_double_round_ur")
    origin = interior.find("**/door_origin")
    if source.isEmpty() or origin.isEmpty():
        raise RuntimeError("shop door missing")
    door = source.copyTo(origin)
    origin.setScale(0.8, 0.8, 0.8)
    origin.setPos(origin, 0, -0.025, 0)
    color = rng.choice(door_colors)
    door.setColor(Vec4(*color))
    flat = door.find("**/door_*_flat")
    if not flat.isEmpty():
        flat.setColor(Vec4(*color))
    style_pieces(door)
    door.setName("door_0")


def export_one(record: dict, textures, models, cache) -> None:
    dest = OUT_DIR / f"shop_{record['zone']}.glb"
    if dest.exists():
        return
    colors = door_colors_for(int(record["street"]))
    SURFACE["TI_door"] = colors
    rooms = models["TI_room"]
    rng = random.Random(record["zone"])
    room_path = rooms[rng.randint(0, len(rooms) - 1)]
    interior = load_model(room_path)
    interior.setName("Shop")
    replace_random(interior, record["zone"], rng, textures, models, cache)
    place_door(interior, rng, colors)
    hide_helpers(interior)
    root = NodePath("ShopRoot")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest.write_bytes(writer.pack("Shop"))
    print(f"wrote {dest.name} room={Path(room_path).name} npcs={len(record['npcs'])}", flush=True)


def export_swing_doors() -> None:
    holder = NodePath("Doors")
    for code in SWING_DOORS:
        found = None
        for relative in DOOR_CATALOGS:
            if not Filename(ASSETS, relative).exists():
                continue
            catalog = load_model(relative)
            match = catalog.find("**/" + DOOR_NODE.get(code, code))
            if not match.isEmpty():
                found = match
                break
        if found is None:
            print("missing swing door", code)
            continue
        door = found.copyTo(holder)
        door.setName(code)
        style_pieces(door)
        flat = door.find("**/door_flat")
        if not flat.isEmpty():
            flat.hide()
        hide_helpers(door)
        print(code, [child.getName() for child in door.getChildren()])
    root = NodePath("ShopDoors")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    holder.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT_DIR / "doors.glb"
    dest.write_bytes(writer.pack("ShopDoors"))
    print(f"wrote {dest.name}", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    textures, models = parse_catalog(INTERIOR_DNA.read_text(encoding="utf-8"))
    records = []
    for street, relative in STREETS:
        records.extend(buildings_in(street, relative))
    zones = {int(record["zone"]) for record in records}
    keepers = shopkeepers(zones, npc_names())
    for record in records:
        record["npcs"] = keepers.get(int(record["zone"]), [])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    catalog = {}
    for record in records:
        catalog[str(record["zone"])] = {
            "street": record["street"],
            "block": record["block"],
            "title": record["title"],
            "npcs": record["npcs"],
        }
    (OUT_DIR / "shops.json").write_text(json.dumps(catalog, indent=1), encoding="utf-8")
    print(f"shops {len(records)} with keepers {sum(1 for record in records if record['npcs'])}", flush=True)
    cache: dict[str, NodePath] = {}
    for record in records:
        export_one(record, textures, models, cache)
    export_swing_doors()
    return 0


if __name__ == "__main__":
    sys.exit(main())
