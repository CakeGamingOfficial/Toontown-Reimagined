"""Write the original 24-frame walk beside the standing leg and torso models.

The part glbs stay free of morph targets. Godot's compatibility renderer
crashes when Pick a Toon instances those meshes. ToonActor loads the .walk
sidecar the first time a toon moves.
"""
from __future__ import annotations

import json
import os
import struct
import sys
from pathlib import Path

GAME = r"C:\Users\fukuy\Documents\TTAP\TTAP-0.20.4\game"
os.environ["PATH"] = GAME + os.pathsep + os.environ.get("PATH", "")
os.add_dll_directory(GAME)
sys.path.insert(0, GAME)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from panda3d.core import GeomNode, GeomVertexReader, GeomVertexRewriter, Point3

import export_make_a_toon as toon_export
import export_toontown_central as exporter

OUT = Path(__file__).resolve().parents[1] / "assets" / "toons" / "anims"

PARTS = [
    (
        "legs_s",
        "phase_3/models/char/tt_a_chr_dgs_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_shorts_legs_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgs_shorts_legs_walk.bam",
    ),
    (
        "legs_m",
        "phase_3/models/char/tt_a_chr_dgm_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_shorts_legs_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgm_shorts_legs_walk.bam",
    ),
    (
        "legs_l",
        "phase_3/models/char/tt_a_chr_dgl_shorts_legs_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_shorts_legs_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgl_shorts_legs_walk.bam",
    ),
    (
        "torso_ss",
        "phase_3/models/char/tt_a_chr_dgs_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_shorts_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgs_shorts_torso_walk.bam",
    ),
    (
        "torso_ms",
        "phase_3/models/char/tt_a_chr_dgm_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_shorts_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgm_shorts_torso_walk.bam",
    ),
    (
        "torso_ls",
        "phase_3/models/char/tt_a_chr_dgl_shorts_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_shorts_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgl_shorts_torso_walk.bam",
    ),
    (
        "torso_sd",
        "phase_3/models/char/tt_a_chr_dgs_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgs_skirt_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgs_skirt_torso_walk.bam",
    ),
    (
        "torso_md",
        "phase_3/models/char/tt_a_chr_dgm_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgm_skirt_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgm_skirt_torso_walk.bam",
    ),
    (
        "torso_ld",
        "phase_3/models/char/tt_a_chr_dgl_skirt_torso_1000.bam",
        "phase_3/models/char/tt_a_chr_dgl_skirt_torso_neutral.bam",
        "phase_3.5/models/char/tt_a_chr_dgl_skirt_torso_walk.bam",
    ),
]


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
    # Same triangle expansion as the part glb, so UVs line up with the standing mesh.
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
    anim = toon_export.load_model(relative)
    if anim is None:
        raise RuntimeError("missing " + relative)
    bundle_node = anim.find("**/+AnimBundleNode")
    character = root.find("**/+Character")
    control = character.node().getBundle(0).bindAnim(bundle_node.node().getBundle(), -1)
    toon_export._KEEP.append(anim)
    return control


def joint_names(part: str) -> tuple[str, ...]:
    # The torso is parented to the hip joint and the head to def_head.
    # Those nodes have to follow the walk or the baked meshes leave them behind.
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


PARTS_DIR = OUT.parent / "parts"


def glb_bind(part: str, names: tuple[str, ...]) -> dict[str, list[float]]:
    # Read the joint matrices out of the standing model so the walk is a change
    # from the pose Godot already shows.
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
    # pose() only records the frame. Joints update when the bundle is forced.
    bundle.forceUpdate()
    toon_export.bake_skinning(root)
    return collect_named(root)


def write_walk(path: Path, frame_count: int, nodes, joints: list[tuple[str, list[float], list[list[float]]]]) -> None:
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
        if len(bind) != 16:
            raise RuntimeError(name + " bind matrix")
        blob += struct.pack("<16f", *bind)
        for frame in frames:
            if len(frame) != 16:
                raise RuntimeError(name + " joint matrix")
            blob += struct.pack("<16f", *frame)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


def export_part(name: str, model: str, neutral: str, walk: str) -> None:
    root = toon_export.load_model(model)
    if root is None:
        raise RuntimeError("missing " + model)
    for pattern in ("**/boots_short", "**/boots_long", "**/shoes"):
        toon_export.hide_named(root, pattern)
    saved = snapshot(root)
    names = joint_names(name)
    bind = glb_bind(name, names)
    walk_control = bind_anim(root, walk)
    frame_count = walk_control.getNumFrames()
    names = joint_names(name)
    walked = []
    joint_frames = {joint_name: [] for joint_name in names}
    for frame in range(frame_count):
        walked.append(posed_surfaces(root, saved, walk_control, frame))
        for joint_name, matrix in joint_matrices(root, names):
            joint_frames[joint_name].append(matrix)
    if not walked or not walked[0]:
        raise RuntimeError(name + " produced no walk surfaces")
    peak = 0.0
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (base_pos, uvs) in enumerate(surfaces):
            frames = []
            for frame in walked:
                posed_name, frame_surfaces = frame[node_index]
                if posed_name != node_name:
                    raise RuntimeError(f"{name} node order changed at {node_name}")
                posed, posed_uv = frame_surfaces[surface_index]
                if len(posed) != len(base_pos) or len(posed_uv) != len(uvs):
                    raise RuntimeError(f"{name} {node_name} vertex count changed")
                for left, right in zip(base_pos, posed):
                    peak = max(peak, abs(left[0] - right[0]), abs(left[1] - right[1]), abs(left[2] - right[2]))
                frames.append(posed)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    path = OUT / f"{name}.walk"
    write_walk(
        path,
        frame_count,
        nodes,
        [(joint_name, bind[joint_name], joint_frames[joint_name]) for joint_name in names],
    )
    print(
        f"wrote {name} frames={frame_count} nodes={len(nodes)} peak={peak:.3f} bytes={path.stat().st_size}",
        flush=True,
    )


def main() -> int:
    toon_export.loadPrcFileData("", "window-type none")
    toon_export.loadPrcFileData("", "audio-library-name null")
    toon_export.getModelPath().prependDirectory(toon_export.ASSETS)
    for name, model, neutral, walk in PARTS:
        export_part(name, model, neutral, walk)
    return 0


if __name__ == "__main__":
    sys.exit(main())
