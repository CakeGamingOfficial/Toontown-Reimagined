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
        payload = {
            "zone": zone,
            "bmin": bmin,
            "bmax": bmax,
            "tracks": street["tracks"],
            "levels": street["levels"],
            "blocks": _blocks(str(street["dna"])),
        }
        dest = ROOT / street["out"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")
        print(street["slug"], len(payload["blocks"]), "blocks", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
