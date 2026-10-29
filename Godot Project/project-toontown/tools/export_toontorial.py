"""Export the tutorial building interior the way DistributedTutorialInterior sets it up.

The room is phase_3.5/models/modules/toon_interior_tutorial. The tutorial
street sits outside the window at the original offset, with the landmark and
the HQ door face stashed. Panda stays Z-up until the export root.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.environ["PATH"] = GAME + os.pathsep + os.environ.get("PATH", "")
if hasattr(os, "add_dll_directory"):
    os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import (
    CollisionNode,
    Filename,
    Loader,
    NodePath,
    Vec4,
    getModelPath,
    loadPrcFileData,
)
from panda3d.toontown import DNAStorage, loadDNAFile

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "interiors" / "toontorial" / "toontorial.glb"

# The screenshot's mint striped walls. Tutorial interiors pick from this list.
WALLPAPER = Vec4(0.8, 1.0, 0.7, 1.0)
# Wood door from the tutorial door colors.
DOOR = Vec4(0.8, 0.5, 0.3, 1.0)


def panda_file(relative: str) -> str:
    return str(Filename(ASSETS, relative))


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


# The opening room in the reference shot: mint stripes, warm wood floor,
# and the wood door from the tutorial color list.
SURFACE_COLOR = {
    "TI_wallpaper": WALLPAPER,
    "TI_wallpaper_border": WALLPAPER,
    "TI_floor": Vec4(1.0, 0.684, 0.477, 1.0),
    "TI_wainscotting": Vec4(0.699, 0.586, 0.473, 1.0),
}


def catalog_codes(store: DNAStorage, category: str) -> list[str]:
    count = store.getNumCatalogCodes(category)
    return [store.getCatalogCode(category, index) for index in range(count)]


def pick_code(codes: list[str], hints: tuple[str, ...]) -> str:
    for hint in hints:
        for code in codes:
            if hint in code.lower():
                return code
    return codes[0]


def furnish(interior: NodePath, store: DNAStorage) -> list[list[float]]:
    placed_collision: list[list[float]] = []
    # Same pass as DistributedTutorialInterior.replaceRandomInModel.
    # "m" copies a catalog model onto the marker. "t" paints a catalog
    # texture. "c" tints it. The tutorial room's prop slots are fixed.
    tagged = interior.findAllMatches("**/random_???_*")
    for index in range(tagged.getNumPaths()):
        node = tagged.getPath(index)
        name = node.getName()
        key1 = name[len("random_")]
        key2 = name[len("random_") + 1]
        category = name[len("random_") + 4:]
        codes = catalog_codes(store, category)
        print("slot", name, "codes", codes)
        if not codes:
            continue
        if key1 == "m":
            code = codes[0]
            model = store.findNode(code)
            if model is None or model.isEmpty():
                print("missing model", code)
                continue
            placed = model.copyTo(node)
            placed_collision.extend(collision_triangles(placed, interior))
            for collision in placed.findAllMatches("**/+CollisionNode"):
                collision.stash()
            print("placed", code)
        elif key1 == "t":
            hints = ()
            if category == "TI_wallpaper" or category == "TI_wallpaper_border":
                hints = ("stripe",)
            elif category == "TI_floor":
                hints = ("wood",)
            code = pick_code(codes, hints)
            texture = store.findTexture(code)
            if texture is None:
                print("missing texture", code)
                continue
            node.setTexture(texture, 100)
            print("textured", code)
        if key2 == "c" and category in SURFACE_COLOR:
            node.setColorScale(SURFACE_COLOR[category])
    return placed_collision


def place_door(interior: NodePath, store: DNAStorage) -> list[list[float]]:
    # The source starts from door_double_round_ul and flips the last letter.
    door = store.findNode("door_double_round_ur")
    origin = interior.find("**/door_origin")
    if door is None or door.isEmpty() or origin.isEmpty():
        print("door missing", door, origin)
        return []
    door.copyTo(origin)
    origin.setScale(0.8, 0.8, 0.8)
    origin.setPos(origin, 0, -0.025, 0)
    origin.setColorScale(DOOR)
    door_collision = collision_triangles(origin, interior)
    for collision in origin.findAllMatches("**/+CollisionNode"):
        collision.stash()
    print("door placed")
    return door_collision


def load_store() -> tuple[NodePath, DNAStorage]:
    store = DNAStorage()
    street = None
    for relative in (
        "phase_4/dna/storage.dna",
        "phase_3.5/dna/storage_tutorial.dna",
        "phase_3.5/dna/storage_interior.dna",
        "phase_3.5/dna/tutorial_street.dna",
    ):
        print("loading", relative, flush=True)
        node = loadDNAFile(store, panda_file(relative), 0)
        if relative.endswith("tutorial_street.dna"):
            street = node
    if street is None:
        raise RuntimeError("tutorial street did not load")
    street_np = NodePath(street)
    street_np.setPosHpr(-17, 42, -0.5, 180, 0, 0)
    for pattern in (
        "**/tb2:toon_landmark_TT_A1_DNARoot",
        "**/tb1:toon_landmark_hqTT_DNARoot/**/door_flat_0",
    ):
        found = street_np.find(pattern)
        if found.isEmpty():
            print("not found", pattern)
        else:
            found.stash()
    for collision in street_np.findAllMatches("**/+CollisionNode"):
        collision.stash()
    return street_np, store


def collision_triangles(root: NodePath, space: NodePath) -> list[list[float]]:
    # Interior collision is polygons: walls, the desk and other props, the
    # floor, and the ceiling. Panda (x, y, z) becomes Godot (x, z, -y).
    triangles = []
    matches = root.findAllMatches("**/+CollisionNode")
    for index in range(matches.getNumPaths()):
        path = matches.getPath(index)
        solid_node = path.node()
        placed = path.getMat(space)
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


def godot_pos(node: NodePath, space: NodePath) -> tuple[float, float, float]:
    pos = node.getPos(space)
    # The export root maps Panda (x, y, z) to Godot (x, z, -y).
    return (round(pos.x, 3), round(pos.z, 3), round(-pos.y, 3))


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)

    interior = load_model("phase_3.5/models/modules/toon_interior_tutorial.bam")
    interior.setName("Interior")
    street, store = load_store()
    triangles = furnish(interior, store)
    triangles.extend(place_door(interior, store))
    triangles.extend(collision_triangles(interior, interior))
    for collision in interior.findAllMatches("**/+CollisionNode"):
        collision.stash()
    collision_path = OUT.parent / "collision.json"
    collision_path.write_text(json.dumps({"triangles": triangles}), encoding="utf-8")
    print(f"collision triangles {len(triangles)}", flush=True)

    print("--- origins ---")
    for pattern in ("**/npc_origin_*", "**/door_origin*", "**/camera_origin*"):
        matches = interior.findAllMatches(pattern)
        for index in range(matches.getNumPaths()):
            node = matches.getPath(index)
            print(node.getName(), "panda", tuple(round(v, 3) for v in node.getPos(interior)), "h", round(node.getH(interior), 2))

    street.setName("Street")

    holder = NodePath("holder")
    interior.reparentTo(holder)
    street.reparentTo(holder)

    print("--- godot origins ---")
    for pattern in ("**/npc_origin_*", "**/door_origin*"):
        matches = holder.findAllMatches(pattern)
        for index in range(matches.getNumPaths()):
            node = matches.getPath(index)
            print(node.getName(), godot_pos(node, holder), "h", round(node.getH(holder), 2))

    root = NodePath("Toontorial")
    root.setMat(Z_UP_TO_Y_UP)
    holder.copyTo(root)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    writer = GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack("Toontorial")
    OUT.write_bytes(payload)
    print(
        f"wrote {OUT} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"nodes={len(writer.nodes)} meshes={writer.mesh_count}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
