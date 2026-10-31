"""Export Toon Hall the way DistributedToonHallInterior.setup does.

Zone ToontownGlobals.ToonHall is 2513, so the wallpaper seed and the
Toontown Central door colors match that room. The hung door is
door_double_round_ur. The holiday meter stays out: enterFlat is the
ordinary look, with the ropes, the flat meter, and the three scientist
cards.

A second file holds the swinging panels for the playground door. The
neighborhood export only kept the closed slab.
"""
from __future__ import annotations

import random
import sys
import types
from pathlib import Path

from panda3d.core import Filename, NodePath, Point3, Vec4, getModelPath, loadPrcFileData

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_gag_shop as shop
import export_toontown_central as exporter

ASSETS = shop.ASSETS
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "interiors" / "toon_hall"
ZONE_ID = 2513
CREAM = shop.CREAM
BROWN = shop.BROWN

ROPE_PATHS = (
    "phase_4/models/modules/tt_m_ara_int_ropes.bam",
    "phase_3.5/models/modules/tt_m_ara_int_ropes.bam",
)
FLAT_METER = "phase_3.5/models/modules/tt_m_ara_int_sillyMeterFlat.bam"
SCIENTISTS = (
    ("npc_origin_1", "phase_3.5/models/modules/tt_m_ara_int_scientistDuckFlat.bam", "FlatDuck"),
    ("npc_origin_2", "phase_3.5/models/modules/tt_m_ara_int_scientistMonkeyFlat.bam", "FlatMonkey"),
    ("npc_origin_3", "phase_3.5/models/modules/tt_m_ara_int_scientistHorseFlat.bam", "FlatHorse"),
)


def load_first(paths: tuple[str, ...]) -> NodePath:
    for relative in paths:
        if Filename(ASSETS, relative).exists():
            print("loaded", relative)
            return shop.load_model(relative)
    raise RuntimeError("missing " + paths[0])


def place_props(interior: NodePath) -> None:
    ropes = load_first(ROPE_PATHS)
    ropes.copyTo(interior).setName("Ropes")
    meter = shop.load_model(FLAT_METER)
    meter.copyTo(interior).setName("SillyMeterFlat")
    for origin_name, relative, name in SCIENTISTS:
        origin = interior.find("**/" + origin_name)
        card = shop.load_model(relative)
        if origin.isEmpty():
            print("missing", origin_name)
            card.copyTo(interior).setName(name)
            continue
        placed = card.copyTo(origin)
        placed.setName(name)
        print(name, "on", origin_name, tuple(round(v, 2) for v in origin.getPos(interior)))


def export_interior(textures, models, cache) -> None:
    interior = shop.load_model("phase_3.5/models/modules/tt_m_ara_int_toonhall.bam")
    interior.setName("ToonHall")
    halls = models.get("TI_hall", [])
    rng = random.Random(ZONE_ID)
    # randomDNAItem consumes one roll even when the catalog has a single hall.
    rng.randint(0, max(len(halls), 1) - 1)
    shop.replace_random(interior, ZONE_ID, rng, textures, models, cache)
    shop.place_door(interior, rng, [CREAM, BROWN])
    place_props(interior)
    shop.hide_helpers(interior)
    origins = interior.findAllMatches("**/npc_origin*")
    for index in range(origins.getNumPaths()):
        origin = origins.getPath(index)
        print("origin", origin.getName(), tuple(round(v, 2) for v in origin.getPos(interior)))
    low, high = interior.getTightBounds()
    print("bounds", tuple(round(v, 2) for v in low), tuple(round(v, 2) for v in high))
    root = NodePath("ToonHallRoot")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    interior.copyTo(root)
    shop.write_glb(root, OUT_DIR / "toon_hall.glb", "ToonHall")


def export_door() -> None:
    hall = shop.load_model("phase_4/models/modules/toonhall.bam")
    origin = hall.find("**/toonhall_door_origin")
    if origin.isEmpty():
        raise RuntimeError("toonhall_door_origin missing")
    pos = origin.getPos(hall)
    hpr = origin.getHpr(hall)
    scale = origin.getScale(hall)
    print(
        "exterior origin panda",
        tuple(round(v, 3) for v in pos),
        "hpr",
        tuple(round(v, 2) for v in hpr),
        "scale",
        tuple(round(v, 3) for v in scale),
    )
    print("exterior origin godot", round(pos.x, 3), round(pos.z, 3), round(-pos.y, 3))
    door = shop.find_door("door_double_round_ur").copyTo(NodePath("holder"))
    shop.style_pieces(door)
    flat = door.find("**/door_flat")
    if not flat.isEmpty():
        flat.hide()
    shop.hide_helpers(door)
    holder = NodePath("Doors")
    door.reparentTo(holder)
    door.setName("door_double_round_ur")
    root = NodePath("ToonHallDoors")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    holder.copyTo(root)
    shop.write_glb(root, OUT_DIR / "doors.glb", "ToonHallDoors")


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(ASSETS)
    textures, models = shop.parse_catalog(shop.INTERIOR_DNA.read_text(encoding="utf-8"))
    print("TI_hall", models.get("TI_hall"))
    cache: dict[str, NodePath] = {}
    export_interior(textures, models, cache)
    export_door()
    return 0


if __name__ == "__main__":
    sys.exit(main())
