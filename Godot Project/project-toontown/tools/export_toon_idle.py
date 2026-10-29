"""Write the original neutral cycle beside the standing leg and torso models.

Neutral is the idle the game loops while a toon is standing still: 50 frames
at 24 fps. The sidecar uses the same layout as the walk files.
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

from panda3d.core import (
    Filename,
    GeomNode,
    GeomVertexReader,
    GeomVertexRewriter,
    Loader,
    NodePath,
    Point3,
    Thread,
    getModelPath,
    loadPrcFileData,
)

import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "toons" / "anims"
PARTS_DIR = OUT.parent / "parts"
_KEEP: list[NodePath] = []

PARTS = [
    (
        "legs_s",
        "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_shorts_legs_neutral.bam",
    ),
    (
        "legs_m",
        "phase_3/models/char/tt_a_chr_dgm_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_shorts_legs_neutral.bam",
    ),
    (
        "legs_l",
        "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_shorts_legs_neutral.bam",
    ),
    (
        "torso_ss",
        "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_shorts_torso_neutral.bam",
    ),
    (
        "torso_ms",
        "phase_3/models/char/tt_a_chr_dgm_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_shorts_torso_neutral.bam",
    ),
    (
        "torso_ls",
        "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_shorts_torso_neutral.bam",
    ),
    (
        "torso_sd",
        "phase_3/models/char/tt_a_chr_dgs_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_skirt_torso_neutral.bam",
    ),
    (
        "torso_md",
        "phase_3/models/char/tt_a_chr_dgm_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_skirt_torso_neutral.bam",
    ),
    (
        "torso_ld",
        "phase_3/models/char/tt_a_chr_dgl_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_skirt_torso_neutral.bam",
    ),
]


def load_model(relative: str) -> NodePath | None:
    node = Loader.getGlobalPtr().loadSync(Filename(ASSETS, relative))
    if node is None:
        print("missing", relative)
        return None
    return NodePath(node)


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


def snapshot(root):
    saved = []
    for path in root.findAllMatches("**/+GeomNode"):
        node = path.node()
        geoms = []
        for index in range(node.getNumGeoms()):
            vdata = node.getGeom(index).getVertexData()
            reader = GeomVertexReader(vdata, "vertex")
            points = []
            for row in range(vdata.getNumRows()):
                reader.setRow(row)
                value = reader.getData3()
                points.append(Point3(value.x, value.y, value.z))
            geoms.append(points)
        saved.append(geoms)
    return saved


def restore(root, saved) -> None:
    geom_nodes = root.findAllMatches("**/+GeomNode")
    for node_index in range(geom_nodes.getNumPaths()):
        node = geom_nodes.getPath(node_index).node()
        for index, points in enumerate(saved[node_index]):
            rewriter = GeomVertexRewriter(node.modifyGeom(index).modifyVertexData(), "vertex")
            for row, point in enumerate(points):
                rewriter.setRow(row)
                rewriter.setData3(point)


def surface_attributes(np):
    geom_node = np.node()
    surfaces = []
    for geom_index in range(geom_node.getNumGeoms()):
        geom = exporter.bake_skin(geom_node.getGeom(geom_index))
        state = np.getNetState().compose(geom_node.getGeomState(geom_index))
        vdata = geom.getVertexData()
        if vdata.getNumRows() == 0:
            continue
        triangles = exporter.triangle_indices(geom)
        if len(triangles) < 3:
            continue
        positions = exporter.read_column(vdata, "vertex", exporter.copy3)
        out_pos = exporter.position_strip(positions, triangles, state, np)
        out_uv = []
        if vdata.hasColumn("texcoord"):
            raw = exporter.read_column(vdata, "texcoord", exporter.copy2)
            tex_matrix = None
            tex_attrib = state.getAttrib(exporter.TextureAttrib.getClassSlot())
            if tex_attrib is not None and tex_attrib.getNumOnStages() > 0:
                stage = tex_attrib.getOnStage(0)
                matrix_attrib = state.getAttrib(exporter.TexMatrixAttrib.getClassSlot())
                if matrix_attrib is not None and matrix_attrib.hasStage(stage):
                    tex_matrix = matrix_attrib.getTransform(stage).getMat()
            for index in triangles:
                u, v = raw[index]
                if tex_matrix is not None:
                    transformed = tex_matrix.xform(exporter.Vec3(u, v, 1.0))
                    u, v = transformed.x, transformed.y
                out_uv.append((u, 1.0 - v))
        surfaces.append((out_pos, out_uv))
    return surfaces


def collect_named(root):
    groups = []

    def walk(node):
        if node.node().isOfType(GeomNode.getClassType()):
            surfaces = surface_attributes(node)
            if surfaces:
                groups.append((exporter.sanitize(node.getName()), surfaces))
        for child in exporter.visit_children(node):
            walk(child)

    walk(root)
    return groups


def bind_anim(root, relative: str):
    anim = load_model(relative)
    if anim is None:
        raise RuntimeError("missing " + relative)
    bundle_node = anim.find("**/+AnimBundleNode")
    character = root.find("**/+Character")
    bundle = bundle_node.node().getBundle()
    control = character.node().getBundle(0).bindAnim(bundle, -1)
    _KEEP.append(anim)
    return control, bundle.getBaseFrameRate()


def joint_names(part: str) -> tuple[str, ...]:
    if part.startswith("legs_"):
        return ("joint_hips",)
    return ("def_head",)


def joint_matrices(root, names: tuple[str, ...]) -> list[tuple[str, list[float]]]:
    found = []
    for name in names:
        node = root.find("**/" + name)
        if node.isEmpty():
            raise RuntimeError("missing joint " + name)
        mat = node.getTransform(node.getParent()).getMat()
        found.append((name, [mat.getCell(row, col) for row in range(4) for col in range(4)]))
    return found


def glb_bind(part: str, names: tuple[str, ...]) -> dict[str, list[float]]:
    data = (PARTS_DIR / f"{part}.glb").read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    found = {}
    for node in document["nodes"]:
        if node["name"] in names and "matrix" in node:
            found[node["name"]] = [float(value) for value in node["matrix"]]
    missing = [name for name in names if name not in found]
    if missing:
        raise RuntimeError(part + " missing " + ", ".join(missing))
    return found


def posed_surfaces(root, saved, control, frame: int):
    restore(root, saved)
    character = root.find("**/+Character")
    bundle = character.node().getBundle(0)
    bundle.setControlEffect(control, 1.0)
    control.pose(frame)
    bundle.forceUpdate()
    bake_skinning(root)
    return collect_named(root)


def write_clip(path: Path, frame_count: int, nodes, joints) -> None:
    blob = bytearray()
    blob += b"TWALK3\0\0"
    blob += struct.pack("<II", frame_count, len(nodes))
    for name, surfaces in nodes:
        encoded = name.encode("utf-8")
        blob += struct.pack("<H", len(encoded))
        blob += encoded
        blob += struct.pack("<I", len(surfaces))
        for uvs, frames in surfaces:
            vertex_count = len(frames[0])
            blob += struct.pack("<IB", vertex_count, 1 if uvs else 0)
            if uvs:
                blob += b"".join(struct.pack("<2f", u, v) for u, v in uvs)
            for frame in frames:
                blob += b"".join(struct.pack("<3f", *point) for point in frame)
    blob += struct.pack("<I", len(joints))
    for name, bind, frames in joints:
        encoded = name.encode("utf-8")
        blob += struct.pack("<H", len(encoded))
        blob += encoded
        blob += struct.pack("<16f", *bind)
        for frame in frames:
            blob += struct.pack("<16f", *frame)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


def export_part(name: str, model: str, anim: str, suffix: str) -> None:
    root = load_model(model)
    if root is None:
        raise RuntimeError("missing " + model)
    for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
        found = root.findAllMatches(pattern)
        for index in range(found.getNumPaths()):
            found.getPath(index).hide()
    saved = snapshot(root)
    names = joint_names(name)
    bind = glb_bind(name, names)
    control, rate = bind_anim(root, anim)
    frame_count = control.getNumFrames()
    posed_frames = []
    joint_frames = {joint_name: [] for joint_name in names}
    for frame in range(frame_count):
        posed_frames.append(posed_surfaces(root, saved, control, frame))
        for joint_name, matrix in joint_matrices(root, names):
            joint_frames[joint_name].append(matrix)
    if not posed_frames or not posed_frames[0]:
        raise RuntimeError(name + " produced no " + suffix + " surfaces")
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(posed_frames[0]):
        packed = []
        for surface_index, (_base_pos, uvs) in enumerate(surfaces):
            frames = []
            for frame in posed_frames:
                posed_name, frame_surfaces = frame[node_index]
                if posed_name != node_name:
                    raise RuntimeError(f"{name} node order changed at {node_name}")
                posed, _posed_uv = frame_surfaces[surface_index]
                frames.append(posed)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = OUT / f"{name}.{suffix}"
    write_clip(
        path,
        frame_count,
        nodes,
        [(joint_name, bind[joint_name], joint_frames[joint_name]) for joint_name in names],
    )
    print(
        f"wrote {name} frames={frame_count} rate={rate:.1f} nodes={len(nodes)} bytes={path.stat().st_size}",
        flush=True,
    )


def anim_path(model: str, phase: str, suffix: str) -> str:
    relative = model.replace("phase_3/", phase + "/", 1)
    return relative.replace("_1000.bam", suffix)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(ASSETS)
    # Run is the forward cycle. jump-zhang is the standing hop held in the air.
    # leap_zhang is the same hop while running. Neutral is exported separately.
    jobs = [
        ("run", "phase_3", "_run.bam"),
        ("jump", "phase_3.5", "_jump-zhang.bam"),
        ("rjump", "phase_3.5", "_leap_zhang.bam"),
        ("land", "phase_3.5", "_jump-zend.bam"),
        ("rland", "phase_3.5", "_leap_zend.bam"),
    ]
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, model, neutral in PARTS:
        if which == "idle":
            export_part(name, model, neutral, "idle")
            continue
        for suffix, phase, ending in jobs:
            if which in ("", suffix):
                export_part(name, model, anim_path(model, phase, ending), suffix)
    return 0


if __name__ == "__main__":
    sys.exit(main())
