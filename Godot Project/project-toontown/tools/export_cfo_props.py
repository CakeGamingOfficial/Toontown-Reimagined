"""Export the Cashbot crane and safe from the original vault models."""
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

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cog_hq"

loadPrcFileData("", "model-cache-dir")
getModelPath().prependDirectory(Filename.from_os_specific(str(RESOURCES)))

PROPS = [
    ("phase_10/models/cogHQ/CBSafe.bam", "cfo_safe.glb"),
    ("phase_10/models/cogHQ/CBCraneArm.bam", "cfo_crane_arm.glb"),
    ("phase_10/models/cogHQ/CBMagnet.bam", "cfo_magnet.glb"),
    ("phase_10/models/cogHQ/CBCraneControls.bam", "cfo_crane_controls.glb"),
    ("phase_10/models/cogHQ/CBCraneStick.bam", "cfo_crane_stick.glb"),
]


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(RESOURCES / relative)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def main() -> None:
    # The vault root already turns panda into Godot. These stay panda so the
    # room converts them once, the same way the boss body does.
    for relative, name in PROPS:
        model = load(relative)
        root = NodePath(Path(name).stem)
        model.copyTo(root)
        writer = exporter.GltfWriter()
        writer.add_node(root, None)
        payload = writer.pack(Path(name).stem)
        dest = OUT / name
        dest.write_bytes(payload)
        print("wrote", name, len(payload), flush=True)


def export_body() -> None:
    import export_make_a_toon as toon_export
    import export_sellbot_vp as vp

    legs = vp.load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = vp.load("phase_10/models/char/cashbotBoss-torso-zero.bam")
    head = vp.load("phase_10/models/char/cashbotBoss-head-zero.bam")
    treads = vp.load("phase_9/models/char/bossCog-treads.bam")
    vp.pose(legs, "phase_9/models/char/bossCog-legs-Fb_neutral.bam")
    vp.pose(torso, "phase_9/models/char/bossCog-torso-Fb_neutral.bam")
    vp.pose(head, "phase_9/models/char/bossCog-head-Fb_neutral.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    if pelvis.isEmpty() or neck.isEmpty() or axle.isEmpty():
        raise RuntimeError("missing pelvis, joint34, or axle")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    # Battle three faces heading 180. The vault root converts this once.
    legs.setH(180)
    vp._hinge(legs, "joint_doorFront", "DoorFront", (0, 0, -80))
    vp._hinge(legs, "joint_doorRear", "DoorRear", (0, 0, 80))
    toon_export.bake_skinning(legs)
    root = NodePath("CashbotBoss")
    legs.reparentTo(root)
    print("bounds", root.getTightBounds(), flush=True)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "cashbot_boss.glb"
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload = writer.pack("CashbotBoss")
    dest.write_bytes(payload)
    print("wrote", dest, len(payload), flush=True)


def export_clips() -> None:
    # Same baker as the Sellbot V.P. clips, on the Cashbot body. The walk
    # files are read directly, so the editor does not have to import them.
    import json

    import export_make_a_toon as toon_export
    import export_sellbot_vp as vp
    from export_toon_walk import collect_named, restore, snapshot, write_walk

    legs = vp.load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = vp.load("phase_10/models/char/cashbotBoss-torso-zero.bam")
    head = vp.load("phase_10/models/char/cashbotBoss-head-zero.bam")
    treads = vp.load("phase_9/models/char/bossCog-treads.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    legs.setH(180)
    vp._hinge(legs, "joint_doorFront", "DoorFront", (0, 0, -80))
    vp._hinge(legs, "joint_doorRear", "DoorRear", (0, 0, 80))
    root = NodePath("CashbotBoss")
    legs.reparentTo(root)
    saved = snapshot(root)
    parts = (("legs", legs), ("torso", torso), ("head", head))
    found = root.findAllMatches("**/+GeomNode")
    paths = [found.getPath(index) for index in range(found.getNumPaths())]
    neutral_controls = []
    neutral_bundles = []
    for part_name, part in parts:
        control, bundle = vp._bind_part(part, part_name, "Fb_neutral")
        neutral_controls.append(control)
        neutral_bundles.append(bundle)
    vp._pose_controls(neutral_controls, neutral_bundles, 0)
    binds = [path.getTransform(root).getMat() for path in paths]
    for control, bundle in zip(neutral_controls, neutral_bundles):
        bundle.setControlEffect(control, 0.0)
    dest_dir = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "cfo_anims"
    dest_dir.mkdir(parents=True, exist_ok=True)
    timing = {}
    # Ff_neutral is the roll. Fb_firstHit is the hit. Fb_down2Up is the get-up.
    # Fb_downNeutral is dizzy. Fb_UpThrow is the slow directed swing.
    for clip in ("Ff_neutral", "Fb_firstHit", "Fb_downHit", "Fb_down2Up", "Fb_downNeutral", "Fb_UpThrow"):
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
        print(f"bake {clip} source={frame_count} kept={len(frames)}", flush=True)
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
        path = dest_dir / f"{clip}.walk"
        write_walk(path, len(frames), nodes, [])
        span = max(frame_count - 1, 1) / rate
        played = max(len(frames) - 1, 1) / span
        timing[clip] = {"frames": len(frames), "fps": round(played, 3)}
        print(f"wrote {clip} frames={len(frames)} bytes={path.stat().st_size}", flush=True)
        for control, bundle in zip(controls, bundles):
            bundle.setControlEffect(control, 0.0)
    (dest_dir / "clips.json").write_text(json.dumps(timing), encoding="utf-8")
    print("wrote", dest_dir / "clips.json", flush=True)


def _bind_file(root: NodePath, relative: str):
    import export_make_a_toon as toon_export

    anim = load(relative)
    bundle_node = anim.find("**/+AnimBundleNode")
    character = root.find("**/+Character")
    if bundle_node.isEmpty() or character.isEmpty():
        raise RuntimeError("no character anim in " + relative)
    control = character.node().getBundle(0).bindAnim(bundle_node.node().getBundle(), -1)
    toon_export._KEEP.append(anim)
    return control


def export_lever() -> None:
    # leverReach, leverNeutral, and leverPull for every leg and torso size.
    import export_make_a_toon as toon_export
    import export_toon_walk as walk

    models = {
        "legs_s": "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam",
        "legs_m": "phase_3/models/char/tt_a_chr_dgm_shorts_legs_1000.bam",
        "legs_l": "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam",
        "torso_ss": "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam",
        "torso_ms": "phase_3/models/char/tt_a_chr_dgm_shorts_torso_1000.bam",
        "torso_ls": "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam",
        "torso_sd": "phase_3/models/char/tt_a_chr_dgs_skirt_torso_1000.bam",
        "torso_md": "phase_3/models/char/tt_a_chr_dgm_skirt_torso_1000.bam",
        "torso_ld": "phase_3/models/char/tt_a_chr_dgl_skirt_torso_1000.bam",
    }
    anims = {
        "legs_s": "tt_a_chr_dgs_shorts_legs",
        "legs_m": "tt_a_chr_dgm_shorts_legs",
        "legs_l": "tt_a_chr_dgl_shorts_legs",
        "torso_ss": "tt_a_chr_dgs_shorts_torso",
        "torso_ms": "tt_a_chr_dgm_shorts_torso",
        "torso_ls": "tt_a_chr_dgl_shorts_torso",
        "torso_sd": "tt_a_chr_dgs_skirt_torso",
        "torso_md": "tt_a_chr_dgm_skirt_torso",
        "torso_ld": "tt_a_chr_dgl_skirt_torso",
    }
    pairs = []
    for part, model_path in models.items():
        for suffix in ("leverReach", "leverNeutral", "leverPull"):
            pairs.append((part, model_path, f"phase_10/models/char/{anims[part]}_{suffix}.bam", suffix))
    for part, model_path, anim_path, suffix in pairs:
        root = toon_export.load_model(model_path)
        if root is None:
            raise RuntimeError("missing " + model_path)
        for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
            toon_export.hide_named(root, pattern)
        names = walk.joint_names(part)
        saved = walk.snapshot(root)
        control = _bind_file(root, anim_path)
        bind = walk.glb_bind(part, names)
        frame_count = control.getNumFrames()
        hold = frame_count == 1
        if frame_count < 1:
            print(f"skip {part}.{suffix} frames={frame_count}", flush=True)
            continue
        sample_count = 40 if hold else frame_count
        walked = []
        joint_frames = {name: [] for name in names}
        for frame in range(sample_count):
            source = 0 if hold else frame
            walked.append(walk.posed_surfaces(root, saved, control, source))
            for joint_name, matrix in walk.joint_matrices(root, names):
                joint_frames[joint_name].append(matrix)
        nodes = []
        for node_index, (node_name, surfaces) in enumerate(walked[0]):
            packed = []
            for surface_index, (_base, uvs) in enumerate(surfaces):
                samples = []
                for posed in walked:
                    _name, frame_surfaces = posed[node_index]
                    positions, _uv = frame_surfaces[surface_index]
                    samples.append(positions)
                packed.append((uvs, samples))
            nodes.append((node_name, packed))
        path = walk.OUT / f"{part}.{suffix}"
        walk.write_walk(path, sample_count, nodes, [(name, bind[name], joint_frames[name]) for name in names])
        print(f"toon {part}.{suffix} frames={sample_count} bytes={path.stat().st_size}", flush=True)


def export_goon_clips() -> None:
    # collapse holds the stunned pose. recovery is the get-up before she runs.
    import json

    import export_make_a_toon as toon_export
    from export_toon_walk import collect_named, restore, snapshot, write_walk

    model = load("phase_9/models/char/Cog_Goonie-zero.bam")
    dest_dir = OUT / "goon_anims"
    dest_dir.mkdir(parents=True, exist_ok=True)
    timing = {}
    clips = (
        ("collapse", "phase_9/models/char/Cog_Goonie-collapse.bam"),
        ("recovery", "phase_9/models/char/Cog_Goonie-recovery.bam"),
        ("walk", "phase_9/models/char/Cog_Goonie-walk.bam"),
    )
    for clip, relative in clips:
        saved = snapshot(model)
        control = _bind_file(model, relative)
        frame_count = control.getNumFrames()
        rate = float(control.getFrameRate() or 24.0)
        stride = 2
        frames = list(range(0, frame_count, stride))
        if frames[-1] != frame_count - 1:
            frames.append(frame_count - 1)
        print(f"bake goon {clip} source={frame_count} kept={len(frames)}", flush=True)
        walked = []
        for frame in frames:
            restore(model, saved)
            character = model.find("**/+Character")
            bundle = character.node().getBundle(0)
            bundle.setControlEffect(control, 1.0)
            control.pose(frame)
            bundle.forceUpdate()
            toon_export.bake_skinning(model)
            walked.append(collect_named(model))
        nodes = []
        for node_index, (node_name, surfaces) in enumerate(walked[0]):
            packed = []
            for surface_index, (_base, uvs) in enumerate(surfaces):
                samples = []
                for posed in walked:
                    _name, frame_surfaces = posed[node_index]
                    positions, _uv = frame_surfaces[surface_index]
                    samples.append(positions)
                packed.append((uvs, samples))
            nodes.append((node_name, packed))
        path = dest_dir / f"{clip}.walk"
        write_walk(path, len(frames), nodes, [])
        span = max(frame_count - 1, 1) / rate
        played = max(len(frames) - 1, 1) / span
        timing[clip] = {"frames": len(frames), "fps": round(played, 3)}
        print(f"wrote goon {clip} frames={len(frames)} bytes={path.stat().st_size}", flush=True)
        bundle = model.find("**/+Character").node().getBundle(0)
        bundle.setControlEffect(control, 0.0)
    (dest_dir / "clips.json").write_text(json.dumps(timing), encoding="utf-8")
    print("wrote", dest_dir / "clips.json", flush=True)


def export_cone() -> None:
    # Goon.scaleRadar builds the vision beam from this model.
    model = load("phase_9/models/cogHQ/alphaCone2.bam")
    root = NodePath("cone")
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT / "alpha_cone.glb"
    dest.write_bytes(writer.pack("cone"))
    print("wrote", dest, dest.stat().st_size, flush=True)


def export_lightning() -> None:
    # startFlicker copies this onto the magnet while the sniffer is live.
    model = load("phase_10/models/cogHQ/CBLightning.bam")
    root = NodePath("lightning")
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT / "cfo_lightning.glb"
    dest.write_bytes(writer.pack("lightning"))
    print("wrote", dest, dest.stat().st_size, flush=True)


def export_stun() -> None:
    # BossCog.setDizzy parents this prop to the neck and loops its stun anim.
    model = load("phase_3.5/models/props/stun-mod.bam")
    root = NodePath("stun")
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "stun.glb"
    dest.write_bytes(writer.pack("stun"))
    print("wrote", dest, dest.stat().st_size, flush=True)


if __name__ == "__main__":
    choice = sys.argv[1] if len(sys.argv) > 1 else ""
    if choice == "clips":
        export_clips()
    elif choice == "lever":
        export_lever()
    elif choice == "goon":
        export_goon_clips()
    elif choice == "stun":
        export_stun()
    elif choice == "lightning":
        export_lightning()
    elif choice == "cone":
        export_cone()
    else:
        main()
        export_body()
