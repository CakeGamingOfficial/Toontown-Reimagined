"""Read mover and windmill locators out of the exported hole models.

The names are the original ones: optional_mover_1_X2_Y3_d8p0 and
required_windmillLocator_1. Optional movers are kept only for the hole ids
GolfGlobals lists. The matrices are already Y-up.
"""
from __future__ import annotations

import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets" / "minigolf"
HOLES = MODELS / "holes.json"
GLOBALS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\golf\GolfGlobals.py")
OUT = MODELS / "movers.json"


def mat_mul(a: list[float], b: list[float]) -> list[float]:
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def mat_id() -> list[float]:
    return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def node_local(node: dict) -> list[float]:
    if "matrix" in node:
        return [float(v) for v in node["matrix"]]
    return mat_id()


def glb_nodes(path: Path) -> list[dict]:
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20 : 20 + length])
    nodes = doc.get("nodes", [])
    parent = {child: index for index, node in enumerate(nodes) for child in node.get("children", [])}
    world: dict[int, list[float]] = {}

    def world_of(index: int) -> list[float]:
        if index in world:
            return world[index]
        local = node_local(nodes[index])
        if index in parent:
            world[index] = mat_mul(world_of(parent[index]), local)
        else:
            world[index] = local
        return world[index]

    for index in range(len(nodes)):
        nodes[index]["_world"] = world_of(index)
    return nodes


def number(token: str) -> float | None:
    if len(token) < 2 or token[0] not in "XYd":
        return None
    try:
        return float(token[1:].replace("p", "."))
    except ValueError:
        return None


def mover_id(name: str) -> int | None:
    parts = name.split("_")
    for index, part in enumerate(parts[:-1]):
        if part in ("mover", "windmillLocator") and parts[index + 1].isdigit():
            return int(parts[index + 1])
    return None


def optional_sets() -> dict[int, set[int]]:
    text = GLOBALS.read_text(encoding="utf-8", errors="replace")
    body = text.split("HoleInfo = ", 1)[1]
    found: dict[int, set[int]] = {}
    for match in re.finditer(r"(\d+):\s*\{(.*?)\n\s*\d+:\s*\{", body, re.S):
        block = match.group(2)
        movers = re.search(r"'optionalMovers':\s*(\([^)]*\)|\d+)", block)
        ids: set[int] = set()
        if movers:
            ids = {int(piece) for piece in re.findall(r"\d+", movers.group(1))}
        found[int(match.group(1))] = ids
    last = re.findall(r"(\d+):\s*\{", body)
    if last:
        tail = body.split(f"{last[-1]}:", 1)[1]
        movers = re.search(r"'optionalMovers':\s*(\([^)]*\)|\d+)", tail)
        ids = {int(piece) for piece in re.findall(r"\d+", movers.group(1))} if movers else set()
        found[int(last[-1])] = ids
    return found


def describe(name: str, world: list[float]) -> dict | None:
    kind = ""
    if "windmill" in name:
        kind = "fan"
    elif "mover" in name and "_X" in name:
        kind = "slide"
    else:
        return None
    record = {
        "kind": kind,
        "origin": [round(world[12], 4), round(world[13], 4), round(world[14], 4)],
        "basis": [
            round(world[0], 5), round(world[1], 5), round(world[2], 5),
            round(world[4], 5), round(world[5], 5), round(world[6], 5),
            round(world[8], 5), round(world[9], 5), round(world[10], 5),
        ],
    }
    if kind == "slide":
        size_x = size_y = travel = None
        for token in name.split("_"):
            value = number(token)
            if value is None:
                continue
            if token[0] == "X":
                size_x = value
            elif token[0] == "Y":
                size_y = value
            elif token[0] == "d":
                travel = value
        if size_x is None or size_y is None or travel is None:
            return None
        record["size"] = [size_x, size_y]
        record["travel"] = travel
    record["id"] = mover_id(name)
    record["optional"] = name.startswith("optional")
    return record


def main() -> None:
    holes = json.loads(HOLES.read_text(encoding="utf-8"))
    wanted = optional_sets()
    by_model: dict[str, list[dict]] = {}
    payload: dict[str, list[dict]] = {}
    for hole_id, info in holes.items():
        model = Path(str(info["model"]).replace("res://", str(ROOT) + "/").replace("/", "\\"))
        # res paths use forward slashes. Build from the file name.
        model = MODELS / Path(str(info["model"])).name
        key = model.name
        if key not in by_model:
            by_model[key] = []
            if model.exists():
                for node in glb_nodes(model):
                    record = describe(str(node.get("name", "")), node["_world"])
                    if record is not None:
                        by_model[key].append(record)
        chosen = []
        allowed = wanted.get(int(hole_id), set())
        for record in by_model[key]:
            if record["optional"] and record["id"] not in allowed:
                continue
            if not record["optional"] or record["kind"] == "fan" or record["id"] in allowed:
                item = {k: v for k, v in record.items() if k not in ("id", "optional")}
                chosen.append(item)
        if chosen:
            payload[str(hole_id)] = chosen
            print(hole_id, key, [(item["kind"], item["origin"]) for item in chosen], flush=True)
    OUT.write_text(json.dumps(payload, indent=1), encoding="utf-8")
    print("wrote", OUT.name, "holes", len(payload), flush=True)


if __name__ == "__main__":
    main()
