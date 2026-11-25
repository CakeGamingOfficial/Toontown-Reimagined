"""Export the Sellbot Field Office maze rooms and their collision tables.

CogdoMazeFactory builds a 3 by 3 of tt_m_ara_cmg_quadrant models. The collision
rows live in CogdoMazeData, already rotated for 0, 90, 180, and 270.
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

from panda3d.core import getModelPath, loadPrcFileData

import export_minigames as games
import export_toon_idle as idle


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "buildings" / "field_office"
DATA = Path(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code"
    r"\toontown\cogdominium\CogdoMazeData.py"
)
PHASE = "phase_5/models/cogdominium/"

# CogdoMazeGameGlobals.MazeBarriers. These cells are opened after the rooms join.
BARRIERS = (
    ((7, 34), (8, 34), (9, 34), (10, 34)),
    ((24, 34), (25, 34), (26, 34), (27, 34)),
    ((41, 34), (42, 34), (43, 34), (44, 34)),
    ((7, 17), (8, 17), (9, 17), (10, 17)),
    ((24, 17), (25, 17), (26, 17), (27, 17)),
    ((41, 17), (42, 17), (43, 17), (44, 17)),
    ((17, 41), (17, 42), (17, 43), (17, 44)),
    ((17, 24), (17, 25), (17, 26), (17, 27)),
    ((17, 7), (17, 8), (17, 9), (17, 10)),
    ((34, 41), (34, 42), (34, 43), (34, 44)),
    ((34, 24), (34, 25), (34, 26), (34, 27)),
    ((34, 7), (34, 8), (34, 9), (34, 10)),
)


def _pos(node, parent) -> list[float]:
    point = node.getPos(parent)
    return [round(point.x, 4), round(point.y, 4), round(point.z, 4)]


def _coolers(relative: str) -> list[dict]:
    model = games.load_model(relative)
    if model is None:
        return []
    found = []
    for cooler in model.findAllMatches("**/*waterCooler*"):
        found.append({
            "pos": _pos(cooler, model),
            "h": round(cooler.getH(model), 4),
        })
    found.sort(key=lambda item: (item["pos"][0], item["pos"][1], item["pos"][2], item["h"]))
    print(relative, "coolers", len(found), flush=True)
    return found


def _locator(relative: str, name: str) -> list[float]:
    model = games.load_model(relative)
    if model is None:
        return [0.0, 0.0, 0.0]
    spot = model.find(f"**/{name}")
    if spot.isEmpty():
        print("missing locator", name, flush=True)
        return [0.0, 0.0, 0.0]
    point = _pos(spot, model)
    print(name, point, "h", round(spot.getH(model), 4), flush=True)
    return point + [round(spot.getH(model), 4)]


def dump_tables() -> None:
    namespace: dict = {}
    exec(DATA.read_text(encoding="utf-8"), namespace)
    collisions: dict = namespace["QuadrantCollisions"]
    angles = [0, 90, 180, 270]
    quadrants = []
    tables = []
    for index in range(1, 10):
        key = f"{PHASE}tt_m_ara_cmg_quadrant{index}"
        book = collisions[key]
        tables.append([book[angle] for angle in angles])
        quadrants.append({"coolers": _coolers(key + ".bam")})
        width = len(book[0][0])
        height = len(book[0])
        if width != 16 or height != 16:
            raise SystemExit(f"quadrant {index} is {width}x{height}")
    level = f"{PHASE}tt_m_ara_cmg_level.bam"
    payload = {
        "cell": namespace["QuadrantCellWidth"],
        "quadrant": namespace["QuadrantSize"],
        "grid": 3,
        "frame": 1,
        "exit": _locator(level, "exit_loc"),
        "elevator": _locator(level, "elevator_loc"),
        "barriers": [[list(pair) for pair in group] for group in BARRIERS],
        "quadrants": quadrants,
        "tables": tables,
    }
    path = OUT / "field_maze.json"
    path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print("field_maze.json bytes", path.stat().st_size, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    games.OUT = OUT
    dump_tables()
    for index in range(1, 10):
        games.scene(
            f"field_maze_quadrant{index}",
            [(f"{PHASE}tt_m_ara_cmg_quadrant{index}.bam",)],
        )
    games.scene("field_maze_level", [(f"{PHASE}tt_m_ara_cmg_level.bam",)])
    games.scene("field_maze_divider", [(f"{PHASE}tt_m_ara_cmg_grouping_blockerDivider.bam",)])
    games.scene("field_maze_exit", [(f"{PHASE}tt_m_ara_csa_exitDoor.bam",)])
    games.scene("field_maze_memo", [(f"{PHASE}tt_m_ara_csa_memo.bam",)])
    games.scene("field_maze_balloon", [(f"{PHASE}tt_m_ara_cmg_waterBalloon.bam",)])
    games.scene("field_maze_cabinet", [(f"{PHASE}tt_m_ara_cmg_cabinetSmFalling.bam",)])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
