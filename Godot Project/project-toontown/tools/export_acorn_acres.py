"""Build a Y-up glTF of Chip 'n Dale's Acorn Acres from the original DNA.

Load order matches the client: storage.dna, storage_OZ.dna, storage_OZ_sz.dna,
then outdoor_zone_sz.dna. The hood sky is TT_sky. Lake and pond surfaces keep
the alpha the safe-zone loader applies, and the waterfall sits on its marker.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import Filename, Loader, NodePath, TransparencyAttrib, getModelPath, loadPrcFileData
from panda3d.toontown import DNAStorage, loadDNAFile

import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "neighborhoods" / "acorn_acres" / "acorn_acres.glb"

DNA_FILES = [
    "phase_4/dna/storage.dna",
    "phase_6/dna/storage_OZ.dna",
    "phase_6/dna/storage_OZ_sz.dna",
    "phase_6/dna/outdoor_zone_sz.dna",
]


def panda_path(relative: str) -> str:
    return str(Filename(ASSETS, relative))


def make_transparent(geom: NodePath, pattern: str) -> None:
    node = geom.find(pattern)
    if node.isEmpty():
        print("warning: missing", pattern)
        return
    node.setTransparency(TransparencyAttrib.M_alpha)
    print("transparent", node.getName())


def place_waterfall(geom: NodePath, loader: Loader) -> None:
    marker = geom.find("**/waterfall*")
    if marker.isEmpty():
        print("warning: waterfall marker not found")
        return
    model = loader.loadSync(panda_path("phase_6/models/golf/golf_waterfall_model.bam"))
    if model is None:
        print("warning: waterfall model failed to load")
        return
    waterfall = NodePath(model)
    waterfall.reparentTo(geom)
    waterfall.setPos(marker.getPos(geom))
    waterfall.setHpr(marker.getHpr(geom))
    waterfall.setName("waterfall")
    print("waterfall", tuple(round(v, 2) for v in waterfall.getPos(geom)))


def load_playground() -> NodePath:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(ASSETS)

    store = DNAStorage()
    node = None
    for relative in DNA_FILES:
        print("loading", relative, flush=True)
        node = loadDNAFile(store, panda_path(relative), 0)
    if node is None:
        raise RuntimeError("DNA loader returned no playground")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)

    make_transparent(geom, "**/water1*")
    make_transparent(geom, "**/pPlane5*")

    loader = Loader.getGlobalPtr()
    place_waterfall(geom, loader)

    sky_node = loader.loadSync(panda_path("phase_3.5/models/props/TT_sky.bam"))
    if sky_node is None:
        raise RuntimeError("TT_sky failed to load")
    sky = NodePath(sky_node)
    sky.setName("OZSky")

    root = NodePath("AcornAcres")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    geom.copyTo(root)
    sky.copyTo(root)
    return root


def main() -> int:
    root = load_playground()
    print("export bounds", root.getBounds())
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = writer.pack()
    OUT.write_bytes(payload)
    print(
        f"wrote {OUT} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"nodes={len(writer.nodes)} meshes={writer.mesh_count} "
        f"tris={writer.tri_count} materials={len(writer.materials)} "
        f"textures={len(writer.textures)} billboards={writer.billboards}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
