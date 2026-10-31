"""Export the toon swing clip Jungle Vines plays. One-shot; safe to re-run."""
from __future__ import annotations

import os
import sys
from pathlib import Path

if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import getModelPath, loadPrcFileData

import export_battle as battle
import export_make_a_toon as toon_export
import export_toon_walk as walk_export

HEADS = {
    "dls": "phase_3/models/char/tt_a_chr_dgm_shorts_head_1000.bam",
    "dss": "phase_3/models/char/tt_a_chr_dgm_skirt_head_1000.bam",
    "dsl": "phase_3/models/char/tt_a_chr_dgs_shorts_head_1000.bam",
    "dll": "phase_3/models/char/tt_a_chr_dgl_shorts_head_1000.bam",
}


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(toon_export.ASSETS)
    for part, model, _neutral, _walk in walk_export.PARTS:
        battle.export_toon_anim(part, model, "swing", "phase_4", "swing")
    heads = walk_export.OUT.parent / "heads"
    walk_export.PARTS_DIR = heads
    for part, model in HEADS.items():
        battle.export_toon_anim(part, model, "swing", "phase_4", "swing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
