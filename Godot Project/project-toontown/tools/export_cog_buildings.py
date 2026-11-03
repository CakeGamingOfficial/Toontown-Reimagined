"""Export cog building exteriors and each street's takeover blocks.

suit_landmark_c1 through c5 are the same corp model; the other departments
match. Floor count is the elevator lights, not a taller mesh. Field offices
are not exported. Blocks are the landmark and animated buildings a suit can
take, which leaves out HQ, the gag shop, the pet shop, and the kart shop.
"""
from __future__ import annotations

import json
import os
import re
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.DNASuitPoint = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

if not hasattr(os, "add_dll_directory"):
    def _safe(_path):
        class _Dummy:
            def close(self):
                return None

            def __enter__(self):
                return None

            def __exit__(self, *_args):
                return False

        return _Dummy()

    os.add_dll_directory = _safe

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = ROOT / "assets" / "buildings" / "cog"
SKIP_TYPES = {"hq", "gagshop", "petshop", "kartshop"}
# SuitHoodInfo bmin, bmax. TTC streets stop at 5. The other playgrounds do not.
HOOD = {
    1100: (0, 99),
    1200: (0, 99),
    1300: (0, 99),
    2100: (0, 5),
    2200: (0, 5),
    2300: (0, 5),
    3100: (0, 99),
    3200: (0, 99),
    3300: (0, 99),
    4100: (0, 99),
    4200: (0, 99),
    4300: (0, 99),
    5100: (0, 99),
    5200: (0, 99),
    5300: (0, 99),
    9100: (0, 99),
    9200: (0, 99),
}
MODELS = {
    "corp": "phase_4/models/modules/suit_landmark_corp.bam",
    "legal": "phase_4/models/modules/suit_landmark_legal.bam",
    "money": "phase_4/models/modules/suit_landmark_money.bam",
    "sales": "phase_4/models/modules/suit_landmark_sales.bam",
    "elevator": "phase_4/models/modules/elevator.bam",
    "suit_sign": "phase_5/models/modules/suit_sign.bam",
    # DNAFlatBuilding.setup_suit_flat_building swaps each toon wall for one of these.
    "suit_walls": "phase_5/models/modules/suit_walls.bam",
    "suit_door": "phase_5/models/modules/suit_door.bam",
}


def _street_rows() -> list[dict]:
    text = Path(__file__).with_name("export_street_cogs.py").read_text(encoding="utf-8")
    rows = []
    for match in re.finditer(r"\{[^{}]*\"slug\":\s*\"([^\"]+)\"[^{}]*\}", text, flags=re.S):
        body = match.group(0)
        if "\"dna\"" not in body:
            continue
        slug = match.group(1)
        zone = int(re.search(r"\"zone\":\s*(\d+)", body).group(1))
        tracks = [int(item) for item in re.search(r"\"tracks\":\s*\[([^\]]*)\]", body).group(1).split(",") if item.strip()]
        levels = [int(item) for item in re.search(r"\"levels\":\s*\[([^\]]*)\]", body).group(1).split(",") if item.strip()]
        dna_body = re.search(r"\"dna\":\s*\[(.*?)\]", body, flags=re.S).group(1)
        dna = re.findall(r"\"([^\"]+)\"", dna_body)
        out = re.search(r"\"out\":\s*\"([^\"]+)\"", body).group(1)
        rows.append({
            "slug": slug,
            "zone": zone,
            "tracks": tracks,
            "levels": levels,
            "dna": dna[-1],
            "out": out.replace("_suits.json", "_buildings.json"),
        })
    return rows


def _bracket_body(text: str, start: int) -> str:
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "[":
            depth += 1
        elif text[index] == "]":
            depth -= 1
        index += 1
    return text[start:index]


def _blocks(relative: str) -> list[dict]:
    path = ASSETS / relative.replace("/", os.sep)
    text = path.read_text(encoding="utf-8")
    found = []
    for match in re.finditer(
        r'(landmark_building|anim_building)\s+"tb(\d+):([^"]+)"\s*\[',
        text,
    ):
        block = int(match.group(2))
        dna_name = match.group(3)
        body = _bracket_body(text, match.end())
        building_type = ""
        typed = re.search(r'building_type\s*\[\s*"([^"]+)"\s*\]', body)
        if typed:
            building_type = typed.group(1)
        if building_type in SKIP_TYPES or "hq" in dna_name.lower():
            continue
        title = ""
        titled = re.search(r'title\s*\[\s*"([^"]*)"\s*\]', body)
        if titled:
            title = titled.group(1)
        # DNA is Z-up. The street is exported as (x, z, -y).
        pos = None
        posed = re.search(r"pos\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]", body)
        if posed:
            x, y, z = (float(posed.group(1)), float(posed.group(2)), float(posed.group(3)))
            pos = [x, z, -y]
        row = {"block": block, "title": title}
        if pos is not None:
            row["pos"] = pos
        found.append(row)
    found.sort(key=lambda row: int(row["block"]))
    return found


def _godot(x: float, y: float, z: float) -> list[float]:
    # DNA is Z-up. The street is exported as (x, z, -y).
    return [x, z, -y]


def _side_doors(dna_relative: str, suits_relative: str) -> dict[int, list[dict]]:
    """SIDE_DOOR_POINT plus the street point it opens onto.

    createNewSuit starts a building suit on a side door. The suits file is
    already shifted with the street mesh, so the door uses that same slide.
    """
    text = (ASSETS / dna_relative.replace("/", os.sep)).read_text(encoding="utf-8")
    points: dict[int, dict] = {}
    for match in re.finditer(
        r"store_suit_point\s*\[\s*(\d+)\s*,\s*"
        r"(STREET_POINT|FRONT_DOOR_POINT|SIDE_DOOR_POINT|COGHQ_IN_POINT|COGHQ_OUT_POINT)\s*,\s*"
        r"([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)(?:\s*,\s*(\d+))?",
        text,
    ):
        points[int(match.group(1))] = {
            "kind": match.group(2),
            "pos": _godot(float(match.group(3)), float(match.group(4)), float(match.group(5))),
            "block": int(match.group(6) or 0),
        }
    neighbors: dict[int, set[int]] = {}
    for match in re.finditer(r"suit_edge\s*\[\s*(\d+)\s+(\d+)\s*\]", text):
        start, end = int(match.group(1)), int(match.group(2))
        neighbors.setdefault(start, set()).add(end)
        neighbors.setdefault(end, set()).add(start)
    street_ids = sorted(index for index, point in points.items() if point["kind"] == "STREET_POINT")
    delta = [0.0, 0.0, 0.0]
    suits_path = ROOT / suits_relative
    if street_ids and suits_path.exists():
        suits = json.loads(suits_path.read_text(encoding="utf-8"))
        suit_points = suits.get("points") or []
        if suit_points:
            origin = points[street_ids[0]]["pos"]
            first = suit_points[0]
            delta = [float(first[0]) - origin[0], float(first[1]) - origin[1], float(first[2]) - origin[2]]
    by_block: dict[int, list[dict]] = {}
    for index, point in points.items():
        if point["kind"] != "SIDE_DOOR_POINT":
            continue
        exits = [
            other for other in neighbors.get(index, ())
            if points.get(other, {}).get("kind") == "STREET_POINT"
        ]
        if not exits:
            continue
        exit_pos = points[exits[0]]["pos"]
        by_block.setdefault(int(point["block"]), []).append({
            "pos": [round(value + slide, 3) for value, slide in zip(point["pos"], delta)],
            "exit": [round(value + slide, 3) for value, slide in zip(exit_pos, delta)],
        })
    return by_block


def _export_model(loader: Loader, name: str, relative: str) -> None:
    source = ASSETS / relative.replace("/", os.sep)
    loaded = loader.loadSync(Filename.from_os_specific(str(source)))
    if loaded is None:
        raise RuntimeError("missing " + relative)
    model = NodePath(loaded)
    root = NodePath(name)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = OUT / f"{name}.glb"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(writer.pack(name))
    print(f"wrote {dest.name} ({dest.stat().st_size / 1024:.0f} KB)", flush=True)


def main() -> int:
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    loader = Loader.getGlobalPtr()
    for name, relative in MODELS.items():
        _export_model(loader, name, relative)
    for street in _street_rows():
        zone = int(street["zone"])
        bmin, bmax = HOOD.get(zone, (0, 0))
        blocks = _blocks(str(street["dna"]))
        doors = _side_doors(str(street["dna"]), str(street["out"]).replace("_buildings.json", "_suits.json"))
        for block in blocks:
            found = doors.get(int(block["block"]), [])
            if found:
                block["doors"] = found
        payload = {
            "zone": zone,
            "bmin": bmin,
            "bmax": bmax,
            "tracks": street["tracks"],
            "levels": street["levels"],
            "blocks": blocks,
        }
        dest = ROOT / street["out"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")
        print(street["slug"], len(payload["blocks"]), "blocks", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
