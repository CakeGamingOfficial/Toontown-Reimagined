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
    ("sidestep-left", "phase_3.5", "sidestep-left"),
    ("sidestep-right", "phase_3.5", "jump-back-right"),
    ("duck", "phase_3.5", "duck"),
    ("victory", "phase_3.5", "victory-dance"),
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


def present_joints(part: str, names: tuple[str, ...]) -> tuple[str, ...]:
    data = (walk_export.PARTS_DIR / f"{part}.glb").read_bytes()
    import struct
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    have = {node["name"] for node in document["nodes"]}
    return tuple(name for name in names if name in have)


def export_toon_anim(part: str, model: str, suffix: str, phase: str, anim: str) -> None:
    relative = anim_relative(model, phase, anim)
    root = toon_export.load_model(model)
    if root is None:
        print("missing part", model, flush=True)
        return
    for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
        toon_export.hide_named(root, pattern)
    names = present_joints(part, joint_list(part))
    if not names:
        print("no joints", part, flush=True)
        return
    saved = walk_export.snapshot(root)
    try:
        control = walk_export.bind_anim(root, relative)
    except RuntimeError as error:
        print("skip", part, suffix, error, flush=True)
        return
    bind = walk_export.glb_bind(part, names)
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
    sys.exit(main())
