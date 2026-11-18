"""Export the live Silly Meter and the two hand props.

DistributedToonHallInterior.enterSetup loads the default actor and the phase
clips. The flat meter stays in the hall export. These files replace it while
holiday 60 or 116 is running.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, Loader, NodePath, TextureAttrib, TexturePool, getModelPath, loadPrcFileData

from export_party_anims import export_one
from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP


ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = Path(__file__).resolve().parents[1] / "assets" / "interiors" / "toon_hall"
CLIPS = (
    ("arrow_tube", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_arrowFluid.bam"),
    ("phase_one", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseOne.bam"),
    ("phase_two", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseTwo.bam"),
    ("phase_three", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseThree.bam"),
    ("phase_four", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseFour.bam"),
    ("phase_four_to_five", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseFourToFive.bam"),
    ("phase_five", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_phaseFive.bam"),
)
PROPS = (
    ("silly_reader", "phase_4/models/props/tt_m_prp_acs_sillyReader.bam"),
    ("clipboard", "phase_4/models/props/tt_m_prp_acs_clipboard.bam"),
    ("silly_meter", "phase_4/models/props/tt_a_ara_ttc_sillyMeter_default.bam"),
)


def load_model(relative: str) -> NodePath:
    path = ASSETS.joinpath(*relative.split("/"))
    node = Loader.getGlobalPtr().loadSync(Filename.from_os_specific(str(path)))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def paint(model: NodePath) -> None:
    pngs = sorted(ASSETS.glob("phase_4/maps/*sillyMeter*.png"))
    if not pngs:
        return
    tex = TexturePool.loadTexture(Filename.from_os_specific(str(pngs[0])))
    if tex is None:
        return
    for geom in model.findAllMatches("**/+GeomNode"):
        node = geom.node()
        if node.getNumGeoms() == 0:
            continue
        attrib = node.getGeomState(0).getAttrib(TextureAttrib.getClassType())
        if attrib is not None and attrib.getNumOnStages() > 0:
            continue
        geom.setTexture(tex, 1)
        print("painted", geom.getName(), pngs[0].name, flush=True)


def write_model(name: str, relative: str) -> None:
    model = load_model(relative)
    for piece in model.findAllMatches("**/*collision*"):
        piece.detachNode()
    paint(model)
    root = NodePath(name)
    root.setMat(Z_UP_TO_Y_UP)
    model.reparentTo(root)
    model.show()
    for child in model.findAllMatches("**"):
        child.show()
    writer = GltfWriter()
    writer.add_node(root, None)
    dest = OUT / f"{name}.glb"
    dest.write_bytes(writer.pack(name))
    print(f"wrote {dest.name} meshes={writer.mesh_count} images={len(writer.images)} bytes={dest.stat().st_size}", flush=True)
    root.removeNode()


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "model-cache-dir")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    OUT.mkdir(parents=True, exist_ok=True)
    anim_dir = OUT / "anims"
    anim_dir.mkdir(parents=True, exist_ok=True)
    # export_one writes beside the party anims. Point it at this folder.
    import export_party_anims as party
    party.OUT = anim_dir
    for name, _model, _anim in CLIPS:
        if not party.export_one(Loader.getGlobalPtr(), name, _model, _anim):
            return 1
    for name, relative in PROPS:
        write_model(name, relative)
    return 0


if __name__ == "__main__":
    sys.exit(main())
