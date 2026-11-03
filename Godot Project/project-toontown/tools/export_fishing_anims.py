"""Bake the fishing clips the toon plays on a shore spot.

Toon.AnimDict maps cast, castlong, pole, pole-neutral, fish-neutral, reel,
reel-neutral, fish-again, and fish-end onto the phase_4 files. The pole is
parented to the right hand, so torso clips keep that joint the way the
jellybean jar clip does. Dog ears use the matching head file.
"""
from __future__ import annotations

import sys
import types

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import getModelPath, loadPrcFileData

import export_dog_ears as ears
import export_toon_idle as idle


JOBS = [
    ("cast", "phase_4", "_cast.bam"),
    ("castlong", "phase_4", "_castlong.bam"),
    ("pole", "phase_4", "_pole.bam"),
    ("pole-neutral", "phase_4", "_poleneutral.bam"),
    ("fish-neutral", "phase_4", "_fishneutral.bam"),
    ("reel", "phase_4", "_reel.bam"),
    ("reel-neutral", "phase_4", "_reelneutral.bam"),
    ("fish-again", "phase_4", "_fishAGAIN.bam"),
    ("fish-end", "phase_4", "_fishEND.bam"),
]


def _joints(part: str) -> tuple[str, ...]:
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head", "def_joint_right_hold")


def export_bodies() -> None:
    idle.joint_names = _joints
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, model, _neutral in idle.PARTS:
        for suffix, phase, ending in JOBS:
            if which not in ("", suffix):
                continue
            try:
                idle.export_part(name, model, idle.anim_path(model, phase, ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for code, prefix in ears.HEADS.items():
        for suffix, phase, ending in JOBS:
            if which not in ("", suffix):
                continue
            try:
                ears.export_ears(code, prefix, suffix, phase, ending)
            except RuntimeError as error:
                print("skip", code, suffix, error, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    export_bodies()
    export_ears()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
