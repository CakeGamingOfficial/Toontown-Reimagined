"""Export phase_9 cogHQ_elevator for the Sellbot lobby locator.

The lobby glb already turns Z-up into Y-up on its root. This car stays in
panda axes so it can sit on elevator_locator and take setH(180) there.
"""
from __future__ import annotations

import os
import sys
import types
from pathlib import Path

PANDA = Path(r"C:\Panda3D-1.10.16-x64")
os.environ["PATH"] = str(PANDA / "bin") + os.pathsep + os.environ.get("PATH", "")
if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_toontown_central as exporter

RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
OUT = Path(__file__).resolve().parents[1] / "assets" / "cog_hq" / "cog_hq_elevator.glb"

loadPrcFileData("", "model-cache-dir")
getModelPath().prependDirectory(Filename.from_os_specific(str(RESOURCES)))


def main() -> None:
    loaded = Loader.getGlobalPtr().loadSync(
        Filename.from_os_specific(str(RESOURCES / "phase_9/models/cogHQ/cogHQ_elevator.bam"))
    )
    if loaded is None:
        raise RuntimeError("missing cogHQ_elevator.bam")
    model = NodePath(loaded)
    model.setName("cogHQ_elevator")
    for child in model.findAllMatches("**"):
        print(child.getName(), flush=True)
    root = NodePath("cogHQ_elevator")
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack("cogHQ_elevator")
    OUT.write_bytes(payload)
    print("wrote", OUT.name, len(payload), flush=True)


if __name__ == "__main__":
    main()
