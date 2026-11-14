"""Export the furniture and window views the cattlelog can deliver."""
from __future__ import annotations

import json
import re
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "estate" / "furniture"
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\catalog\CatalogFurnitureItem.py")
ISSUE = ROOT / "assets" / "catalog" / "issue.json"
RESOURCES = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")

WINDOWS = {
    10: "phase_5.5/models/estate/Garden1",
    20: "phase_5.5/models/estate/GardenA",
    30: "phase_5.5/models/estate/GardenB",
    40: "phase_5.5/models/estate/cityView",
    50: "phase_5.5/models/estate/westernView",
    60: "phase_5.5/models/estate/underwaterView",
    70: "phase_5.5/models/estate/tropicView",
    80: "phase_5.5/models/estate/spaceView",
    90: "phase_5.5/models/estate/PoolView",
    100: "phase_5.5/models/estate/SnowView",
    110: "phase_5.5/models/estate/FarmView",
    120: "phase_5.5/models/estate/IndianView",
    130: "phase_5.5/models/estate/WesternMainStreetView",
}
FLAGS = {
    "FLBank": 1,
    "FLCloset": 2,
    "FLRug": 4,
    "FLPainting": 8,
    "FLOnTable": 16,
    "FLIsTable": 32,
    "FLPhone": 64,
    "FLBillboard": 128,
    "FLTrunk": 256,
}


def catalog_ids(kind: str) -> set[int]:
    issue = json.loads(ISSUE.read_text(encoding="utf-8"))
    found: set[int] = set()
    for week in issue["weeks"]:
        for item in week:
            if item.get("kind") == kind:
                found.add(int(item["id"]))
    return found


def furniture_rows() -> dict[int, dict]:
    text = SOURCE.read_text(encoding="utf-8")
    marks = list(re.finditer(r"(\d+):\s*\(\s*'([^']+)'", text))
    wanted = catalog_ids("furniture")
    rows: dict[int, dict] = {}
    for index, mark in enumerate(marks):
        item_id = int(mark.group(1))
        if item_id not in wanted:
            continue
        end = marks[index + 1].start() if index + 1 < len(marks) else mark.end() + 800
        body = text[mark.end():end]
        flags = 0
        for name, bit in FLAGS.items():
            if name in body:
                flags |= bit
        scale = 1.0
        numbers = re.findall(r"([0-9]+\.[0-9]+)\s*\)", body)
        if numbers:
            scale = float(numbers[-1])
        rows[item_id] = {
            "model": Path(mark.group(2)).name + ".glb",
            "path": mark.group(2),
            "scale": scale,
            "flags": flags,
        }
    return rows


def load_prop(relative: str):
    bam = relative + ".bam"
    model = idle.load_model(bam)
    if model is not None:
        return model
    path = RESOURCES / Path(bam)
    node = idle.Loader.getGlobalPtr().loadSync(idle.Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path)
        return None
    return idle.NodePath(node)


def hide_helpers(prop: NodePath) -> None:
    for child in prop.findAllMatches("**"):
        name = child.getName().lower()
        if "collision" in name or "trigger" in name or name.startswith("shadow"):
            child.hide()


def export_model(relative: str, filename: str, done: set[str]) -> None:
    if filename in done:
        return
    model = load_prop(relative)
    if model is None:
        return
    hide_helpers(model)
    root = NodePath(Path(filename).stem)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.copyTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path = OUT / filename
    path.write_bytes(writer.pack(root.getName()))
    done.add(filename)
    print(f"{filename} meshes={writer.mesh_count} bytes={path.stat().st_size}", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    idle.ASSETS = Filename.from_os_specific(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = furniture_rows()
    windows = {}
    for item_id, relative in WINDOWS.items():
        if item_id not in catalog_ids("window"):
            continue
        windows[str(item_id)] = {"model": Path(relative).name + ".glb"}
    done: set[str] = set()
    for row in rows.values():
        export_model(row["path"], row["model"], done)
    for item_id, relative in WINDOWS.items():
        if str(item_id) not in windows:
            continue
        export_model(relative, Path(relative).name + ".glb", done)
    book = {
        "furniture": {
            str(item_id): {"model": row["model"], "scale": row["scale"], "flags": row["flags"]}
            for item_id, row in sorted(rows.items())
        },
        "windows": windows,
    }
    dest = OUT / "house_catalog.json"
    dest.write_text(json.dumps(book, indent=1), encoding="utf-8")
    print("catalog", len(rows), "windows", len(windows), "models", len(done), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
