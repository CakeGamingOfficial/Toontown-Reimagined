"""Export the solo trolley minigame models and copy their sounds.

Each glb is parented under the same Z-up to Y-up root as the playground, so a
Panda point (x, y, z) is the Godot point (x, z, -y). Dynamic props are exported
at the origin. Scenery that the original places once is baked at that pose.
"""
from __future__ import annotations

import json
import shutil
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "minigames"
SFX = ROOT / "assets" / "audio" / "sfx"
GAME = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
MAZE_PY = Path(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code"
    r"\toontown\minigame\MazeData.py"
)

SOUNDS = (
    "MG_cannon_adjust",
    "MG_cannon_fire_alt",
    "MG_cannon_hit_dirt",
    "MG_cannon_hit_tower",
    "MG_cannon_splash",
    "MG_cannon_whizz",
    "MG_win",
    "tick_counter",
    "AV_ambient_water",
    "ring_perfect",
    "ring_get",
    "ring_miss",
    "SZ_DD_treasure",
    "AA_drop_anvil_miss",
    "MG_Tag_C",
    "MG_maze_pickup",
    "MG_pos_buzzer",
    "AA_sound_whistle",
    "King_Crab",
    "diving_game_hit",
    "diving_treasure_drop_off",
    "diving_treasure_pick_up",
    "diving_swim_loop",
    "target_cloud",
    "target_trampoline_2",
    "target_launch",
    "target_Lose",
    "target_happydance",
    "target_impact_grunt1",
    "target_chute",
    "target_impact_only",
    "target_wind_fly_loop",
    "target_stretching_aim_loop",
    "target_wind_float_clothloop",
    "MG_pairing_all_matched",
    "MG_pairing_match",
    "MG_pairing_match_bonus_both",
    "MG_pairing_jumping_signal",
    "MG_pairing_bonus_moves",
    "MG_pairing_card_flip_face_up",
    "MG_pairing_card_flip_face_down",
    "MG_sfx_vine_game_bananas",
    "MG_sfx_vine_game_jump",
    "MG_sfx_vine_game_catch",
    "MG_sfx_vine_game_spider_hit",
    "MG_sfx_vine_game_bat_hit",
    "MG_sfx_vine_game_bat_hit_midair",
    "MG_sfx_vine_game_bat_flying_lp",
    "MG_sfx_vine_game_finish",
    "MG_sfx_vine_game_fall",
    "AA_pie_throw_only",
    "AA_squirt_seltzer_miss",
    "Seltzer_squirt_2dgame_hit",
    "threeSparkles",
    "sparkly",
    "AV_collision",
    "Piano_Tuna",
)


def load_model(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename(idle.ASSETS, relative))
    if node is None:
        print("missing", relative, flush=True)
        return None
    model = NodePath(node)
    model.show()
    return model


def write_root(root: NodePath, name: str) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path = OUT / f"{name}.glb"
    path.write_bytes(writer.pack(name))
    print(f"{name} meshes={writer.mesh_count}", flush=True)


def scene(name: str, pieces: list[tuple]) -> None:
    root = NodePath(name)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    kept = 0
    for piece in pieces:
        relative = piece[0]
        pos = piece[1] if len(piece) > 1 else (0, 0, 0)
        hpr = piece[2] if len(piece) > 2 else (0, 0, 0)
        scale = piece[3] if len(piece) > 3 else (1, 1, 1)
        model = load_model(relative)
        if model is None:
            continue
        if len(scale) == 1:
            scale = (scale[0], scale[0], scale[0])
        model.setPosHprScale(pos[0], pos[1], pos[2], hpr[0], hpr[1], hpr[2], scale[0], scale[1], scale[2])
        model.reparentTo(root)
        kept += 1
    if kept == 0:
        print("skip scene", name, flush=True)
        return
    write_root(root, name)


def extract(relative: str, search: str, name: str, scale: float = 1.0) -> None:
    model = load_model(relative)
    if model is None:
        return
    piece = model.find(search)
    if piece.isEmpty():
        print("missing node", search, "in", relative, flush=True)
        return
    piece.show()
    root = NodePath(name)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    copied = piece.copyTo(root)
    copied.setPosHprScale(0, 0, 0, 0, 0, 0, scale, scale, scale)
    write_root(root, name)


def dump_maze() -> None:
    namespace: dict = {}
    exec(MAZE_PY.read_text(encoding="utf-8"), namespace)
    data = namespace["mazeData"]["phase_4/models/minigames/maze_1player"]
    payload = {
        "width": data["width"],
        "height": data["height"],
        "originX": data["originX"],
        "originY": data["originY"],
        "cell": namespace["CELL_WIDTH"],
        "collision": data["collisionTable"],
        "treasures": [list(spot) for spot in data["treasurePosList"]],
    }
    path = OUT / "maze_1player.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    print(f"maze treasures={len(payload['treasures'])} {data['width']}x{data['height']}", flush=True)


def copy_sounds() -> None:
    folders = list(GAME.glob("phase_*/audio/sfx"))
    SFX.mkdir(parents=True, exist_ok=True)
    for base in SOUNDS:
        dest_ogg = SFX / f"{base}.ogg"
        dest_mp3 = SFX / f"{base}.mp3"
        if dest_ogg.exists() or dest_mp3.exists():
            continue
        found = False
        for folder in folders:
            ogg = folder / f"{base}.ogg"
            mp3 = folder / f"{base}.mp3"
            if ogg.exists():
                shutil.copy2(ogg, dest_ogg)
                found = True
                break
            if mp3.exists():
                shutil.copy2(mp3, dest_mp3)
                found = True
                break
        if not found:
            print("missing sound", base, flush=True)
        else:
            print("sound", base, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    copy_sounds()
    dump_maze()
    # CannonGame: ground 2.8, sky 2, tower in front, hill under the cannon.
    scene("cannon_set", [
        ("phase_4/models/minigames/toon_cannon_gameground.bam", (0, 0, 0), (0, 0, 0), (2.8, 2.8, 2.8)),
        ("phase_4/models/minigames/toon_cannon_water_tower.bam", (0, 40, 0), (0, 0, 0), (1, 1, 1)),
        ("phase_4/models/minigames/cannon_hill.bam", (0, -127.67, 0), (0, 0, 0), (1, 1, 1)),
        ("phase_3.5/models/props/TT_sky.bam", (0, 0, 0), (0, 0, 0), (2, 2, 2)),
    ])
    scene("toon_cannon", [("phase_4/models/minigames/toon_cannon.bam",)])
    scene("swimming_game", [("phase_4/models/minigames/swimming_game.bam", (0, 75, -14.5))])
    scene("swimming_ring", [("phase_4/models/minigames/swimming_game_ring.bam", (0, 0, 0), (0, 0, 0), (0.75, 0.75, 0.75))])
    scene("maze_1player", [("phase_4/models/minigames/maze_1player.bam",)])
    scene("mickey", [("phase_3.5/models/props/mickeySZ.bam", (0, 0, 0), (0, -90, 0), (1.6, 1.6, 1.6))])
    scene("tug_set", [
        ("phase_4/models/minigames/tug_of_war_dock.bam",),
        ("phase_4/models/minigames/tug_of_war_rope.bam", (0, 18, 1)),
        ("phase_3.5/models/props/TT_sky.bam", (0, 0, 0), (0, 0, 0), (1, 1, 1)),
    ])
    # CatchGame stands the treehouse up: heading 180, pitch -90.
    scene("treehouse", [("phase_4/models/minigames/treehouse_2players.bam", (0, 0, 0), (180, -90, 0))])
    scene("apple", [("phase_4/models/minigames/apple.bam",)])
    scene("anvil", [("phase_4/models/props/anvil-mod.bam",)])
    scene("diving_game", [("phase_4/models/minigames/diving_game.bam",)])
    scene("treasure", [("phase_4/models/minigames/treasure.bam",)])
    scene("clownfish", [("phase_4/models/char/clownFish-zero.bam",)])
    scene("slingshot_desert", [("phase_4/models/minigames/slingshot_game_desert4.bam", (0, -5, 0), (0, 0, 0), (15, 15, 2))])
    scene("trampoline", [("phase_4/models/minigames/slingshot_game_tramp.bam",)])
    scene("umbrella", [("phase_4/models/minigames/slingshot_game_umbrellas.bam",)])
    extract("phase_4/models/minigames/slingshot_game_cacti.bam", "**/cactus_a", "cactus")
    scene("memory_room", [("phase_4/models/minigames/memory_room.bam", (0.5, 0, 0))])
    scene("garden_sign", [("phase_4/models/minigames/garden_sign_memory.bam",)])
    scene("playing_card", [("phase_3.5/models/gui/playingCard.bam",)])
    extract("phase_4/models/minigames/vine_game.bam", "**/background", "vine_background")
    extract("phase_4/models/minigames/vine_game.bam", "**/vine1", "vine")
    extract("phase_4/models/minigames/vine_game.bam", "**/bananas", "bananas")
    extract("phase_4/models/minigames/vine_game.bam", "**/bat__1", "bat")
    extract("phase_4/models/minigames/vine_game.bam", "**/spider_2", "spider")
    extract("phase_4/models/minigames/vine_game_shelf.bam", "**/start1", "vine_start")
    extract("phase_4/models/minigames/vine_game_shelf.bam", "**/end1", "vine_end")
    scene("cogthief", [("phase_4/models/minigames/cogthief_game.bam",)])
    scene("gag_tank", [("phase_4/models/minigames/cogthief_game_gagTank.bam",)])
    scene("tart", [("phase_3.5/models/props/tart.bam",)])
    scene("toonblitz", [("phase_4/models/minigames/toonblitz_game.bam",)])
    scene("toonblitz_start", [("phase_4/models/minigames/toonblitz_game_start.bam",)])
    scene("toonblitz_wall", [("phase_4/models/minigames/toonblitz_game_wall.bam",)])
    scene("toonblitz_elevator", [("phase_4/models/minigames/toonblitz_game_elevator.bam",)])
    scene("toonblitz_block", [("phase_4/models/minigames/toonblitz_game_block00.bam",)])
    scene("toonblitz_stomper", [("phase_4/models/minigames/toonblitz_game_stomper.bam",)])
    scene("sales_icon", [("phase_4/models/minigames/salesIcon.bam",)])
    scene("money_icon", [("phase_4/models/minigames/moneyIcon.bam",)])
    scene("legal_icon", [("phase_4/models/minigames/legalIcon.bam",)])
    scene("corp_icon", [("phase_4/models/minigames/corpIcon.bam",)])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
