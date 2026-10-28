"""Build a Y-up glTF of Donald's Dock playground from the original DNA.

Load order matches the client: storage.dna, storage_DD.dna, storage_DD_sz.dna,
then donalds_dock_sz.dna. The hood sky is BR_sky. Fog and the interface are
left out. Water keeps the alpha the safe-zone loader applies, and the boat
stays in the pose stored on the neighborhood model.
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
OUT = ROOT / "assets" / "neighborhoods" / "donalds_dock" / "donalds_dock.glb"

DNA_FILES = [
    "phase_4/dna/storage.dna",
    "phase_6/dna/storage_DD.dna",
    "phase_6/dna/storage_DD_sz.dna",
    "phase_6/dna/donalds_dock_sz.dna",
]


def panda_path(relative: str) -> str:
    return str(Filename(ASSETS, relative))


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

    water = geom.find("**/water")
    if water.isEmpty():
        print("warning: water node not found")
    else:
        water.setTransparency(TransparencyAttrib.M_alpha)
        water.setColor(1, 1, 1, 0.8)
        print("water", water.getName())

    boat = geom.find("**/donalds_boat")
    if boat.isEmpty():
        print("warning: boat not found")
    else:
        # The reference playground has the boat at the west dock, which is the
        # end of the east-to-west path. The curve is in the boat node's parent
        # space, which is how Mopath.goTo applies it.
        boat.setPos(-49.724, -10.711, -3.85)
        boat.setHpr(0, 0, 0)
        wheel = boat.find("**/wheel")
        if not wheel.isEmpty():
            wheel.hide()
        print("boat", boat.getPos(geom), "hpr", boat.getHpr(geom))

    # The west drawbridge is raised beside the docked boat. The east bridge
    # stays lowered, which is the pose stored on the model.
    west_pier = geom.find("**/west_pier")
    if not west_pier.isEmpty():
        west_pier.setHpr(-90, 0.25, 0)

    loader = Loader.getGlobalPtr()
    sky_node = loader.loadSync(panda_path("phase_3.5/models/props/BR_sky.bam"))
    if sky_node is None:
        raise RuntimeError("BR_sky failed to load")
    sky = NodePath(sky_node)
    sky.setName("DDSky")
    print("sky children", [sky.getChild(i).getName() for i in range(sky.getNumChildren())])

    root = NodePath("DonaldsDock")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    geom.copyTo(root)
    sky.copyTo(root)
    return root


def main() -> int:
    probe = exporter.Z_UP_TO_Y_UP.xform(exporter.LPoint3f(1, 2, 3))
    print("axis probe (1, 2, 3) ->", tuple(round(v, 4) for v in probe))
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
        f"textures={len(writer.textures)} empty={writer.skipped_empty} "
        f"billboards={writer.billboards}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
