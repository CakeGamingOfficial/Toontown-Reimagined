"""Export battle gag props and the attack clips the street battle plays.

Props stay in Panda's Z-up space, same as the toon parts, so they can be
parented to a hand joint. Attack clips use the walk sidecar format.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import types
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

# Stock Panda has no toontown DNA module. The glTF writer does not need it.
_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_make_a_toon as toon_export
import export_toon_walk as walk_export
import export_tutorial_props as tutorial
import export_toontown_central as exporter

ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT / "assets" / "battle" / "props"
ANIMS = ROOT / "assets" / "toons" / "anims"
COG = ROOT / "assets" / "cogs"
SFX = ROOT / "assets" / "audio" / "battle"

# phase, file, exported name, scale baked into the node.
PROP_FILES = [
    ("phase_3.5/models/props/tart.bam", "tart", 0.5),
    ("phase_5/models/props/fruit-pie-slice.bam", "fruitpie-slice", 1.0),
    ("phase_5/models/props/cream-pie-slice.bam", "creampie-slice", 1.0),
    ("phase_3.5/models/props/tart.bam", "fruitpie", 0.75),
    ("phase_3.5/models/props/tart.bam", "creampie", 1.0),
    ("phase_5/models/props/birthday-cake-mod.bam", "birthday-cake", 1.0),
    ("phase_5/models/props/wedding_cake.bam", "wedding-cake", 1.0),
    ("phase_3.5/models/props/squirting-flower.bam", "squirting-flower", 1.0),
    ("phase_5/models/props/glass-mod.bam", "glass", 1.0),
    ("phase_4/models/props/water-gun.bam", "water-gun", 1.0),
    ("phase_3.5/models/props/bottle.bam", "bottle", 1.0),
    ("phase_5/models/props/firehose-mod.bam", "firehose", 1.0),
    ("phase_4/models/props/stormcloud-mod.bam", "stormcloud", 1.0),
    ("phase_5/models/props/geyser.bam", "geyser", 1.0),
    ("phase_3.5/models/props/button.bam", "button", 1.0),
    ("phase_3.5/models/props/spray.bam", "spray", 1.0),
    ("phase_3.5/models/props/splat-mod.bam", "splat", 1.0),
    ("phase_5/models/props/feather-mod.bam", "feather", 1.0),
    ("phase_5/models/props/megaphone.bam", "megaphone", 1.0),
    ("phase_5/models/props/lipstick.bam", "lipstick", 1.0),
    ("phase_5/models/props/cane.bam", "cane", 1.0),
    ("phase_5/models/props/cubes-mod.bam", "cubes", 1.0),
    ("phase_5/models/props/ladder2.bam", "ladder", 1.0),
    ("phase_5/models/props/banana-peel-mod.bam", "banana", 1.0),
    ("phase_5/models/props/rake-mod.bam", "rake", 1.0),
    ("phase_5/models/props/marbles-mod.bam", "marbles", 1.0),
    ("phase_5/models/props/quicksand.bam", "quicksand", 1.0),
    ("phase_5/models/props/trapdoor.bam", "trapdoor", 1.0),
    ("phase_5/models/props/tnt-mod.bam", "tnt", 1.0),
    ("phase_5/models/props/traintrack2.bam", "traintrack", 1.0),
    ("phase_5/models/props/1dollar-bill-mod.bam", "1dollar", 1.0),
    ("phase_5/models/props/magnet.bam", "magnet", 1.0),
    ("phase_4/models/props/fishing-pole-mod.bam", "fishing-pole", 1.0),
    ("phase_5/models/props/lips.bam", "lips", 1.0),
    ("phase_5/models/props/hat.bam", "hat", 1.0),
    ("phase_5/models/props/battle_hydrant.bam", "hydrant", 1.0),
    ("phase_5/models/props/train.bam", "train", 1.0),
    ("phase_5/models/props/hypnotize-mod.bam", "hypno-goggles", 1.0),
    ("phase_5/models/props/av_screen.bam", "slideshow", 1.0),
    ("phase_5/models/props/bikehorn.bam", "bikehorn", 1.0),
    ("phase_5/models/props/whistle.bam", "whistle", 1.0),
    ("phase_5/models/props/bugle.bam", "bugle", 1.0),
    ("phase_5/models/props/aoogah.bam", "aoogah", 1.0),
    ("phase_5/models/props/elephant.bam", "elephant", 1.0),
    ("phase_5/models/props/fog_horn.bam", "fog_horn", 1.0),
    ("phase_5/models/props/singing.bam", "singing", 1.0),
    ("phase_5/models/props/flowerpot-mod.bam", "flowerpot", 1.0),
    ("phase_5/models/props/sandbag-mod.bam", "sandbag", 1.0),
    ("phase_4/models/props/anvil-mod.bam", "anvil", 1.0),
    ("phase_5/models/props/weight-mod.bam", "weight", 1.0),
    ("phase_5/models/props/safe-mod.bam", "safe", 1.0),
    ("phase_5/models/props/piano-mod.bam", "piano", 1.0),
    ("phase_5/models/props/ship.bam", "ship", 1.0),
    ("phase_3.5/models/props/phone.bam", "phone", 1.0),
    ("phase_3.5/models/props/receiver.bam", "receiver", 1.0),
    ("phase_3.5/models/props/shredder.bam", "shredder", 1.0),
    ("phase_3.5/models/props/shredder-paper-mod.bam", "shredder-paper", 1.0),
    ("phase_3.5/models/props/clip-on-tie-mod.bam", "clip-on-tie", 1.0),
]

# Actor name, phase, bam suffix. These are the clips MovieThrow, MovieSquirt,
# MovieDrop, and MovieSuitAttacks play on the toon.
TOON_ANIMS = [
    ("throw", "phase_3.5", "pie-throw"),
    ("pushbutton", "phase_3.5", "press-button"),
    ("conked", "phase_3.5", "conked"),
    ("cringe", "phase_3.5", "cringe"),
    ("slip-forward", "phase_4", "slip-forward"),
    ("slip-backward", "phase_4", "slip-backward"),
    ("struggle", "phase_5", "struggle"),
    ("sidestep-left", "phase_3.5", "sidestep-left"),
    ("sidestep-right", "phase_3.5", "jump-back-right"),
    ("duck", "phase_3.5", "duck"),
    ("victory", "phase_3.5", "victory-dance"),
    # MovieLure, MovieSquirt, MovieSound, MovieHeal, and MovieTrap.
    ("battlecast", "phase_4", "fish"),
    ("water-gun", "phase_5", "water-gun"),
    ("hold-bottle", "phase_5", "hold-bottle"),
    ("firehose", "phase_5", "firehose"),
    ("spit", "phase_5", "spit"),
    ("tickle", "phase_5", "tickle"),
    ("smooch", "phase_5", "smooch"),
    ("happy-dance", "phase_5", "happy-dance"),
    ("sprinkle-dust", "phase_5", "sprinkle-dust"),
    ("juggle", "phase_5", "juggle"),
    ("climb", "phase_5", "climb"),
    ("sound", "phase_5", "shout"),
    ("toss", "phase_5", "toss"),
    ("hold-magnet", "phase_5", "hold-magnet"),
    ("hypnotize", "phase_5", "hypnotize"),
    # Toon.getDiedInterval plays lose, then the playground Sad state uses these.
    ("lose", "phase_5", "lose"),
    ("sad-neutral", "phase_4", "sad-neutral"),
    ("sad-walk", "phase_4", "losewalk"),
]

# TTEmote body clips. Happy is the phase 3.5 jump hop. The clip named jump
# in the game is jump-zhang, the hang pose used while leaving the ground.
# Dance reuses victory. The belly flop and banana peel reuse the slip clips.
EMOTE_ANIMS = [
    ("happy", "phase_3.5", "jump"),
    ("wave", "phase_3.5", "wave"),
    ("shrug", "phase_3.5", "shrug"),
    ("angry", "phase_3.5", "angry"),
    ("applause", "phase_4", "applause"),
    ("confused", "phase_4", "confused"),
    ("bow", "phase_4", "bow"),
    ("curtsy", "phase_4", "curtsy"),
    ("bored", "phase_4", "bored"),
    ("think", "phase_4", "think"),
    ("left", "phase_4", "left"),
    ("bad-putt", "phase_6", "bad-putt"),
]

# suitC files. Flunky is a C body. Tutorial reacts live in phase 4;
# the three Flunky attacks live in phase 3.5.
COG_ANIMS = [
    ("phone", "phase_3.5/models/char/suitC-phone.bam"),
    ("throw-paper", "phase_3.5/models/char/suitC-throw-paper.bam"),
    ("shredder", "phase_3.5/models/char/suitC-shredder.bam"),
    ("pie-small", "phase_3.5/models/char/suitC-pie-small.bam"),
    ("squirt-small", "phase_3.5/models/char/suitC-squirt-small.bam"),
    ("sidestep-left", "phase_5/models/char/suitC-sidestep-left.bam"),
    ("sidestep-right", "phase_5/models/char/suitC-sidestep-right.bam"),
    ("drop-react", "phase_5/models/char/suitC-anvil-drop.bam"),
]

SOUNDS = [
    "phase_3.5/audio/sfx/AA_pie_throw_only.mp3",
    "phase_3.5/audio/sfx/AA_tart_only.mp3",
    "phase_5/audio/sfx/AA_slice_only.mp3",
    "phase_4/audio/sfx/AA_wholepie_only.mp3",
    "phase_3.5/audio/sfx/AA_squirt_flowersquirt.mp3",
    "phase_5/audio/sfx/AA_squirt_flowersquirt_miss.mp3",
    "phase_5/audio/sfx/SA_powertie_throw.mp3",
    "phase_3.5/audio/sfx/SA_hangup.mp3",
    "phase_3.5/audio/sfx/SA_shred.mp3",
    "phase_3.5/audio/sfx/AV_side_step.mp3",
    "phase_3.5/audio/sfx/Cog_Death.mp3",
    "phase_3.5/audio/sfx/ENC_cogfall_apart.mp3",
    "phase_5/audio/sfx/ENC_Lose.ogg",
]


def load_prop(relative: str):
    return toon_export.load_model(relative)


def godot_xform(pos, hpr, scale=(1.0, 1.0, 1.0)):
    node = NodePath("attach")
    node.setPosHprScale(pos[0], pos[1], pos[2], hpr[0], hpr[1], hpr[2], scale[0], scale[1], scale[2])
    mat = node.getMat()
    cells = [mat.getCell(row, col) for row in range(4) for col in range(4)]
    return {
        "origin": cells[12:15],
        "x": cells[0:3],
        "y": cells[4:7],
        "z": cells[8:11],
    }


def write_prop(relative: str, out_name: str, scale: float) -> None:
    model = load_prop(relative)
    if model is None:
        print("missing prop", relative, flush=True)
        return
    if out_name == "clip-on-tie" and model.getNumChildren() > 0:
        model.getChild(0).setHpr(23.86, -16.03, 9.18)
    if out_name == "shredder-paper":
        model.setPosHpr(2.22, -0.95, 1.16, -48.61, 26.57, -111.51)
        model.flattenMedium()
    if out_name == "ship":
        found = model.find("**/ship_gag")
        if not found.isEmpty():
            model = found
    if scale != 1.0:
        model.setScale(scale)
    writer = exporter.GltfWriter()
    writer.add_node(model, None)
    path = PROPS / f"{out_name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(writer.pack(out_name))
    print(f"prop {out_name} meshes={writer.mesh_count}", flush=True)


def anim_relative(model: str, phase: str, anim: str) -> str:
    stem = model.split("/")[-1].replace("_1000.bam", "")
    return f"{phase}/models/char/{stem}_{anim}.bam"


def joint_list(part: str) -> tuple[str, ...]:
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head", "def_joint_right_hold", "def_joint_left_hold", "def_joint_attachFlower")


def present_joints(part: str, names: tuple[str, ...], directory: Path | None = None) -> tuple[str, ...]:
    folder = walk_export.PARTS_DIR if directory is None else directory
    data = (folder / f"{part}.glb").read_bytes()
    import struct
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    have = {node["name"] for node in document["nodes"]}
    return tuple(name for name in names if name in have)


def export_toon_anim(part: str, model: str, suffix: str, phase: str, anim: str, directory: Path | None = None) -> None:
    relative = anim_relative(model, phase, anim)
    root = toon_export.load_model(model)
    if root is None:
        print("missing part", model, flush=True)
        return
    for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
        toon_export.hide_named(root, pattern)
    names = present_joints(part, joint_list(part), directory)
    if not names:
        print("no joints", part, flush=True)
        return
    saved = walk_export.snapshot(root)
    try:
        control = walk_export.bind_anim(root, relative)
    except RuntimeError as error:
        print("skip", part, suffix, error, flush=True)
        return
    bind = walk_export.glb_bind(part, names) if directory is None else _glb_bind(directory / f"{part}.glb", names)
    frame_count = control.getNumFrames()
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        walked.append(walk_export.posed_surfaces(root, saved, control, frame))
        for joint_name, matrix in walk_export.joint_matrices(root, names):
            joint_frames[joint_name].append(matrix)
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for posed in walked:
                _name, frame_surfaces = posed[node_index]
                positions, _uv = frame_surfaces[surface_index]
                frames.append(positions)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = ANIMS / f"{part}.{suffix}"
    walk_export.write_walk(
        path,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print(f"toon {part}.{suffix} frames={frame_count} bytes={path.stat().st_size}", flush=True)


def export_cog_anim(suffix: str, relative: str) -> None:
    model = toon_export.load_model("phase_3.5/models/char/suitC-mod.bam")
    if model is None:
        raise RuntimeError("missing suitC")
    tutorial.paint_flunky(model)
    model.setScale(4.0 / 4.14)
    saved = walk_export.snapshot(model)
    try:
        control = walk_export.bind_anim(model, relative)
    except RuntimeError as error:
        print("skip cog", suffix, error, flush=True)
        return
    neutral = walk_export.bind_anim(model, "phase_3.5/models/char/suitC-neutral.bam")
    names = ("joint_head", "joint_Rhold", "joint_Lhold", "joint_attachMeter")
    frame_count = control.getNumFrames()
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        walk_export.restore(model, saved)
        bundle = model.find("**/+Character").node().getBundle(0)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        toon_export.bake_skinning(model)
        walked.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, names):
            joint_frames[joint_name].append(matrix)
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(neutral, 1.0)
    neutral.pose(0)
    bundle.forceUpdate()
    bind = {}
    for joint_name, matrix in walk_export.joint_matrices(model, names):
        bind[joint_name] = matrix
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for posed in walked:
                _name, frame_surfaces = posed[node_index]
                positions, _uv = frame_surfaces[surface_index]
                frames.append(positions)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = COG / f"flunky.{suffix}"
    walk_export.write_walk(
        path,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print(f"cog {suffix} frames={frame_count} bytes={path.stat().st_size}", flush=True)


def _pose_control(model, saved, control, frame: int) -> None:
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(control, 1.0)
    control.pose(frame)
    bundle.forceUpdate()
    toon_export.bake_skinning(model)


def export_lose() -> None:
    # Suit.getLoseActor swaps in suitC-lose-mod for the death. The unnamed
    # geom is the body and oil that fly apart; the shoulder card stays put.
    model = toon_export.load_model("phase_3.5/models/char/suitC-lose-mod.bam")
    if model is None:
        raise RuntimeError("missing suitC-lose-mod")
    empties = [path for path in model.findAllMatches("**/+GeomNode") if path.getName() == ""]
    if len(empties) >= 1:
        empties[0].setName("pieces")
    if len(empties) >= 2:
        empties[1].setName("shoulder")
    tutorial.paint_flunky(model)
    model.setScale(4.0 / 4.14)
    saved = walk_export.snapshot(model)
    control = walk_export.bind_anim(model, "phase_3.5/models/char/suitC-lose.bam")
    _pose_control(model, saved, control, 0)
    root = NodePath("FlunkyLose")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    out = COG / "flunky_lose.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(writer.pack("FlunkyLose"))
    print(f"wrote {out.name} meshes={writer.mesh_count}", flush=True)
    model.detachNode()
    names = ("joint_head",)
    frame_count = control.getNumFrames()
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        _pose_control(model, saved, control, frame)
        walked.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, names):
            joint_frames[joint_name].append(matrix)
    _pose_control(model, saved, control, 0)
    bind = {}
    for joint_name, matrix in walk_export.joint_matrices(model, names):
        bind[joint_name] = matrix
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for posed in walked:
                _name, frame_surfaces = posed[node_index]
                positions, _uv = frame_surfaces[surface_index]
                frames.append(positions)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = COG / "flunky.lose"
    walk_export.write_walk(
        path,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print(f"cog lose frames={frame_count} bytes={path.stat().st_size}", flush=True)


def export_death_props() -> None:
    parts = toon_export.load_model("phase_3.5/models/props/suit-particles.bam")
    gear = parts.find("**/gear")
    writer = exporter.GltfWriter()
    writer.add_node(gear, None)
    gear_path = PROPS / "gear.glb"
    gear_path.write_bytes(writer.pack("gear"))
    print(f"prop gear meshes={writer.mesh_count}", flush=True)
    explosion = toon_export.load_model("phase_3.5/models/props/explosion.bam")
    frames = explosion.findAllMatches("**/+GeomNode")
    for index in range(frames.getNumPaths()):
        frames[index].setName("boom%d" % index)
    writer = exporter.GltfWriter()
    writer.add_node(explosion, None)
    boom_path = PROPS / "explosion.glb"
    boom_path.write_bytes(writer.pack("explosion"))
    print(f"prop explosion meshes={writer.mesh_count}", flush=True)


def copy_sounds() -> None:
    SFX.mkdir(parents=True, exist_ok=True)
    for relative in SOUNDS:
        source = ASSETS / relative
        if not source.exists():
            print("missing sfx", relative, flush=True)
            continue
        dest = SFX / source.name
        shutil.copyfile(source, dest)
        print("sfx", dest.name, flush=True)


def export_bills() -> None:
    # BattleProps.makeVariant swaps the bill's second texture for $5 and $10.
    for name, texture in (("5dollar", "phase_5/maps/dollar_5.png"), ("10dollar", "phase_5/maps/dollar_10.png")):
        model = load_prop("phase_5/models/props/1dollar-bill-mod.bam")
        if model is None:
            continue
        image = toon_export.Loader.getGlobalPtr().loadSync(toon_export.Filename(toon_export.ASSETS, texture))
        if image is not None:
            model.setTexture(image, 1)
        writer = exporter.GltfWriter()
        writer.add_node(model, None)
        path = PROPS / f"{name}.glb"
        path.write_bytes(writer.pack(name))
        print(f"prop {name} meshes={writer.mesh_count}", flush=True)


def _glb_bind(path: Path, names: tuple[str, ...]) -> dict:
    import struct
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    found = {}
    for node in document["nodes"]:
        if node["name"] in names and "matrix" in node:
            found[node["name"]] = [float(value) for value in node["matrix"]]
    missing = [name for name in names if name not in found]
    if missing:
        raise RuntimeError(path.name + " missing " + ", ".join(missing))
    return found


def export_shticker_book() -> int:
    """The book the toon holds. Pages are joint children, so the clip is joints only."""
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    prop = toon_export.load_model("phase_3.5/models/props/book-mod.bam")
    channel = toon_export.load_model("phase_3.5/models/props/book-chan.bam")
    if prop is None or channel is None:
        raise RuntimeError("missing shticker book prop")
    control = walk_export.bind_anim(prop, "phase_3.5/models/props/book-chan.bam")
    control.pose(0)
    prop.find("**/+Character").node().getBundle(0).forceUpdate()
    out = ROOT / "assets" / "props" / "shticker_book.glb"
    toon_export.write_gltf(prop, out)
    names = ("joint_front_page", "joint_back_page")
    bind = _glb_bind(out, names)
    frames = {name: [] for name in names}
    for frame in range(control.getNumFrames()):
        control.pose(frame)
        prop.find("**/+Character").node().getBundle(0).forceUpdate()
        for name, matrix in walk_export.joint_matrices(prop, names):
            frames[name].append(matrix)
    walk_export.write_walk(
        ANIMS / "shticker_book.book",
        control.getNumFrames(),
        [],
        [(name, bind[name], frames[name]) for name in names],
    )
    print(f"shticker book frames={control.getNumFrames()}", flush=True)
    for part, model, _neutral, _walk in walk_export.PARTS:
        export_toon_anim(part, model, "book", "phase_3.5", "book")
    heads = ROOT / "assets" / "toons" / "heads"
    for code, prefix in (
        ("dls", "tt_a_chr_dgm_shorts_head"),
        ("dss", "tt_a_chr_dgm_skirt_head"),
        ("dsl", "tt_a_chr_dgs_shorts_head"),
        ("dll", "tt_a_chr_dgl_shorts_head"),
    ):
        export_toon_anim(code, f"phase_3/models/char/{prefix}_1000.bam", "book", "phase_3.5", "book", heads)
    return 0


def export_emotes() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    for suffix, phase, anim in EMOTE_ANIMS:
        for part, model, _neutral, _walk in walk_export.PARTS:
            export_toon_anim(part, model, suffix, phase, anim)
    return 0


def export_added() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    PROPS.mkdir(parents=True, exist_ok=True)
    added = {
        "fishing-pole", "lips", "hat", "hydrant", "train",
    }
    for relative, name, scale in PROP_FILES:
        if name in added:
            write_prop(relative, name, scale)
    export_bills()
    added_anims = {
        "battlecast", "water-gun", "hold-bottle", "firehose", "spit", "tickle",
        "smooch", "happy-dance", "sprinkle-dust", "juggle", "climb", "sound",
        "toss", "hold-magnet", "hypnotize",
        "slip-forward", "slip-backward", "struggle",
        "lose", "sad-neutral", "sad-walk",
    }
    for suffix, phase, anim in TOON_ANIMS:
        if suffix not in added_anims:
            continue
        for part, model, _neutral, _walk in walk_export.PARTS:
            export_toon_anim(part, model, suffix, phase, anim)
    # Only the dog heads have slip channels. The head sits on the torso neck,
    # and these clips are the face that falls with it.
    heads = ROOT / "assets" / "toons" / "heads"
    dog_heads = (
        ("dls", "tt_a_chr_dgm_shorts_head"),
        ("dss", "tt_a_chr_dgm_skirt_head"),
        ("dsl", "tt_a_chr_dgs_shorts_head"),
        ("dll", "tt_a_chr_dgl_shorts_head"),
    )
    for suffix in ("slip-forward", "slip-backward"):
        for code, prefix in dog_heads:
            export_toon_anim(code, f"phase_3/models/char/{prefix}_1000.bam", suffix, "phase_4", suffix, heads)
    return 0


# Actor props. MovieThrow, MovieSquirt, MovieDrop, MovieTrap, MovieLure, and
# MovieHeal play these channels. The glb stays on the bind pose.
GAG_ANIMS = [
    ("banana", "phase_5/models/props/banana-peel-mod.bam", "phase_5/models/props/banana-peel-chan.bam"),
    ("rake", "phase_5/models/props/rake-mod.bam", "phase_5/models/props/rake-chan.bam"),
    ("marbles", "phase_5/models/props/marbles-mod.bam", "phase_5/models/props/marbles-chan.bam"),
    ("tnt", "phase_5/models/props/tnt-mod.bam", "phase_5/models/props/tnt-chan.bam"),
    ("birthday-cake", "phase_5/models/props/birthday-cake-mod.bam", "phase_5/models/props/birthday-cake-chan.bam"),
    ("splat", "phase_3.5/models/props/splat-mod.bam", "phase_3.5/models/props/splat-chan.bam"),
    ("flowerpot", "phase_5/models/props/flowerpot-mod.bam", "phase_5/models/props/flowerpot-chan.bam"),
    ("sandbag", "phase_5/models/props/sandbag-mod.bam", "phase_5/models/props/sandbag-chan.bam"),
    ("anvil", "phase_4/models/props/anvil-mod.bam", "phase_4/models/props/anvil-chan.bam"),
    ("weight", "phase_5/models/props/weight-mod.bam", "phase_5/models/props/weight-chan.bam"),
    ("safe", "phase_5/models/props/safe-mod.bam", "phase_5/models/props/safe-chan.bam"),
    ("piano", "phase_5/models/props/piano-mod.bam", "phase_5/models/props/piano-chan.bam"),
    ("stormcloud", "phase_4/models/props/stormcloud-mod.bam", "phase_4/models/props/stormcloud-chan.bam"),
    ("glass", "phase_5/models/props/glass-mod.bam", "phase_5/models/props/glass-chan.bam"),
    ("firehose", "phase_5/models/props/firehose-mod.bam", "phase_5/models/props/firehose-chan.bam"),
    ("feather", "phase_5/models/props/feather-mod.bam", "phase_5/models/props/feather-chan.bam"),
    ("cubes", "phase_5/models/props/cubes-mod.bam", "phase_5/models/props/cubes-chan.bam"),
    ("fishing-pole", "phase_4/models/props/fishing-pole-mod.bam", "phase_4/models/props/fishing-pole-chan.bam"),
    ("1dollar", "phase_5/models/props/1dollar-bill-mod.bam", "phase_5/models/props/1dollar-bill-chan.bam"),
    ("hypno-goggles", "phase_5/models/props/hypnotize-mod.bam", "phase_5/models/props/hypnotize-chan.bam"),
]


def _local_matrix(path) -> list[float]:
    mat = path.getTransform(path.getParent()).getMat()
    return [mat.getCell(row, col) for row in range(4) for col in range(4)]


def _moved(before: list[float], after: list[float], tol: float = 0.0008) -> bool:
    return any(abs(left - right) > tol for left, right in zip(before, after))


def export_gag_clip(name: str, model_rel: str, anim_rel: str) -> None:
    from panda3d.core import GeomNode

    model = load_prop(model_rel)
    if model is None:
        print("missing gag", model_rel, flush=True)
        return
    saved = walk_export.snapshot(model)
    control = walk_export.bind_anim(model, anim_rel)
    bundle = model.find("**/+Character").node().getBundle(0)
    named = []
    seen = set()
    for path in model.findAllMatches("**"):
        label = path.getName()
        if not label or label.endswith(".egg") or label in seen:
            continue
        seen.add(label)
        named.append(path)
    parents = []

    def walk_parents(node) -> None:
        if node.node().isOfType(GeomNode.getClassType()) and walk_export.surface_attributes(node):
            parents.append(node.getParent().getName() or "node")
        for child in exporter.visit_children(node):
            walk_parents(child)

    walk_parents(model)
    frame_count = control.getNumFrames()
    joint_frames = {path.getName(): [] for path in named}
    vertex_frames = []
    for frame in range(frame_count):
        walk_export.restore(model, saved)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        for path in named:
            joint_frames[path.getName()].append(_local_matrix(path))
        toon_export.bake_skinning(model)
        vertex_frames.append(walk_export.collect_named(model))
    joints = []
    for path in named:
        frames = joint_frames[path.getName()]
        if any(_moved(frames[0], frame) for frame in frames[1:]):
            joints.append((path.getName(), frames[0], frames))
    nodes = []
    used = {}
    for index, (node_name, surfaces) in enumerate(vertex_frames[0]):
        parent = parents[index] if index < len(parents) else node_name
        moves = False
        for posed in vertex_frames[1:]:
            for surface, other in zip(surfaces, posed[index][1]):
                for left, right in zip(surface[0], other[0]):
                    if _moved(left, right, 0.002):
                        moves = True
                        break
                if moves:
                    break
            if moves:
                break
        if not moves:
            continue
        slot = used.get(parent, 0)
        used[parent] = slot + 1
        label = parent if slot == 0 else "%s#%d" % (parent, slot)
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = [posed[index][1][surface_index][0] for posed in vertex_frames]
            packed.append((uvs, frames))
        nodes.append((label, packed))
    walk_export.write_walk(PROPS / f"{name}.walk", frame_count, nodes, joints)
    print(f"gag {name} frames={frame_count} joints={len(joints)} meshes={len(nodes)}", flush=True)


def export_gag_anims() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    PROPS.mkdir(parents=True, exist_ok=True)
    # The planted rake is rake-step-mod. The throw plays rake-chan on the other model.
    write_prop("phase_5/models/props/rake-step-mod.bam", "rake-react", 1.0)
    for name, model_rel, anim_rel in GAG_ANIMS:
        export_gag_clip(name, model_rel, anim_rel)
    return 0


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    PROPS.mkdir(parents=True, exist_ok=True)
    for relative, name, scale in PROP_FILES:
        write_prop(relative, name, scale)
    attachments = {
        "tie": godot_xform((0.66, 0.51, 0.28), (-69.652, -17.199, 67.96)),
        "phone": godot_xform((0.23, 0.17, -0.11), (5.939, 2.763, -177.591)),
        "receiver_left": godot_xform((0.23, 0.17, -0.11), (5.939, 2.763, -177.591)),
        "receiver_right": godot_xform((-0.45, 0.48, -0.62), (-87.47, -18.21, 7.82)),
        "paper": godot_xform((0.59, -0.31, 0.81), (79.224, 32.576, -179.449)),
        "shredder": godot_xform((0.0, -0.12, -0.34), (-90.0, -53.77, 0.0)),
    }
    (PROPS / "attachments.json").write_text(json.dumps(attachments), encoding="utf-8")
    print("wrote attachments", flush=True)
    copy_sounds()
    for suffix, phase, anim in TOON_ANIMS:
        for part, model, _neutral, _walk in walk_export.PARTS:
            export_toon_anim(part, model, suffix, phase, anim)
    for suffix, relative in COG_ANIMS:
        export_cog_anim(suffix, relative)
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "emotes":
        sys.exit(export_emotes())
    if len(sys.argv) > 1 and sys.argv[1] == "added":
        sys.exit(export_added())
    if len(sys.argv) > 1 and sys.argv[1] == "book":
        sys.exit(export_shticker_book())
    if len(sys.argv) > 1 and sys.argv[1] == "gag-anims":
        sys.exit(export_gag_anims())
    sys.exit(main())
