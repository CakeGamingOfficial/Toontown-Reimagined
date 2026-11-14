"""Export the C.E.O. banquet table, food, seltzer bottle, snacks, and sit clips.

Sit clips are phase_12 suitA/suitC only. suitB has no sit reel.
"""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

PANDA = Path(r"C:\Panda3D-1.10.16-x64")
os.environ["PATH"] = str(PANDA / "bin") + os.pathsep + os.environ.get("PATH", "")
if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

class _Dna:
    pass


_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = _Dna
_toontown.DNASuitPoint = _Dna
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_street_cogs as street
import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cog_hq"
ANIMS = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "anims"

loadPrcFileData("", "model-cache-dir")
getModelPath().prependDirectory(Filename.from_os_specific(str(RESOURCES)))

SIT = (
    ("sit", "sit"),
    ("sit_hungry_left", "leftsit-hungry"),
    ("sit_hungry_right", "rightsit-hungry"),
    ("sit_angry", "sit-angry"),
    ("sit_eat_in", "sit-eat-in"),
    ("sit_eat_loop", "sit-eat-loop"),
    ("sit_eat_out", "sit-eat-out"),
    ("sit_lose", "sit-lose"),
)

PROPS = (
    ("phase_12/models/bossbotHQ/BanquetTableChairs.bam", "banquet_table.glb"),
    ("phase_12/models/bossbotHQ/canoffood.bam", "can_of_food.glb"),
    ("phase_12/models/bossbotHQ/tt_m_ara_bhq_seltzerBottle.bam", "seltzer_bottle.glb"),
    ("phase_6/models/golf/picnic_apple.bam", "picnic_apple.glb"),
    ("phase_6/models/golf/picnic_cupcake.bam", "picnic_cupcake.glb"),
    ("phase_6/models/golf/picnic_sandwich.bam", "picnic_sandwich.glb"),
    ("phase_6/models/golf/picnic_chocolate_cake.bam", "picnic_cake.glb"),
)


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(RESOURCES / relative)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def write(model: NodePath, name: str) -> None:
    dest = OUT / name
    if dest.exists() and dest.stat().st_size > 0:
        print("keep", name, flush=True)
        return
    root = NodePath(Path(name).stem)
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest.write_bytes(writer.pack(Path(name).stem))
    print("wrote", name, dest.stat().st_size, flush=True)


def load_model(relative: str):
    path = RESOURCES / relative
    if not path.exists():
        return None
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(path)))
    if node is None:
        return None
    return NodePath(node)


def bake_sits() -> None:
    import export_make_a_toon as toon_export

    toon_export.load_model = load_model
    street.ASSETS = RESOURCES
    street.load_model = load_model
    for body in ("a", "c"):
        mod, _heads, neutral, _phase = street.BODIES[body]
        model = load_model(mod)
        if model is None:
            raise RuntimeError("missing " + mod)
        saved, control = street.pose_neutral(model, neutral)
        street.BODIES_NEUTRAL[body] = control
        model.setTag("suit_body", body)
        for key, stem in SIT:
            relative = "phase_12/models/char/suit%s-%s.bam" % (body.upper(), stem)
            dest = ANIMS / body / ("%s.walk" % key)
            if dest.exists() and dest.stat().st_size > 0:
                print("keep", body, key, flush=True)
                continue
            print("bake", body, key, flush=True)
            frames, rate = street.bake_clip(model, saved, relative, dest)
            print("  ", frames, rate, flush=True)
        model.removeNode()


def pose(model: NodePath, relative: str) -> None:
    import export_make_a_toon as toon_export

    anim = load(relative)
    toon_export._KEEP.append(anim)
    bundle = anim.find("**/+AnimBundleNode")
    character = model.find("**/+Character")
    if bundle.isEmpty() or character.isEmpty():
        raise RuntimeError("no character in " + relative)
    control = character.node().getBundle(0).bindAnim(bundle.node().getBundle(), -1)
    character.node().getBundle(0).setControlEffect(control, 1.0)
    control.pose(0)
    character.node().getBundle(0).forceUpdate()


def export_body() -> None:
    import export_make_a_toon as toon_export

    dest = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "bossbot_ceo_body.glb"
    if dest.exists() and dest.stat().st_size > 0:
        print("keep", dest.name, flush=True)
        return
    legs = load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = load("phase_12/models/char/bossbotBoss-torso-zero.bam")
    head = load("phase_12/models/char/bossbotBoss-head-zero.bam")
    treads = load("phase_9/models/char/bossCog-treads.bam")
    club = load("phase_12/models/char/bossbotBoss-golfclub.bam")
    pose(legs, "phase_9/models/char/bossCog-legs-Ff_neutral.bam")
    pose(torso, "phase_9/models/char/bossCog-torso-Ff_neutral.bam")
    pose(head, "phase_9/models/char/bossCog-head-Ff_neutral.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    hand = torso.find("**/joint17")
    if pelvis.isEmpty() or neck.isEmpty() or axle.isEmpty() or hand.isEmpty():
        raise RuntimeError("missing a boss joint")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    club.reparentTo(hand)
    toon_export.bake_skinning(legs)
    root = NodePath("BossbotCEO")
    legs.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(writer.pack("BossbotCEO"))
    print("wrote", dest.name, dest.stat().st_size, flush=True)


def bake_trays() -> None:
    import export_make_a_toon as toon_export

    toon_export.load_model = load_model
    street.ASSETS = RESOURCES
    street.load_model = load_model
    clips = (("tray_walk", "tray-walk"), ("tray_neutral", "tray-neutral"))
    for body in ("a", "b", "c"):
        mod, _heads, neutral, _phase = street.BODIES[body]
        model = load_model(mod)
        saved, control = street.pose_neutral(model, neutral)
        street.BODIES_NEUTRAL[body] = control
        model.setTag("suit_body", body)
        for key, stem in clips:
            relative = "phase_12/models/char/suit%s-%s.bam" % (body.upper(), stem)
            dest = ANIMS / body / ("%s.walk" % key)
            if dest.exists() and dest.stat().st_size > 0:
                print("keep", body, key, flush=True)
                continue
            print("bake", body, key, flush=True)
            frames, rate = street.bake_clip(model, saved, relative, dest)
            print("  ", frames, rate, flush=True)
        model.removeNode()


def main() -> None:
    for relative, name in PROPS:
        write(load(relative), name)
    table = load("phase_12/models/bossbotHQ/BanquetTableChairs.bam")
    names = []
    for node in table.findAllMatches("**"):
        text = node.getName()
        if text and ("chair" in text or "bottle" in text or "lamp" in text or "table" in text):
            names.append(text)
    print("table nodes", names[:48], flush=True)
    bake_sits()
    bake_trays()
    export_body()


def export_clips() -> None:
    # Same baker as the Cashbot clips. The standing body is Ff_neutral, so the
    # swing and the throw are measured from that pose.
    import json

    import export_make_a_toon as toon_export
    import export_sellbot_vp as vp
    from export_toon_walk import collect_named, restore, snapshot, write_walk

    legs = vp.load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = vp.load("phase_12/models/char/bossbotBoss-torso-zero.bam")
    head = vp.load("phase_12/models/char/bossbotBoss-head-zero.bam")
    treads = vp.load("phase_9/models/char/bossCog-treads.bam")
    club = vp.load("phase_12/models/char/bossbotBoss-golfclub.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    hand = torso.find("**/joint17")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    club.reparentTo(hand)
    root = NodePath("BossbotCEO")
    legs.reparentTo(root)
    saved = snapshot(root)
    parts = (("legs", legs), ("torso", torso), ("head", head))
    found = root.findAllMatches("**/+GeomNode")
    paths = [found.getPath(index) for index in range(found.getNumPaths())]
    neutral_controls = []
    neutral_bundles = []
    for part_name, part in parts:
        control, bundle = vp._bind_part(part, part_name, "Ff_neutral")
        neutral_controls.append(control)
        neutral_bundles.append(bundle)
    vp._pose_controls(neutral_controls, neutral_bundles, 0)
    binds = [path.getTransform(root).getMat() for path in paths]
    for control, bundle in zip(neutral_controls, neutral_bundles):
        bundle.setControlEffect(control, 0.0)
    dest_dir = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "ceo_anims"
    dest_dir.mkdir(parents=True, exist_ok=True)
    timing = {}
    for clip in ("Ff_neutral", "golf_swing", "Fb_UpThrow", "Fb_down2Up"):
        controls = []
        bundles = []
        for part_name, part in parts:
            control, bundle = vp._bind_part(part, part_name, clip)
            controls.append(control)
            bundles.append(bundle)
        frame_count = max(control.getNumFrames() for control in controls)
        rate = float(controls[0].getFrameRate() or 24.0)
        stride = 3
        frames = list(range(0, frame_count, stride))
        if frames[-1] != frame_count - 1:
            frames.append(frame_count - 1)
        print("bake", clip, "source", frame_count, "kept", len(frames), flush=True)
        walked = []
        for frame in frames:
            restore(root, saved)
            vp._pose_controls(controls, bundles, frame)
            toon_export.bake_skinning(root)
            vp._apply_motion(paths, binds, root)
            walked.append(collect_named(root))
        nodes = []
        for node_index, (node_name, surfaces) in enumerate(walked[0]):
            packed = []
            for surface_index, (_base, uvs) in enumerate(surfaces):
                samples = []
                for frame in walked:
                    _name, frame_surfaces = frame[node_index]
                    posed, _uv = frame_surfaces[surface_index]
                    samples.append(posed)
                packed.append((uvs, samples))
            nodes.append((node_name, packed))
        path = dest_dir / ("%s.walk" % clip)
        write_walk(path, len(frames), nodes, [])
        span = max(frame_count - 1, 1) / rate
        played = max(len(frames) - 1, 1) / span
        timing[clip] = {"frames": len(frames), "fps": round(played, 3)}
        print("wrote", clip, path.stat().st_size, flush=True)
        for control, bundle in zip(controls, bundles):
            bundle.setControlEffect(control, 0.0)
    (dest_dir / "clips.json").write_text(json.dumps(timing), encoding="utf-8")
    print("wrote clips.json", flush=True)


def export_icons() -> None:
    model = load("phase_12/models/bossbotHQ/BanquetIcons.bam")
    names = []
    for node in model.findAllMatches("**"):
        text = node.getName()
        if text:
            names.append(text)
    print("icon nodes", names, flush=True)
    write(model, "banquet_icons.glb")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "clips":
        export_clips()
    elif len(sys.argv) > 1 and sys.argv[1] == "icons":
        export_icons()
    else:
        main()
