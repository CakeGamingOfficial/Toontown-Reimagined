"""Export the 500 and 250 toon parts from Toon.setLODs.

1000 stays the close model. 500 is the model from 20 to 80 feet, and 250 is
the model from 80 to 280. The animation bams are the same files the 1000
parts already play. Dog muzzles exist for 500; the 250 head includes its own.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

import types

from panda3d.core import getModelPath, loadPrcFileData

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

sys.path.insert(0, str(Path(__file__).resolve().parent))

import export_make_a_toon as toon_export
import export_toon_idle as idle


HEADS = [
    "dls", "dss", "dsl", "dll",
    "cls", "css", "csl", "cll",
    "hls", "hss", "hsl", "hll",
    "mls", "mss",
    "rls", "rss", "rsl", "rll",
    "fls", "fss", "fsl", "fll",
    "pls", "pss", "psl", "pll",
    "bls", "bss", "bsl", "bll",
    "sls", "sss", "ssl", "sll",
]

DOG_HEADS = {
    "dls": "tt_a_chr_dgm_shorts_head",
    "dss": "tt_a_chr_dgm_skirt_head",
    "dsl": "tt_a_chr_dgs_shorts_head",
    "dll": "tt_a_chr_dgl_shorts_head",
}

BODY = (
    ("legs_{size}_{lod}", "tt_a_chr_{code}_shorts_legs_{lod}.bam"),
    ("torso_{size}s_{lod}", "tt_a_chr_{code}_shorts_torso_{lod}.bam"),
    ("torso_{size}d_{lod}", "tt_a_chr_{code}_skirt_torso_{lod}.bam"),
)

CLIPS = (
    ("walk", "phase_3.5", "_walk.bam"),
    ("run", "phase_3", "_run.bam"),
    ("idle", "phase_3", "_neutral.bam"),
    ("sad-neutral", "phase_4", "_sad-neutral.bam"),
    ("sad-walk", "phase_4", "_losewalk.bam"),
    ("jump", "phase_3.5", "_jump-zhang.bam"),
    ("rjump", "phase_3.5", "_leap_zhang.bam"),
    ("land", "phase_3.5", "_jump-zend.bam"),
    ("rland", "phase_3.5", "_leap_zend.bam"),
)

EAR_CLIPS = (
    ("idle", "phase_3", "_neutral.bam"),
    ("run", "phase_3", "_run.bam"),
    ("walk", "phase_3.5", "_walk.bam"),
    ("jump", "phase_3.5", "_jump-zhang.bam"),
    ("rjump", "phase_3.5", "_leap_zhang.bam"),
    ("land", "phase_3.5", "_jump-zend.bam"),
    ("rland", "phase_3.5", "_leap_zend.bam"),
)


def anim_for(model_file: str, phase: str, ending: str) -> str:
    stem = model_file
    for token in ("_500.bam", "_250.bam", "_1000.bam"):
        if stem.endswith(token):
            stem = stem[: -len(token)]
            break
    return f"{phase}/models/char/{stem}{ending}"


def export_models() -> None:
    for size, code in (("s", "dgs"), ("m", "dgm"), ("l", "dgl")):
        for lod in ("500", "250"):
            for name_fmt, file_fmt in BODY:
                model_file = file_fmt.format(code=code, lod=lod)
                toon_export.export_part(
                    name_fmt.format(size=size, lod=lod),
                    f"phase_3/models/char/{model_file}",
                    anim_for(model_file, "phase_3", "_neutral.bam"),
                )
    for lod in ("500", "250"):
        for head in HEADS:
            toon_export.export_head(head, lod)


def export_body_clips() -> None:
    for size, code in (("s", "dgs"), ("m", "dgm"), ("l", "dgl")):
        for lod in ("500", "250"):
            for name_fmt, file_fmt in BODY:
                model_file = file_fmt.format(code=code, lod=lod)
                name = name_fmt.format(size=size, lod=lod)
                model = f"phase_3/models/char/{model_file}"
                for suffix, phase, ending in CLIPS:
                    try:
                        idle.export_part(name, model, anim_for(model_file, phase, ending), suffix)
                    except Exception as error:
                        print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    for code, prefix in DOG_HEADS.items():
        for lod in ("500", "250"):
            for suffix, phase, ending in EAR_CLIPS:
                model = f"phase_3/models/char/{prefix}_{lod}.bam"
                anim = f"{phase}/models/char/{prefix}{ending}"
                try:
                    _write_ears(f"{code}_{lod}", model, anim, suffix)
                except Exception as error:
                    print("skip", code, lod, suffix, error, flush=True)


def _write_ears(name: str, model: str, anim: str, suffix: str) -> None:
    root = idle.load_model(model)
    if root is None:
        raise RuntimeError("missing " + model)
    saved = idle.snapshot(root)
    control, rate = idle.bind_anim(root, anim)
    frame_count = control.getNumFrames()
    posed_frames = []
    for frame in range(frame_count):
        posed = idle.posed_surfaces(root, saved, control, frame)
        posed_frames.append([(node, surfaces) for node, surfaces in posed if node == "ears"])
    if not posed_frames or not posed_frames[0]:
        raise RuntimeError(name + " " + suffix + " has no ears")
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
    path = idle.OUT / f"{name}.{suffix}"
    idle.write_clip(path, frame_count, nodes, [])
    print(
        f"wrote {name}.{suffix} frames={frame_count} rate={rate:.1f} bytes={path.stat().st_size}",
        flush=True,
    )


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    if which in ("", "models"):
        export_models()
    if which in ("", "anims"):
        export_body_clips()
        export_ears()
    return 0


if __name__ == "__main__":
    sys.exit(main())
