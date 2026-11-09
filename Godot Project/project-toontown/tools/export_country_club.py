"""Export Bossbot country club courses.

CountryClubLayout draws hallways with random.Random(countryClubId * floorNum).
gotAllRooms then starts a second Random on that same seed to pick entrances.
The shipped module replaces countryClubLayouts with testLayout, so every
Front Three index is ClubLayout3_0, every Middle Six is ClubLayout6_0, and
every Back Nine is ClubLayout9_0. Those are the floors baked here.
"""
from __future__ import annotations

import json
import random
import shutil
import sys
from pathlib import Path

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

from export_law_office import (
    ASSETS,
    AUDIO,
    SPEC_DIR,
    Z_UP_TO_Y_UP,
    attach_to,
    dress,
    entity_record,
    godot_placement,
    load_model,
    resolve_model,
    vec3,
)
from export_toontown_central import GltfWriter

OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "cog_hq" / "courses"

ROOM_NAMES = {
    0: "BossbotCountryClubEntrance_Action00",
    2: "BossbotCountryClubTeeOffRoom_Action00",
    4: "BossbotCountryClubFairwayRoom_Battle00",
    5: "BossbotCountryClubMazeRoom_Battle00",
    6: "BossbotCountryClubMazeRoom_Battle01",
    7: "BossbotCountryClubMazeRoom_Battle02",
    9: "BossbotCountryClubGreenRoom_Action00",
    17: "BossbotCountryClubKartRoom_Battle00",
    18: "BossbotCountryClubPresidentRoom_Battle00",
    22: "BossbotCountryClubTeeOffRoom_Action01",
    29: "BossbotCountryClubGreenRoom_Action01",
    32: "BossbotCountryClubTeeOffRoom_Action02",
    39: "BossbotCountryClubGreenRoom_Action02",
}
COG_ROOMS = {
    4: "BossbotCountryClubFairwayRoom_Battle00",
    5: "BossbotCountryClubMazeRoom_Battle00",
    6: "BossbotCountryClubMazeRoom_Battle01",
    7: "BossbotCountryClubMazeRoom_Battle02",
    17: "BossbotCountryClubKartRoom_Battle00",
    18: "BossbotCountryClubPresidentRoom_Battle00",
}
# CountryClubLayout assigns countryClubLayouts = testLayout, three copies each.
LAYOUTS = [
    [(0, 2, 5, 9, 17), (0, 2, 4, 9, 17), (0, 2, 5, 9, 18)],
    [(0, 2, 5, 9, 17), (0, 2, 4, 9, 17), (0, 2, 5, 9, 18)],
    [(0, 2, 5, 9, 17), (0, 2, 4, 9, 17), (0, 2, 5, 9, 18)],
    [(0, 22, 4, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 18)],
    [(0, 22, 4, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 18)],
    [(0, 22, 4, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 17), (0, 22, 6, 29, 17), (0, 22, 5, 29, 18)],
    [(0, 32, 4, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 7, 39, 17), (0, 32, 6, 39, 18)],
    [(0, 32, 4, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 7, 39, 17), (0, 32, 6, 39, 18)],
    [(0, 32, 4, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 5, 39, 17), (0, 32, 6, 39, 17), (0, 32, 7, 39, 17), (0, 32, 7, 39, 17), (0, 32, 6, 39, 18)],
]
ZONES = [10500, 10500, 10500, 10600, 10600, 10600, 10700, 10700, 10700]
# numHallways = 1 + CountryClubNumRooms[zone][0]
HALL_DRAWS = {10500: 5, 10600: 9, 10700: 11}
CONNECTORS = (
    "phase_12/models/bossbotHQ/Connector_Tunnel_A",
    "phase_12/models/bossbotHQ/Connector_Tunnel_B",
)
PLAY = {
    "door", "button", "battleBlocker", "collisionSolid", "elevatorMarker",
    "entrancePoint", "golfGreenGame", "moleField", "stomper", "gagBarrel", "healBarrel",
}
EXTRA_KEYS = (
    "timeToPlay", "puzzleBase", "puzzlePerPlayer", "numSquaresX", "numSquaresY",
    "spacingX", "spacingY", "molesBase", "molesPerPlayer", "cellId",
)


def load_spec(name: str) -> dict:
    source = (SPEC_DIR / f"{name}.py").read_text(encoding="utf-8")
    lines = []
    for line in source.splitlines():
        stripped = line.strip()
        if stripped.startswith("import ") or stripped.startswith("from "):
            continue
        lines.append(line)
    namespace = {
        "Point3": lambda *args: vec3(args),
        "Vec3": lambda *args: vec3(args),
        "Vec4": lambda *args: tuple(float(item) for item in args),
        "random": random,
        "ToontownGlobals": type("ToontownGlobals", (), {
            "BossbotCountryClubCogLevel": 11,
            "BossbotCountryClubSkelecogLevel": 12,
            "BossbotCountryClubBossLevel": 12,
        }),
    }
    exec("\n".join(lines), namespace)
    return namespace


def number(spec: dict, key: str):
    value = spec.get(key)
    if isinstance(value, tuple):
        return [round(float(item), 4) for item in value]
    if isinstance(value, float):
        return round(value, 4)
    return value


def gameplay_record(ent_id: int, spec: dict) -> dict:
    record = entity_record(ent_id, spec)
    for key in EXTRA_KEYS:
        if key in spec and spec[key] not in (None, "") and key not in record:
            record[key] = number(spec, key)
    return record


def cog_records(room_id: int) -> list[dict]:
    name = COG_ROOMS.get(room_id, "")
    if not name or not (SPEC_DIR / f"{name}_Cogs.py").exists():
        return []
    data = load_spec(f"{name}_Cogs")
    rows = []
    for spec in data.get("CogData", []):
        rows.append({
            "parent": int(spec.get("parentEntId", 0) or 0),
            "pos": [round(value, 4) for value in vec3(spec.get("pos"))],
            "h": float(spec.get("h", 0) or 0),
            "level": int(spec.get("level", 1) or 1),
            "skeleton": int(spec.get("skeleton", 0) or 0),
            "boss": int(spec.get("boss", 0) or 0),
            "revives": int(spec.get("revives", 0) or 0),
            "cell": int(spec.get("battleCell", 0) or 0),
        })
    return rows


def export_room(room_id: int) -> tuple[dict, NodePath]:
    spec = load_spec(ROOM_NAMES[room_id])
    entities = spec.get("GlobalEntities", {})
    geom = dress(room_id, entities)
    gameplay = []
    spawn = 0
    for ent_id, ent in entities.items():
        kind = str(ent.get("type", ""))
        if kind == "entrancePoint" and spawn == 0:
            spawn = int(ent_id)
        if kind in PLAY:
            gameplay.append(gameplay_record(int(ent_id), ent))
    root = NodePath(f"room_{room_id}")
    root.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    dest = OUT_DIR / f"room_{room_id}.glb"
    dest.write_bytes(writer.pack(f"room_{room_id}"))
    print(f"wrote room_{room_id}.glb", flush=True)
    return {
        "file": f"res://assets/cog_hq/courses/room_{room_id}.glb",
        "spawn": spawn,
        "entities": gameplay,
        "cogs": cog_records(room_id),
    }, geom


def export_hall(index: int, relative: str) -> str:
    model = load_model(resolve_model(relative) or relative)
    root = NodePath(f"hall_{index}")
    root.setMat(Z_UP_TO_Y_UP)
    model.copyTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    dest = OUT_DIR / f"hall_{index}.glb"
    dest.write_bytes(writer.pack(f"hall_{index}"))
    print(f"wrote hall_{index}.glb", flush=True)
    return f"res://assets/cog_hq/courses/hall_{index}.glb"


def bake_floor(zone: int, layout: int, floor: int, room_ids: tuple, rooms: dict[int, NodePath]) -> dict:
    hall_rng = random.Random(zone * floor)
    drawn = [hall_rng.choice(CONNECTORS) for _ in range(HALL_DRAWS[zone])]
    used = drawn[:len(room_ids) - 1]
    attach_rng = random.Random(zone * floor)
    stage = NodePath("stage")
    pieces = []
    halls = []
    for index, room_id in enumerate(room_ids):
        room = rooms[room_id].copyTo(NodePath())
        if index == 0:
            room.reparentTo(stage)
        else:
            attach_to(room, halls[index - 1], attach_rng)
        pieces.append({
            "kind": "room",
            "room": room_id,
            "mat": godot_placement(room.getMat(stage)),
        })
        if index < len(room_ids) - 1:
            hall = load_model(resolve_model(used[index]) or used[index])
            attach_to(hall, room, attach_rng)
            halls.append(hall)
            pieces.append({
                "kind": "hall",
                "hall": CONNECTORS.index(used[index]),
                "mat": godot_placement(hall.getMat(stage)),
            })
    stage.removeNode()
    return {"rooms": list(room_ids), "pieces": pieces}


def copy_music() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    source = ASSETS / "phase_12/audio/bgm/Bossbot_Factory_v1.ogg"
    dest = AUDIO / "Bossbot_Factory_v1.ogg"
    if source.exists() and not dest.exists():
        shutil.copy2(source, dest)
        print("copied", dest.name, flush=True)


def main() -> int:
    loadPrcFileData("", "notify-level-loader error")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    copy_music()
    rooms_json = {}
    dressed: dict[int, NodePath] = {}
    for room_id in ROOM_NAMES:
        record, geom = export_room(room_id)
        rooms_json[str(room_id)] = record
        dressed[room_id] = geom
    halls = [export_hall(index, relative) for index, relative in enumerate(CONNECTORS)]
    floors = {}
    for layout, room_floors in enumerate(LAYOUTS):
        zone = ZONES[layout]
        for floor, room_ids in enumerate(room_floors):
            key = f"{zone}:{layout}:{floor}"
            floors[key] = bake_floor(zone, layout, floor, room_ids, dressed)
            print("baked", key, room_ids, flush=True)
    for geom in dressed.values():
        geom.removeNode()
    payload = {"rooms": rooms_json, "halls": halls, "floors": floors}
    dest = OUT_DIR / "courses.json"
    dest.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print("wrote", dest, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
