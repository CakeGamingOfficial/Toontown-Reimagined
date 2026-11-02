"""Crop the street-battle cards from phase_3.5 battle_gui."""
from __future__ import annotations

import os
import sys
from pathlib import Path

BIN = r"C:\Panda3D-1.10.16-x64\bin"
os.environ["PATH"] = BIN + os.pathsep + os.environ.get("PATH", "")

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData  # noqa: E402

import export_friends_gui as cards

ASSETS = cards.ASSETS
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "battle"
NAMES = (
    "ToonBtl_Status_BG",
    "tt_t_gui_bat_pass",
    "Waiting4Others",
    "BtlPick_TAB",
    "PckMn_Select_Tab",
    "PckMn_Arrow_Up",
    "PckMn_Arrow_Dn",
    "PckMn_Arrow_Rlvr",
    "PckMn_BackBtn",
    "PckMn_BackBtn_Dn",
    "PckMn_BackBtn_Rlvr",
)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, "phase_3.5/models/gui/battle_gui.bam"))
    if node is None:
        raise RuntimeError("missing battle_gui")
    model = NodePath(node)
    cards.OUT = OUT
    for name in NAMES:
        found = model.find("**/" + name)
        if found.isEmpty():
            print("missing", name)
            continue
        low, high = found.getTightBounds()
        print(
            "bounds %s %.4f %.4f %.4f  %.4f %.4f %.4f" % (
                name, low.x, low.y, low.z, high.x, high.y, high.z,
            ),
            flush=True,
        )
        cards.crop_card(found, OUT / ("%s.png" % name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
