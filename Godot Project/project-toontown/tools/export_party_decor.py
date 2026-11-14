"""Export party decoration models and the winter, valentine, and victory activity models."""
from __future__ import annotations

import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, TexturePool, loadPrcFileData

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "parties"
DECOR = OUT / "decor"
RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")

# Names the shared partyDecorations bam keeps, one file each.
PIECES = {
    "balloon_anvil": "BalloonAnvil",
    "balloon_stage": "BalloonStage",
    "bow": "Bow",
    "cake": "Cake",
    "castle": "Castle",
    "gift_pile": "GiftPile",
    "horn": "Horn",
    "mardi_gras": "MardiGras",
    "noise_makers": "NoiseMakers",
    "pinwheel": "Pinwheel",
    "heart_target": "HeartTarget",
    "balloon_anvil_valentine": "BalloonAnvilValentine",
}

SINGLES = {
    "gag_globe": "phase_13/models/parties/tt_m_ara_pty_gagGlobe_model.bam",
    "bean_banner": "phase_13/models/parties/tt_m_ara_pty_bannerJellybean_model.bam",
    "gag_cake": "phase_13/models/parties/tt_m_ara_pty_cakeTower.bam",
    "heart_banner": "phase_13/models/parties/tt_m_ara_pty_bannerValentine_model.bam",
    "flying_heart": "phase_13/models/parties/tt_m_ara_pty_heartWing_model.bam",
    "hydra": "phase_13/models/parties/tt_a_ara_pty_hydra_default.bam",
    "banner_victory": "phase_13/models/parties/tt_m_ara_pty_bannerVictory_model.bam",
    "cannon_victory": "phase_13/models/parties/tt_m_ara_pty_cannonVictory_model.bam",
    "cog_statue_victory": "phase_13/models/parties/tt_m_ara_pty_cogDoodleVictory.bam",
    "tube_cog": "phase_5.5/models/estate/tt_a_ara_pty_tubeCogVictory_default.bam",
    "cog_ice_cream_victory": "phase_13/models/parties/tt_m_ara_pty_cogIceCreamVictory.bam",
    "cog_ice_cream_winter": "phase_13/models/parties/tt_m_ara_pty_cogIceCreamWinter.bam",
    "stage_winter": "phase_13/models/parties/tt_r_ara_pty_winterProps.bam",
    "cog_statue_winter": "phase_13/models/parties/tt_m_ara_pty_cogDoodleWinter.bam",
    "snowman": "phase_13/models/estate/tt_m_prp_ext_snowman.bam",
    "snow_doodle": "phase_5.5/models/estate/tt_m_prp_ext_snowDoodle.bam",
    "catch_winter": "phase_13/models/parties/tt_m_ara_pty_partyCatchTreeWinter.bam",
    "cog_winter": "phase_13/models/parties/tt_m_ara_pty_cogPieArenaWinter.bam",
    "dance_valentine": "phase_13/models/parties/tt_m_ara_pty_danceFloorValentine.bam",
}


def load_relative(loader, relative):
    path = RESOURCES.joinpath(*relative.split("/"))
    node = loader.loadSync(Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path, flush=True)
        return None
    return NodePath(node)


def load_texture(loader: Loader, relative: str):
    path = RESOURCES.joinpath(*relative.split("/"))
    texture = TexturePool.loadTexture(Filename.from_os_specific(str(path)))
    if texture is None:
        print("missing texture", path, flush=True)
    return texture


def detach_helpers(model: NodePath) -> None:
    for piece in model.findAllMatches("**/*collision*"):
        piece.detachNode()
    for piece in model.findAllMatches("**/*trigger*"):
        piece.detachNode()
    for name in ("growthStage_1", "growthStage_2"):
        stage = model.find("**/" + name)
        if not stage.isEmpty():
            stage.detachNode()


def write_model(name: str, model: NodePath, folder: Path) -> None:
    detach_helpers(model)
    root = NodePath(name)
    root.setMat(Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(name)
    dest = folder / f"{name}.glb"
    dest.write_bytes(payload)
    print(f"wrote {dest.name} meshes={writer.mesh_count} bytes={len(payload)}", flush=True)
    root.removeNode()


def keep_piece(model: NodePath, token: str) -> int:
    kept = 0
    for piece in model.findAllMatches("**/partyDecoration_*"):
        name = piece.getName()
        if name.endswith(token) and "collision" not in name:
            kept += 1
            continue
        piece.detachNode()
    return kept


def hide_other_balls(model: NodePath, keep: str) -> None:
    parent = model.find("**/discoBall_mesh")
    ball = model.find("**/" + keep)
    if parent.isEmpty() or ball.isEmpty():
        print("disco ball missing", keep, flush=True)
        return
    for child in parent.getChildren():
        if child != ball:
            child.detachNode()


def reskin(model: NodePath, texture, queries: tuple) -> None:
    hit = 0
    for query in queries:
        for piece in model.findAllMatches(query):
            piece.setTexture(texture, 100)
            hit += 1
    if hit == 0:
        model.setTexture(texture, 100)
        print("reskin fell back to the whole model", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    DECOR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    loader = Loader.getGlobalPtr()
    failed = False
    shared = load_relative(loader, "phase_4/models/parties/partyDecorations.bam")
    if shared is None:
        return 1
    names = []
    for piece in shared.findAllMatches("**/partyDecoration_*"):
        names.append(piece.getName())
    print("pieces", len(names), flush=True)
    print(", ".join(names), flush=True)
    for name, token in PIECES.items():
        copy = shared.copyTo(NodePath("copy"))
        kept = keep_piece(copy, token)
        if kept == 0:
            print("no piece", token, flush=True)
            failed = True
            copy.removeNode()
            continue
        write_model(name, copy, DECOR)
    for name, relative in SINGLES.items():
        model = load_relative(loader, relative)
        if model is None:
            failed = True
            continue
        if name == "dance_valentine":
            ten = model.copyTo(NodePath("ten"))
            hide_other_balls(ten, "discoBall_10")
            write_model("dance_valentine", ten, OUT)
            hide_other_balls(model, "discoBall_20")
            write_model("dance_valentine_20", model, OUT)
            continue
        folder = OUT if name in ("catch_winter", "cog_winter", "dance_valentine") else DECOR
        write_model(name, model, folder)
    tramp = load_relative(loader, "phase_13/models/parties/trampoline_model.bam")
    juke = load_relative(loader, "phase_13/models/parties/jukebox_model.bam")
    skins = (
        ("trampoline_winter", tramp, "phase_13/maps/tt_t_ara_pty_trampolineWinter.jpg", ("**/trampoline/**",)),
        ("trampoline_victory", tramp, "phase_13/maps/tt_t_ara_pty_trampolineVictory.jpg", ("**/trampoline/**",)),
        ("trampoline_valentine", tramp, "phase_13/maps/tt_t_ara_pty_trampolineValentine.jpg", ("**/trampoline/**",)),
        ("jukebox_valentine", juke, "phase_13/maps/tt_t_ara_pty_jukeboxValentineA.jpg", ("**/jukeboxGlass", "**/jukeboxBody")),
        ("jukebox_valentine_40", juke, "phase_13/maps/tt_t_ara_pty_jukeboxValentineB.jpg", ("**/jukeboxGlass", "**/jukeboxBody")),
    )
    for name, source, texture_path, queries in skins:
        if source is None:
            failed = True
            continue
        texture = load_texture(loader, texture_path)
        if texture is None:
            failed = True
            continue
        copy = source.copyTo(NodePath("skin"))
        reskin(copy, texture, queries)
        write_model(name, copy, OUT)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
