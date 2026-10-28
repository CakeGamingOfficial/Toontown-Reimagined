"""Build a Y-up glTF of each Donald's Dock street from the original DNA.

Load order matches the client: storage.dna and storage_DD.dna from the hood,
then storage_town.dna, storage_DD_town.dna, and the street file. The hood sky
is BR_sky. Each street is centered on the ground plane so a camera at the
origin looks down the block.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData
from panda3d.toontown import DNAStorage, loadDNAFile

import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT_DIR = ROOT / "assets" / "neighborhoods" / "donalds_dock" / "streets"

STORAGE = [
    "phase_4/dna/storage.dna",
    "phase_6/dna/storage_DD.dna",
    "phase_5/dna/storage_town.dna",
    "phase_6/dna/storage_DD_town.dna",
]

STREETS = [
    ("barnacle_boulevard", "phase_6/dna/donalds_dock_1100.dna"),
    ("seaweed_street", "phase_6/dna/donalds_dock_1200.dna"),
    ("lighthouse_lane", "phase_6/dna/donalds_dock_1300.dna"),
]


def panda_path(relative: str) -> str:
    return str(Filename(ASSETS, relative))


def load_street(street_file: str) -> NodePath:
    store = DNAStorage()
    node = None
    for relative in STORAGE + [street_file]:
        print("loading", relative, flush=True)
        node = loadDNAFile(store, panda_path(relative), 0)
    if node is None:
        raise RuntimeError(f"DNA loader returned nothing for {street_file}")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)
    center = geom.getBounds().getCenter()
    # Keep the street on the ground and slide it so the block sits at the origin.
    geom.setPos(-center.x, -center.y, 0)
    print(
        "centered from panda",
        tuple(round(v, 2) for v in (center.x, center.y, center.z)),
        "bounds",
        geom.getBounds(),
    )
    return geom


def export_street(name: str, street_file: str, sky: NodePath) -> None:
    geom = load_street(street_file)
    root = NodePath(name)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    geom.copyTo(root)
    sky.copyTo(root)
    print("export bounds", root.getBounds())
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    out = OUT_DIR / f"{name}.glb"
    payload = writer.pack()
    out.write_bytes(payload)
    print(
        f"wrote {out} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"nodes={len(writer.nodes)} meshes={writer.mesh_count} "
        f"tris={writer.tri_count} materials={len(writer.materials)} "
        f"textures={len(writer.textures)} billboards={writer.billboards}"
    )


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(ASSETS)

    loader = Loader.getGlobalPtr()
    sky_node = loader.loadSync(panda_path("phase_3.5/models/props/BR_sky.bam"))
    if sky_node is None:
        raise RuntimeError("BR_sky failed to load")
    sky = NodePath(sky_node)
    sky.setName("DDSky")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, street_file in STREETS:
        print("===", name, flush=True)
        export_street(name, street_file, sky)
    return 0


if __name__ == "__main__":
    sys.exit(main())
