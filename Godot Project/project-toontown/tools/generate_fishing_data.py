"""Shore spots and the fish tables the cast uses.

DNA fishing_spot props are where the toon stands. Their offset from
npc_fisherman_origin_0 is in the same space as that exported origin.
FishGlobals.__fishDict is the pond table getRandomFishVitals reads.
"""
from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = Path(__file__).resolve().parents[1]
SPECIES_GD = OUT / "scenes" / "fishing" / "fish_species.gd"
SHORE_GD = OUT / "scenes" / "playgrounds" / "fishing_shore_data.gd"

ZONES = {
    "Anywhere": 1,
    "ToontownCentral": 2000,
    "DonaldsDock": 1000,
    "TheBrrrgh": 3000,
    "MinniesMelodyland": 4000,
    "DaisyGardens": 5000,
    "DonaldsDreamland": 9000,
    "BarnacleBoulevard": 1100,
    "SeaweedStreet": 1200,
    "LighthouseLane": 1300,
    "SillyStreet": 2100,
    "LoopyLane": 2200,
    "PunchlinePlace": 2300,
    "WalrusWay": 3100,
    "SleetStreet": 3200,
    "PolarPlace": 3300,
    "AltoAvenue": 4100,
    "BaritoneBoulevard": 4200,
    "TenorTerrace": 4300,
    "ElmStreet": 5100,
    "MapleStreet": 5200,
    "OakStreet": 5300,
    "LullabyLane": 9100,
    "PajamaPlace": 9200,
    "MyEstate": 16000,
}

# scene, zone, water level, street shift (sx, sy). Playgrounds are unshifted.
SCENES = [
    ("phase_4/dna/toontown_central_sz.dna", "toontown_central.tscn", 2000, -1.4, (0.0, 0.0)),
    ("phase_5/dna/toontown_central_2100.dna", "silly_street.tscn", 2100, -1.838, (0.0, 0.0)),
    ("phase_5/dna/toontown_central_2200.dna", "loopy_lane.tscn", 2200, -1.862, (0.0, 0.0)),
    ("phase_5/dna/toontown_central_2300.dna", "punchline_place.tscn", 2300, -1.886, (0.0, 0.0)),
    ("phase_6/dna/donalds_dock_sz.dna", "donalds_dock.tscn", 1000, -1.885, (0.0, 0.0)),
    ("phase_6/dna/donalds_dock_1100.dna", "barnacle_boulevard.tscn", 1100, -2.482, (-243.207, 118.168)),
    ("phase_6/dna/donalds_dock_1200.dna", "seaweed_street.tscn", 1200, -2.482, (208.247, 282.559)),
    ("phase_6/dna/donalds_dock_1300.dna", "lighthouse_lane.tscn", 1300, -2.482, (-315.035, 36.856)),
    ("phase_8/dna/daisys_garden_sz.dna", "daisy_gardens.tscn", 5000, -1.825, (0.0, 0.0)),
    ("phase_8/dna/daisys_garden_5100.dna", "elm_street.tscn", 5100, -2.048, (-290.439, -103.754)),
    ("phase_8/dna/daisys_garden_5200.dna", "maple_street.tscn", 5200, -2.048, (-331.83, -24.827)),
    ("phase_8/dna/daisys_garden_5300.dna", "oak_street.tscn", 5300, -1.877, (50.965, -75.06)),
    ("phase_6/dna/minnies_melody_land_sz.dna", "minnies_melodyland.tscn", 4000, -2.65, (0.0, 0.0)),
    ("phase_6/dna/minnies_melody_land_4100.dna", "alto_avenue.tscn", 4100, -2.714, (388.179, -36.366)),
    ("phase_6/dna/minnies_melody_land_4200.dna", "baritone_boulevard.tscn", 4200, -2.714, (21.288, -345.237)),
    ("phase_6/dna/minnies_melody_land_4300.dna", "tenor_terrace.tscn", 4300, -2.714, (-451.217, -48.178)),
    ("phase_8/dna/the_burrrgh_sz.dna", "the_burrrgh.tscn", 3000, -0.8, (0.0, 0.0)),
    ("phase_8/dna/the_burrrgh_3100.dna", "walrus_way.tscn", 3100, -2.4, (-269.438, -28.638)),
    ("phase_8/dna/the_burrrgh_3200.dna", "sleet_street.tscn", 3200, -2.4, (-239.236, -304.316)),
    ("phase_8/dna/the_burrrgh_3300.dna", "polar_place.tscn", 3300, -2.4, (-247.262, -245.814)),
    ("phase_8/dna/donalds_dreamland_sz.dna", "donalds_dreamland.tscn", 9000, -2.5, (0.0, 0.0)),
    ("phase_8/dna/donalds_dreamland_9100.dna", "lullaby_lane.tscn", 9100, -2.478, (105.988, 206.045)),
    ("phase_8/dna/donalds_dreamland_9200.dna", "pajama_place.tscn", 9200, -2.478, (-150.034, 77.423)),
    ("phase_5.5/dna/estate_1.dna", "toon_estate.tscn", 16000, -0.83, (0.0, 0.0)),
]

CENTERS = {
    "toontown_central.tscn": (-81.0, -31.0),
    "silly_street.tscn": (20.0, 664.0),
    "loopy_lane.tscn": (-234.0, -175.0),
    "punchline_place.tscn": (529.0, 70.0),
    "donalds_dock.tscn": (-17.0, -130.0),
    "barnacle_boulevard.tscn": (137.793, 231.832),
    "seaweed_street.tscn": (-186.753, -56.559),
    "lighthouse_lane.tscn": (34.965, -136.856),
    "daisy_gardens.tscn": (50.0, -47.0),
    "elm_street.tscn": (-141.439, 59.754),
    "maple_street.tscn": (-155.83, -75.173),
    "oak_street.tscn": (184.965, 145.56),
    "minnies_melodyland.tscn": (-0.2, 20.2),
    "alto_avenue.tscn": (-191.821, 126.366),
    "baritone_boulevard.tscn": (-192.712, 95.237),
    "tenor_terrace.tscn": (263.783, 63.178),
    "the_burrrgh.tscn": (-58.0, 26.0),
    "walrus_way.tscn": (190.562, -0.362),
    "sleet_street.tscn": (100.764, -175.684),
    "polar_place.tscn": (-201.762, 154.954),
    "donalds_dreamland.tscn": (159.0, -0.2),
    "lullaby_lane.tscn": (223.988, -21.045),
    "pajama_place.tscn": (90.966, 270.577),
    "toon_estate.tscn": (30.0, 126.0),
}


def _pond_blocks(text: str) -> list[str]:
    blocks = []
    cursor = 0
    while True:
        start = text.find('"fishing_pond', cursor)
        if start < 0:
            break
        bracket = text.find("[", start)
        depth = 0
        for index in range(bracket, len(text)):
            if text[index] == "[":
                depth += 1
            elif text[index] == "]":
                depth -= 1
                if depth == 0:
                    blocks.append(text[bracket + 1 : index])
                    cursor = index + 1
                    break
        else:
            break
    return blocks


def _vec(match: re.Match) -> tuple[float, float, float]:
    return (float(match.group(1)), float(match.group(2)), float(match.group(3)))


def _spots(block: str) -> tuple[tuple[float, float, float] | None, list[tuple]]:
    origin = re.search(
        r'npc_fisherman_origin_0.*?pos \[ ([-\d.]+) ([-\d.]+) ([-\d.]+) \]',
        block,
        re.S,
    )
    found = []
    for spot in re.finditer(
        r'code \[ "fishing_spot" \].*?pos \[ ([-\d.]+) ([-\d.]+) ([-\d.]+) \].*?(?:n)?hpr \[ ([-\d.]+) ([-\d.]+) ([-\d.]+) \]',
        block,
        re.S,
    ):
        found.append(
            (
                float(spot.group(1)),
                float(spot.group(2)),
                float(spot.group(3)),
                float(spot.group(4)),
            )
        )
    return (_vec(origin) if origin else None, found)


def _godot(x: float, y: float, z: float, shift: tuple[float, float]) -> tuple[float, float, float]:
    sx, sy = shift
    return (x + sx, z, -(y + sy))


def _forward(heading: float) -> tuple[float, float]:
    radians = math.radians(heading)
    return (-math.sin(radians), -math.cos(radians))


def _facing(scene: str, points: list[tuple[float, float, float, float]]) -> int:
    center = CENTERS[scene]
    good = 0
    for x, _y, z, heading in points:
        fx, fz = _forward(heading)
        dx, dz = center[0] - x, center[1] - z
        if fx * dx + fz * dz > 0.0:
            good += 1
    return good


def _f(value: float) -> str:
    return f"{value:.4f}"


def write_shores() -> None:
    lines = [
        "extends RefCounted",
        "",
        "## DNA fishing_spot, where the toon stands. Anchored spots are an offset",
        "## from npc_fisherman_origin_0. The estate pond has no fisherman, so those",
        "## spots are already in playground space. heading is the Godot yaw.",
        "",
        "const SHORES := {",
    ]
    for relative, scene, zone, water, shift in SCENES:
        text = (ROOT / relative).read_text(encoding="utf-8", errors="ignore")
        anchored_rows: list[tuple[float, float, float, float]] = []
        absolute_rows: list[tuple[float, float, float, float]] = []
        has_origin = False
        for block in _pond_blocks(text):
            origin, spots = _spots(block)
            if origin is not None:
                has_origin = True
            for x, y, z, panda_h in spots:
                # Panda's heading, used as the Godot yaw, points in at the pond.
                godot_h = panda_h
                if origin is None:
                    gx, gy, gz = _godot(x, y, z, shift)
                    absolute_rows.append((gx, gy, gz, godot_h))
                else:
                    ox, oy, oz = origin
                    dx, dy, dz = x - ox, y - oy, z - oz
                    anchored_rows.append((dx, dz, -dy, godot_h))
                    gx, gy, gz = _godot(x, y, z, shift)
                    absolute_rows.append((gx, gy, gz, godot_h))
        use_anchor = bool(has_origin and anchored_rows and len(anchored_rows) == len(absolute_rows))
        placed = absolute_rows
        rows = anchored_rows if use_anchor else absolute_rows
        facing = _facing(scene, placed)
        far = 0.0
        center = CENTERS[scene]
        for x, _y, z, _h in placed:
            far = max(far, math.hypot(center[0] - x, center[1] - z))
        print(f"{scene} spots={len(rows)} facing={facing} farthest={far:.1f} anchored={use_anchor}")
        spot_text = ", ".join(
            "[" + ", ".join(_f(value) for value in row) + "]" for row in rows
        )
        lines.append(f'\t"{scene}": {{')
        lines.append(f'\t\t"zone": {zone},')
        lines.append(f'\t\t"water": {_f(water)},')
        lines.append(f'\t\t"anchored": {"true" if use_anchor else "false"},')
        lines.append(f"\t\t\"spots\": [{spot_text}],")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    SHORE_GD.write_text("\n".join(lines), encoding="utf-8")


def _fish_dict() -> dict:
    text = (
        Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\fishing\FishGlobals.py")
        .read_text(encoding="utf-8")
    )
    start = text.index("__fishDict = {")
    start = text.index("{", start)
    depth = 0
    end = start
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    body = text[start:end]
    for name, zone in ZONES.items():
        body = body.replace(f"TTG.{name}", str(zone))
    body = re.sub(r"\bAnywhere\b", "1", body)
    return eval(body)  # The source table is a literal of tuples.


def write_species() -> None:
    fish = _fish_dict()
    lines = [
        "extends RefCounted",
        "",
        "## FishGlobals.__fishDict. min and max are pounds. Zones use the hood ids,",
        "## and 1 is Anywhere.",
        "",
        "const FISH: Array = [",
    ]
    count = 0
    for genus, species_list in fish.items():
        for species, desc in enumerate(species_list):
            min_w, max_w, rarity, zones = desc
            zone_text = ", ".join(str(int(zone)) for zone in zones)
            lines.append(f"\t[{int(genus)}, {species}, {int(min_w)}, {int(max_w)}, {int(rarity)}, [{zone_text}]],")
            count += 1
    lines.append("]")
    lines.append("")
    SPECIES_GD.write_text("\n".join(lines), encoding="utf-8")
    print("species", count)


if __name__ == "__main__":
    write_species()
    write_shores()
