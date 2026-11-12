"""Export suitA/B/C lose-mod, the model Suit.getLoseActor swaps in on death."""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

import export_battle as battle
import export_make_a_toon as toon_export
import export_toon_walk as walk_export
import export_toontown_central as exporter

ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cogs" / "lose"

# phase models. The scale stays 1 here. The live suit's egg node carries the
# cog's generateSuit scale, and the death actor copies that.
BODIES = (
    ("a", "phase_4/models/char/suitA-lose-mod.bam", "phase_4/models/char/suitA-lose.bam"),
    ("b", "phase_4/models/char/suitB-lose-mod.bam", "phase_4/models/char/suitB-lose.bam"),
    ("c", "phase_3.5/models/char/suitC-lose-mod.bam", "phase_3.5/models/char/suitC-lose.bam"),
    # Suit.getLoseActor when isSkeleton. The lose clip is the body's own lose.
    ("robot_a", "phase_5/models/char/cogA_robot-lose-mod.bam", "phase_4/models/char/suitA-lose.bam"),
    ("robot_b", "phase_5/models/char/cogB_robot-lose-mod.bam", "phase_4/models/char/suitB-lose.bam"),
    ("robot_c", "phase_5/models/char/cogC_robot-lose-mod.bam", "phase_3.5/models/char/suitC-lose.bam"),
)


def _name_pieces(model) -> None:
    index = 0
    for path in model.findAllMatches("**/+GeomNode"):
        if path.getName() != "":
            continue
        index += 1
        path.setName("pieces" if index == 1 else "pieces%d" % index)


def export_body(body: str, model_file: str, anim_file: str) -> None:
    model = toon_export.load_model(model_file)
    if model is None:
        raise RuntimeError("missing " + model_file)
    _name_pieces(model)
    saved = walk_export.snapshot(model)
    control = walk_export.bind_anim(model, anim_file)
    battle._pose_control(model, saved, control, 0)
    root = NodePath("lose" + body)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    OUT.mkdir(parents=True, exist_ok=True)
    glb = OUT / ("%s.glb" % body)
    glb.write_bytes(writer.pack("lose" + body))
    print("wrote", glb.name, "meshes", writer.mesh_count, flush=True)
    model.detachNode()
    names = []
    for joint_name in ("joint_head", "joint_attachMeter"):
        if not model.find("**/" + joint_name).isEmpty():
            names.append(joint_name)
    frame_count = control.getNumFrames()
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        battle._pose_control(model, saved, control, frame)
        walked.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, names):
            joint_frames[joint_name].append(matrix)
    battle._pose_control(model, saved, control, 0)
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
    path = OUT / ("%s.lose" % body)
    walk_export.write_walk(
        path,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print("clip", path.name, "frames", frame_count, "bytes", path.stat().st_size, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    loadPrcFileData("", "model-cache-dir")
    asset_root = Filename.from_os_specific(str(ASSETS))
    toon_export.ASSETS = asset_root
    getModelPath().prependDirectory(asset_root)
    for body, model_file, anim_file in BODIES:
        export_body(body, model_file, anim_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
