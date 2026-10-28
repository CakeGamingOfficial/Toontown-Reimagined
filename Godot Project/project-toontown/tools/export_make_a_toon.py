"""Export the Make a Toon room, a posed toon, and the chooser button art.

Body parts are skinned. The neutral animation is posed and the vertices are
baked, so Godot can assemble legs, torso, and head without a skeleton.
Parts stay in Panda's Z-up space. The room is written Y-up, matching the
other playground exports.
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import (
    Filename,
    GeomNode,
    GeomVertexReader,
    GeomVertexRewriter,
    Loader,
    NodePath,
    Point3,
    Texture,
    TextureAttrib,
    Thread,
    getModelPath,
    loadPrcFileData,
)

import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "toons"
_KEEP: list[NodePath] = []


def panda_path(relative: str) -> str:
    return str(Filename(ASSETS, relative))


def load_model(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        print("missing", relative)
        return None
    return NodePath(node)


def pose_neutral(root: NodePath, anim_relative: str) -> None:
    anim = load_model(anim_relative)
    if anim is None:
        return
    bundle_node = anim.find("**/+AnimBundleNode")
    character = root.find("**/+Character")
    if bundle_node.isEmpty() or character.isEmpty():
        return
    _KEEP.append(anim)
    control = character.node().getBundle(0).bindAnim(bundle_node.node().getBundle(), -1)
    hold = root.find("**/def_joint_right_hold")
    if hold.isEmpty():
        control.pose(12)
        return
    best_frame = 0
    best_score = 999.0
    for frame in range(control.getNumFrames()):
        control.pose(frame)
        score = abs(hold.getX(root) - 0.85) + abs(hold.getZ(root) - 0.2)
        if score < best_score:
            best_score = score
            best_frame = frame
    control.pose(best_frame)
    print(" posed", anim_relative, "frame", best_frame, "hold", tuple(round(v, 2) for v in hold.getPos(root)))


def bake_skinning(root: NodePath) -> None:
    thread = Thread.getCurrentThread()
    for path in root.findAllMatches("**/+GeomNode"):
        geom_node = path.node()
        for index in range(geom_node.getNumGeoms()):
            geom = geom_node.modifyGeom(index)
            vdata = geom.modifyVertexData()
            table = vdata.getTransformBlendTable()
            if table is None:
                continue
            positions = GeomVertexReader(vdata, "vertex")
            blends = GeomVertexReader(vdata, "transform_blend")
            points: list[Point3] = []
            for row in range(vdata.getNumRows()):
                positions.setRow(row)
                blends.setRow(row)
                point = Point3(positions.getData3())
                blend = table.getBlend(blends.getData1i())
                if blend.getNumTransforms():
                    blend.updateBlend(thread)
                    blend.transformPoint(point, thread)
                points.append(point)
            rewriter = GeomVertexRewriter(vdata, "vertex")
            for row, point in enumerate(points):
                rewriter.setRow(row)
                rewriter.setData3(point)


def hide_named(root: NodePath, pattern: str) -> None:
    found = root.findAllMatches(pattern)
    for index in range(found.getNumPaths()):
        found.getPath(index).hide()


def prepare_head(root: NodePath, head: str) -> None:
    species = head[0]
    long_muzzle = head[1] == "l"
    long_ears = head[2] == "l"
    if species != "d":
        if long_muzzle and long_ears:
            hide_named(root, "**/*short*")
        elif not long_muzzle and not long_ears:
            hide_named(root, "**/*long*")
        else:
            _hide_mixed(root, species, long_muzzle, long_ears)
    for token in ("surprise", "angry", "sad", "smile", "laugh"):
        hide_named(root, f"**/muzzle*{token}")
    eye_tex = Texture()
    if eye_tex.read(panda_path("phase_3/maps/eyes.png")):
        for path in root.findAllMatches("**/eyes*"):
            path.setTexture(eye_tex, 1)
    if species == "d":
        muzzle_file = {
            "dls": "phase_3/models/char/dogMM_Shorts-headMuzzles-1000.bam",
            "dss": "phase_3/models/char/dogMM_Skirt-headMuzzles-1000.bam",
            "dsl": "phase_3/models/char/dogSS_Shorts-headMuzzles-1000.bam",
            "dll": "phase_3/models/char/dogLL_Shorts-headMuzzles-1000.bam",
        }[head]
        muzzle = load_model(muzzle_file)
        anchor = root.find("**/def_head")
        if muzzle is not None and not anchor.isEmpty():
            muzzle.reparentTo(anchor)
            _KEEP.append(muzzle)
            for token in ("surprise", "angry", "sad", "smile", "laugh"):
                hide_named(muzzle, f"**/*{token}*")
    lashes = load_model(f"phase_3/models/char/{_SPECIES_FILE[species]}-lashes.bam")
    if lashes is not None:
        piece = "open-long" if long_muzzle else "open-short"
        found = lashes.find(f"**/{piece}")
        if not found.isEmpty():
            copied = found.copyTo(root)
            copied.setName("eyelashes")
            _KEEP.append(lashes)


def _hide_mixed(root: NodePath, species: str, long_muzzle: bool, long_ears: bool) -> None:
    if species not in ("f", "h"):
        if species == "r":
            hide_named(root, "**/ears-long" if not long_ears else "**/ears-short")
        else:
            hide_named(root, "**/ears-short" if not long_ears else "**/ears-long")
    if species != "r":
        hide_named(root, "**/eyes-short" if long_muzzle else "**/eyes-long")
    if species != "d":
        suffix = "short" if long_muzzle else "long"
        hide_named(root, f"**/joint_pupilL_{suffix}")
        hide_named(root, f"**/joint_pupilR_{suffix}")
    hide_named(root, "**/head-short" if long_muzzle else "**/head-long")
    hide_named(root, "**/head-front-short" if long_muzzle else "**/head-front-long")
    if species == "r":
        hide_named(root, "**/muzzle-short*" if long_muzzle else "**/muzzle-long*")
    else:
        hide_named(root, "**/muzzle-long*" if long_muzzle else "**/muzzle-short*")


_SPECIES_FILE = {
    "d": "dog",
    "c": "cat",
    "h": "horse",
    "m": "mouse",
    "r": "rabbit",
    "f": "duck",
    "p": "monkey",
    "b": "bear",
    "s": "pig",
}

_HEAD_FILE = {
    "dls": "phase_3/models/char/tt_a_chr_dgm_shorts_head_1000.bam",
    "dss": "phase_3/models/char/tt_a_chr_dgm_skirt_head_1000.bam",
    "dsl": "phase_3/models/char/tt_a_chr_dgs_shorts_head_1000.bam",
    "dll": "phase_3/models/char/tt_a_chr_dgl_shorts_head_1000.bam",
}


def write_gltf(root: NodePath, path: Path) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = writer.pack()
    path.write_bytes(payload)
    print(f"wrote {path.name} nodes={len(writer.nodes)} tris={writer.tri_count}")


def export_part(name: str, model_relative: str, anim_relative: str | None) -> None:
    root = load_model(model_relative)
    if root is None:
        return
    for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
        hide_named(root, pattern)
    if anim_relative:
        pose_neutral(root, anim_relative)
    bake_skinning(root)
    write_gltf(root, OUT / "parts" / f"{name}.glb")


def export_head(head: str) -> None:
    species = head[0]
    if head in _HEAD_FILE:
        relative = _HEAD_FILE[head]
        anim = relative.replace("_1000.bam", "_neutral.bam")
    else:
        relative = f"phase_3/models/char/{_SPECIES_FILE[species]}-heads-1000.bam"
        anim = None
    root = load_model(relative)
    if root is None:
        return
    prepare_head(root, head)
    if anim:
        pose_neutral(root, anim)
    bake_skinning(root)
    write_gltf(root, OUT / "heads" / f"{head}.glb")


def export_room() -> None:
    room = load_model("phase_3/models/makeatoon/tt_m_ara_mat_room.bam")
    if room is None:
        return
    root = NodePath("MakeAToonRoom")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    room.copyTo(root)
    write_gltf(root, OUT / "room.glb")


def save_cards() -> None:
    gui_dir = OUT / "gui"
    gui_dir.mkdir(parents=True, exist_ok=True)
    sources = [
        "phase_3/models/gui/tt_m_gui_pat_mainGui.bam",
        "phase_3/models/gui/tt_m_gui_mat_mainGui.bam",
        "phase_3/models/gui/quit_button.bam",
        "phase_3/models/gui/trashcan_gui.bam",
    ]
    for relative in sources:
        model = load_model(relative)
        if model is None:
            continue
        cards = model.findAllMatches("**/+GeomNode")
        for index in range(cards.getNumPaths()):
            card = cards.getPath(index)
            png = _card_png(card)
            if png is None:
                print("no image", card.getName())
                continue
            target = gui_dir / f"{exporter.sanitize(card.getName())}.png"
            target.write_bytes(png)
            print("card", target.name, len(png))


def _card_png(card: NodePath) -> bytes | None:
    node = card.node()
    if not isinstance(node, GeomNode) or node.getNumGeoms() == 0:
        return None
    state = node.getGeomState(0)
    attrib = state.getAttrib(TextureAttrib.getClassSlot())
    if attrib is None or attrib.getNumOnStages() == 0:
        return None
    stage = attrib.getOnStage(0)
    source = attrib.getOnTexture(stage)
    tex = Texture()
    filename = source.getFullpath()
    if filename.empty():
        filename = source.getFilename()
    if filename.empty() or not tex.read(filename):
        if not source.hasRamImage():
            return None
        tex = source
    if not tex.hasRamImage():
        return None
    raw = bytes(tex.getRamImageAs("RGBA"))
    width = tex.getXSize()
    height = tex.getYSize()
    if len(raw) != width * height * 4:
        return None
    vdata = node.getGeom(0).getVertexData()
    if not vdata.hasColumn("texcoord"):
        return exporter.encode_rgba_png(raw, width, height)
    reader = GeomVertexReader(vdata, "texcoord")
    us = []
    vs = []
    for row in range(vdata.getNumRows()):
        reader.setRow(row)
        u, v = reader.getData2()
        us.append(u)
        vs.append(v)
    pad = 1
    x0 = max(int(min(us) * width) - pad, 0)
    x1 = min(int(max(us) * width) + pad + 1, width)
    # Panda RAM images are bottom-up. Texture v=0 is the bottom row.
    y0 = max(int(min(vs) * height) - pad, 0)
    y1 = min(int(max(vs) * height) + pad + 1, height)
    if x1 <= x0 or y1 <= y0:
        return exporter.encode_rgba_png(raw, width, height)
    cropped = bytearray()
    row_bytes = width * 4
    for y in range(y0, y1):
        start = y * row_bytes + x0 * 4
        cropped.extend(raw[start:start + (x1 - x0) * 4])
    return exporter.encode_rgba_png(bytes(cropped), x1 - x0, y1 - y0)


def copy_clothes() -> None:
    clothes = OUT / "clothes"
    clothes.mkdir(parents=True, exist_ok=True)
    names = [
        "desat_shirt_1.png",
        "desat_shirt_2.png",
        "desat_sleeve_1.png",
        "desat_sleeve_2.png",
        "desat_shorts_1.png",
        "desat_shorts_2.png",
        "desat_skirt_1.png",
        "desat_shorts_5.png",
    ]
    maps = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets\phase_3\maps")
    for name in names:
        source = maps / name
        if source.exists():
            shutil.copyfile(source, clothes / name)
            print("clothes", name)
        else:
            print("missing clothes", name)
    music = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets\phase_3\audio\bgm\create_a_toon.ogg")
    audio = OUT / "audio"
    audio.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(music, audio / "create_a_toon.ogg")


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    copy_clothes()
    save_cards()
    export_room()
    for size, code in (("s", "dgs"), ("m", "dgm"), ("l", "dgl")):
        export_part(
            f"legs_{size}",
            f"phase_3/models/char/tt_a_chr_{code}_shorts_legs_1000.bam",
            f"phase_3/models/char/tt_a_chr_{code}_shorts_legs_neutral.bam",
        )
        export_part(
            f"torso_{size}s",
            f"phase_3/models/char/tt_a_chr_{code}_shorts_torso_1000.bam",
            f"phase_3/models/char/tt_a_chr_{code}_shorts_torso_neutral.bam",
        )
        export_part(
            f"torso_{size}d",
            f"phase_3/models/char/tt_a_chr_{code}_skirt_torso_1000.bam",
            f"phase_3/models/char/tt_a_chr_{code}_skirt_torso_neutral.bam",
        )
    heads = [
        "dls", "dss", "dsl", "dll",
        "cls", "css", "csl", "cll",
        "hls", "hss", "hsl", "hll",
        "mls", "mss",
        "rls", "rss", "rsl", "rll",
        "fls", "fss", "fsl", "fll",
        "pls", "pss", "psl", "pll",
        "bls", "bss", "bsl", "bll",
        "sls", "sss", "ssl", "sll",
    ]
    for head in heads:
        export_head(head)
    return 0


if __name__ == "__main__":
    sys.exit(main())
