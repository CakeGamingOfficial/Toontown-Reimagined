"""Export the party activity models placed on the party grounds grid."""
from __future__ import annotations

import sys
from pathlib import Path

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

from export_neighborhoods import ASSETS, ROOT
from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP, panda_path

OUT = ROOT / "assets" / "parties"
MODELS = {
    "clock": "phase_13/models/parties/partyClock.bam",
    "cannon": "phase_4/models/minigames/toon_cannon.bam",
    "trampoline": "phase_13/models/parties/trampoline_model.bam",
    "jukebox": "phase_13/models/parties/jukebox_model.bam",
    "dance": "phase_13/models/parties/danceFloor.bam",
    "tug": "phase_13/models/parties/partyTugOfWar.bam",
    "catch": "phase_13/models/parties/partyCatchTree.bam",
    "cog": "phase_13/models/parties/cogPieArena_model.bam",
}


def write_model(name: str, model: NodePath) -> None:
    root = NodePath(name)
    root.setMat(Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(name)
    dest = OUT / f"{name}.glb"
    dest.write_bytes(payload)
    print(f"wrote {dest} ({len(payload) / 1024:.0f} KB)", flush=True)
    root.removeNode()


def fireworks(loader: Loader) -> None:
    pad = NodePath(loader.loadSync(panda_path("phase_13/models/parties/launchPad.bam")))
    # DistributedPartyFireworksActivity places the pad under the activity root.
    pad.setH(90.0)
    pad.setPos(0.0, -18.0, 0.0)
    rocket_loaded = loader.loadSync(panda_path("phase_13/models/parties/rocket_model.bam"))
    if rocket_loaded is not None:
        rocket = NodePath(rocket_loaded)
        locator = pad.find("**/rocket_locator")
        rocket.reparentTo(locator if not locator.isEmpty() else pad)
    write_model("fireworks", pad)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT.mkdir(parents=True, exist_ok=True)
    loader = Loader.getGlobalPtr()
    failed = []
    for name, relative in MODELS.items():
        loaded = loader.loadSync(panda_path(relative))
        if loaded is None:
            failed.append(relative)
            print("missing", relative, flush=True)
            continue
        write_model(name, NodePath(loaded))
    fireworks(loader)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
