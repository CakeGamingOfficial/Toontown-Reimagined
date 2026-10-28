"""Sample Donald's Dock boat paths and pier poses for the Godot scene.

The curves are the same files DistributedBoat loads. Positions are the boat's
local matrix, in the cell order the playground exporter writes into glTF.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import Filename, Loader, NodePath, Point3, getModelPath, loadPrcFileData
from panda3d.core import ParametricCurve, PCTXYZ, PCTHPR, PCTNONE, PCTT
from panda3d.toontown import DNAStorage, loadDNAFile

import export_toontown_central as exporter
import export_donalds_dock as dock

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "neighborhoods" / "donalds_dock" / "boat_path.json"
ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
SAMPLE_STEP = 0.1


def cells(node: NodePath) -> list[float]:
    mat = node.getMat()
    return [mat.getCell(row, col) for row in range(4) for col in range(4)]


def extract(path_node: NodePath):
    xyz = None
    hpr = None
    times: list = []

    def walk(node: NodePath) -> None:
        nonlocal xyz, hpr
        curve = node.node()
        if isinstance(curve, ParametricCurve):
            kind = curve.getCurveType()
            if kind == PCTXYZ or (kind == PCTNONE and xyz is None):
                xyz = curve
            elif kind == PCTHPR:
                hpr = curve
            elif kind == PCTT:
                times.append(curve)
        for child in node.getChildren():
            walk(child)

    walk(path_node)
    if xyz is not None and times:
        max_t = times[-1].getMaxT()
    elif xyz is not None:
        max_t = xyz.getMaxT()
    else:
        raise RuntimeError("path has no position curve")
    return xyz, hpr, times, max_t


def calc_time(t_in: float, curves: list) -> float:
    if not curves:
        return t_in
    point = Point3()
    curves[-1].getPoint(t_in, point)
    return calc_time(point[0], curves[:-1])


def sample_path(boat: NodePath, filename: str) -> dict:
    loader = Loader.getGlobalPtr()
    path_node = NodePath(loader.loadSync(str(Filename(ASSETS, filename))))
    xyz, hpr, times, max_t = extract(path_node)
    steps = max(1, int(round(max_t / SAMPLE_STEP)))
    samples = []
    point = Point3()
    angles = Point3()
    for index in range(steps + 1):
        t = max_t * index / steps
        playback = calc_time(min(max(t, 0.0), max_t), times)
        xyz.getPoint(playback, point)
        boat.setPos(point)
        if hpr is not None:
            hpr.getPoint(playback, angles)
            boat.setHpr(angles)
        samples.append(cells(boat))
    print(
        filename,
        "duration", round(max_t, 4),
        "samples", len(samples),
        "time curves", len(times),
        "hpr", hpr is not None,
        "start", [round(v, 3) for v in samples[0][12:15]],
        "end", [round(v, 3) for v in samples[-1][12:15]],
    )
    path_node.removeNode()
    return {"duration": max_t, "samples": samples}


def pier_pose(pier: NodePath, hpr) -> list[float]:
    pier.setHpr(*hpr)
    return cells(pier)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(ASSETS)

    store = DNAStorage()
    node = None
    for relative in dock.DNA_FILES:
        node = loadDNAFile(store, dock.panda_path(relative), 0)
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)
    boat = geom.find("**/donalds_boat")
    east = geom.find("**/east_pier")
    west = geom.find("**/west_pier")
    print("boat parent", boat.getParent().getName())
    print("east rest", boat.getParent().getName(), east.getHpr())
    print("east hpr", east.getHpr(), "west hpr", west.getHpr())

    payload = {
        "sample_step": SAMPLE_STEP,
        "east_to_west": sample_path(boat, "phase_6/paths/dd-e-w.bam"),
        "west_to_east": sample_path(boat, "phase_6/paths/dd-w-e.bam"),
        "east_down": pier_pose(east, (90, -44.2601, 0)),
        "east_up": pier_pose(east, (90, 0.25, 0)),
        "west_down": pier_pose(west, (-90, -44.2601, 0)),
        "west_up": pier_pose(west, (-90, 0.25, 0)),
    }
    OUT.write_text(json.dumps(payload, separators=(",", ":")))
    print("wrote", OUT, "bytes", OUT.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
