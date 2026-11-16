"""Acorn Acres game tables, plus the checkers, Chinese checkers, and Find Four boards.

The playground export left game_table_1, game_table_2, and game_table_3 empty.
The three tables sit where outdoor_zone_sz.dna places them.
"""

import json
import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import (
    CollisionNode,
    Filename,
    Loader,
    Mat4,
    NodePath,
    Point3,
    getModelPath,
    loadPrcFileData,
)

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP

BASE = Path(__file__).resolve().parents[1]
ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = BASE / "assets" / "neighborhoods" / "acorn_acres"
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")

TABLES = (
    ("game_table_1", Point3(91.7, 5.68547, 1.2), (30.0, 1.45363, 0.0)),
    ("game_table_2", Point3(-75.439, 62.507, 0.55), (90.0, -1.45363, 0.0)),
    ("game_table_3", Point3(7.156, 116.564, 0.79), (0.0, -1.45363, 0.0)),
)

BOARDS = (
    ("regular_checker_game", "phase_6/models/golf/regular_checker_game.bam"),
    ("checker_game", "phase_6/models/golf/checker_game.bam"),
    ("findfour_game", "phase_6/models/golf/findfour_game.bam"),
)

# Pieces are parented onto locators that already sit in the Y-up board, so they
# keep their Panda orientation instead of taking a second Z-up conversion.
PIECES = (
    ("checker_piece_white", "phase_6/models/golf/regular_checker_piecewhite.bam"),
    ("checker_piece_black", "phase_6/models/golf/regular_checker_pieceblack.bam"),
    ("checker_marble", "phase_6/models/golf/checker_marble.bam"),
)


def strip_collisions(root: NodePath) -> None:
    for node in root.findAllMatches("**"):
        if node.isEmpty():
            continue
        if node.node().isOfType(CollisionNode.getClassType()):
            node.removeNode()


def write_glb(root: NodePath, dest: Path, scene_name: str) -> None:
    writer = GltfWriter()
    writer.add_node(root, None)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(writer.pack(scene_name))
    print(f"wrote {dest.name} nodes={len(writer.nodes)} meshes={writer.mesh_count}")


def _load(path: Path, name: str):
    scope = {}
    exec(path.read_text(encoding="utf-8"), scope)
    return scope[name]


def dump_rules() -> None:
    checkers = _load(SOURCE / "toontown" / "safezone" / "CheckersBoard.py", "CheckersBoard")()
    chinese = _load(SOURCE / "toontown" / "safezone" / "ChineseCheckersBoard.py", "ChineseCheckersBoard")()
    homes = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [10, 11, 12, 13, 23, 24, 25, 35, 36, 46],
        [65, 75, 76, 86, 87, 88, 98, 99, 100, 101],
        [111, 112, 113, 114, 115, 116, 117, 118, 119, 120],
        [74, 84, 85, 95, 96, 97, 107, 108, 109, 110],
        [19, 20, 21, 22, 32, 33, 34, 44, 45, 55],
    ]
    payload = {
        "checkers": {
            "adjacent": [[-1 if cell is None else int(cell) for cell in square.adjacent] for square in checkers.squareList],
            "jumps": [[-1 if cell is None else int(cell) for cell in square.jumps] for square in checkers.squareList],
            "king_1": [31, 30, 29, 28],
            "king_2": [0, 1, 2, 3],
        },
        "chinese": {
            "adjacent": [[-1 if cell is None else int(cell) for cell in square.adjacent] for square in chinese.squareList],
            "homes": homes,
        },
    }
    (OUT / "picnic_rules.json").write_text(json.dumps(payload), encoding="utf-8")
    print(
        "rules",
        len(payload["checkers"]["adjacent"]),
        len(payload["chinese"]["adjacent"]),
        [len(row) for row in homes],
    )


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(ASSETS / relative)))
    if node is None:
        raise SystemExit(relative + " failed to load")
    return NodePath(node)


def main() -> None:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT.mkdir(parents=True, exist_ok=True)
    root = NodePath("picnic_tables")
    root.setMat(Mat4(*Z_UP_TO_Y_UP))
    model = load_model("phase_6/models/golf/game_table.bam")
    for name, pos, hpr in TABLES:
        table = model.copyTo(root)
        table.setName(name)
        table.setPos(pos)
        table.setHpr(*hpr)
        anchor = table.attachNewNode("board_anchor")
        anchor.setPos(0, 0, 2.83)
    strip_collisions(root)
    write_glb(root, OUT / "picnic_tables.glb", "PicnicTables")

    for name, rel in BOARDS:
        board = load_model(rel)
        holder = NodePath(name)
        board.reparentTo(holder)
        board.setName(name)
        strip_collisions(holder)
        locators = board.find("**/locators")
        if not locators.isEmpty():
            print(name, "locator order:")
            for index, child in enumerate(locators.getChildren()):
                print(f"  {index} {child.getName()}")
        pieces = board.find("**/pieces")
        if not pieces.isEmpty():
            print(name, "pieces:")
            for index, child in enumerate(pieces.getChildren()):
                print(f"  {index} {child.getName()}")
        starts = board.find("**/locatorStartGroup")
        if not starts.isEmpty():
            print(name, "starts:")
            for index, child in enumerate(starts.getChildren()):
                print(f"  {index} {child.getName()}")
        write_glb(holder, OUT / f"{name}.glb", name)
    for name, rel in PIECES:
        piece = load_model(rel)
        holder = NodePath(name)
        piece.reparentTo(holder)
        piece.setName(name)
        strip_collisions(holder)
        write_glb(holder, OUT / f"{name}.glb", name)
    dump_rules()


if __name__ == "__main__":
    main()
