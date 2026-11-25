"""Export the Tug-of-War clip.

Toons hold frame 3 until they pull, then loop phase_4 tug-o-war. The cog
loops the same clip. The right-hand joint is baked with the torso so the
rope stays in the hand.
"""
from __future__ import annotations

import sys
import types

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from pathlib import Path

from panda3d.core import Filename, getModelPath, loadPrcFileData

import export_battle as battle
import export_dog_ears as ears
import export_make_a_toon as toon_export
import export_toon_idle as idle
import export_toon_walk as walk_export


_BODY_JOINTS = idle.joint_names


def joint_names(part: str) -> tuple[str, ...]:
    names = _BODY_JOINTS(part)
    if part.startswith("torso_"):
        return names + ("def_joint_right_hold",)
    return names


CLIPS = (
    ("tug-o-war", "_tug-o-war.bam"),
    ("slip-forward", "_slip-forward.bam"),
)

SUITS = (
    ("a", "phase_3.5/models/char/suitA-mod.bam", "phase_4/models/char/suitA-neutral.bam"),
    ("b", "phase_3.5/models/char/suitB-mod.bam", "phase_4/models/char/suitB-neutral.bam"),
    ("c", "phase_3.5/models/char/suitC-mod.bam", "phase_3.5/models/char/suitC-neutral.bam"),
)

SUIT_JOINTS = ("joint_head", "joint_attachMeter", "joint_Rhold", "joint_Lhold")


def export_bodies() -> None:
    idle.joint_names = joint_names
    for name, model, _neutral in idle.PARTS:
        for suffix, ending in CLIPS:
            try:
                idle.export_part(name, model, idle.anim_path(model, "phase_4", ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    for code, prefix in ears.HEADS.items():
        for suffix, ending in CLIPS:
            try:
                ears.export_ears(code, prefix, suffix, "phase_4", ending)
            except RuntimeError as error:
                print("skip", code, suffix, error, flush=True)


def export_suit_clip(body: str, model: str, neutral_file: str, anim_file: str, dest: Path) -> None:
    root = idle.load_model(model)
    if root is None:
        print("skip", body, model, flush=True)
        return
    saved = walk_export.snapshot(root)
    neutral = walk_export.bind_anim(root, neutral_file)
    control = walk_export.bind_anim(root, anim_file)
    names = tuple(name for name in SUIT_JOINTS if not root.find("**/" + name).isEmpty())
    frame_count = control.getNumFrames()
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        walk_export.restore(root, saved)
        bundle = root.find("**/+Character").node().getBundle(0)
        bundle.setControlEffect(neutral, 0.0)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        toon_export.bake_skinning(root)
        walked.append(walk_export.collect_named(root))
        for joint_name, matrix in walk_export.joint_matrices(root, names):
            joint_frames[joint_name].append(matrix)
    walk_export.restore(root, saved)
    bundle = root.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(control, 0.0)
    bundle.setControlEffect(neutral, 1.0)
    neutral.pose(0)
    bundle.forceUpdate()
    bind = {}
    for joint_name, matrix in walk_export.joint_matrices(root, names):
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
    dest.parent.mkdir(parents=True, exist_ok=True)
    walk_export.write_walk(
        dest,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print(f"suit {dest.name} frames={frame_count} bytes={dest.stat().st_size}", flush=True)


def export_suits() -> None:
    root = idle.OUT.parents[1] / "cogs" / "anims"
    for body, model, neutral_file in SUITS:
        for suffix in ("tug-o-war", "slip-forward"):
            anim = f"phase_4/models/char/suit{body.upper()}-{suffix}.bam"
            dest = root / body / f"{suffix}.walk"
            try:
                export_suit_clip(body, model, neutral_file, anim, dest)
            except RuntimeError as error:
                print("skip", body, suffix, error, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    export_bodies()
    export_ears()
    export_suits()
    battle.export_cog_anim("tug-o-war", "phase_4/models/char/suitC-tug-o-war.bam")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
