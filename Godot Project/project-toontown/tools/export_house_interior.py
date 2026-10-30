"""Export the estate house interior the way DistributedHouseInterior.setup does.

The room is phase_5.5/models/estate/tt_m_ara_int_estateHouseA. The round door
is door_double_round_ur, hung on door_origin at heading 180 and scale 0.8.
House A has no door in the model, so a second file is the door
DistributedHouse.__setupDoor hangs on that house's door_origin.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import (
    CollisionNode,
    Filename,
    Loader,
    NodePath,
    Point3,
    TransparencyAttrib,
    Vec4,
    getModelPath,
    loadPrcFileData,
)

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "interiors" / "estate"
# HouseGlobals.atticWood, the interior door color.
ATTIC = Vec4(0.49, 0.314, 0.224, 1)
# HouseGlobals.stairWood, the default house's exterior door color.
STAIR = Vec4(0.651, 0.376, 0.31, 1)
# HouseGlobals.archWood.
ARCH = Vec4(0.7, 0.6, 0.5, 1)

RENAMES = {
    "door_double_round_ur_left": "leftDoor",
    "door_double_round_ur_right": "rightDoor",
    "door_double_round_ur_hole_left": "doorFrameHoleLeft",
    "door_double_round_ur_hole_right": "doorFrameHoleRight",
    "door_double_round_ur_flat": "door_flat",
}


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def round_door() -> NodePath:
    catalog = load_model("phase_3.5/models/modules/doors_practical.bam")
    source = catalog.find("**/door_double_round_ur")
    if source.isEmpty():
        raise RuntimeError("door_double_round_ur missing")
    return source


def style_door(door: NodePath, color: Vec4) -> None:
    door.setName("door_0")
    door.setColor(color)
    door.show()
    for child in list(door.getChildren()):
        renamed = RENAMES.get(child.getName())
        if renamed:
            child.setName(renamed)
        child.show()
        if "trigger" in child.getName().lower():
            child.removeNode()
            continue
        if child.node().isOfType(CollisionNode.getClassType()):
            child.removeNode()


def write_glb(root: NodePath, dest: Path, scene_name: str) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(scene_name)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    print(f"wrote {dest} ({len(payload) / (1024 * 1024):.1f} MB) meshes={writer.mesh_count}")


# HouseGlobals.interiors[0] is phase_5.5/dna/house_interior3.dna. That file is the
# starter room: bed, closet, jellybean bank, rugs, fireplace, and chairs.
# chairA.bam is already a full-size chair, so the DNA scale of 10 is not applied.
# GardenA was built for the old house_interiorA window and cuts through this room.
# The phone is catalog item 1399. The client stores no coordinate, so the mount
# stands on the west wall of the front room, clear of the wall mesh.
FURNITURE = (
    ("phase_5.5/models/estate/rugB.bam", "rug", (-7.08867, 19.0589, 0.0), (-120.0, 0.0, 0.0), 5.15552),
    ("phase_5.5/models/estate/regular_bed.bam", "bed", (-13.618, 26.1823, 0.0), (0.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/closetBoy.bam", "closet", (-19.45, 24.7018, 0.0), (0.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/jellybeanBank.bam", "bank", (-21.4932, 5.76027, 0.0), (120.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/rugB.bam", "rug", (7.87512, -11.2897, 0.0), (-90.0, 0.0, 0.0), 3.57074),
    ("phase_5.5/models/estate/rugB.bam", "rug", (-20.6508, 6.52406, 0.0), (135.0, 0.0, 0.0), 2.3354),
    ("phase_5.5/models/estate/FireplaceSq.bam", "fireplace", (15.9865, -11.3307, 0.0), (-90.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/chairA.bam", "chair", (-2.64541, 21.3024, 0.0), (-75.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/chairA.bam", "chair", (-6.36842, 24.5659, 0.0), (-15.0, 0.0, 0.0), 1.0),
    ("phase_5.5/models/estate/chairA.bam", "chair", (-23.9124, 16.9335, 0.0), (90.0, 0.0, 0.0), 1.0),
)


def hide_helpers(prop: NodePath) -> None:
    for child in prop.findAllMatches("**"):
        name = child.getName().lower()
        if "collision" in name or "trigger" in name or name.startswith("shadow"):
            child.hide()


def place_props(interior: NodePath) -> None:
    for path, name, pos, hpr, scale in FURNITURE:
        prop = load_model(path)
        hide_helpers(prop)
        prop.reparentTo(interior)
        prop.setName(name)
        prop.setPos(pos[0], pos[1], pos[2])
        prop.setHpr(hpr[0], hpr[1], hpr[2])
        prop.setScale(scale)
    # DistributedPhone parents the handset onto the wall mount and leaves it
    # posed on the hook. The bind pose already sits on the mount.
    mount = load_model("phase_5.5/models/estate/phoneMount-mod.bam")
    phone = load_model("phase_5.5/models/estate/prop_phone-mod.bam")
    hide_helpers(mount)
    hide_helpers(phone)
    phone.reparentTo(mount)
    # The mount's texture carries an alpha channel. DistributedPhone forces the
    # mount opaque, otherwise the stand renders as glass.
    mount.setTransparency(TransparencyAttrib.M_none, 1)
    mount.reparentTo(interior)
    mount.setName("phone")
    mount.setPos(-17.3, -18.0, 0.0)
    mount.setHpr(90.0, 0.0, 0.0)


def export_interior(source: NodePath) -> None:
    interior = load_model("phase_5.5/models/estate/tt_m_ara_int_estateHouseA.bam")
    interior.setName("HouseInterior")
    place_props(interior)
    origin = interior.find("**/door_origin")
    if origin.isEmpty():
        raise RuntimeError("interior door_origin missing")
    # DistributedHouseInterior.setup
    origin.setHpr(180, 0, 0)
    origin.setScale(0.8, 0.8, 0.8)
    origin.setPos(origin, 0, -0.025, 0)
    door = source.copyTo(origin)
    style_door(door, ATTIC)
    for arch in interior.findAllMatches("**/arch*"):
        arch.setColorScale(ARCH)
    low, high = interior.getTightBounds()
    stood = origin.getParent().getRelativePoint(origin, Point3(-1.5, -6.0, 0.025))
    print(
        "interior bounds",
        tuple(round(v, 2) for v in low),
        tuple(round(v, 2) for v in high),
    )
    print("stand panda", tuple(round(v, 2) for v in stood))
    root = NodePath("HouseInteriorRoot")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    write_glb(root, OUT_DIR / "house_interior.glb", "HouseInterior")


def export_house_door(source: NodePath) -> None:
    # The door's local transform is relative to houseA's unmodified door_origin,
    # which is the marker already baked into the estate.
    house = load_model("phase_5.5/models/estate/houseA.bam")
    origin = house.find("**/door_origin")
    if origin.isEmpty():
        raise RuntimeError("houseA door_origin missing")
    marker = house.attachNewNode("marker")
    marker.setTransform(origin.getTransform())
    # DistributedHouse.__setupDoor
    origin.setHpr(90, 0, 0)
    origin.setScale(0.6, 0.6, 0.8)
    origin.setPos(origin, 0.5, 0, 0.0)
    door = source.copyTo(origin)
    style_door(door, STAIR)
    root = NodePath("HouseDoorRoot")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    exported = door.copyTo(root)
    exported.setTransform(door.getTransform(marker))
    exported.setName("HouseDoor")
    write_glb(root, OUT_DIR / "house_door.glb", "HouseDoor")


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    source = round_door()
    export_interior(source)
    export_house_door(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
