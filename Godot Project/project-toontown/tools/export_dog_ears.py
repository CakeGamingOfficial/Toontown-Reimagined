"""Bake the original dog-head ear cycles.

Only dogs have head animation. The ears are skinned to def_*_ear joints, so a
standing head is stiff until those frames play. Neutral is the idle flop.
Run, walk, and the jump clips are the same files the body already uses.
"""

from __future__ import annotations

import sys

from panda3d.core import getModelPath, loadPrcFileData

import export_toon_idle as idle


HEADS = {
    "dls": "tt_a_chr_dgm_shorts_head",
    "dss": "tt_a_chr_dgm_skirt_head",
    "dsl": "tt_a_chr_dgs_shorts_head",
    "dll": "tt_a_chr_dgl_shorts_head",
}

JOBS = [
    ("idle", "phase_3", "_neutral.bam"),
    ("run", "phase_3", "_run.bam"),
    ("walk", "phase_3.5", "_walk.bam"),
    ("jump", "phase_3.5", "_jump-zhang.bam"),
    ("rjump", "phase_3.5", "_leap_zhang.bam"),
    ("land", "phase_3.5", "_jump-zend.bam"),
    ("rland", "phase_3.5", "_leap_zend.bam"),
]


def export_ears(code: str, prefix: str, suffix: str, phase: str, ending: str) -> None:
    model = f"phase_3/models/char/{prefix}_1000.bam"
    anim = f"{phase}/models/char/{prefix}{ending}"
    root = idle.load_model(model)
    if root is None:
        raise RuntimeError("missing " + model)
    saved = idle.snapshot(root)
    control, rate = idle.bind_anim(root, anim)
    frame_count = control.getNumFrames()
    posed_frames = []
    for frame in range(frame_count):
        posed = idle.posed_surfaces(root, saved, control, frame)
        posed_frames.append([(name, surfaces) for name, surfaces in posed if name == "ears"])
    if not posed_frames or not posed_frames[0]:
        raise RuntimeError(code + " " + suffix + " has no ears")
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(posed_frames[0]):
        packed = []
        for surface_index, (_base_pos, uvs) in enumerate(surfaces):
            frames = []
            for frame in posed_frames:
                _posed_name, frame_surfaces = frame[node_index]
                posed, _posed_uv = frame_surfaces[surface_index]
                frames.append(posed)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = idle.OUT / f"{code}.{suffix}"
    idle.write_clip(path, frame_count, nodes, [])
    first = nodes[0][1][0][1][0]
    mid = nodes[0][1][0][1][frame_count // 2]
    moved = max(abs(a - b) for a, b in zip(
        (sum(point[axis] for point in first) / len(first) for axis in range(3)),
        (sum(point[axis] for point in mid) / len(mid) for axis in range(3)),
    ))
    print(
        f"wrote {code}.{suffix} frames={frame_count} rate={rate:.1f} "
        f"verts={len(first)} drift={moved:.4f} bytes={path.stat().st_size}",
        flush=True,
    )


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for code, prefix in HEADS.items():
        if which not in ("", code):
            continue
        for suffix, phase, ending in JOBS:
            export_ears(code, prefix, suffix, phase, ending)
    return 0


if __name__ == "__main__":
    sys.exit(main())
