"""Export the swim cycle.

Toon.enterSwim loops phase_4 swim and pitches the body flat. Treasure Dive
uses the same cycle (enterDive) and holds frame 55 while carrying a chest.
"""
from __future__ import annotations

import sys
import types

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, getModelPath, loadPrcFileData

import export_dog_ears as ears
import export_toon_idle as idle


def export_bodies() -> None:
    for name, model, _neutral in idle.PARTS:
        try:
            idle.export_part(name, model, idle.anim_path(model, "phase_4", "_swim.bam"), "swim")
        except RuntimeError as error:
            print("skip", name, error, flush=True)


def export_ears() -> None:
    for code, prefix in ears.HEADS.items():
        try:
            ears.export_ears(code, prefix, "swim", "phase_4", "_swim.bam")
        except RuntimeError as error:
            print("skip", code, error, flush=True)


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
    raise SystemExit(main())
