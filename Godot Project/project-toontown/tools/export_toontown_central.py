"""Build a Y-up glTF of Toontown Central's playground from the original DNA.

Load order matches the client: storage.dna, storage_TT.dna, storage_TT_sz.dna,
then toontown_central_sz.dna. Panda is Z-up; the export root applies one
transform so the glTF is Y-up for Godot.
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

from panda3d.core import (
    CollisionNode,
    ColorAttrib,
    ColorScaleAttrib,
    CullFaceAttrib,
    BillboardEffect,
    DecalEffect,
    DepthOffsetAttrib,
    Filename,
    Geom,
    GeomNode,
    GeomVertexReader,
    LODNode,
    Loader,
    LPoint3f,
    Mat4,
    NodePath,
    TexMatrixAttrib,
    Texture,
    TextureAttrib,
    TransparencyAttrib,
    Vec3,
    Vec4,
    getModelPath,
)
from panda3d.toontown import DNAStorage, loadDNAFile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Filename.from_os_specific(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown\Original Toontown Assets\Game Assets"
)
OUT = ROOT / "assets" / "neighborhoods" / "toontown_central" / "toontown_central.glb"

# Panda multiplies row vectors. (x, y, z) -> (x, z, -y). Determinant is +1.
Z_UP_TO_Y_UP = Mat4(
    1, 0, 0, 0,
    0, 0, -1, 0,
    0, 1, 0, 0,
    0, 0, 0, 1,
)

DNA_FILES = [
    "phase_4/dna/storage.dna",
    "phase_4/dna/storage_TT.dna",
    "phase_4/dna/storage_TT_sz.dna",
    "phase_4/dna/toontown_central_sz.dna",
]


def panda_path(relative: str) -> str:
    return str(Filename(ASSETS, relative))


def load_playground() -> NodePath:
    getModelPath().prependDirectory(ASSETS)
    store = DNAStorage()
    node = None
    for relative in DNA_FILES:
        print("loading", relative)
        node = loadDNAFile(store, panda_path(relative), 0)
    if node is None:
        raise RuntimeError("DNA loader returned no playground")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)

    loader = Loader.getGlobalPtr()
    sky_node = loader.loadSync(panda_path("phase_3.5/models/props/TT_sky.bam"))
    sky = NodePath(sky_node)
    sky.setName("Sky")

    root = NodePath("ToontownCentral")
    root.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(root)
    sky.copyTo(root)
    return root


def bake_skin(geom: Geom) -> Geom:
    # Joint weights stay in the bind pose. These props (periscope, telescope,
    # fish) are modeled in that pose, which is the pose shown in the playground.
    return geom


def texture_filename(tex: Texture):
    filename = tex.getFullpath()
    if filename.empty():
        filename = tex.getFilename()
    return filename


def encode_rgba_png(raw: bytes, width: int, height: int) -> bytes:
    """Panda RAM images are bottom-up. PNG rows are top-down."""
    row_bytes = width * 4

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    rows = bytearray()
    for y in range(height - 1, -1, -1):
        rows.append(0)
        start = y * row_bytes
        rows.extend(raw[start:start + row_bytes])
    return b"".join([
        b"\x89PNG\r\n\x1a\n",
        chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(bytes(rows), 6)),
        chunk(b"IEND", b""),
    ])


def texture_bytes(tex: Texture, cache: dict) -> tuple[tuple | None, bytes | None]:
    """Return a cache key and PNG for this texture's current pixels.

    File textures stay keyed by path. Dynamic font pages have no filename and
    are rewritten in place as more signs are built, so they are keyed by the
    pixels themselves. Keying those by object id keeps the first snapshot and
    points later letters at the wrong characters.
    """
    source = tex
    filename = texture_filename(source)
    file_key = None
    if not filename.empty():
        file_key = ("file", str(filename), source.getXSize(), source.getYSize(), source.getFormat())
        if file_key in cache:
            return file_key, cache[file_key]
        if not source.hasRamImage():
            loaded = Texture()
            if loaded.read(filename):
                source = loaded
    if not source.hasRamImage():
        if file_key is not None:
            cache[file_key] = None
        return file_key, None
    # "RGBA" expands gray+alpha fonts and RGBM masks into a channel layout glTF understands.
    raw = bytes(source.getRamImageAs("RGBA"))
    expected = source.getXSize() * source.getYSize() * 4
    if len(raw) != expected:
        if file_key is not None:
            cache[file_key] = None
        return file_key, None
    if file_key is None:
        key = ("ram", hashlib.md5(raw).hexdigest(), source.getXSize(), source.getYSize(), source.getFormat())
        cached = cache.get(key, False)
        if cached is not False:
            return key, cached
    else:
        key = file_key
    data = encode_rgba_png(raw, source.getXSize(), source.getYSize())
    cache[key] = data
    return key, data


def sanitize(name: str) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in name)
    cleaned = cleaned.strip("_")
    return cleaned or "node"


class GltfWriter:
    def __init__(self) -> None:
        self.buffer = bytearray()
        self.buffer_views: list[dict] = []
        self.accessors: list[dict] = []
        self.meshes: list[dict] = []
        self.materials: list[dict] = []
        self.textures: list[dict] = []
        self.images: list[dict] = []
        self.samplers: list[dict] = []
        self.nodes: list[dict] = []
        self.material_ids: dict[tuple, int] = {}
        self.image_ids: dict[tuple, int] = {}
        self.sampler_ids: dict[tuple, int] = {}
        self.texture_cache: dict[int, bytes | None] = {}
        self.mesh_count = 0
        self.tri_count = 0
        self.skipped_empty = 0
        self.billboards = 0

    def align(self, n: int = 4) -> None:
        while len(self.buffer) % n:
            self.buffer.append(0)

    def add_bytes(self, data: bytes, target: int | None = None) -> int:
        self.align(4)
        offset = len(self.buffer)
        self.buffer.extend(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            view["target"] = target
        self.buffer_views.append(view)
        return len(self.buffer_views) - 1

    def add_accessor(self, view: int, comp_type: int, count: int, type_name: str, mins=None, maxs=None) -> int:
        accessor = {
            "bufferView": view,
            "componentType": comp_type,
            "count": count,
            "type": type_name,
        }
        if mins is not None:
            accessor["min"] = mins
            accessor["max"] = maxs
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def sampler_index(self, tex: Texture) -> int:
        wrap_map = {
            Texture.WM_clamp: 33071,
            Texture.WM_border_color: 33071,
            Texture.WM_mirror: 33648,
            Texture.WM_mirror_once: 33648,
            Texture.WM_repeat: 10497,
        }
        wrap_u = tex.getWrapU()
        wrap_v = tex.getWrapV()
        # Godot turns repeat off for both axes when either axis clamps.
        # These textures repeat along the fence or awning and only clamp vertically.
        if wrap_u == Texture.WM_repeat or wrap_v == Texture.WM_repeat:
            wrap_u = Texture.WM_repeat
            wrap_v = Texture.WM_repeat
        key = (wrap_map.get(wrap_u, 10497), wrap_map.get(wrap_v, 10497))
        if key not in self.sampler_ids:
            self.samplers.append({"wrapS": key[0], "wrapT": key[1], "magFilter": 9729, "minFilter": 9987})
            self.sampler_ids[key] = len(self.samplers) - 1
        return self.sampler_ids[key]

    def texture_index(self, tex: Texture) -> int | None:
        key, png = texture_bytes(tex, self.texture_cache)
        if not png or key is None:
            return None
        if key not in self.image_ids:
            view = self.add_bytes(png)
            self.images.append({"bufferView": view, "mimeType": "image/png"})
            self.textures.append({"sampler": self.sampler_index(tex), "source": len(self.images) - 1})
            self.image_ids[key] = len(self.textures) - 1
        return self.image_ids[key]

    def material_index(self, state, tex: Texture | None) -> int:
        color = Vec4(1, 1, 1, 1)
        color_attrib = state.getAttrib(ColorAttrib.getClassSlot())
        if color_attrib is not None and color_attrib.getColorType() == ColorAttrib.T_flat:
            color = color_attrib.getColor()
        scale_attrib = state.getAttrib(ColorScaleAttrib.getClassSlot())
        if scale_attrib is not None:
            scale = scale_attrib.getScale()
            color = Vec4(color.x * scale.x, color.y * scale.y, color.z * scale.z, color.w * scale.w)

        transparency = state.getAttrib(TransparencyAttrib.getClassSlot())
        mode = transparency.getMode() if transparency is not None else TransparencyAttrib.M_none
        if mode in (TransparencyAttrib.M_binary, TransparencyAttrib.M_dual, TransparencyAttrib.M_multisample_mask):
            alpha_mode = "MASK"
        elif mode in (TransparencyAttrib.M_alpha, TransparencyAttrib.M_premultiplied_alpha) or color.w < 0.99:
            alpha_mode = "BLEND"
        else:
            alpha_mode = "OPAQUE"

        cull = state.getAttrib(CullFaceAttrib.getClassSlot())
        double_sided = cull is not None and cull.getEffectiveMode() == CullFaceAttrib.M_cull_none

        tex_index = self.texture_index(tex) if tex is not None else None

        factor = [round(color.x, 5), round(color.y, 5), round(color.z, 5), round(color.w, 5)]
        key = (tex_index, tuple(factor), alpha_mode, double_sided)
        if key in self.material_ids:
            return self.material_ids[key]

        material = {
            "name": f"mat_{len(self.materials)}",
            "doubleSided": double_sided,
            "alphaMode": alpha_mode,
            "pbrMetallicRoughness": {
                "baseColorFactor": factor,
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
            },
        }
        if alpha_mode == "MASK":
            material["alphaCutoff"] = 0.5
        if tex_index is not None:
            material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": tex_index}
        self.materials.append(material)
        self.material_ids[key] = len(self.materials) - 1
        return self.material_ids[key]

    def mesh_from_geom_node(self, np: NodePath) -> int | None:
        geom_node = np.node()
        primitives = []
        for geom_index in range(geom_node.getNumGeoms()):
            geom = bake_skin(geom_node.getGeom(geom_index))
            state = np.getNetState().compose(geom_node.getGeomState(geom_index))
            primitive = self.primitive_from_geom(geom, state, np)
            if primitive is not None:
                primitives.append(primitive)
        if not primitives:
            self.skipped_empty += 1
            return None
        self.meshes.append({"name": sanitize(np.getName()), "primitives": primitives})
        self.mesh_count += 1
        return len(self.meshes) - 1

    def primitive_from_geom(self, geom: Geom, state, np: NodePath) -> dict | None:
        vdata = geom.getVertexData()
        if vdata.getNumRows() == 0:
            return None
        # Copy each column before the next read. Panda reuses the returned vector,
        # so holding onto getData4() makes every vertex the last sample.
        positions = read_column(vdata, "vertex", copy3)
        uvs = read_column(vdata, "texcoord", copy2) if vdata.hasColumn("texcoord") else []
        colors = read_column(vdata, "color", copy4) if vdata.hasColumn("color") else []

        tex_matrix = None
        tex_attrib = state.getAttrib(TextureAttrib.getClassSlot())
        tex = None
        if tex_attrib is not None and tex_attrib.getNumOnStages() > 0:
            stage = tex_attrib.getOnStage(0)
            tex = tex_attrib.getOnTexture(stage)
            matrix_attrib = state.getAttrib(TexMatrixAttrib.getClassSlot())
            if matrix_attrib is not None and matrix_attrib.hasStage(stage):
                tex_matrix = matrix_attrib.getTransform(stage).getMat()

        triangles = triangle_indices(geom)
        if len(triangles) < 3:
            return None

        out_pos = position_strip(positions, triangles, state, np)
        out_uv: list[tuple[float, float]] = []
        out_color: list[tuple[float, float, float, float]] = []
        for index in triangles:
            if uvs:
                u, v = uvs[index]
                if tex_matrix is not None:
                    transformed = tex_matrix.xform(Vec3(u, v, 1))
                    u, v = transformed.x, transformed.y
                # glTF UV origin is top-left; Panda's is bottom-left.
                out_uv.append((u, 1.0 - v))
            if colors:
                out_color.append(colors[index])

        normals = smooth_normals(out_pos)
        self.tri_count += len(out_pos) // 3

        attributes = {
            "POSITION": self.vec3_accessor(out_pos),
            "NORMAL": self.vec3_accessor(normals, bounds=False),
        }
        if out_uv:
            attributes["TEXCOORD_0"] = self.vec2_accessor(out_uv)
        if out_color:
            attributes["COLOR_0"] = self.vec4_accessor(out_color)

        return {
            "attributes": attributes,
            "material": self.material_index(state, tex),
        }

    def add_position_morphs(self, surfaces: list[list[list[tuple[float, float, float]]]]) -> None:
        # One entry per primitive, in the order mesh_from_geom_node created them.
        # Each entry is a walk frame of position deltas from the neutral pose.
        flat = 0
        for mesh in self.meshes:
            primitives = mesh.get("primitives", [])
            if not primitives:
                continue
            frame_count = 0
            for primitive in primitives:
                frames = surfaces[flat]
                flat += 1
                frame_count = len(frames)
                primitive["targets"] = [
                    {"POSITION": self.vec3_accessor(deltas, bounds=False)}
                    for deltas in frames
                ]
            mesh["weights"] = [0.0] * frame_count
            mesh["extras"] = {"targetNames": [f"walk_{index}" for index in range(frame_count)]}
        if flat != len(surfaces):
            raise RuntimeError(f"morph surfaces {len(surfaces)} != primitives {flat}")

    def vec3_accessor(self, values: list[tuple[float, float, float]], bounds: bool = True) -> int:
        data = b"".join(struct.pack("<3f", *value) for value in values)
        view = self.add_bytes(data, 34962)
        mins = maxs = None
        if bounds and values:
            mins = [min(v[i] for v in values) for i in range(3)]
            maxs = [max(v[i] for v in values) for i in range(3)]
        return self.add_accessor(view, 5126, len(values), "VEC3", mins, maxs)

    def vec2_accessor(self, values: list[tuple[float, float]]) -> int:
        data = b"".join(struct.pack("<2f", *value) for value in values)
        view = self.add_bytes(data, 34962)
        return self.add_accessor(view, 5126, len(values), "VEC2")

    def vec4_accessor(self, values: list[tuple[float, float, float, float]]) -> int:
        data = b"".join(struct.pack("<4f", *value) for value in values)
        view = self.add_bytes(data, 34962)
        return self.add_accessor(view, 5126, len(values), "VEC4")

    def add_node(self, np: NodePath, parent: int | None) -> int:
        mat = np.getTransform(np.getParent() if parent is not None else np).getMat()
        if parent is None:
            mat = np.getMat()
        name = sanitize(np.getName())
        # Axial billboards (tree cards, lamp heads, fountain top) yaw toward the camera.
        if np.getEffect(BillboardEffect.getClassType()) is not None:
            name += "__billboard"
            self.billboards += 1
        node = {
            "name": name,
            "matrix": [mat.getCell(row, col) for row in range(4) for col in range(4)],
        }
        if np.node().isOfType(GeomNode.getClassType()):
            mesh_index = self.mesh_from_geom_node(np)
            if mesh_index is not None:
                node["mesh"] = mesh_index
        index = len(self.nodes)
        self.nodes.append(node)
        if parent is not None:
            self.nodes[parent].setdefault("children", []).append(index)

        for child in visit_children(np):
            self.add_node(child, index)
        return index

    def pack(self, scene_name: str = "ToontownCentral") -> bytes:
        gltf = {
            "asset": {"version": "2.0", "generator": "export_toontown_central.py"},
            "scene": 0,
            "scenes": [{"name": scene_name, "nodes": [0]}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "buffers": [{"byteLength": len(self.buffer)}],
            "bufferViews": self.buffer_views,
            "accessors": self.accessors,
        }
        if self.textures:
            gltf["textures"] = self.textures
            gltf["images"] = self.images
            gltf["samplers"] = self.samplers
        text = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        text += b" " * ((4 - (len(text) % 4)) % 4)
        binary = bytes(self.buffer)
        binary += b"\x00" * ((4 - (len(binary) % 4)) % 4)
        total = 12 + 8 + len(text) + 8 + len(binary)
        return b"".join([
            struct.pack("<4sII", b"glTF", 2, total),
            struct.pack("<I4s", len(text), b"JSON"),
            text,
            struct.pack("<I4s", len(binary), b"BIN\x00"),
            binary,
        ])


def copy3(reader: GeomVertexReader) -> tuple[float, float, float]:
    value = reader.getData3()
    return (value.x, value.y, value.z)


def copy2(reader: GeomVertexReader) -> tuple[float, float]:
    value = reader.getData2()
    return (value.x, value.y)


def copy4(reader: GeomVertexReader) -> tuple[float, float, float, float]:
    value = reader.getData4()
    return (value.x, value.y, value.z, value.w)


def read_column(vdata, column: str, read) -> list:
    reader = GeomVertexReader(vdata, column)
    values = []
    for row in range(vdata.getNumRows()):
        reader.setRow(row)
        values.append(read(reader))
    return values


def triangle_indices(geom: Geom) -> list[int]:
    triangles: list[int] = []
    for prim_index in range(geom.getNumPrimitives()):
        primitive = geom.getPrimitive(prim_index).decompose()
        for vertex_index in range(primitive.getNumVertices()):
            triangles.append(primitive.getVertex(vertex_index))
    return triangles


def position_strip(positions: list[tuple[float, float, float]], triangles: list[int], state, np: NodePath) -> list[tuple[float, float, float]]:
    # Doors, windows, and signs are coplanar decals. Panda draws them with a
    # depth offset; glTF has no equivalent, so the card is nudged along its normal.
    out_pos = [positions[index] for index in triangles]
    nudge = decal_nudge(np, state)
    if not nudge:
        return out_pos
    normal = average_normal(out_pos)
    return [
        (point[0] + normal.x * nudge, point[1] + normal.y * nudge, point[2] + normal.z * nudge)
        for point in out_pos
    ]


def expanded_positions(np: NodePath) -> list[list[tuple[float, float, float]]]:
    # Same primitive order as GltfWriter.mesh_from_geom_node.
    geom_node = np.node()
    surfaces = []
    for geom_index in range(geom_node.getNumGeoms()):
        geom = bake_skin(geom_node.getGeom(geom_index))
        state = np.getNetState().compose(geom_node.getGeomState(geom_index))
        vdata = geom.getVertexData()
        if vdata.getNumRows() == 0:
            continue
        triangles = triangle_indices(geom)
        if len(triangles) < 3:
            continue
        positions = read_column(vdata, "vertex", copy3)
        surfaces.append(position_strip(positions, triangles, state, np))
    return surfaces


def under_decal(np: NodePath) -> bool:
    parent = np.getParent()
    while not parent.isEmpty():
        if parent.getEffect(DecalEffect.getClassType()) is not None:
            return True
        parent = parent.getParent()
    return False


def decal_nudge(np: NodePath, state) -> float:
    depth = state.getAttrib(DepthOffsetAttrib.getClassSlot())
    offset = depth.getOffset() if depth is not None else 0
    if under_decal(np):
        offset = max(offset, 1)
    # One Panda depth unit is a fraction of a foot at playground scale.
    return offset * 0.06


def average_normal(positions: list[tuple[float, float, float]]) -> Vec3:
    accumulated = Vec3(0, 0, 0)
    for index in range(0, len(positions), 3):
        a = Vec3(*positions[index])
        b = Vec3(*positions[index + 1])
        c = Vec3(*positions[index + 2])
        accumulated += (b - a).cross(c - a)
    if accumulated.lengthSquared() > 1e-12:
        accumulated.normalize()
    return accumulated


def visit_children(np: NodePath) -> list[NodePath]:
    node = np.node()
    if node.isOfType(LODNode.getClassType()):
        return [np.getChild(0)] if np.getNumChildren() else []
    children = []
    for index in range(np.getNumChildren()):
        child = np.getChild(index)
        if child.isHidden():
            continue
        if child.node().isOfType(CollisionNode.getClassType()):
            continue
        children.append(child)
    return children


def smooth_normals(positions: list[tuple[float, float, float]]) -> list[tuple[float, float, float]]:
    faces: list[Vec3] = []
    groups: dict[tuple[int, int, int], list[int]] = {}
    for index in range(0, len(positions), 3):
        a = Vec3(*positions[index])
        b = Vec3(*positions[index + 1])
        c = Vec3(*positions[index + 2])
        normal = (b - a).cross(c - a)
        if normal.lengthSquared() > 1e-12:
            normal.normalize()
        else:
            normal = Vec3(0, 0, 1)
        tri = len(faces)
        faces.append(normal)
        for corner in range(3):
            point = positions[index + corner]
            key = (round(point[0] * 64), round(point[1] * 64), round(point[2] * 64))
            groups.setdefault(key, []).append(tri)
    result: list[tuple[float, float, float]] = []
    for index, point in enumerate(positions):
        face = faces[index // 3]
        key = (round(point[0] * 64), round(point[1] * 64), round(point[2] * 64))
        accumulated = Vec3(0, 0, 0)
        for other in groups[key]:
            # A thin ear has a back face on the same corners. Averaging both
            # cancels the normal and leaves every triangle flat-shaded.
            if face.dot(faces[other]) > 0.0:
                accumulated += faces[other]
        if accumulated.lengthSquared() > 1e-12:
            accumulated.normalize()
            result.append((accumulated.x, accumulated.y, accumulated.z))
        else:
            result.append((face.x, face.y, face.z))
    return result


def main() -> int:
    probe = Z_UP_TO_Y_UP.xform(LPoint3f(1, 2, 3))
    print("axis probe (1, 2, 3) ->", tuple(round(v, 4) for v in probe))
    root = load_playground()
    print("export bounds", root.getBounds())
    writer = GltfWriter()
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
