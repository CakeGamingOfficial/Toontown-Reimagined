"""Export the Sellbot VP from the original bossCog parts.

BossCog builds him from phase_9 bossCog-legs, sellbotBoss-torso, and
sellbotBoss-head, with bossCog-treads on joint_axle. The pie round uses the
back-facing neutral, doors closed. Door panels stay on their hinge nodes so
the round can swing them open.
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

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_make_a_toon as toon_export
import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
GAME = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "bosses" / "sellbot_vp.glb"

loadPrcFileData("", "model-cache-dir")
for root in (RESOURCES, GAME):
    getModelPath().prependDirectory(Filename.from_os_specific(str(root)))


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(RESOURCES / relative)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def pose(model: NodePath, relative: str) -> None:
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


def _hinge(legs: NodePath, joint_name: str, hinge_name: str, closed_hpr: tuple) -> None:
    joint = legs.find("**/" + joint_name)
    if joint.isEmpty():
        raise RuntimeError("missing " + joint_name)
    hinge = joint.attachNewNode(hinge_name)
    children = joint.getChildren()
    for index in range(children.getNumPaths()):
        child = children.getPath(index)
        if child == hinge:
            continue
        child.reparentTo(hinge)
    hinge.setHpr(*closed_hpr)


def main() -> None:
    legs = load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = load("phase_9/models/char/sellbotBoss-torso-zero.bam")
    head = load("phase_9/models/char/sellbotBoss-head-zero.bam")
    treads = load("phase_9/models/char/bossCog-treads.bam")
    pose(legs, "phase_9/models/char/bossCog-legs-Fb_neutral.bam")
    pose(torso, "phase_9/models/char/bossCog-torso-Fb_neutral.bam")
    pose(head, "phase_9/models/char/bossCog-head-Fb_neutral.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    if pelvis.isEmpty() or neck.isEmpty() or axle.isEmpty():
        raise RuntimeError("missing pelvis, joint34, or axle")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    # Battle three shows the door side. Heading 180 turns joint_doorFront toward Godot -Z.
    legs.setH(180)
    # BossCog.__setupDoor parents the joint's children to a hinge. Closed is a
    # roll; open is identity, which is what the round swaps to.
    _hinge(legs, "joint_doorFront", "DoorFront", (0, 0, -80))
    _hinge(legs, "joint_doorRear", "DoorRear", (0, 0, 80))
    toon_export.bake_skinning(legs)
    # The VP room root already turns panda into Godot. This model stays panda
    # so it is converted once, with the room.
    root = NodePath("SellbotVP")
    legs.reparentTo(root)
    front = root.find("**/DoorFront")
    rear = root.find("**/DoorRear")
    print("front", front.getPos(root), "rear", rear.getPos(root))
    print("bounds", root.getTightBounds())
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(writer.pack("SellbotVP"))
    print("wrote", OUT, "meshes", writer.mesh_count, "bytes", OUT.stat().st_size)
    export_gear()


def export_gear() -> None:
    # BossCog.getGearFrisbee. Directed attacks and strafes throw these.
    gear = load("phase_9/models/char/gearProp.bam")
    root = NodePath("Gear")
    gear.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT.parent / "gear.glb"
    dest.write_bytes(writer.pack("Gear"))
    print("wrote", dest, "meshes", writer.mesh_count, "bytes", dest.stat().st_size)


CLIPS = (
    "Fb_neutral",
    "Ff_speech",
    "ltTurn2Wave",
    "wave",
    "Ff_lookRt",
    "turn2Fb",
    "Fb_UpThrow",
    "Fb_firstHit",
    "Fb_downHit",
    "Fb_downNeutral",
    "Fb_jump",
    "Fb_fall",
    "Bb2Ff_spin",
    "Fb_downLtSwing",
    "Fb_downRtSwing",
)


def _assemble() -> tuple:
    # Same build as the standing glb, before the skin is baked, so each frame
    # starts from the bind pose.
    legs = load("phase_9/models/char/bossCog-legs-zero.bam")
    torso = load("phase_9/models/char/sellbotBoss-torso-zero.bam")
    head = load("phase_9/models/char/sellbotBoss-head-zero.bam")
    treads = load("phase_9/models/char/bossCog-treads.bam")
    pelvis = legs.find("**/joint_pelvis")
    neck = torso.find("**/joint34")
    axle = legs.find("**/joint_axle")
    if pelvis.isEmpty() or neck.isEmpty() or axle.isEmpty():
        raise RuntimeError("missing pelvis, joint34, or axle")
    torso.reparentTo(pelvis)
    head.reparentTo(neck)
    treads.reparentTo(axle)
    legs.setH(180)
    _hinge(legs, "joint_doorFront", "DoorFront", (0, 0, -80))
    _hinge(legs, "joint_doorRear", "DoorRear", (0, 0, 80))
    root = NodePath("SellbotVP")
    legs.reparentTo(root)
    return root, legs, torso, head


def _own_character(part: NodePath) -> NodePath:
    # The torso is under the pelvis and the head is under the neck, so a
    # search from the legs would bind the wrong character.
    from panda3d.core import Character

    if part.node().isOfType(Character.getClassType()):
        return part
    for child in part.getChildren():
        if child.node().isOfType(Character.getClassType()):
            return child
    found = part.find("+Character")
    if found.isEmpty():
        found = part.find("**/+Character")
    return found


def _bind_part(part: NodePath, part_name: str, clip: str):
    anim = load(f"phase_9/models/char/bossCog-{part_name}-{clip}.bam")
    toon_export._KEEP.append(anim)
    bundle = anim.find("**/+AnimBundleNode")
    character = _own_character(part)
    if bundle.isEmpty() or character.isEmpty():
        raise RuntimeError("no character for " + clip)
    control = character.node().getBundle(0).bindAnim(bundle.node().getBundle(), -1)
    character.node().getBundle(0).setControlEffect(control, 1.0)
    return control, character.node().getBundle(0)


def _pose_controls(controls, bundles, frame: int) -> None:
    for control, bundle in zip(controls, bundles):
        bundle.setControlEffect(control, 1.0)
        # The down-hit legs bundle is one frame. Hold it while the body plays.
        control.pose(min(frame, max(control.getNumFrames() - 1, 0)))
        bundle.forceUpdate()


def _apply_motion(paths, binds, root: NodePath) -> None:
    # Rigid pieces (the head, the gears, the treads) move because their joint
    # moves. The glb keeps the neutral joint, so that motion is baked into the
    # vertices. Panda applies the right-hand matrix first.
    from panda3d.core import GeomVertexReader, GeomVertexRewriter, Mat4

    for path, bind in zip(paths, binds):
        now = path.getTransform(root).getMat()
        inverse = Mat4(bind)
        if not inverse.invertInPlace():
            continue
        delta = now * inverse
        node = path.node()
        for index in range(node.getNumGeoms()):
            vdata = node.modifyGeom(index).modifyVertexData()
            count = vdata.getNumRows()
            if count == 0:
                continue
            reader = GeomVertexReader(vdata, "vertex")
            points = []
            for row in range(count):
                reader.setRow(row)
                points.append(delta.xformPoint(reader.getData3()))
            writer = GeomVertexRewriter(vdata, "vertex")
            for row, point in enumerate(points):
                writer.setRow(row)
                writer.setData3(point)


def probe() -> None:
    root, legs, torso, head = _assemble()
    print("--- geoms ---", flush=True)
    for path in root.findAllMatches("**/+GeomNode"):
        node = path.node()
        skinned = False
        rows = 0
        for index in range(node.getNumGeoms()):
            table = node.getGeom(index).getVertexData().getTransformBlendTable()
            rows += node.getGeom(index).getVertexData().getNumRows()
            skinned = skinned or table is not None
        parent = path.getParent().getName()
        print(f"{path.getName()} parent={parent} skinned={skinned} rows={rows}", flush=True)
    parts = (("legs", legs), ("torso", torso), ("head", head))
    controls = []
    bundles = []
    for part_name, part in parts:
        control, bundle = _bind_part(part, part_name, "Fb_jump")
        controls.append(control)
        bundles.append(bundle)
    print("jump frames", [control.getNumFrames() for control in controls], "rate", controls[0].getFrameRate(), flush=True)

    def place(frame: int) -> None:
        for control, bundle in zip(controls, bundles):
            bundle.setControlEffect(control, 1.0)
            control.pose(frame)
            bundle.forceUpdate()

    place(0)
    pelvis = legs.find("**/joint_pelvis")
    axle = legs.find("**/joint_axle")
    neck = torso.find("**/joint34")
    bind = {
        "pelvis": pelvis.getTransform(root).getMat(),
        "axle": axle.getTransform(root).getMat(),
        "neck": neck.getTransform(root).getMat(),
        "torso": torso.getTransform(root).getMat(),
        "head": head.getTransform(root).getMat(),
    }
    place(controls[0].getNumFrames() // 2)
    for name, node in (("pelvis", pelvis), ("axle", axle), ("neck", neck), ("torso", torso), ("head", head)):
        now = node.getTransform(root).getPos()
        was = bind[name].getRow3(3)
        print(name, "delta", (now - was), flush=True)
    from panda3d.core import GeomVertexReader, Mat4

    place(0)
    head_geom = None
    for path in root.findAllMatches("**/+GeomNode"):
        if path.getParent().getName() == "joint35":
            head_geom = path
            break
    neutral = head_geom.getTransform(root).getMat()
    reader = GeomVertexReader(head_geom.node().getGeom(0).getVertexData(), "vertex")
    reader.setRow(0)
    point = reader.getData3()
    place(controls[0].getNumFrames() // 2)
    posed = head_geom.getTransform(root).getMat()
    target = posed.xformPoint(point)
    for label, delta in (
        ("inv_now", Mat4(neutral) if False else None),
    ):
        pass
    left = Mat4(neutral)
    left.invertInPlace()
    candidate_a = (left * posed).xformPoint(point)
    candidate_b = (posed * left).xformPoint(point)
    shown_a = neutral.xformPoint(candidate_a)
    shown_b = neutral.xformPoint(candidate_b)
    print("target", target, flush=True)
    print("shown A", shown_a, "err", (shown_a - target).length(), flush=True)
    print("shown B", shown_b, "err", (shown_b - target).length(), flush=True)


def export_clips() -> None:
    import json

    from export_toon_walk import collect_named, restore, snapshot, write_walk

    root, legs, torso, head = _assemble()
    saved = snapshot(root)
    parts = (("legs", legs), ("torso", torso), ("head", head))
    neutral_controls = []
    neutral_bundles = []
    for part_name, part in parts:
        control, bundle = _bind_part(part, part_name, "Fb_neutral")
        neutral_controls.append(control)
        neutral_bundles.append(bundle)
    _pose_controls(neutral_controls, neutral_bundles, 0)
    found = root.findAllMatches("**/+GeomNode")
    paths = [found.getPath(index) for index in range(found.getNumPaths())]
    binds = [path.getTransform(root).getMat() for path in paths]
    for control, bundle in zip(neutral_controls, neutral_bundles):
        bundle.setControlEffect(control, 0.0)
    dest_dir = OUT.parent / "anims"
    dest_dir.mkdir(parents=True, exist_ok=True)
    timing = {}
    sidecar = dest_dir / "clips.json"
    if sidecar.exists():
        timing = json.loads(sidecar.read_text(encoding="utf-8"))
    for clip in CLIPS:
        path = dest_dir / f"{clip}.walk"
        if path.exists() and path.stat().st_size > 0 and clip in timing:
            print("keep", clip, flush=True)
            continue
        controls = []
        bundles = []
        for part_name, part in parts:
            control, bundle = _bind_part(part, part_name, clip)
            controls.append(control)
            bundles.append(bundle)
        frame_count = max(control.getNumFrames() for control in controls)
        rate = float(controls[0].getFrameRate() or 24.0)
        stride = 1
        if frame_count > 72:
            stride = max(1, (frame_count + 71) // 72)
        frames = list(range(0, frame_count, stride))
        if frames[-1] != frame_count - 1:
            frames.append(frame_count - 1)
        print(f"bake {clip} source={frame_count} kept={len(frames)}", flush=True)
        walked = []
        for frame in frames:
            restore(root, saved)
            _pose_controls(controls, bundles, frame)
            toon_export.bake_skinning(root)
            _apply_motion(paths, binds, root)
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
        print(f"wrote {clip} frames={len(frames)} stride={stride} bytes={path.stat().st_size}", flush=True)
        for control, bundle in zip(controls, bundles):
            bundle.setControlEffect(control, 0.0)
    (dest_dir / "clips.json").write_text(json.dumps(timing), encoding="utf-8")
    print("wrote", dest_dir / "clips.json", flush=True)


def export_tank() -> None:
    # DistributedBarrelBase loads phase_4 gagTank. Storm Sellbot stands these
    # in the VP room, still in panda axes like the rest of that room.
    tank = load("phase_4/models/cogHQ/gagTank.bam")
    root = NodePath("GagTank")
    tank.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT.parent / "gag_tank.glb"
    dest.write_bytes(writer.pack("GagTank"))
    print("wrote", dest, "meshes", writer.mesh_count, "bytes", dest.stat().st_size)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "tank":
        export_tank()
    elif len(sys.argv) > 1 and sys.argv[1] == "clips":
        export_clips()
    elif len(sys.argv) > 1 and sys.argv[1] == "probe":
        probe()
    else:
        main()
