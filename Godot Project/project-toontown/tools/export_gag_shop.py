"""Export Goofy's Gag Shop the way DistributedGagshopInterior.setup does.

The room is phase_4/models/modules/gagShop_interior. Wallpaper, wainscotting,
and the props on random_* nodes are chosen with random.Random seeded by the
shop's interior zone, from the phase_3.5 interior catalog. The round door is
door_double_round_ur (chooseDoor flips door_double_round_ul), hung on
door_origin at scale 0.8. One file per playground, because that seed and the
hood's TI_door colors are what make each shop its own.

A second file holds the swinging panels of each exterior door. The playground
export only kept the closed slab.
"""
from __future__ import annotations

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
    Point3,
    TexturePool,
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
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "interiors" / "gag_shop"
INTERIOR_DNA = Path(str(Filename(ASSETS, "phase_3.5/dna/storage_interior.dna").toOsSpecific()))

# ToonInteriorColors. The extra TI_door brown is only on Toontown Central.
WAINSCOT = [(0.8, 0.5, 0.3, 1.0), (0.699, 0.586, 0.473, 1.0), (0.473, 0.699, 0.488, 1.0)]
WALLPAPER = [(1.0, 1.0, 0.7, 1.0), (0.8, 1.0, 0.7, 1.0), (0.4, 0.5, 0.4, 1.0), (0.5, 0.7, 0.6, 1.0)]
CREAM = (1.0, 1.0, 0.7, 1.0)
BROWN = (0.8, 0.5, 0.3, 1.0)
SURFACE = {
    "TI_wainscotting": WAINSCOT,
    "TI_wallpaper": WALLPAPER,
    "TI_wallpaper_border": WALLPAPER,
}

# Hood id, interior zone the original clerks stand in. That zone seeds the room.
SHOPS = (
    (1000, 1506, [CREAM]),
    (2000, 2519, [CREAM, BROWN]),
    (3000, 3507, [CREAM]),
    (4000, 4503, [CREAM]),
    (5000, 5501, [CREAM]),
    (9000, 9504, [CREAM]),
)

# Exterior door models. Donald's Dock and Dreamland keep theirs in later phases.
DOOR_CATALOGS = (
    "phase_3.5/models/modules/doors_practical.bam",
    "phase_4/models/modules/doors.bam",
    "phase_6/models/modules/DD_doors_practical.bam",
    "phase_8/models/modules/DL_doors_practical.bam",
)
EXTERIOR_DOORS = (
    "door_double_square_ur",
    "door_double_wood_ur",
    "door_double_curved_ur",
    "door_double_curvedDL_ur",
)


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def parse_catalog(text: str) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    # Drop // comments before matching, so the retired wallpaper lines stay out.
    kept = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
    textures: dict[str, list[str]] = {}
    models: dict[str, list[str]] = {}
    for category, _code, path in re.findall(
        r'store_texture\s*\[\s*"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"',
        kept,
        flags=re.S,
    ):
        textures.setdefault(category, []).append(path)
    # The model path is the file. findNode returns that model under the code.
    for path, category, _code in re.findall(
        r'model\s+"([^"]+)"\s*\[\s*store_node\s*\[\s*"([^"]+)"\s+"([^"]+)"',
        kept,
        flags=re.S,
    ):
        models.setdefault(category, []).append(path)
    return textures, models


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


def pick(rng: random.Random, choices: list[str], cache: dict[str, NodePath], kind: str) -> NodePath | str:
    index = rng.randint(0, len(choices) - 1)
    chosen = choices[index]
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
        key1 = name[7]
        key2 = name[8]
        category = name[11:]
        placed = node
        if key1 == "m":
            paths = models.get(category, [])
            if not paths:
                print("no models", category)
                continue
            model = pick(rng, paths, cache, "model")
            placed = model.copyTo(node)
            hide_helpers(placed)
            print("model", name, paths[0] if len(paths) == 1 else category)
        elif key1 == "t":
            paths = textures.get(category, [])
            if not paths:
                print("no textures", category)
                continue
            relative = pick(rng, paths, cache, "texture")
            texture = TexturePool.loadTexture(Filename(relative))
            if texture is None:
                print("missing texture", relative)
                continue
            node.setTexture(texture, 100)
            placed = node
            print("texture", name, relative)
        if key2 == "c" and category in SURFACE:
            if category in ("TI_wallpaper", "TI_wallpaper_border"):
                rng.seed(zone_id)
            color = rng.choice(SURFACE[category])
            placed.setColorScale(Vec4(*color))
            print("color", category, tuple(round(v, 3) for v in color))


def place_door(interior: NodePath, rng: random.Random, door_colors: list[tuple[float, float, float, float]]) -> None:
    # chooseDoor starts at door_double_round_ul and flips the last letter.
    catalog = load_model("phase_3.5/models/modules/doors_practical.bam")
    source = catalog.find("**/door_double_round_ur")
    origin = interior.find("**/door_origin")
    if source.isEmpty() or origin.isEmpty():
        raise RuntimeError("gag shop door missing")
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
    stood = origin.getParent().getRelativePoint(origin, Point3(-1.5, -6.0, 0.025))
    print("door", tuple(round(v, 3) for v in color), "stand panda", tuple(round(v, 2) for v in stood))


def write_glb(root: NodePath, dest: Path, scene_name: str) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(scene_name)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    print(f"wrote {dest.name} ({len(payload) / (1024 * 1024):.2f} MB) meshes={writer.mesh_count}")


def export_shop(hood: int, zone_id: int, door_colors, textures, models, cache) -> None:
    interior = load_model("phase_4/models/modules/gagShop_interior.bam")
    interior.setName("GagShop")
    rng = random.Random(zone_id)
    replace_random(interior, zone_id, rng, textures, models, cache)
    place_door(interior, rng, door_colors)
    hide_helpers(interior)
    low, high = interior.getTightBounds()
    print(
        f"hood {hood} zone {zone_id} bounds",
        tuple(round(v, 2) for v in low),
        tuple(round(v, 2) for v in high),
    )
    root = NodePath(f"GagShop{hood}")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    write_glb(root, OUT_DIR / f"gag_shop_{hood}.glb", f"GagShop{hood}")


def find_door(code: str) -> NodePath:
    for relative in DOOR_CATALOGS:
        if not Filename(ASSETS, relative).exists():
            continue
        catalog = load_model(relative)
        found = catalog.find("**/" + code)
        if not found.isEmpty():
            print("door catalog", code, relative)
            return found
    raise RuntimeError("missing door " + code)


def export_doors() -> None:
    holder = NodePath("Doors")
    for code in EXTERIOR_DOORS:
        door = find_door(code).copyTo(holder)
        door.setName(code)
        style_pieces(door)
        flat = door.find("**/door_flat")
        if not flat.isEmpty():
            flat.hide()
        hide_helpers(door)
        pieces = [child.getName() for child in door.getChildren() if not child.isHidden()]
        print(code, "pieces", pieces)
    root = NodePath("GagShopDoors")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    holder.copyTo(root)
    write_glb(root, OUT_DIR / "doors.glb", "GagShopDoors")


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)
    textures, models = parse_catalog(INTERIOR_DNA.read_text(encoding="utf-8"))
    print("textures", {key: len(values) for key, values in textures.items()})
    print("models", {key: values[0] for key, values in models.items()})
    cache: dict[str, NodePath] = {}
    for hood, zone_id, door_colors in SHOPS:
        export_shop(hood, zone_id, door_colors, textures, models, cache)
    export_doors()
    return 0


if __name__ == "__main__":
    sys.exit(main())
