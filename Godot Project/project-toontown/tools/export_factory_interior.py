"""Dress the Sellbot factory shell with the props SellbotLegFactorySpec places.

The bam is only the rooms. Doors, gears, paint mixers, stompers, crates,
elevators, barrels, and the other model entities are parented to the zone
nodes at runtime. This writes that dressed factory over sellbot_factory.glb.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

fake_toontown = types.ModuleType("panda3d.toontown")
fake_toontown.DNAStorage = object
fake_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = fake_toontown

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from export_cog_hqs import export_node  # noqa: E402

ASSETS = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
SPEC = Path(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code"
    r"\toontown\coghq\SellbotLegFactorySpec.py"
)
OUT = TOOLS.parent / "assets" / "cog_hq" / "sellbot_factory.glb"

DOOR = "phase_9/models/cogHQ/CogDoorHandShake.bam"
GEAR = "phase_9/models/cogHQ/FactoryGearB.bam"
STOMPER = "phase_9/models/cogHQ/square_stomper.bam"
CRATE = "phase_9/models/cogHQ/woodCrateB.bam"
ELEVATOR = "phase_9/models/cogHQ/Elevator.bam"
BUTTON = "phase_9/models/cogHQ/CogDoor_Button.bam"
PLATFORM = "phase_9/models/cogHQ/platform1.bam"
BARREL = "phase_4/models/cogHQ/gagTank.bam"
LOCK_CLOSED = ("Slide_One_Closed", "Slide_Two_Closed", "Slide_Three_Closed")


class _Text:
    def __getattr__(self, _name: str) -> str:
        return ""


def load_spec() -> dict:
    source = SPEC.read_text(encoding="utf-8")
    source = source.split("GlobalEntities", 1)[1]
    namespace = {"Point3": _Vec, "Vec3": _Vec, "Vec4": _Vec, "TTLocalizer": _Text()}
    exec("GlobalEntities" + source, namespace)
    return namespace["GlobalEntities"]


class _Vec:
    def __init__(self, x=0, y=0, z=0, w=0):
        self.values = (x, y, z, w)

    def __getitem__(self, index: int) -> float:
        return self.values[index]


def vec3(value, fallback: float = 1.0) -> tuple[float, float, float]:
    if isinstance(value, (int, float)):
        return (float(value), float(value), float(value))
    if value is None:
        return (fallback, fallback, fallback)
    return (float(value[0]), float(value[1]), float(value[2]))


def find_zones(model: NodePath) -> dict[int, NodePath]:
    zones = {0: model}
    for node in model.findAllMatches("**/zone*;+i"):
        tail = node.getName()[4:]
        digits = ""
        for char in tail:
            if not char.isdigit():
                break
            digits += char
        if not digits:
            continue
        number = int(digits)
        if number == 0 or number in zones:
            continue
        zones[number] = node
    return zones


def place_holders(model: NodePath, entities: dict, zones: dict[int, NodePath]) -> dict[int, NodePath]:
    holders: dict[int, NodePath] = {}
    for ent_id, ent in entities.items():
        if ent.get("type") == "zone":
            holders[ent_id] = zones.get(ent_id, model)
    pending = [ent_id for ent_id in entities if ent_id not in holders]
    guard = 0
    while pending and guard < 8:
        guard += 1
        next_pending = []
        for ent_id in pending:
            ent = entities[ent_id]
            parent_id = ent.get("parentEntId", 0)
            parent = holders.get(parent_id)
            if parent is None:
                next_pending.append(ent_id)
                continue
            holder = parent.attachNewNode(f"{ent.get('type', 'ent')}-{ent_id}")
            pos = vec3(ent.get("pos"), 0.0)
            hpr = vec3(ent.get("hpr"), 0.0)
            scale = vec3(ent.get("scale"), 1.0)
            holder.setPosHprScale(*pos, *hpr, *scale)
            holders[ent_id] = holder
        if len(next_pending) == len(pending):
            break
        pending = next_pending
    print("holders", len(holders), "unplaced", len(pending), flush=True)
    return holders


def load_copy(loader: Loader, relative: str) -> NodePath | None:
    path = ASSETS.joinpath(*relative.replace("\\", "/").split("/"))
    loaded = loader.loadSync(Filename.fromOsSpecific(str(path)))
    if loaded is None:
        print("missing", relative, flush=True)
        return None
    return NodePath(loaded).copyTo(NodePath("copy"))


def hide_named(root: NodePath, piece: str) -> None:
    for node in root.findAllMatches(f"**/{piece}"):
        node.hide()


def dress_door(loader: Loader, holder: NodePath, ent: dict) -> None:
    model = load_copy(loader, DOOR)
    if model is None:
        return
    for node in model.findAllMatches("**/*Open*"):
        node.hide()
    locks = (
        ent.get("isLock0Unlocked", 1),
        ent.get("isLock1Unlocked", 1),
        ent.get("isLock2Unlocked", 1),
    )
    for unlocked, name in zip(locks, LOCK_CLOSED):
        if unlocked:
            hide_named(model, name)
    model.reparentTo(holder)


def dress_gear(loader: Loader, holder: NodePath, ent: dict) -> None:
    model = load_copy(loader, GEAR)
    if model is None:
        return
    pivot = holder.attachNewNode("gearParent")
    if ent.get("orientation") == "horizontal":
        for node in model.findAllMatches("**/VerticalCollisions"):
            node.hide()
    else:
        for node in model.findAllMatches("**/HorizontalCollisions"):
            node.hide()
        model.setZ(0.15)
        pivot.setP(-90)
    gear_scale = float(ent.get("gearScale", 1.0))
    model.setScale(*(gear_scale * axis for axis in holder.getScale()))
    model.reparentTo(pivot)
    holder.setScale(1)


def dress_stomper(loader: Loader, holder: NodePath, ent: dict) -> None:
    model = load_copy(loader, STOMPER)
    if model is None:
        return
    pivot = holder.attachNewNode("stomper-pivot")
    if ent.get("style") == "vertical":
        pivot.setP(-90)
    shaft = model.find("**/shaft")
    head = model.find("**/head")
    if not shaft.isEmpty():
        shaft.setScale(*vec3(ent.get("shaftScale"), 1.0))
    if not head.isEmpty():
        head.setScale(*vec3(ent.get("headScale"), 1.0))
    if ent.get("motion") == 3:
        model.setY(-float(ent.get("range", 0.0)))
    model.reparentTo(pivot)


def dress_model(loader: Loader, holder: NodePath, ent: dict) -> None:
    if ent.get("collisionsOnly"):
        return
    relative = ent.get("modelPath")
    if not isinstance(relative, str) or not relative:
        return
    if not relative.endswith(".bam"):
        relative += ".bam"
    model = load_copy(loader, relative)
    if model is None:
        return
    scale = ent.get("modelScale")
    if scale is not None:
        model.setScale(*vec3(scale, 1.0))
    model.reparentTo(holder)


def dress(loader: Loader, holders: dict[int, NodePath], entities: dict) -> None:
    placed = 0
    for ent_id, ent in entities.items():
        holder = holders.get(ent_id)
        if holder is None:
            continue
        kind = ent.get("type")
        if kind == "door":
            dress_door(loader, holder, ent)
        elif kind == "gear":
            dress_gear(loader, holder, ent)
        elif kind == "stomper":
            dress_stomper(loader, holder, ent)
        elif kind == "crate":
            model = load_copy(loader, CRATE)
            if model is not None:
                model.reparentTo(holder)
        elif kind == "lift":
            model = load_copy(loader, ELEVATOR)
            if model is not None:
                model.reparentTo(holder)
        elif kind == "button":
            model = load_copy(loader, BUTTON)
            if model is not None:
                model.reparentTo(holder)
        elif kind in ("platform", "sinkingPlatform", "conveyorBelt"):
            model = load_copy(loader, PLATFORM)
            if model is not None:
                model.reparentTo(holder)
        elif kind in ("healBarrel", "gagBarrel", "beanBarrel"):
            model = load_copy(loader, BARREL)
            if model is not None:
                model.setScale(0.5)
                model.reparentTo(holder)
        elif kind in ("model", "paintMixer"):
            dress_model(loader, holder, ent)
        else:
            continue
        placed += 1
    print("dressed", placed, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(Filename.fromOsSpecific(str(ASSETS)))
    entities = load_spec()
    loader = Loader.getGlobalPtr()
    factory = load_copy(loader, "phase_9/models/cogHQ/SelbotLegFactory.bam")
    if factory is None:
        return 1
    factory.setName("SelbotLegFactory")
    zones = find_zones(factory)
    print("zones", len(zones), flush=True)
    holders = place_holders(factory, entities, zones)
    dress(loader, holders, entities)
    export_node(factory, OUT, "SellbotFactory")
    return 0


if __name__ == "__main__":
    sys.exit(main())
