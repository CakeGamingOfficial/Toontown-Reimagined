"""Bake Mickey for the tutorial_mickey entrance.

phase_3 mickey-1200 plus the run, wait, and point clips. Vertices are baked
the same way as the Flunky walk sidecar so Godot can play him without skinning.
Ears stay on sphere3, which the toontorial billboards toward the camera.
"""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

os.add_dll_directory = lambda _path: None
stub = types.ModuleType("panda3d.toontown")
stub.DNAStorage = object
stub.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = stub
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import NodePath, loadPrcFileData, getModelPath

import export_make_a_toon as toon_export
import export_toon_walk as walk_export
import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "chars"
MODEL = "phase_3/models/char/mickey-1200.bam"
CLIPS = (
    ("wait", "phase_3/models/char/mickey-wait.bam"),
    ("run", "phase_3/models/char/mickey-run.bam"),
    ("left-start", "phase_3.5/models/char/mickey-left-start.bam"),
    ("left", "phase_3.5/models/char/mickey-left.bam"),
    ("right-start", "phase_3.5/models/char/mickey-right-start.bam"),
    ("right", "phase_3.5/models/char/mickey-right.bam"),
)
JOINTS = ("sphere3__billboard", "joint_pupilL", "joint_pupilR")


def name_parts(model: NodePath) -> None:
    for path in model.findAllMatches("**/+GeomNode"):
        parent = path.getParent().getName()
        if path.getName() == "eyes":
            continue
        if parent == "joint_pupilL":
            path.setName("pupilL")
        elif parent == "joint_pupilR":
            path.setName("pupilR")
        elif "sphere3" in parent:
            path.setName("ears")
        elif path.getName() == "":
            path.setName("mickey_mesh")
    ears = model.find("**/sphere3")
    if ears.isEmpty():
        raise RuntimeError("mickey has no sphere3 ears")
    ears.setName("sphere3__billboard")


def bake_clip(model, saved, relative: str, controls: list):
    control = walk_export.bind_anim(model, relative)
    controls.append(control)
    frame_count = control.getNumFrames()
    character = model.find("**/+Character")
    bundle = character.node().getBundle(0)
    for other in controls:
        bundle.setControlEffect(other, 1.0 if other == control else 0.0)
    posed = []
    joint_frames = {name: [] for name in JOINTS}
    present = [name for name in JOINTS if not model.find("**/" + name).isEmpty()]
    for frame in range(frame_count):
        walk_export.restore(model, saved)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        toon_export.bake_skinning(model)
        posed.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, tuple(present)):
            joint_frames[joint_name].append(matrix)
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(control, 1.0)
    control.pose(0)
    bundle.forceUpdate()
    bind = {}
    for joint_name, matrix in walk_export.joint_matrices(model, tuple(present)):
        bind[joint_name] = matrix
    if not posed or not posed[0]:
        raise RuntimeError(relative + " produced no surfaces")
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(posed[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for frame in posed:
                _name, frame_surfaces = frame[node_index]
                posed_points, _uv = frame_surfaces[surface_index]
                frames.append(posed_points)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    joints = [(name, bind[name], joint_frames[name]) for name in present]
    return frame_count, nodes, joints


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    model = toon_export.load_model(MODEL)
    if model is None:
        raise RuntimeError("missing " + MODEL)
    name_parts(model)
    saved = walk_export.snapshot(model)
    wait = walk_export.bind_anim(model, CLIPS[0][1])
    character = model.find("**/+Character")
    bundle = character.node().getBundle(0)
    bundle.setControlEffect(wait, 1.0)
    wait.pose(0)
    bundle.forceUpdate()
    toon_export.bake_skinning(model)
    holder = NodePath("Mickey")
    holder.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(holder)
    writer = exporter.GltfWriter()
    writer.add_node(holder, None)
    OUT.mkdir(parents=True, exist_ok=True)
    glb = OUT / "mickey.glb"
    glb.write_bytes(writer.pack("Mickey"))
    print(f"wrote {glb.name} meshes={writer.mesh_count}", flush=True)
    model.detachNode()
    walk_export.restore(model, saved)
    controls = [wait]
    for clip_name, relative in CLIPS:
        frame_count, nodes, joints = bake_clip(model, saved, relative, controls)
        path = OUT / f"mickey.{clip_name}"
        walk_export.write_walk(path, frame_count, nodes, joints)
        print(
            f"wrote {path.name} frames={frame_count} nodes={len(nodes)} joints={len(joints)} bytes={path.stat().st_size}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
