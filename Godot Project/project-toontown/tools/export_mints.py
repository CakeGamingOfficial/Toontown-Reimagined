"""Export Cashbot mint rooms, connectors, and the baked floor layouts.

MintLayout stitches an entrance, middle rooms, hallways, and a final room.
Each room bam is only the shell. Model, gear, stomper, barrel, crate, mixer,
and platform entities are parented on here so the glb matches the original
room. Coin, dollar, and bullion props stay out of the glb: MintProduct picks
the mesh from the mint you entered.
"""
from __future__ import annotations

import json
import math
import random
import sys
import types
from pathlib import Path

from panda3d.core import (
    Filename,
    Loader,
    Mat4,
    NodePath,
    Point3,
    Vec3,
    getModelPath,
    loadPrcFileData,
)

fake_toontown = types.ModuleType("panda3d.toontown")
fake_toontown.DNAStorage = object
fake_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = fake_toontown

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from export_cog_hqs import export_node  # noqa: E402
from export_toontown_central import Z_UP_TO_Y_UP  # noqa: E402

ASSETS = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
SOURCE = Path(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\coghq"
)
OUT = TOOLS.parent / "assets" / "cog_hq" / "mint"
DATA = TOOLS.parent / "assets" / "cog_hq" / "mint_data.json"
LAYOUT = SOURCE.parent.parent / "coghq" / "MintLayout.py"
# MintLayout.py lives next to the room specs.
LAYOUT = SOURCE / "MintLayout.py"

MINTS = (12500, 12600, 12700)
# ToontownGlobals.MintNumRooms. The baked list is this many rooms plus the ends.
MIDDLE = {
    12500: (6,) * 2 + (7,) * 5 + (8,) * 5 + (9,) * 5 + (10,) * 3,
    12600: (8,) * 3 + (9,) * 6 + (10,) * 6 + (11,) * 5,
    12700: (10,) * 4 + (11,) * 10 + (12,) * 6,
}
CONNECTORS = (
    "phase_10/models/cashbotHQ/connector_7cubeL2",
    "phase_10/models/cashbotHQ/connector_7cubeR2",
)
PRODUCTS = {
    "mintProduct": {
        12500: ("phase_10/models/cashbotHQ/MoneyBag", 0.98),
        12600: ("phase_10/models/cashbotHQ/MoneyStackPallet", 0.38),
        12700: ("phase_10/models/cashbotHQ/GoldBarStack", 0.6),
    },
    "mintShelf": {
        12500: ("phase_10/models/cashbotHQ/shelf_A1MoneyBags", 1.0),
        12600: ("phase_10/models/cashbotHQ/shelf_A1Money", 1.0),
        12700: ("phase_10/models/cashbotHQ/shelf_A1Gold", 1.0),
    },
    "mintProductPallet": {
        12500: ("phase_10/models/cashbotHQ/DoubleCoinStack", 1.0),
        12600: ("phase_10/models/cogHQ/DoubleMoneyStack", 1.0),
        12700: ("phase_10/models/cashbotHQ/DoubleGoldStack", 1.0),
    },
}
BOSS = 12
SKELE = 11
COG = 10
Z = Z_UP_TO_Y_UP
ZI = Mat4(Z)
ZI.invertInPlace()


class _Vec:
    def __init__(self, x=0, y=0, z=0, w=0):
        self.values = (float(x), float(y), float(z), float(w))

    def __getitem__(self, index: int) -> float:
        return self.values[index]


def vec3(value, fallback: float = 0.0) -> tuple[float, float, float]:
    if isinstance(value, (int, float)):
        return (float(value), float(value), float(value) if fallback != 0.0 else float(value))
    if value is None:
        return (fallback, fallback, fallback)
    return (float(value[0]), float(value[1]), float(value[2]))


def scale_of(value) -> Vec3:
    if isinstance(value, (int, float)):
        return Vec3(float(value), float(value), float(value))
    if value is None:
        return Vec3(1, 1, 1)
    return Vec3(float(value[0]), float(value[1]), float(value[2]))


def panda_seed(mint_id: int, floor_num: int) -> random.Random:
    # MintLayout.getRng. Toontown seeded Python 2's generator.
    rng = random.Random()
    rng.seed(mint_id * floor_num, version=1)
    return rng


def load_py(path: Path, extra: dict | None = None) -> dict:
    source = path.read_text(encoding="utf-8")
    lines = []
    for line in source.splitlines():
        stripped = line.strip()
        if stripped.startswith("from ") or stripped.startswith("import "):
            continue
        lines.append(line)
    namespace = {
        "Point3": _Vec,
        "Vec3": _Vec,
        "Vec4": _Vec,
        "VBase3": _Vec,
        "CashbotMintBossLevel": BOSS,
        "CashbotMintSkelecogLevel": SKELE,
        "CashbotMintCogLevel": COG,
    }
    if extra:
        namespace.update(extra)
    exec("\n".join(lines), namespace)
    return namespace


def load_model(relative: str) -> NodePath:
    name = relative
    if name.endswith(".bam"):
        name = name[:-4]
    loader = Loader.getGlobalPtr()
    loaded = loader.loadSync(Filename(name))
    if loaded is None:
        loaded = loader.loadSync(Filename(name + ".bam"))
    if loaded is None:
        raise RuntimeError(f"missing model {relative}")
    node = NodePath(loaded)
    node.setName(Path(name).stem)
    return node


def drop_collision(model: NodePath) -> None:
    for coll in list(model.findAllMatches("**/+CollisionNode")):
        label = coll.getName().upper()
        if label.startswith("ENTRANCE") or label.startswith("EXIT"):
            continue
        coll.removeNode()


def doors_of(model: NodePath) -> dict:
    found = {"entrances": [], "exits": []}
    for kind, key in (("ENTRANCE", "entrances"), ("EXIT", "exits")):
        for node in model.findAllMatches(f"**/{kind}*"):
            pos = node.getPos(model)
            found[key].append({
                "pos": [pos.x, pos.y, pos.z],
                "h": node.getH(model),
            })
    return found


def xform_of(mat: Mat4) -> dict:
    # T = inv(Z) * M * Z. The glb root already applies Z, so this is the
    # instance transform in Godot's Y-up space.
    converted = ZI * mat * Z
    origin = converted.xformPoint(Point3(0, 0, 0))
    axes = []
    for axis in (Point3(1, 0, 0), Point3(0, 1, 0), Point3(0, 0, 1)):
        axes.append(converted.xformPoint(axis) - origin)
    return {
        "x": [axes[0].x, axes[0].y, axes[0].z],
        "y": [axes[1].x, axes[1].y, axes[1].z],
        "z": [axes[2].x, axes[2].y, axes[2].z],
        "o": [origin.x, origin.y, origin.z],
    }


def make_holders(model: NodePath, entities: dict) -> dict[int, NodePath]:
    holders = {0: model}
    pending = [int(key) for key, spec in entities.items() if spec.get("type") == "nodepath"]
    guard = 0
    while pending and guard < 20:
        guard += 1
        nxt = []
        for ent_id in pending:
            spec = entities[ent_id]
            parent = int(spec.get("parentEntId", 0))
            if parent not in holders:
                nxt.append(ent_id)
                continue
            node = holders[parent].attachNewNode(f"nodepath-{ent_id}")
            pos = vec3(spec.get("pos"), 0.0)
            hpr = vec3(spec.get("hpr"), 0.0)
            node.setPosHprScale(Vec3(*pos), Vec3(*hpr), scale_of(spec.get("scale", 1)))
            holders[ent_id] = node
        if len(nxt) == len(pending):
            break
        pending = nxt
    return holders


def parent_of(holders: dict[int, NodePath], spec: dict) -> NodePath:
    parent = int(spec.get("parentEntId", 0))
    return holders.get(parent, holders[0])


def place_mesh(holders: dict[int, NodePath], spec: dict, ent_id: int, relative: str, node_name: str) -> NodePath | None:
    try:
        mesh = load_model(relative)
    except RuntimeError as error:
        print("skip", error, flush=True)
        return None
    mesh.setName(node_name)
    mesh.reparentTo(parent_of(holders, spec))
    pos = vec3(spec.get("pos"), 0.0)
    hpr = vec3(spec.get("hpr"), 0.0)
    mesh.setPosHprScale(Vec3(*pos), Vec3(*hpr), scale_of(spec.get("scale", 1)))
    holders[ent_id] = mesh
    return mesh


def dress(model: NodePath, entities: dict) -> dict:
    holders = make_holders(model, entities)
    hazards = {"stompers": [], "gears": [], "barrels": [], "goons": [], "crates": [], "belts": [], "platforms": [], "products": []}
    pending = []
    for key, spec in entities.items():
        if not isinstance(spec, dict):
            continue
        kind = spec.get("type")
        if kind in ("levelMgr", "editMgr", "zone", "nodepath", "attribModifier", "battleBlocker", "locator", "grid", "path", "entrancePoint"):
            continue
        pending.append(int(key))
    guard = 0
    while pending and guard < 12:
        guard += 1
        nxt = []
        for ent_id in pending:
            spec = entities[ent_id]
            if int(spec.get("parentEntId", 0)) not in holders:
                nxt.append(ent_id)
                continue
            _place_one(holders, hazards, ent_id, spec)
        if len(nxt) == len(pending):
            for ent_id in nxt:
                _place_one(holders, hazards, ent_id, entities[ent_id])
            break
        pending = nxt
    return hazards


def _place_one(holders: dict[int, NodePath], hazards: dict, ent_id: int, spec: dict) -> None:
    kind = spec.get("type")
    if kind == "model":
        path = spec.get("modelPath")
        if isinstance(path, str) and path:
            place_mesh(holders, spec, ent_id, path, f"model-{ent_id}")
        return
    if kind == "paintMixer":
        place_mesh(holders, spec, ent_id, spec.get("modelPath", "phase_9/models/cogHQ/PaintMixer"), f"mixer-{ent_id}")
        return
    if kind == "gear":
        _place_gear(holders, hazards, ent_id, spec)
        return
    if kind == "stomper":
        _place_stomper(holders, hazards, ent_id, spec)
        return
    if kind in ("healBarrel", "gagBarrel", "beanBarrel"):
        mesh = place_mesh(holders, spec, ent_id, "phase_4/models/cogHQ/gagTank", f"barrel-{ent_id}")
        if mesh is not None:
            hazards["barrels"].append({
                "id": ent_id,
                "name": f"barrel-{ent_id}",
                "kind": kind,
                "grab": int(spec.get("rewardPerGrab", 5)),
                "track": spec.get("gagTrack", "random"),
                "level": int(spec.get("gagLevel", 0) or 0),
            })
        return
    if kind == "crate":
        model_type = int(spec.get("modelType", 0) or 0)
        path = "phase_10/models/cashbotHQ/CBWoodCrate" if model_type else "phase_9/models/cogHQ/woodCrateB"
        mesh = place_mesh(holders, spec, ent_id, path, f"crate-{ent_id}")
        if mesh is not None:
            hazards["crates"].append({"id": ent_id, "name": f"crate-{ent_id}"})
        return
    if kind == "conveyorBelt":
        mesh = place_mesh(holders, spec, ent_id, spec.get("treadModelPath", "phase_9/models/cogHQ/platform1"), f"belt-{ent_id}")
        if mesh is not None:
            hazards["belts"].append({
                "id": ent_id,
                "name": f"belt-{ent_id}",
                "speed": float(spec.get("speed", 1.0)),
                "length": float(spec.get("length", 10.0)),
            })
        return
    if kind == "sinkingPlatform":
        mesh = place_mesh(holders, spec, ent_id, "phase_9/models/cogHQ/platform1", f"platform-{ent_id}")
        if mesh is not None:
            hazards["platforms"].append({
                "id": ent_id,
                "name": f"platform-{ent_id}",
                "drop": float(spec.get("verticalRange", 1.0)),
                "sink": float(spec.get("sinkDuration", 1.0)),
                "pause": float(spec.get("pauseBeforeRise", 1.0)),
                "rise": float(spec.get("riseDuration", 1.0)),
            })
        return
    if kind == "goon":
        # The mesh is the shared goon. A marker keeps the entity transform.
        node = parent_of(holders, spec).attachNewNode(f"goon-{ent_id}")
        pos = vec3(spec.get("pos"), 0.0)
        hpr = vec3(spec.get("hpr"), 0.0)
        node.setPosHprScale(Vec3(*pos), Vec3(*hpr), scale_of(spec.get("scale", 1)))
        holders[ent_id] = node
        spot = node.getPos(holders[0])
        hazards["goons"].append({
            "id": ent_id,
            "pos": [spot.x, spot.y, spot.z],
            "h": node.getH(holders[0]),
            "scale": float(spec.get("scale", 1) if isinstance(spec.get("scale", 1), (int, float)) else spec.get("scale", [1])[0]),
            "speed": float(spec.get("velocity", 4.0)),
            "reach": float(spec.get("attackRadius", 15.0)),
            "strength": int(spec.get("strength", 5)),
            "fov": float(spec.get("hFov", 70.0)),
        })
        return
    if kind in PRODUCTS:
        node = parent_of(holders, spec).attachNewNode(f"product-{ent_id}")
        pos = vec3(spec.get("pos"), 0.0)
        hpr = vec3(spec.get("hpr"), 0.0)
        node.setPosHprScale(Vec3(*pos), Vec3(*hpr), scale_of(spec.get("scale", 1)))
        holders[ent_id] = node
        mat = node.getMat(holders[0])
        hazards["products"].append({
            "kind": kind,
            "mat": [mat.getCell(row, col) for row in range(4) for col in range(4)],
        })


def _place_gear(holders, hazards, ent_id: int, spec: dict) -> None:
    path = "phase_10/models/cashbotHQ/MintGear"
    if spec.get("modelType") == "factory":
        path = "phase_9/models/cogHQ/FactoryGearB"
    try:
        mesh = load_model(path)
    except RuntimeError as error:
        print("skip", error, flush=True)
        return
    pivot = parent_of(holders, spec).attachNewNode(f"gear-{ent_id}")
    pos = vec3(spec.get("pos"), 0.0)
    hpr = vec3(spec.get("hpr"), 0.0)
    pivot.setPosHprScale(Vec3(*pos), Vec3(*hpr), Vec3(1, 1, 1))
    if spec.get("orientation") == "vertical":
        pivot.setP(pivot.getP() - 90.0)
    mesh.reparentTo(pivot)
    gear_scale = float(spec.get("gearScale", 1.0) or 1.0)
    entity_scale = scale_of(spec.get("scale", 1))
    mesh.setScale(entity_scale * gear_scale)
    if spec.get("orientation", "horizontal") == "horizontal":
        mesh.setZ(0.15)
    holders[ent_id] = pivot
    hazards["gears"].append({
        "name": f"gear-{ent_id}",
        "speed": float(spec.get("degreesPerSec", 0.0) or 0.0),
        "phase": float(spec.get("phaseShift", 0.0) or 0.0),
    })


def _place_stomper(holders, hazards, ent_id: int, spec: dict) -> None:
    try:
        mesh = load_model("phase_9/models/cogHQ/square_stomper")
    except RuntimeError as error:
        print("skip", error, flush=True)
        return
    pivot = parent_of(holders, spec).attachNewNode(f"stomper-{ent_id}")
    pos = vec3(spec.get("pos"), 0.0)
    hpr = vec3(spec.get("hpr"), 0.0)
    pivot.setPosHprScale(Vec3(*pos), Vec3(*hpr), scale_of(spec.get("scale", 1)))
    spin = pivot.attachNewNode("spin")
    if spec.get("style") == "vertical":
        spin.setP(-90.0)
    mesh.setName(f"stomp-{ent_id}")
    mesh.reparentTo(spin)
    motion = int(spec.get("motion", 3) or 0)
    reach = float(spec.get("range", 0.0) or 0.0)
    if motion == 5:
        mesh.setY(-reach)
    shaft = mesh.find("**/shaft")
    head = mesh.find("**/head")
    if not shaft.isEmpty():
        shaft.setScale(scale_of(spec.get("shaftScale", 1)))
    if not head.isEmpty():
        head.setScale(scale_of(spec.get("headScale", 1)))
    holders[ent_id] = pivot
    hazards["stompers"].append({
        "name": f"stomp-{ent_id}",
        "motion": motion,
        "period": float(spec.get("period", 2.0) or 2.0),
        "phase": float(spec.get("phaseShift", 0.0) or 0.0),
        "range": reach,
        "damage": int(spec.get("damage", 3) or 3),
        "rest": mesh.getY(),
    })


def cog_rows(model: NodePath, entities: dict, cog_data: list, cells: dict) -> tuple[list, list]:
    holders = {0: model}
    for node in model.findAllMatches("**/*"):
        name = node.getName()
        for prefix in ("nodepath-", "model-", "product-", "gear-", "stomper-", "barrel-", "crate-", "belt-", "platform-", "mixer-"):
            if not name.startswith(prefix):
                continue
            try:
                holders[int(name.split("-", 1)[1])] = node
            except ValueError:
                pass
    rows = []
    for spec in cog_data:
        parent = int(spec.get("parentEntId", 0))
        node = holders.get(parent, model).attachNewNode("cog")
        pos = vec3(spec.get("pos"), 0.0)
        node.setPosHpr(Vec3(*pos), Vec3(float(spec.get("h", 0.0)), 0, 0))
        spot = node.getPos(model)
        rows.append({
            "pos": [spot.x, spot.y, spot.z],
            "h": node.getH(model),
            "level": int(spec.get("level", COG)),
            "cell": int(spec.get("battleCell", 0)),
            "boss": int(spec.get("boss", 0)),
            "skeleton": int(spec.get("skeleton", 0)),
        })
        node.removeNode()
    blockers = []
    for spec in entities.values():
        if not isinstance(spec, dict) or spec.get("type") != "battleBlocker":
            continue
        parent = int(spec.get("parentEntId", 0))
        node = holders.get(parent, model).attachNewNode("block")
        pos = vec3(spec.get("pos"), 0.0)
        hpr = vec3(spec.get("hpr"), 0.0)
        node.setPosHpr(Vec3(*pos), Vec3(*hpr))
        spot = node.getPos(model)
        blockers.append({
            "pos": [spot.x, spot.y, spot.z],
            "h": node.getH(model),
            "radius": float(spec.get("radius", 10.0)),
            "cell": int(spec.get("cellId", 0)),
        })
        node.removeNode()
    return rows, blockers


def entrance_point(entities: dict) -> list:
    # EntrancePoint.placeToon for one toon. The rotator stays at H=0 and the
    # placer steps back by radius, so the toon stands behind the marker.
    for spec in entities.values():
        if isinstance(spec, dict) and spec.get("type") == "entrancePoint":
            pos = vec3(spec.get("pos"), 0.0)
            heading = float(vec3(spec.get("hpr"), 0.0)[0])
            radius = float(spec.get("radius", 15.0))
            rad = math.radians(heading)
            return [
                pos[0] + math.sin(rad) * radius,
                pos[1] - math.cos(rad) * radius,
                pos[2],
                heading,
            ]
    return [0.0, -9.0, 0.0, 0.0]


def attach(world: NodePath, other_exit: NodePath, options: list, rng: random.Random) -> tuple[NodePath, NodePath]:
    picked = rng.choice(options)
    room = NodePath("room")
    door = room.attachNewNode("door")
    door.setPos(Vec3(*picked["pos"]))
    door.setH(picked["h"])
    temp = other_exit.attachNewNode("temp")
    room.reparentTo(temp)
    room.clearMat()
    room.setPos(-door.getPos(room))
    temp.setH(-door.getH(other_exit))
    room.wrtReparentTo(world)
    temp.removeNode()
    return room, door


def add_exit(room: NodePath, exits: list) -> NodePath:
    exit_node = room.attachNewNode("exit")
    if exits:
        exit_node.setPos(Vec3(*exits[0]["pos"]))
        exit_node.setH(exits[0]["h"])
    return exit_node


def piece_record(kind: str, ident, node: NodePath, frame: NodePath | None) -> dict:
    row = {"kind": kind, "id": ident, **xform_of(node.getMat())}
    if frame is not None:
        row["frame"] = xform_of(frame.getMat())
    return row


def build_layout(mint_id: int, floor_num: int, room_ids: list, doors: dict, cog_info: dict) -> dict:
    hall_rng = panda_seed(mint_id, floor_num)
    halls = [hall_rng.choice(CONNECTORS) for _ in range(len(room_ids) - 1)]
    attach_rng = panda_seed(mint_id, floor_num)
    world = NodePath("world")
    pieces = []
    cogs = []
    blockers = []
    first = doors[room_ids[0]]
    room = world.attachNewNode("room0")
    pieces.append(piece_record("room", room_ids[0], room, None))
    exit_node = add_exit(room, first["exits"])
    props = []
    goons = []
    _collect_room(cogs, blockers, props, goons, room, room_ids[0], 0, cog_info)
    for index, room_id in enumerate(room_ids[1:], start=1):
        hall_key = "l" if halls[index - 1].endswith("L2") else "r"
        hall_doors = doors[hall_key]
        hall, _hall_door = attach(world, exit_node, hall_doors["entrances"], attach_rng)
        pieces.append(piece_record("hall", hall_key, hall, hall.find("**/door")))
        hall_exit = add_exit(hall, hall_doors["exits"])
        info = doors[room_id]
        nxt, _door = attach(world, hall_exit, info["entrances"], attach_rng)
        pieces.append(piece_record("room", room_id, nxt, nxt.find("**/door")))
        exit_node = add_exit(nxt, info["exits"])
        _collect_room(cogs, blockers, props, goons, nxt, room_id, index, cog_info)
    spawn = cog_info[room_ids[0]]["spawn"]
    spawn_godot = Z.xformPoint(Point3(*spawn[:3]))
    yaw = _yaw(Vec3(-math.sin(math.radians(spawn[3])), math.cos(math.radians(spawn[3])), 0))
    world.removeNode()
    return {
        "spawn": [spawn_godot.x, spawn_godot.y, spawn_godot.z],
        "spawn_h": yaw,
        "pieces": pieces,
        "cogs": cogs,
        "blockers": blockers,
        "props": props,
        "goons": goons,
    }


def _yaw(panda_forward: Vec3) -> float:
    turned = Z.xformVec(panda_forward)
    return math.degrees(math.atan2(-turned.x, -turned.z))


def _panda_mat(values: list) -> Mat4:
    mat = Mat4()
    for row in range(4):
        for col in range(4):
            mat.setCell(row, col, values[row * 4 + col])
    return mat


def _collect_room(cogs: list, blockers: list, props: list, goons: list, node: NodePath, room_id: int, room_index: int, cog_info: dict) -> None:
    mat = node.getMat()
    info = cog_info[room_id]
    for row in info["cogs"]:
        spot = mat.xformPoint(Point3(*row["pos"]))
        godot = Z.xformPoint(spot)
        forward = mat.xformVec(Vec3(-math.sin(math.radians(row["h"])), math.cos(math.radians(row["h"])), 0))
        cogs.append({
            "room": room_index,
            "pos": [godot.x, godot.y, godot.z],
            "yaw": _yaw(forward),
            "level": row["level"],
            "cell": row["cell"],
            "boss": row["boss"],
            "skeleton": row["skeleton"],
        })
    for row in info["blockers"]:
        spot = mat.xformPoint(Point3(*row["pos"]))
        godot = Z.xformPoint(spot)
        forward = mat.xformVec(Vec3(-math.sin(math.radians(row["h"])), math.cos(math.radians(row["h"])), 0))
        blockers.append({
            "room": room_index,
            "pos": [godot.x, godot.y, godot.z],
            "yaw": _yaw(forward),
            "radius": row["radius"],
            "cell": row["cell"],
        })
    for row in info["products"]:
        # Panda applies the left matrix first, so E then the room is E * M.
        props.append({"kind": row["kind"], **xform_of(_panda_mat(row["mat"]) * mat)})
    for row in info["goons"]:
        spot = mat.xformPoint(Point3(*row["pos"]))
        godot = Z.xformPoint(spot)
        forward = mat.xformVec(Vec3(-math.sin(math.radians(row["h"])), math.cos(math.radians(row["h"])), 0))
        goons.append({
            "pos": [godot.x, godot.y, godot.z],
            "yaw": _yaw(forward),
            "scale": row["scale"],
            "speed": row["speed"],
            "reach": row["reach"],
            "strength": row["strength"],
            "fov": row["fov"],
            "id": row["id"],
        })


def export_products() -> dict:
    files = {}
    for kind, by_mint in PRODUCTS.items():
        files[kind] = {}
        for mint_id, (path, scale) in by_mint.items():
            mesh = load_model(path)
            mesh.setScale(scale)
            dest = OUT / f"{kind}_{mint_id}.glb"
            export_node(mesh, dest, kind)
            mesh.removeNode()
            files[kind][str(mint_id)] = f"res://assets/cog_hq/mint/{dest.name}"
    return files


def export_static(relative: str, dest_name: str) -> str:
    mesh = load_model(relative)
    drop_collision(mesh)
    dest = OUT / dest_name
    export_node(mesh, dest, Path(dest_name).stem)
    mesh.removeNode()
    return f"res://assets/cog_hq/mint/{dest_name}"


def elevator_rows() -> list:
    station = load_model("phase_10/models/cogHQ/CashBotShippingStation")
    names = {12500: "Coin Mint", 12600: "Dollar Mint", 12700: "Bullion Mint"}
    origins = {12500: 1, 12600: 2, 12700: 0}
    rows = []
    for mint_id, origin_id in origins.items():
        locator = station.find(f"**/elevator_origin_{origin_id}")
        if locator.isEmpty():
            print("missing elevator origin", origin_id, flush=True)
            continue
        rows.append({
            "mint": mint_id,
            "name": names[mint_id],
            "origin": origin_id,
            **xform_of(locator.getMat(station)),
        })
    station.removeNode()
    return rows


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "model-cache-dir")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT.mkdir(parents=True, exist_ok=True)
    layout_text = LAYOUT.read_text(encoding="utf-8")
    baked_src = layout_text[layout_text.index("BakedFloorLayouts"):layout_text.index("class MintLayout")]
    baked_ns: dict = {}
    exec(baked_src, baked_ns)
    baked = baked_ns["BakedFloorLayouts"]
    rooms = {}
    doors = {}
    cog_info = {}
    for room_id in range(26):
        spec_path = SOURCE / f"{_room_name(room_id)}.py"
        namespace = load_py(spec_path)
        entities = namespace["GlobalEntities"]
        model_path = entities[1000]["modelFilename"]
        print(f"room {room_id} {model_path}", flush=True)
        model = load_model(model_path)
        drop_collision(model)
        door = doors_of(model)
        if not door["entrances"] or not door["exits"]:
            print("  missing a door", door, flush=True)
        hazards = dress(model, entities)
        cog_path = SOURCE / f"{_room_name(room_id)}_Cogs.py"
        cog_data = []
        if cog_path.exists():
            cog_ns = load_py(cog_path, {"ToontownGlobals": types.SimpleNamespace(
                CashbotMintBossLevel=BOSS,
                CashbotMintSkelecogLevel=SKELE,
                CashbotMintCogLevel=COG,
            )})
            # The cog files say ToontownGlobals.CashbotMintBossLevel. The
            # import line was stripped, so those names have to exist.
            cog_data = cog_ns.get("CogData", [])
        cogs, blockers = cog_rows(model, entities, cog_data, {})
        dest = OUT / f"room_{room_id}.glb"
        export_node(model, dest, f"MintRoom{room_id}")
        model.removeNode()
        kept = dict(hazards)
        kept.pop("products", None)
        kept.pop("goons", None)
        rooms[str(room_id)] = {
            "file": f"res://assets/cog_hq/mint/{dest.name}",
            "hazards": kept,
        }
        doors[room_id] = door
        cog_info[room_id] = {
            "cogs": cogs,
            "blockers": blockers,
            "spawn": entrance_point(entities),
            "products": hazards["products"],
            "goons": hazards["goons"],
        }
    for key, relative in (("l", CONNECTORS[0]), ("r", CONNECTORS[1])):
        model = load_model(relative)
        drop_collision(model)
        doors[key] = doors_of(model)
        dest = OUT / f"connector_{key}.glb"
        export_node(model, dest, f"MintHall{key}")
        model.removeNode()
        rooms[key] = {"file": f"res://assets/cog_hq/mint/{dest.name}", "hazards": {}}
        if not doors[key]["entrances"] or not doors[key]["exits"]:
            print("connector missing a door", key, doors[key], flush=True)
    frame = export_static("phase_10/models/cashbotHQ/DoorFrame", "door_frame.glb")
    elevator = export_static("phase_10/models/cogHQ/mintElevator", "mint_elevator.glb")
    products = export_products()
    layouts = {}
    for mint_id in MINTS:
        layouts[str(mint_id)] = {}
        for floor_num in range(20):
            room_ids = list(baked[mint_id][floor_num])
            layouts[str(mint_id)][str(floor_num)] = build_layout(mint_id, floor_num, room_ids, doors, cog_info)
            print(f"layout {mint_id} floor {floor_num} rooms {room_ids}", flush=True)
    payload = {
        "rooms": rooms,
        "products": products,
        "frame": frame,
        "elevator": elevator,
        "elevators": elevator_rows(),
        "layouts": layouts,
        "rewards": {"12500": 8, "12600": 14, "12700": 20},
        "credit": {"12500": 2.0, "12600": 2.5, "12700": 3.0},
    }
    DATA.write_text(json.dumps(payload), encoding="utf-8")
    print("wrote", DATA, flush=True)
    return 0


def _room_name(room_id: int) -> str:
    names = {
        0: "CashbotMintEntrance_Action00",
        1: "CashbotMintBoilerRoom_Action00",
        2: "CashbotMintBoilerRoom_Battle00",
        3: "CashbotMintDuctRoom_Action00",
        4: "CashbotMintDuctRoom_Battle00",
        5: "CashbotMintGearRoom_Action00",
        6: "CashbotMintGearRoom_Battle00",
        7: "CashbotMintLavaRoomFoyer_Action00",
        8: "CashbotMintLavaRoomFoyer_Action01",
        9: "CashbotMintLavaRoomFoyer_Battle00",
        10: "CashbotMintLavaRoom_Action00",
        11: "CashbotMintLobby_Action00",
        12: "CashbotMintLobby_Battle00",
        13: "CashbotMintPaintMixer_Action00",
        14: "CashbotMintPipeRoom_Action00",
        15: "CashbotMintPipeRoom_Battle00",
        16: "CashbotMintStomperAlley_Action00",
        17: "CashbotMintBoilerRoom_Battle01",
        18: "CashbotMintControlRoom_Battle00",
        19: "CashbotMintDuctRoom_Battle01",
        20: "CashbotMintGearRoom_Battle01",
        21: "CashbotMintLavaRoomFoyer_Battle01",
        22: "CashbotMintOilRoom_Battle00",
        23: "CashbotMintLobby_Battle01",
        24: "CashbotMintPaintMixerReward_Battle00",
        25: "CashbotMintPipeRoom_Battle01",
    }
    return names[room_id]


if __name__ == "__main__":
    raise SystemExit(main())
