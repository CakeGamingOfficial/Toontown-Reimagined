"""Export the trolley boarding clips.

DistributedTrolley.fillSlot plays sit-start (phase_4 intoSit) while the toon
drops into the seat, then loops sit. Legs and torsos are the body. Only dogs
have a head clip, and that clip is the ears.
"""
from __future__ import annotations

import sys
import types

# Stock Panda has no toontown DNA module. The clip bake does not need it.
_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, getModelPath, loadPrcFileData

import export_dog_ears as ears
import export_toon_idle as idle


JOBS = (
    ("sit-start", "phase_4", "_intoSit.bam"),
    ("sit", "phase_4", "_sit.bam"),
)


def export_bodies() -> None:
    for name, model, _neutral in idle.PARTS:
        for suffix, phase, ending in JOBS:
            try:
                idle.export_part(name, model, idle.anim_path(model, phase, ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def export_ears() -> None:
    for code, prefix in ears.HEADS.items():
        for suffix, phase, ending in JOBS:
            try:
                ears.export_ears(code, prefix, suffix, phase, ending)
            except RuntimeError as error:
                print("skip", code, suffix, error, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(
        r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
    )
    getModelPath().prependDirectory(idle.ASSETS)
    export_bodies()
    export_ears()
    return 0


if __name__ == "__main__":
    sys.exit(main())
