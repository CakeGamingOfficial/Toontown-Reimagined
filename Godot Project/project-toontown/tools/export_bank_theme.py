"""Export the original props the Toontown Bank interior dresses with.

The bank room itself stays the toon interior. These are the pieces that turn
that room into a bank: the estate jellybean machine, the drop-gag safe, and
the cashbot money bag, money stack, and cash register.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

import export_toontown_central as exporter

ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "interiors" / "bank" / "props"

PROPS = (
    ("phase_5.5/models/estate/jellybeanBank.bam", "teller.glb", "Teller"),
    ("phase_5/models/props/safe.bam", "vault_safe.glb", "VaultSafe"),
    ("phase_10/models/cashbotHQ/MoneyBag.bam", "money_bag.glb", "MoneyBag"),
    ("phase_10/models/cashbotHQ/MoneyStack.bam", "money_stack.glb", "MoneyStack"),
    ("phase_10/models/cashbotHQ/CashBotHQCshRegister.bam", "cash_register.glb", "CashRegister"),
)


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def hide_helpers(prop: NodePath) -> None:
    for child in prop.findAllMatches("**"):
        name = child.getName().lower()
        if "collision" in name or "trigger" in name or name.startswith("shadow"):
            child.hide()


def write_prop(relative: str, filename: str, scene_name: str) -> None:
    prop = load_model(relative)
    hide_helpers(prop)
    prop.setName(scene_name)
    root = NodePath(scene_name + "Root")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    prop.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(scene_name)
    dest = OUT_DIR / filename
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    print(f"wrote {filename} ({len(payload) / 1024:.0f} KB)", flush=True)


def main() -> None:
    getModelPath().prependDirectory(ASSETS)
    loadPrcFileData("", "model-cache-dir")
    for relative, filename, scene_name in PROPS:
        write_prop(relative, filename, scene_name)


if __name__ == "__main__":
    main()
