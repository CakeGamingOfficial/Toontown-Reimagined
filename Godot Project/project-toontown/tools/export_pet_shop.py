"""Export the pet shop the way DistributedPetshopInterior.setup does.

The room is phase_4/models/modules/PetShopInterior. Wallpaper and the props
on random_* nodes are chosen with random.Random seeded by the clerk zone.
The round door is door_double_round_ur, hung on door_origin at scale 0.8.
The tank fish is interiorfish, swimming at 0.7 speed. One room per playground.

A second file holds the swinging panels of each playground's exterior door.
The neighborhood export only kept the closed slab.
"""
from __future__ import annotations

import json
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
    TransparencyAttrib,
    Vec4,
    getModelPath,
    loadPrcFileData,
)
from panda3d.core import TexturePool

loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
loadPrcFileData("", "default-model-extension .bam")

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from direct.actor.Actor import Actor
from direct.showbase.ShowBase import ShowBase

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "interiors" / "pet_shop"
INTERIOR_DNA = Path(str(Filename(ASSETS, "phase_3.5/dna/storage_interior.dna").toOsSpecific()))

WAINSCOT = [(0.8, 0.5, 0.3, 1.0), (0.699, 0.586, 0.473, 1.0), (0.473, 0.699, 0.488, 1.0)]
WALLPAPER = [(1.0, 1.0, 0.7, 1.0), (0.8, 1.0, 0.7, 1.0), (0.4, 0.5, 0.4, 1.0), (0.5, 0.7, 0.6, 1.0)]
FLOOR = [(0.746, 1.0, 0.477, 1.0), (1.0, 0.684, 0.477, 1.0)]
CREAM = (1.0, 1.0, 0.7, 1.0)
BROWN = (0.8, 0.5, 0.3, 1.0)
SURFACE = {
    "TI_wainscotting": WAINSCOT,
    "TI_wallpaper": WALLPAPER,
    "TI_wallpaper_border": WALLPAPER,
    "TI_floor": FLOOR,
}

# Hood id, interior zone the clerks stand in. That zone seeds the room.
SHOPS = (
    (1000, 1510, [CREAM]),
    (2000, 2522, [CREAM, BROWN]),
    (3000, 3511, [CREAM]),
    (4000, 4508, [CREAM]),
    (5000, 5505, [CREAM]),
    (9000, 9508, [CREAM]),
)

DOOR_CATALOGS = (
    "phase_3.5/models/modules/doors_practical.bam",
    "phase_4/models/modules/doors.bam",
    "phase_6/models/modules/DD_doors_practical.bam",
    "phase_8/models/modules/DL_doors_practical.bam",
)
# Playground node name, then the name to search for in the door catalogs.
EXTERIOR_DOORS = (
    ("door_double_square_ur", "door_double_square_ur"),
    ("door_double_round_ur", "door_double_round_ur"),
    ("door_double_clothshop", "door_double_clothesshop_ur"),
    ("door_double_clothshop", "door_double_clothshop"),
    ("door_double_curved_ul", "door_double_curved_ul"),
    ("door_double_curved_ur", "door_double_curved_ur"),
    ("door_double_curvedDL_ur", "door_double_curvedDL_ur"),
)


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def parse_catalog(text: str) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    kept = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
    textures: dict[str, list[str]] = {}
    models: dict[str, list[str]] = {}
    for category, _code, path in re.findall(
        r'store_texture\s*\[\s*"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"',
        kept,
        flags=re.S,
    ):
        textures.setdefault(category, []).append(path)
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
            print("model", name, category)
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


def place_door(interior: NodePath, rng: random.Random, door_colors) -> None:
    catalog = load_model("phase_3.5/models/modules/doors_practical.bam")
    source = catalog.find("**/door_double_round_ur")
    origin = interior.find("**/door_origin")
    if source.isEmpty() or origin.isEmpty():
        raise RuntimeError("pet shop door missing")
    door = source.copyTo(origin)
    origin.setScale(0.8, 0.8, 0.8)
    origin.setPos(origin, 0, -0.25, 0)
    color = rng.choice(door_colors)
    door.setColor(Vec4(*color))
    flat = door.find("**/door_*_flat")
    if not flat.isEmpty():
        flat.setColor(Vec4(*color))
    style_pieces(door)
    door.setName("door_0")
    print("door", tuple(round(v, 3) for v in color))


def make_fish(interior: NodePath) -> Actor:
    actor = Actor(
        "phase_4/models/props/interiorfish-zero.bam",
        {"swim": "phase_4/models/props/interiorfish-swim.bam"},
    )
    actor.reparentTo(interior)
    actor.setName("interior_fish")
    actor.setColorScale(0.8, 0.9, 1, 0.8)
    actor.setTransparency(TransparencyAttrib.M_alpha)
    actor.setScale(0.8)
    actor.setPos(0, 6, -4)
    actor.pose("swim", 0)
    actor.find("**/+Character").node().forceUpdate()
    return actor


def fish_clip(actor: Actor) -> dict:
    control = actor.getAnimControl("swim")
    frames = []
    for frame in range(control.getNumFrames()):
        actor.pose("swim", frame)
        actor.find("**/+Character").node().forceUpdate()
        sample = {}
        for joint in actor.getJoints():
            sample[joint.getName()] = [
                round(joint.getTransform().getCell(row, col), 5) for row in range(4) for col in range(4)
            ]
        frames.append(sample)
    actor.pose("swim", 0)
    actor.find("**/+Character").node().forceUpdate()
    print("fish", control.getNumFrames(), "frames", "joints", list(frames[0]))
    return {"fps": control.getFrameRate() * 0.7, "frames": frames}


def write_glb(root: NodePath, dest: Path, scene_name: str) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(scene_name)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    print(f"wrote {dest.name} ({len(payload) / (1024 * 1024):.2f} MB) meshes={writer.mesh_count}")


def export_shop(hood: int, zone_id: int, door_colors, textures, models, cache) -> None:
    interior = load_model("phase_4/models/modules/PetShopInterior.bam")
    interior.setName("PetShop")
    rng = random.Random(zone_id)
    replace_random(interior, zone_id, rng, textures, models, cache)
    make_fish(interior)
    place_door(interior, rng, door_colors)
    hide_helpers(interior)
    low, high = interior.getTightBounds()
    print(
        f"hood {hood} zone {zone_id} bounds",
        tuple(round(v, 2) for v in low),
        tuple(round(v, 2) for v in high),
    )
    root = NodePath(f"PetShop{hood}")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    write_glb(root, OUT_DIR / f"pet_shop_{hood}.glb", f"PetShop{hood}")


def find_door(code: str) -> NodePath:
    for relative in DOOR_CATALOGS:
        if not Filename(ASSETS, relative).exists():
            continue
        catalog = load_model(relative)
        found = catalog.find("**/" + code)
        if not found.isEmpty():
            print("door catalog", code, relative)
            return found
    return NodePath()


def export_doors() -> None:
    holder = NodePath("Doors")
    seen: set[str] = set()
    for export_name, code in EXTERIOR_DOORS:
        if export_name in seen:
            continue
        found = find_door(code)
        if found.isEmpty():
            print("missing door", code)
            continue
        door = found.copyTo(holder)
        door.setName(export_name)
        style_pieces(door)
        flat = door.find("**/door_flat")
        if not flat.isEmpty():
            flat.hide()
        hide_helpers(door)
        pieces = [child.getName() for child in door.getChildren() if not child.isHidden()]
        print(export_name, "pieces", pieces)
        seen.add(export_name)
    missing = [name for name, _code in EXTERIOR_DOORS if name not in seen]
    if missing:
        raise RuntimeError("missing exterior doors " + ", ".join(missing))
    root = NodePath("PetShopDoors")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    holder.copyTo(root)
    write_glb(root, OUT_DIR / "doors.glb", "PetShopDoors")


def main() -> int:
    ShowBase(windowType="none")
    getModelPath().prependDirectory(ASSETS)
    textures, models = parse_catalog(INTERIOR_DNA.read_text(encoding="utf-8"))
    cache: dict[str, NodePath] = {}
    for hood, zone_id, door_colors in SHOPS:
        export_shop(hood, zone_id, door_colors, textures, models, cache)
    fish_actor = make_fish(NodePath("fish"))
    fish = fish_clip(fish_actor)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "fish_swim.json").write_text(json.dumps(fish, separators=(",", ":")))
    print("wrote fish_swim.json", (OUT_DIR / "fish_swim.json").stat().st_size)
    export_doors()
    return 0


if __name__ == "__main__":
    sys.exit(main())
