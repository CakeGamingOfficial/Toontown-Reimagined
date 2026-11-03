"""Export the five fishing poles, the bob, and the splash sounds."""
from __future__ import annotations

import shutil
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT / "assets" / "props"
SFX = ROOT / "assets" / "audio" / "sfx"
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")

MODELS = [
    ("phase_4/models/props/pole_treebranch-mod.bam", "fishing_pole.glb", "FishingPole"),
    ("phase_4/models/props/pole_bamboo-mod.bam", "fishing_pole_bamboo.glb", "FishingPoleBamboo"),
    ("phase_4/models/props/pole_wood-mod.bam", "fishing_pole_wood.glb", "FishingPoleWood"),
    ("phase_4/models/props/pole_steel-mod.bam", "fishing_pole_steel.glb", "FishingPoleSteel"),
    ("phase_4/models/props/pole_gold-mod.bam", "fishing_pole_gold.glb", "FishingPoleGold"),
    ("phase_4/models/props/fishing_bob.bam", "fishing_bob.glb", "FishingBob"),
]
RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")


def load_prop(relative: str):
    model = idle.load_model(relative)
    if model is not None:
        return model
    path = RESOURCES / relative
    node = idle.Loader.getGlobalPtr().loadSync(idle.Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path)
        return None
    return idle.NodePath(node)


def export_models() -> None:
    PROPS.mkdir(parents=True, exist_ok=True)
    for relative, filename, title in MODELS:
        model = load_prop(relative)
        if model is None:
            continue
        writer = exporter.GltfWriter()
        writer.add_node(model, None)
        path = PROPS / filename
        path.write_bytes(writer.pack(title))
        print(f"{filename} meshes={writer.mesh_count} bytes={path.stat().st_size}", flush=True)


def copy_audio() -> None:
    SFX.mkdir(parents=True, exist_ok=True)
    for name in ("TT_splash1.ogg", "TT_splash2.ogg"):
        source = SOURCE / "phase_4" / "audio" / "sfx" / name
        dest = SFX / name
        shutil.copyfile(source, dest)
        print("audio", dest.name, dest.stat().st_size, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(str(SOURCE))
    getModelPath().prependDirectory(idle.ASSETS)
    export_models()
    copy_audio()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
