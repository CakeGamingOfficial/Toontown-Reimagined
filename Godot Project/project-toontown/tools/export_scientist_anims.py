"""Bake the scientist body clips Toon.enterScientist* loops.

Short and long bodies use scientistJealous, scientistWork, and scientistGame.
The medium body uses scientistEmcee. Species heads have no scientist clip.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import getModelPath, loadPrcFileData

import export_toon_idle as idle


JOBS = (
    ("legs_s", "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_legs_scientistJealous.bam", "scientistJealous"),
    ("legs_s", "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_legs_scientistWork.bam", "scientistWork"),
    ("legs_s", "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_legs_scientistGame.bam", "scientistGame"),
    ("torso_ss", "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_torso_scientistJealous.bam", "scientistJealous"),
    ("torso_ss", "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_torso_scientistWork.bam", "scientistWork"),
    ("torso_ss", "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgs_shorts_torso_scientistGame.bam", "scientistGame"),
    ("legs_l", "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_legs_scientistJealous.bam", "scientistJealous"),
    ("legs_l", "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_legs_scientistWork.bam", "scientistWork"),
    ("legs_l", "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_legs_scientistGame.bam", "scientistGame"),
    ("torso_ls", "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_torso_scientistJealous.bam", "scientistJealous"),
    ("torso_ls", "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_torso_scientistWork.bam", "scientistWork"),
    ("torso_ls", "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgl_shorts_torso_scientistGame.bam", "scientistGame"),
    ("legs_m", "phase_3/models/char/tt_a_chr_dgm_shorts_legs_1000.bam", "phase_4/models/char/tt_a_chr_dgm_shorts_legs_scientistEmcee.bam", "scientistEmcee"),
    ("torso_ms", "phase_3/models/char/tt_a_chr_dgm_shorts_torso_1000.bam", "phase_4/models/char/tt_a_chr_dgm_shorts_torso_scientistEmcee.bam", "scientistEmcee"),
)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    for name, model, anim, suffix in JOBS:
        idle.export_part(name, model, anim, suffix)
    return 0


if __name__ == "__main__":
    sys.exit(main())
