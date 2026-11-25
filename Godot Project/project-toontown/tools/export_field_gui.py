"""Export the field office memo card, boss panel, chat bubble, and cooler arrow."""
from __future__ import annotations

import sys
import types

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import getModelPath, loadPrcFileData

import export_minigames as games
import export_toon_idle as idle


OUT_NAME = "field_office"


def names(relative: str) -> None:
    model = games.load_model(relative)
    if model is None:
        return
    print("--", relative, flush=True)
    for node in model.findAllMatches("**"):
        if node.isEmpty():
            continue
        print(" ", node.getName(), flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(idle.ASSETS)
    games.OUT = games.ROOT / "assets" / "buildings" / OUT_NAME
    games.OUT.mkdir(parents=True, exist_ok=True)
    names("phase_5/models/cogdominium/tt_m_gui_csa_memo_card.bam")
    names("phase_5/models/cogdominium/tt_m_gui_cmg_bossCog.bam")
    names("phase_5/models/cogdominium/tt_m_gui_csa_flyThru.bam")
    names("phase_3.5/models/gui/matching_game_gui.bam")
    games.scene("field_memo_card", [("phase_5/models/cogdominium/tt_m_gui_csa_memo_card.bam",)])
    games.scene("field_boss_gui", [("phase_5/models/cogdominium/tt_m_gui_cmg_bossCog.bam",)])
    games.scene("field_flythru", [("phase_5/models/cogdominium/tt_m_gui_csa_flyThru.bam",)])
    games.extract("phase_3.5/models/gui/matching_game_gui.bam", "**/minnieArrow", "field_arrow")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
