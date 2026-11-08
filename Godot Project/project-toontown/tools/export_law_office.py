"""Export Lawbot D.A. Office rooms and the baked floor plans.

StageLayout picks hallways with random.Random(stageId * floorNum), then a second
Random with the same seed chooses which ENTRANCE each piece attaches to.
Those choices are baked here so the game does not reimplement Python's RNG.
Each room is exported like the other HQ models: a Z-up root, content as a child.
The placement matrix is the Y-up conjugate of the assembled panda matrix, so a
pivot parent times that root lands on the original floor.
"""
from __future__ import annotations

import json
import random
import shutil
import sys
from pathlib import Path

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP, panda_path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Game Assets"
)
SPEC_DIR = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Source Code\toontown\coghq"
)
OUT_DIR = ROOT / "assets" / "cog_hq" / "offices"
AUDIO = ROOT / "assets" / "cog_hq" / "audio"

ROOM_NAMES = {
    0: "LawbotOfficeEntrance_Action00",
    1: "LawbotOfficeOilRoom_Battle00",
    2: "LawbotOfficeOilRoom_Battle01",
    3: "LawbotOfficeBoilerRoom_Security00",
    4: "LawbotOfficeBoilerRoom_Battle00",
    5: "LawbotOfficeGearRoom_Action00",
    6: "LawbotOfficeLobby_Action00",
    7: "LawbotOfficeGearRoom_Security00",
    8: "LawbotOfficeLobby_Trap00",
    9: "LawbotOfficeDiamondRoom_Security00",
    10: "LawbotOfficeDiamondRoom_Trap00",
    11: "LawbotOfficeGearRoom_Platform00",
    12: "LawbotOfficeLobby_Lights00",
    100: "LawbotOfficeBoilerRoom_Action01",
    101: "LawbotOfficeDiamondRoom_Action00",
    102: "LawbotOfficeDiamondRoom_Action01",
    103: "LawbotOfficeLobby_Action01",
    104: "LawbotOfficeDiamondRoom_Battle00",
    105: "LawbotOfficeGearRoom_Battle00",
}
COG_ROOMS = {
    1: "LawbotOfficeOilRoom_Battle00",
    2: "LawbotOfficeOilRoom_Battle01",
    4: "LawbotOfficeBoilerRoom_Battle00",
    8: "LawbotOfficeLobby_Trap00",
    10: "LawbotOfficeDiamondRoom_Trap00",
    104: "LawbotOfficeDiamondRoom_Battle00",
    105: "LawbotOfficeGearRoom_Battle00",
}
# LawbotOfficeBoilerRoom_Trap00 has cogs too.
COG_ROOMS[3] = ""  # security, no cog module under this name
CONNECTORS = (
    "phase_11/models/lawbotHQ/LB_connector_7cubeL2",
    "phase_11/models/lawbotHQ/LB_connector_7cubeLR",
)
MODEL_ALIAS = {
    "phase_11/models/lawbotHQ/LB_Zone8a": "phase_11/models/lawbotHQ/LB_Zone08a",
}
LAYOUTS = [
    [(0, 7, 8, 105, 1), (0, 10, 104, 103, 1), (0, 105, 101, 12, 2)],
    [(0, 10, 11, 104, 1), (0, 100, 105, 8, 1), (0, 103, 3, 104, 2)],
    [(0, 8, 105, 102, 1), (0, 100, 104, 10, 1), (0, 101, 105, 3, 2)],
    [(0, 8, 101, 104, 1), (0, 7, 105, 103, 1), (0, 100, 8, 104, 1), (0, 105, 10, 12, 2)],
    [(0, 100, 8, 105, 1), (0, 103, 10, 104, 1), (0, 8, 7, 105, 1), (0, 104, 12, 101, 2)],
    [(0, 103, 104, 100, 1), (0, 102, 8, 105, 1), (0, 10, 104, 3, 1), (0, 105, 10, 11, 2)],
    [(0, 3, 7, 105, 1), (0, 103, 104, 8, 1), (0, 102, 105, 11, 1), (0, 8, 104, 100, 1), (0, 10, 105, 12, 2)],
    [(0, 7, 105, 102, 1), (0, 103, 12, 104, 1), (0, 101, 104, 8, 1), (0, 10, 3, 105, 1), (0, 8, 104, 102, 2)],
    [(0, 11, 105, 102, 1), (0, 3, 104, 8, 1), (0, 100, 10, 104, 1), (0, 8, 12, 105, 1), (0, 104, 102, 11, 2)],
    [(0, 104, 10, 7, 1), (0, 105, 103, 3, 1), (0, 104, 11, 12, 1), (0, 101, 8, 105, 1), (0, 10, 104, 12, 1), (0, 105, 100, 7, 2)],
    [(0, 11, 8, 104, 1), (0, 102, 10, 105, 1), (0, 104, 7, 101, 1), (0, 105, 10, 12, 1), (0, 8, 11, 105, 1), (0, 104, 12, 3, 2)],
    [(0, 105, 103, 8, 1), (0, 10, 3, 104, 1), (0, 105, 103, 101, 1), (0, 12, 8, 104, 1), (0, 7, 11, 104, 1), (0, 105, 12, 10, 2)],
]
# Office A uses layouts 0-2, B 3-5, C 6-8, D 9-11. The RNG seed is the zone id.
ZONES = [13300, 13300, 13300, 13400, 13400, 13400, 13500, 13500, 13500, 13600, 13600, 13600]
PLAY = {
    "laserField", "button", "door", "stomper", "securityCamera", "platform", "mover",
    "goon", "path", "pathMaster", "gagBarrel", "healBarrel", "battleBlocker", "collisionSolid",
    "elevatorMarker", "entrancePoint",
}
SFX = [
    "phase_11/audio/sfx/LB_laser_beam_on_2.ogg",
    "phase_11/audio/sfx/LB_laser_beam_off_2.ogg",
    "phase_11/audio/sfx/LB_camera_shutter_2.ogg",
    "phase_9/audio/sfx/CHQ_FACT_door_open_sliding.ogg",
    "phase_9/audio/sfx/CHQ_FACT_door_open_final.ogg",
    "phase_9/audio/sfx/CHQ_FACT_door_unlock.ogg",
    "phase_9/audio/sfx/CHQ_FACT_switch_pressed.ogg",
    "phase_4/audio/sfx/MG_cannon_fire_alt.ogg",
]


def vec3(value) -> tuple[float, float, float]:
    if isinstance(value, (int, float)):
        return (float(value), float(value), float(value))
    if value is None:
        return (0.0, 0.0, 0.0)
    numbers = list(value)
    while len(numbers) < 3:
        numbers.append(0.0)
    return (float(numbers[0]), float(numbers[1]), float(numbers[2]))


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
        "Vec4": lambda *args: tuple(float(v) for v in args),
        "random": random,
        "ToontownGlobals": type("ToontownGlobals", (), {
            "CashbotMintBossLevel": 12,
            "CashbotMintCogLevel": 10,
            "CashbotMintSkelecogLevel": 11,
        }),
    }
    exec("\n".join(lines), namespace)
    return namespace


def resolve_model(path) -> str | None:
    if path in (0, None, "0", ""):
        return None
    text = str(path).replace("\\", "/")
    if text.endswith(".bam"):
        text = text[:-4]
    text = MODEL_ALIAS.get(text, text)
    bam = ASSETS / f"{text}.bam"
    egg = ASSETS / f"{text}.egg"
    if bam.exists():
        return f"{text}.bam"
    if egg.exists():
        return f"{text}.egg"
    print("missing model", text, flush=True)
    return None


def load_model(relative: str) -> NodePath | None:
    loader = Loader.getGlobalPtr()
    loaded = loader.loadSync(panda_path(relative))
    if loaded is None:
        print("unreadable", relative, flush=True)
        return None
    node = NodePath(loaded)
    node.setName(Path(relative).stem)
    return node


def prop_for(kind: str, spec: dict) -> str | None:
    explicit = resolve_model(spec.get("modelPath"))
    if explicit:
        return explicit
    if kind == "door":
        return resolve_model("phase_9/models/cogHQ/CogDoorHandShake")
    if kind == "button":
        return resolve_model("phase_9/models/cogHQ/CogDoor_Button")
    if kind == "stomper":
        if int(spec.get("cogStyle", 0) or 0) == 1:
            return resolve_model("phase_11/models/lawbotHQ/LB_square_stomper")
        return resolve_model("phase_9/models/cogHQ/square_stomper")
    if kind in ("gagBarrel", "healBarrel"):
        return resolve_model("phase_4/models/cogHQ/gagTank")
    if kind == "goon":
        # Goon.generateGoon loads the zero pose. There is no Cog_Goonie.bam.
        return resolve_model("phase_9/models/char/Cog_Goonie-zero")
    if kind == "platform":
        return resolve_model("phase_9/models/cogHQ/platform1")
    return None


def apply_transform(node: NodePath, spec: dict) -> None:
    node.setPos(*vec3(spec.get("pos", (0.0, 0.0, 0.0))))
    node.setHpr(*vec3(spec.get("hpr", (0.0, 0.0, 0.0))))
    scale = spec.get("scale", 1)
    node.setScale(*vec3(scale))
    color = spec.get("color")
    if isinstance(color, tuple) and len(color) >= 3:
        node.setColorScale(*color[:4]) if len(color) >= 4 else node.setColorScale(color[0], color[1], color[2], 1)


def dress(room_id: int, entities: dict) -> NodePath:
    shell = "phase_11/models/lawbotHQ/LB_Zone03a"
    for spec in entities.values():
        if spec.get("type") == "levelMgr" and spec.get("modelFilename"):
            shell = str(spec["modelFilename"])
            break
    relative = resolve_model(shell)
    if relative is None:
        raise RuntimeError(f"room {room_id} has no shell")
    geom = load_model(relative)
    if geom is None:
        raise RuntimeError(f"room {room_id} shell failed")
    geom.setName(f"room-{room_id}")
    nodes: dict[int, NodePath] = {0: geom}
    for ent_id, spec in entities.items():
        if ent_id == 0 or spec.get("type") in ("levelMgr", "editMgr", "zone"):
            continue
        node = geom.attachNewNode(f"ent-{ent_id}")
        nodes[int(ent_id)] = node
    for ent_id, spec in entities.items():
        if int(ent_id) not in nodes or int(ent_id) == 0:
            continue
        parent_id = int(spec.get("parentEntId", 0) or 0)
        parent = nodes.get(parent_id, geom)
        node = nodes[int(ent_id)]
        node.reparentTo(parent)
        apply_transform(node, spec)
        kind = str(spec.get("type", ""))
        relative = prop_for(kind, spec)
        if not relative:
            continue
        model = load_model(relative)
        if model is None:
            continue
        if kind == "stomper":
            rotate = node.attachNewNode("stomp-rotate")
            if str(spec.get("style", "vertical")) == "vertical":
                rotate.setP(-90)
            model.reparentTo(rotate)
            model.setName("stomp-model")
            head = model.find("**/head")
            shaft = model.find("**/shaft")
            if not head.isEmpty():
                head.setScale(*vec3(spec.get("headScale", (1, 1, 1))))
            if not shaft.isEmpty():
                shaft.setScale(*vec3(spec.get("shaftScale", (1, 1, 1))))
            continue
        if kind == "platform":
            model.setName("platform-move")
            model.setScale(*vec3(spec.get("modelScale", (1, 1, 1))))
        model.reparentTo(node)
        if kind == "goon":
            # Goon.initGoon turns the geom around so the face leads the path.
            actor = model.find("**/actorGeom")
            if not actor.isEmpty():
                actor.setH(180)
            hat_name = "hard_hat" if str(spec.get("goonType", "sg")) == "sg" else "security_hat"
            hat = model.find(f"**/{hat_name}")
            if not hat.isEmpty():
                hat.hide()
    return geom


def paths_of(collection) -> list[NodePath]:
    return [collection[index] for index in range(collection.getNumPaths())]


def attach_to(geom: NodePath, other: NodePath, rng: random.Random) -> None:
    exits = paths_of(other.findAllMatches("**/EXIT*"))
    entrances = paths_of(geom.findAllMatches("**/ENTRANCE*"))
    if not exits or not entrances:
        print("no door", geom.getName(), "exits", len(exits), "entrances", len(entrances), flush=True)
        geom.reparentTo(other.getParent())
        return
    other_door = exits[0]
    this_door = rng.choice(entrances)
    temp = other_door.attachNewNode("tempRotNode")
    geom.reparentTo(temp)
    geom.clearMat()
    spot = this_door.getPos(geom)
    geom.setPos(-spot[0], -spot[1], -spot[2])
    temp.setH(-this_door.getH(other_door))
    geom.wrtReparentTo(other.getParent())
    temp.removeNode()


def column_matrix(mat) -> list[list[float]]:
    # Panda stores a row-vector matrix. Column-vector form is its transpose.
    return [[mat.getCell(col, row) for col in range(4)] for row in range(4)]


def mul(a, b):
    out = [[0.0] * 4 for _ in range(4)]
    for row in range(4):
        for col in range(4):
            out[row][col] = sum(a[row][k] * b[k][col] for k in range(4))
    return out


def godot_placement(mat) -> list[float]:
    # G = Z * M^T * Z^-1. The room's own Z-up root supplies Z, so the pivot is G.
    z_up = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, -1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    z_inv = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, -1.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    placed = mul(mul(z_up, column_matrix(mat)), z_inv)
    columns = []
    for col in range(3):
        columns.extend([placed[0][col], placed[1][col], placed[2][col]])
    columns.extend([placed[0][3], placed[1][3], placed[2][3]])
    return [round(value, 5) for value in columns]


def number(spec: dict, key: str, default=0):
    value = spec.get(key, default)
    if isinstance(value, tuple):
        return [round(float(item), 4) for item in value]
    if isinstance(value, float):
        return round(value, 4)
    return value


def entity_record(ent_id: int, spec: dict) -> dict:
    record = {"id": int(ent_id), "type": str(spec.get("type", ""))}
    keys = (
        "cellId", "radius", "length", "solidType", "gridGame", "gridScaleX", "gridScaleY",
        "switchId", "secondsOn", "isOn", "damage", "motion", "period", "phaseShift", "range",
        "style", "cogStyle", "attackRadius", "strength", "velocity", "hFov", "goonType",
        "pathIndex", "pathScale", "entity2Move", "moveTarget", "pos0Move", "pos0Wait",
        "pos1Move", "pos1Wait", "cycleType", "startOn", "waitPercent", "damPow",
        "gagLevel", "gagTrack", "rewardPerGrab", "rewardPerGrabMax", "secondsOpen",
        "isLock0Unlocked", "isLock1Unlocked", "isLock2Unlocked", "isLock3Unlocked",
        "unlock0Event", "unlock1Event", "unlock2Event", "unlock3Event",
        "trackTarget1", "trackTarget2", "trackTarget3",
        "pathTarget0", "pathTarget1", "pathTarget2", "pathTarget3",
        "pathTarget4", "pathTarget5", "pathTarget6", "pathTarget7",
    )
    for key in keys:
        if key in spec and spec[key] not in (None, ""):
            record[key] = number(spec, key)
    if "offset" in spec:
        record["offset"] = list(vec3(spec.get("offset")))
    if "projector" in spec:
        record["projector"] = list(vec3(spec.get("projector")))
    return record


def cog_records(room_id: int, laser_cells: set[int]) -> list[dict]:
    name = COG_ROOMS.get(room_id, "")
    if not name:
        # Trap boilers use a cog module whose room is not in the first map.
        extra = {
            100: "",
        }
        module_name = {
            8: "LawbotOfficeLobby_Trap00",
            10: "LawbotOfficeDiamondRoom_Trap00",
        }.get(room_id, ROOM_NAMES.get(room_id, ""))
        cog_file = SPEC_DIR / f"{module_name}_Cogs.py"
        if not cog_file.exists():
            return []
        name = module_name
    else:
        cog_file = SPEC_DIR / f"{name}_Cogs.py"
        if not cog_file.exists():
            return []
    data = load_spec(f"{name}_Cogs")
    rows = []
    for spec in data.get("CogData", []):
        cell = int(spec.get("battleCell", 0) or 0)
        rows.append({
            "parent": int(spec.get("parentEntId", 0) or 0),
            "pos": [round(value, 4) for value in vec3(spec.get("pos"))],
            "h": float(spec.get("h", 0) or 0),
            "level": int(spec.get("level", 1) or 1),
            "skeleton": int(spec.get("skeleton", 0) or 0),
            "boss": int(spec.get("boss", 0) or 0),
            "cell": cell,
            "hidden": cell in laser_cells,
        })
    return rows


def export_room(room_id: int) -> tuple[dict, NodePath]:
    spec = load_spec(ROOM_NAMES[room_id])
    entities = spec.get("GlobalEntities", {})
    geom = dress(room_id, entities)
    laser_cells = set()
    gameplay = []
    spawn = 0
    for ent_id, ent in entities.items():
        kind = str(ent.get("type", ""))
        if kind == "laserField":
            laser_cells.add(int(ent.get("cellId", 0) or 0))
        if kind == "entrancePoint" and spawn == 0:
            spawn = int(ent_id)
        if kind in PLAY:
            gameplay.append(entity_record(int(ent_id), ent))
    writer_root = NodePath(f"room_{room_id}")
    writer_root.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(writer_root)
    writer = GltfWriter()
    writer.add_node(writer_root, None)
    dest = OUT_DIR / f"room_{room_id}.glb"
    dest.write_bytes(writer.pack(f"room_{room_id}"))
    print(f"wrote room_{room_id}.glb", flush=True)
    record = {
        "file": f"res://assets/cog_hq/offices/room_{room_id}.glb",
        "spawn": spawn,
        "entities": gameplay,
        "cogs": cog_records(room_id, laser_cells),
    }
    # Assembly uses a fresh dressed copy. The exported one stays in the glb.
    geom.removeNode()
    writer_root.removeNode()
    return record, dress(room_id, entities)


def export_hall(index: int, relative: str) -> str:
    model = load_model(resolve_model(relative) or relative)
    if model is None:
        raise RuntimeError(relative)
    root = NodePath(f"hall_{index}")
    root.setMat(Z_UP_TO_Y_UP)
    model.copyTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    dest = OUT_DIR / f"hall_{index}.glb"
    dest.write_bytes(writer.pack(f"hall_{index}"))
    print(f"wrote hall_{index}.glb", flush=True)
    model.removeNode()
    root.removeNode()
    return f"res://assets/cog_hq/offices/hall_{index}.glb"


def export_prop(name: str, relative: str) -> str:
    model = load_model(resolve_model(relative) or relative)
    if model is None:
        return ""
    root = NodePath(name)
    root.setMat(Z_UP_TO_Y_UP)
    model.copyTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    dest = OUT_DIR / f"{name}.glb"
    dest.write_bytes(writer.pack(name))
    print(f"wrote {name}.glb", flush=True)
    model.removeNode()
    root.removeNode()
    return f"res://assets/cog_hq/offices/{name}.glb"


def bake_floor(zone: int, layout: int, floor: int, room_ids: tuple, rooms: dict[int, NodePath]) -> dict:
    # StageLayout.__init__ draws one hallway per room id, then gotAllRooms uses
    # only the first len-1. The unused draw still advances that RNG.
    hall_rng = random.Random(zone * floor)
    drawn = [hall_rng.choice(CONNECTORS) for _ in room_ids]
    used = drawn[:-1]
    attach_rng = random.Random(zone * floor)
    stage = NodePath("stage")
    pieces = []
    previous = None
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
        previous = room
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


def office_paths() -> dict:
    # PathEntity.setPathIndex reads GoonPathData.Paths['lawOfficeStage'].
    source = (SPEC_DIR.parent / "suit" / "GoonPathData.py").read_text(encoding="utf-8")
    source = source.replace(
        "from panda3d.core import *",
        "def Vec3(x, y, z):\n    return (float(x), float(y), float(z))\nPoint3 = Vec3",
    )
    source = source.replace(
        "from toontown.toonbase import ToontownGlobals",
        "class _Globals:\n    def __getattr__(self, _name):\n        return _name\nToontownGlobals = _Globals()",
    )
    namespace: dict = {}
    exec(source, namespace)
    table = namespace["Paths"]["lawOfficeStage"]
    return {
        str(index): [[round(float(value), 4) for value in point] for point in points]
        for index, points in table.items()
    }


def copy_sfx() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    for relative in SFX:
        source = ASSETS / relative
        dest = AUDIO / Path(relative).name
        if source.exists() and not dest.exists():
            shutil.copy2(source, dest)
            print("copied", dest.name, flush=True)


def main() -> int:
    loadPrcFileData("", "notify-level-loader error")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    copy_sfx()
    rooms_json = {}
    dressed: dict[int, NodePath] = {}
    for room_id in ROOM_NAMES:
        record, geom = export_room(room_id)
        rooms_json[str(room_id)] = record
        dressed[room_id] = geom
    halls = [export_hall(index, relative) for index, relative in enumerate(CONNECTORS)]
    elevators = {
        "lobby": export_prop("mint_elevator", "phase_10/models/cogHQ/mintElevator"),
        "floor": export_prop("floor_elevator", "phase_11/models/lawbotHQ/LB_ElevatorScaled"),
    }
    floors = {}
    for layout, room_floors in enumerate(LAYOUTS):
        zone = ZONES[layout]
        for floor, room_ids in enumerate(room_floors):
            key = f"{zone}:{layout}:{floor}"
            floors[key] = bake_floor(zone, layout, floor, room_ids, dressed)
            print("baked", key, room_ids, flush=True)
    for geom in dressed.values():
        geom.removeNode()
    payload = {
        "rooms": rooms_json,
        "halls": halls,
        "elevators": elevators,
        "floors": floors,
        "paths": office_paths(),
    }
    dest = OUT_DIR / "offices.json"
    dest.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print("wrote", dest, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
