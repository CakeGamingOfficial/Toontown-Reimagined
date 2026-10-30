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


def export_interior(source: NodePath) -> None:
    interior = load_model("phase_5.5/models/estate/tt_m_ara_int_estateHouseA.bam")
    interior.setName("HouseInterior")
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
