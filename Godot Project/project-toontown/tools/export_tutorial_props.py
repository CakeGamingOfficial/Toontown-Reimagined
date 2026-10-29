"""Export the tutorial briefing props: gag icons, laff meter, posters, and the Flunky.

The Flunky is the original C-body sell... bossbot: suitC, flunky head, glasses,
and the corporate chest icon. Walk frames are baked the same way as the toon
walk sidecar so Godot can play them without a skinning importer.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.environ["PATH"] = GAME + os.pathsep + os.environ.get("PATH", "")
if not hasattr(os, "add_dll_directory"):
    os.add_dll_directory = lambda _path: None
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import (
    Filename,
    GeomNode,
    GeomVertexReader,
    Loader,
    NodePath,
    Texture,
    TextureAttrib,
    getModelPath,
    loadPrcFileData,
)

import export_make_a_toon as toon_export
import export_toon_walk as walk_export
import export_toontown_central as exporter

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "assets" / "gui" / "tutorial"
COG = ROOT / "assets" / "cogs"
ASSETS = toon_export.ASSETS

ICONS = (
    "inventory_tart",
    "inventory_squirt_flower",
    "inventory_feather",
    "inventory_bannana_peel",
    "inventory_1dollarbill",
    "inventory_bikehorn",
    "inventory_flower_pot",
)
LAFF_PARTS = (
    "doghead",
    "cathead",
    "mousehead",
    "horsehead",
    "bunnyhead",
    "duckhead",
    "monkeyhead",
    "bearhead",
    "pighead",
    "frown",
    "smile",
    "eyes",
    "open_smile",
    "tooth_1",
    "tooth_2",
    "tooth_3",
    "tooth_4",
    "tooth_5",
    "tooth_6",
)
POSTERS = ("suits", "toon_buildings", "suit_buildings", "squirt1", "squirt2")


def load(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    return NodePath(node)


def texture_on(node: NodePath) -> Texture | None:
    geom_node = node.node()
    if geom_node.isOfType(GeomNode.getClassType()):
        for index in range(geom_node.getNumGeoms()):
            attrib = geom_node.getGeomState(index).getAttrib(TextureAttrib.getClassSlot())
            if attrib is not None and attrib.getNumOnStages() > 0:
                return attrib.getOnTexture(attrib.getOnStage(0))
    attrib = node.getNetState().getAttrib(TextureAttrib.getClassSlot())
    if attrib is None or attrib.getNumOnStages() == 0:
        return None
    return attrib.getOnTexture(attrib.getOnStage(0))


def save_png(tex: Texture, path: Path) -> None:
    _key, png = exporter.texture_bytes(tex, {})
    if not png:
        raise RuntimeError("no pixels for " + path.name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def crop_card(node: NodePath, path: Path) -> None:
    """Save the texture region a flat GUI card actually displays."""
    geom_node = node.node()
    if not geom_node.isOfType(GeomNode.getClassType()):
        found = node.find("**/+GeomNode")
        if found.isEmpty():
            raise RuntimeError(path.name + " has no geometry")
        node = found
        geom_node = node.node()
    tex = texture_on(node)
    if tex is None:
        for child in node.findAllMatches("**/+GeomNode"):
            tex = texture_on(child)
            if tex is not None:
                node = child
                geom_node = child.node()
                break
    if tex is None:
        raise RuntimeError(path.name + " has no texture")
    if not tex.hasRamImage():
        loaded = Texture()
        if not loaded.read(exporter.texture_filename(tex)):
            raise RuntimeError(path.name + " texture did not load")
        tex = loaded
    raw = bytes(tex.getRamImageAs("RGBA"))
    width = tex.getXSize()
    height = tex.getYSize()
    u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
    us = []
    vs = []
    for geom_index in range(geom_node.getNumGeoms()):
        vdata = geom_node.getGeom(geom_index).getVertexData()
        if not vdata.hasColumn("texcoord"):
            continue
        reader = GeomVertexReader(vdata, "texcoord")
        for row in range(vdata.getNumRows()):
            reader.setRow(row)
            u, v = reader.getData2()
            us.append(u)
            vs.append(v)
        break
    if us:
        u0, u1 = min(us), max(us)
        v0, v1 = min(vs), max(vs)
    # Panda RAM is bottom-up. V grows up.
    x0 = max(0, min(width - 1, int(u0 * width)))
    x1 = max(x0 + 1, min(width, int(round(u1 * width))))
    y0 = max(0, min(height - 1, int(v0 * height)))
    y1 = max(y0 + 1, min(height, int(round(v1 * height))))
    cropped_w = x1 - x0
    cropped_h = y1 - y0
    rows = bytearray()
    for y in range(y0, y1):
        start = (y * width + x0) * 4
        rows.extend(raw[start:start + cropped_w * 4])
    png = exporter.encode_rgba_png(bytes(rows), cropped_w, cropped_h)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    print(f"card {path.name} {cropped_w}x{cropped_h}", flush=True)


def export_gui() -> None:
    icons = load("phase_3.5/models/gui/inventory_icons.bam")
    for name in ICONS:
        node = icons.find("**/" + name)
        if node.isEmpty():
            print("missing icon", name)
            continue
        crop_card(node, GUI / "gags" / f"{name}.png")
    buttons = load("phase_3.5/models/gui/inventory_gui.bam")
    for name in ("InventoryButtonUp", "InventoryButtonFlat", "InventoryRow"):
        node = buttons.find("**/" + name)
        if node.isEmpty():
            print("missing", name)
            continue
        crop_card(node, GUI / f"{name}.png")
    laff = load("phase_3/models/gui/laff_o_meter.bam")
    print("laff nodes:")
    for child in laff.findAllMatches("**/*"):
        if child.node().isOfType(GeomNode.getClassType()):
            print(" ", child.getName())
    for name in LAFF_PARTS:
        node = laff.find("**/" + name)
        if node.isEmpty():
            print("missing laff", name)
            continue
        crop_card(node, GUI / "laff" / f"{name}.png")
    posters = load("phase_3.5/models/gui/tutorial_gui.bam")
    print("poster nodes:")
    for child in posters.findAllMatches("*"):
        print(" ", child.getName())
    for name in POSTERS:
        node = posters.find("**/" + name)
        if node.isEmpty():
            print("missing poster", name)
            continue
        crop_card(node, GUI / "posters" / f"{name}.png")
    book = load("phase_3.5/models/gui/stickerbook_gui.bam")
    for name in (
        "questCard",
        "big_book",
        "BookIcon_CLSD",
        "BookIcon_OPEN",
        "BookIcon_RLVR",
        "arrow_button",
    ):
        card = book.find("**/" + name)
        if card.isEmpty():
            print("missing book card", name)
            continue
        crop_card(card, GUI / "book" / f"{name}.png")
    world = load("phase_3.5/models/gui/toontown_map.bam")
    world_card = world.find("**/toontown_map")
    if world_card.isEmpty():
        world_card = world
    crop_card(world_card, GUI / "book" / "toontown_map.png")
    icons_model = load("phase_3/models/gui/cog_icons.bam")
    corp = icons_model.find("**/CorpIcon")
    if not corp.isEmpty():
        crop_card(corp, GUI / "corp_icon.png")


def paint_flunky(model: NodePath) -> None:
    for part, filename in (
        ("torso", "phase_3.5/maps/c_blazer.png"),
        ("arms", "phase_3.5/maps/c_sleeve.png"),
        ("legs", "phase_3.5/maps/c_leg.png"),
    ):
        piece = model.find("**/" + part)
        if piece.isEmpty():
            print("missing suit part", part)
            continue
        tex = Texture()
        if not tex.read(Filename(ASSETS, filename)):
            raise RuntimeError("missing " + filename)
        piece.setTexture(tex, 1)
    hands = model.find("**/hands")
    if not hands.isEmpty():
        hands.setColor(0.95, 0.75, 0.75, 1.0)
    heads = load("phase_3.5/models/char/suitC-heads.bam")
    joint = model.find("**/joint_head")
    if joint.isEmpty():
        raise RuntimeError("suit has no joint_head")
    for name in ("flunky", "glasses"):
        found = heads.find("**/" + name)
        if found.isEmpty():
            print("missing head", name)
            continue
        found.copyTo(joint)
    chest = model.find("**/joint_attachMeter")
    icons = load("phase_3/models/gui/cog_icons.bam")
    medallion = icons.find("**/CorpIcon")
    if not chest.isEmpty() and not medallion.isEmpty():
        badge = medallion.copyTo(chest)
        badge.setPosHprScale(0.02, 0.05, 0.04, 180.0, 0.0, 0.0, 0.51, 0.51, 0.51)


def export_flunky() -> None:
    model = load("phase_3.5/models/char/suitC-mod.bam")
    paint_flunky(model)
    print("--- flunky geoms ---")
    for path in model.findAllMatches("**/+GeomNode"):
        parent = path.getParent().getName()
        print(f"  {path.getName()} parent={parent} geoms={path.node().getNumGeoms()}")
    saved = walk_export.snapshot(model)
    neutral = walk_export.bind_anim(model, "phase_3.5/models/char/suitC-neutral.bam")
    walk_export.restore(model, saved)
    character = model.find("**/+Character")
    bundle = character.node().getBundle(0)
    bundle.setControlEffect(neutral, 1.0)
    neutral.pose(0)
    bundle.forceUpdate()
    toon_export.bake_skinning(model)

    root = NodePath("Flunky")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    model.setScale(4.0 / 4.14)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    out = COG / "flunky.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(writer.pack("Flunky"))
    print(f"wrote {out.name} meshes={writer.mesh_count}", flush=True)

    model.detachNode()
    walk_export.restore(model, saved)
    walk = walk_export.bind_anim(model, "phase_3.5/models/char/suitC-walk.bam")
    frame_count = walk.getNumFrames()
    joint_nodes = []
    for name in ("joint_head", "joint_attachMeter"):
        found = model.find("**/" + name)
        if found.isEmpty():
            print("missing joint", name)
            continue
        joint_nodes.append(name)
        print("joint", name, "type", found.node().getType())
    names = joint_nodes
    walked = []
    joint_frames = {name: [] for name in names}
    for frame in range(frame_count):
        walk_export.restore(model, saved)
        bundle = model.find("**/+Character").node().getBundle(0)
        bundle.setControlEffect(walk, 1.0)
        walk.pose(frame)
        bundle.forceUpdate()
        toon_export.bake_skinning(model)
        walked.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, tuple(names)):
            joint_frames[joint_name].append(matrix)
    # Bind is the standing glb's joint, which is neutral frame 0 baked into the nodes.
    # The walk sidecar stores the joints as they are during the walk, and the
    # player applies them as absolute local transforms of those nodes.
    bind = {}
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(neutral, 1.0)
    neutral.pose(0)
    bundle.forceUpdate()
    for joint_name, matrix in walk_export.joint_matrices(model, tuple(names)):
        bind[joint_name] = matrix
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for frame in walked:
                _name, frame_surfaces = frame[node_index]
                posed, _uv = frame_surfaces[surface_index]
                frames.append(posed)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    walk_path = COG / "flunky.walk"
    walk_export.write_walk(
        walk_path,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    print(f"wrote walk frames={frame_count} joints={len(names)} bytes={walk_path.stat().st_size}", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    export_gui()
    export_flunky()
    return 0


if __name__ == "__main__":
    sys.exit(main())
