"""Export Chip 'n Dale's MiniGolf holes, ball, and putter from phase_6.

Panda is Z-up. The export root applies the same Y-up transform as the
playgrounds, and holes.json stores tees and the cup in that space.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, LPoint3f, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = ROOT / "assets" / "minigolf"
QUESTS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\golf\GolfGlobals.py")

PROPS = [
    "golf_ball.bam",
    "putter.bam",
    "windmill.bam",
    "golf_blocker.bam",
    "golf_geyser.bam",
]


def load_prop(relative: str) -> NodePath | None:
    idle.ASSETS = Filename.from_os_specific(str(SOURCE))
    return idle.load_model(relative)


def upright(model: NodePath, title: str) -> NodePath:
    root = NodePath(title)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    return root


def point(root: NodePath, node: NodePath) -> list[float]:
    pos = node.getPos(root)
    upright_pos = exporter.Z_UP_TO_Y_UP.xform(LPoint3f(pos))
    return [round(upright_pos.x, 4), round(upright_pos.y, 4), round(upright_pos.z, 4)]


def named(root: NodePath, pattern: str) -> list[list[float]]:
    found = []
    index = 0
    while True:
        node = root.find(f"**/{pattern}{index}")
        if node.isEmpty():
            break
        found.append(point(root, node))
        index += 1
    return found


def export_one(relative: str, filename: str, title: str) -> NodePath | None:
    model = load_prop(relative)
    if model is None:
        return None
    root = upright(model, title)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path = OUT / filename
    path.write_bytes(writer.pack(title))
    print(f"{filename} meshes={writer.mesh_count} bytes={path.stat().st_size}", flush=True)
    return root


def hole_records() -> dict[int, dict]:
    text = QUESTS.read_text(encoding="utf-8", errors="replace")
    body = text.split("HoleInfo = ", 1)[1]
    records: dict[int, dict] = {}
    for match in re.finditer(
        r"(\d+):\s*\{[^}]*?'par':\s*(\d+),[^}]*?'terrainModel':\s*'phase_6/models/golf/(hole\d+)\.bam'",
        body,
        re.S,
    ):
        records[int(match.group(1))] = {"par": int(match.group(2)), "model": match.group(3)}
    return records


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "model-cache-dir")
    idle.ASSETS = Filename.from_os_specific(str(SOURCE))
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)

    holes = hole_records()
    print("hole records", len(holes), flush=True)
    exported: dict[str, dict] = {}
    for info in holes.values():
        model = info["model"]
        if model in exported:
            continue
        root = export_one(f"phase_6/models/golf/{model}.bam", f"{model}.glb", model)
        if root is None:
            continue
        if model == "hole1":
            names = sorted({path.getName() for path in root.findAllMatches("**")})
            print("hole1 nodes", ", ".join(names[:80]), flush=True)
        exported[model] = {
            "tees": named(root, "tee"),
            "cup": (named(root, "holebottom") or [[0.0, 0.25, 0.0]])[0],
        }
        print(" ", model, "tees", len(exported[model]["tees"]), "cup", exported[model]["cup"], flush=True)

    for name in PROPS:
        export_one(f"phase_6/models/golf/{name}", name.replace(".bam", ".glb"), name.replace(".bam", ""))

    audio_out = OUT / "audio"
    audio_out.mkdir(exist_ok=True)
    sfx = SOURCE / "phase_6" / "audio" / "sfx"
    for name in ("Golf_Hit_Ball.ogg", "Golf_Hole_In_One.ogg", "Golf_Ball_Goes_In_Start.ogg", "Golf_Ball_Rest_In_Cup.ogg"):
        src = sfx / name
        if src.exists():
            shutil.copyfile(src, audio_out / name)
            print("audio", name, flush=True)

    payload = {}
    for hole_id, info in sorted(holes.items()):
        spot = exported.get(info["model"], {"tees": [], "cup": [0.0, 0.25, 0.0]})
        payload[str(hole_id)] = {
            "par": info["par"],
            "model": f"res://assets/minigolf/{info['model']}.glb",
            "tees": spot["tees"],
            "cup": spot["cup"],
        }
    (OUT / "holes.json").write_text(json.dumps(payload, indent=1), encoding="utf-8")
    print("wrote holes.json", len(payload), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
