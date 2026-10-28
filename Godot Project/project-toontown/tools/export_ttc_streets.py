"""Build Y-up glTF streets for Silly Street, Loopy Lane, and Punchline Place.

Load order matches the client: storage.dna, storage_TT.dna, storage_town.dna,
storage_TT_town.dna, then toontown_central_<zone>.dna. The TT_sky dome is the
same hood sky the street uses.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from panda3d.core import CollisionNode, CollisionPolygon, Filename, Loader, NodePath, getModelPath
from panda3d.toontown import DNAStorage, loadDNAFile

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP, panda_path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "neighborhoods" / "toontown_central" / "streets"

STORAGE = [
    "phase_4/dna/storage.dna",
    "phase_4/dna/storage_TT.dna",
    "phase_5/dna/storage_town.dna",
    "phase_5/dna/storage_TT_town.dna",
]

# Zone ids are ToontownGlobals.SillyStreet, LoopyLane, and PunchlinePlace.
STREETS = [
    ("silly_street", "2100", "SillyStreet"),
    ("loopy_lane", "2200", "LoopyLane"),
    ("punchline_place", "2300", "PunchlinePlace"),
]


def load_dna(zone: str) -> tuple[NodePath, DNAStorage]:
    getModelPath().prependDirectory(Filename.from_os_specific(
        r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown\Original Toontown Assets\Game Assets"
    ))
    store = DNAStorage()
    node = None
    for relative in STORAGE:
        print("loading", relative)
        node = loadDNAFile(store, panda_path(relative), 0)
    street = f"phase_5/dna/toontown_central_{zone}.dna"
    print("loading", street)
    node = loadDNAFile(store, panda_path(street), 0)
    if node is None:
        raise RuntimeError(f"DNA loader returned no street for {zone}")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)
    return geom, store


def load_street(geom: NodePath, root_name: str) -> NodePath:
    placed = NodePath("placed")
    placed.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(placed)
    street_bounds = placed.getBounds()
    street_center = street_bounds.getCenter()
    print(
        "street center",
        round(street_center.x, 2),
        round(street_center.y, 2),
        round(street_center.z, 2),
        "radius",
        round(street_bounds.getRadius(), 2),
    )

    loader = Loader.getGlobalPtr()
    sky = NodePath(loader.loadSync(panda_path("phase_3.5/models/props/TT_sky.bam")))
    sky.setName("Sky")
    # The dome is authored at the origin and only reaches about 300 feet out.
    # These streets sit hundreds of feet from the origin, so an unmoved dome
    # cuts through the blocks. Park it on the street and enlarge it enough that
    # the whole block is inside. Play mode puts the original size back on the camera.
    sky_radius = 300.0
    street_radius = street_bounds.getRadius()
    sky.setScale(max(1.0, street_radius * 1.25 / sky_radius))
    sky.setPos(street_center.x, -street_center.z, 0)

    root = NodePath(root_name)
    root.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(root)
    sky.copyTo(root)
    return root


def _zone_name(path: NodePath) -> str:
    current = path
    while not current.isEmpty():
        name = current.getName().split(":", 1)[0]
        if name.isdigit() and len(name) == 4:
            return name
        current = current.getParent()
    return ""


def write_zones(slug: str, geom: NodePath, store: DNAStorage) -> None:
    """Floor cells and the vis lists Street.doEnterZone uses to stash the rest."""
    zones: dict[str, dict] = {}
    for index in range(store.getNumDNAVisGroups()):
        owner = store.getDNAVisGroupName(index).split(":", 1)[0]
        visible = []
        for visible_index in range(store.getNumVisiblesInDNAVisGroup(index)):
            name = store.getVisibleName(index, visible_index).split(":", 1)[0]
            if name not in visible:
                visible.append(name)
        if owner not in visible:
            visible.append(owner)
        zones[owner] = {"vis": visible, "polygons": []}

    for path in geom.findAllMatches("**/+CollisionNode"):
        node = path.node()
        if not node.isOfType(CollisionNode.getClassType()):
            continue
        if not node.getIntoCollideMask().getBit(1):
            continue
        owner = _zone_name(path)
        if owner not in zones:
            continue
        for solid_index in range(node.getNumSolids()):
            solid = node.getSolid(solid_index)
            if not solid.isOfType(CollisionPolygon.getClassType()):
                continue
            # Panda (x, y) is the ground plane. The export root maps that to Godot (x, -y).
            polygon = []
            for point_index in range(solid.getNumPoints()):
                world = path.getMat(geom).xformPoint(solid.getPoint(point_index))
                polygon.append([round(world.x, 3), round(-world.y, 3)])
            if len(polygon) >= 3:
                zones[owner]["polygons"].append(polygon)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"{slug}_zones.json"
    out.write_text(json.dumps(zones, separators=(",", ":")), encoding="utf-8")
    cells = sum(len(zone["polygons"]) for zone in zones.values())
    print(f"wrote {out} zones={len(zones)} floor_cells={cells}")


def export_one(slug: str, zone: str, root_name: str, zones_only: bool) -> None:
    geom, store = load_dna(zone)
    write_zones(slug, geom, store)
    if zones_only:
        return
    root = load_street(geom, root_name)
    bounds = root.getBounds()
    print("export bounds", bounds)
    center = bounds.getCenter()
    print(
        "center",
        round(center.x, 2),
        round(center.y, 2),
        round(center.z, 2),
        "radius",
        round(bounds.getRadius(), 2),
    )
    writer = GltfWriter()
    writer.add_node(root, None)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"{slug}.glb"
    payload = writer.pack(root_name)
    out.write_bytes(payload)
    print(
        f"wrote {out} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"nodes={len(writer.nodes)} meshes={writer.mesh_count} "
        f"tris={writer.tri_count} materials={len(writer.materials)} "
        f"textures={len(writer.textures)} empty={writer.skipped_empty} "
        f"billboards={writer.billboards}"
    )


def main() -> int:
    zones_only = "--zones-only" in sys.argv
    wanted = {arg for arg in sys.argv[1:] if not arg.startswith("--")}
    for slug, zone, root_name in STREETS:
        if wanted and slug not in wanted and zone not in wanted:
            continue
        export_one(slug, zone, root_name, zones_only)
    return 0


if __name__ == "__main__":
    sys.exit(main())
