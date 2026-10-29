"""Export phase_3.5 HQ_interior the way DistributedHQInterior loads it.

Stock Panda can read the bam. DNA is only needed for the copied door, which
this pass leaves to the door_origin markers already in the model.
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

from panda3d.core import CollisionNode, Filename, GeomNode, Loader, NodePath, getModelPath, loadPrcFileData

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = Path(__file__).resolve().parents[1] / "assets" / "interiors" / "hq" / "hq_interior.glb"


def collision_triangles(root: NodePath) -> list[list[float]]:
    triangles = []
    matches = root.findAllMatches("**/+CollisionNode")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        solid_node = path.node()
        if not solid_node.isOfType(CollisionNode.getClassType()):
            continue
        placed = path.getMat(root)
        for solid_index in range(solid_node.getNumSolids()):
            solid = solid_node.getSolid(solid_index)
            if not hasattr(solid, "getNumPoints"):
                continue
            points = []
            for point_index in range(solid.getNumPoints()):
                point = placed.xformPoint(solid.getPoint(point_index))
                points.append((point.x, point.z, -point.y))
            for fan in range(1, len(points) - 1):
                triangle = []
                for corner in (points[0], points[fan], points[fan + 1]):
                    triangle.extend(round(value, 4) for value in corner)
                triangles.append(triangle)
    return triangles


def place_doors(interior: NodePath) -> None:
    # DistributedHQInterior.chooseDoor starts at door_double_round_ul and flips
    # the last letter, so the interior uses door_double_round_ur.
    catalog = Loader.getGlobalPtr().loadSync(
        Filename(ASSETS, "phase_3.5/models/modules/doors_practical.bam")
    )
    if catalog is None:
        raise RuntimeError("doors_practical.bam did not load")
    source = NodePath(catalog).find("**/door_double_round_ur")
    if source.isEmpty():
        raise RuntimeError("door_double_round_ur missing")
    renames = {
        "door_double_round_ur_left": "leftDoor",
        "door_double_round_ur_right": "rightDoor",
        "door_double_round_ur_hole_left": "doorFrameHoleLeft",
        "door_double_round_ur_hole_right": "doorFrameHoleRight",
        "door_double_round_ur_flat": "door_flat",
    }
    origins = interior.findAllMatches("**/door_origin_*")
    for index in range(origins.getNumPaths()):
        origin = origins.getPath(index)
        suffix = origin.getName().rsplit("_", 1)[-1]
        door = source.copyTo(origin)
        door.setName("door_" + suffix)
        # setupDoors scales the origin to 0.8 and steps it back 0.025.
        door.setPos(0, -0.025, 0)
        door.setHpr(0, 0, 0)
        door.setScale(0.8)
        for child in list(door.getChildren()):
            renamed = renames.get(child.getName())
            if renamed:
                child.setName(renamed)
            if child.node().isOfType(CollisionNode.getClassType()):
                child.removeNode()
        print("placed", door.getName(), "on", origin.getName())


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, "phase_3.5/models/modules/HQ_interior.bam"))
    if node is None:
        raise RuntimeError("HQ_interior.bam did not load")
    interior = NodePath(node)
    interior.setName("HQInterior")
    for pattern in ("**/cream", "**/crashed_piano"):
        found = interior.find(pattern)
        if found.isEmpty():
            print("missing", pattern)
        else:
            found.hide()
            print("hid", found.getName())
    place_doors(interior)
    print("--- nodes ---")
    for child in interior.findAllMatches("**"):
        kind = "geom" if child.node().isOfType(GeomNode.getClassType()) else child.node().getType().getName()
        if kind == "geom" and "wall" not in child.getName().lower() and "floor" not in child.getName().lower():
            pos = child.getPos(interior)
            print(f"  {child.getName()} {kind} ({pos.x:.2f}, {pos.y:.2f}, {pos.z:.2f})")
        elif "origin" in child.getName() or child.getName() in ("periscope", "speakers", "empty_board"):
            pos = child.getPos(interior)
            h = child.getH(interior)
            print(f"  MARK {child.getName()} ({pos.x:.2f}, {pos.y:.2f}, {pos.z:.2f}) h={h:.1f}")
    markers = {}
    for pattern in ("**/npc_origin_*", "**/door_origin*", "**/empty_board"):
        matches = interior.findAllMatches(pattern)
        for index in range(matches.getNumPaths()):
            marker = matches.getPath(index)
            pos = marker.getPos(interior)
            markers[marker.getName()] = {
                "panda": [round(pos.x, 3), round(pos.y, 3), round(pos.z, 3)],
                "godot": [round(pos.x, 3), round(pos.z, 3), round(-pos.y, 3)],
                "h": round(marker.getH(interior), 2),
            }
    meta = OUT.parent / "markers.json"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    meta.write_text(json.dumps(markers, indent=2), encoding="utf-8")
    triangles = collision_triangles(interior)
    (OUT.parent / "collision.json").write_text(json.dumps({"triangles": triangles}), encoding="utf-8")
    print("collision triangles", len(triangles), flush=True)
    root = NodePath("HQ")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack("HQ")
    OUT.write_bytes(payload)
    print(f"wrote {OUT} ({len(payload) / (1024 * 1024):.1f} MB) meshes={writer.mesh_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
