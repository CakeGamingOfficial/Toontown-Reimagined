"""Bake the playground actors the DNA export leaves in bind pose.

Fish and the telescope tip are rigid joints, so their local matrices can be
replayed. The telescope body and the butterflies are skinned, so each frame is
written out as vertices. Ice cream and butterflies are exported as their own
glTF scenes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from panda3d.core import (
    Filename,
    Geom,
    GeomNode,
    GeomVertexData,
    GeomVertexReader,
    GeomVertexWriter,
    Mat4,
    NodePath,
    Point3,
    TexMatrixAttrib,
    TextureAttrib,
    Vec3,
    getModelPath,
    loadPrcFileData,
)

loadPrcFileData("", "window-type none")
loadPrcFileData("", "audio-library-name null")
from direct.actor.Actor import Actor
from direct.showbase.ShowBase import ShowBase

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import export_toontown_central as exporter

ASSETS = r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown\Original Toontown Assets\Game Assets"
OUT = TOOLS.parent / "assets" / "neighborhoods" / "toontown_central" / "props"
getModelPath().prependDirectory(Filename.from_os_specific(ASSETS))
ShowBase(windowType="none")


def cells(mat: Mat4) -> list[float]:
    return [round(mat.getCell(row, col), 5) for row in range(4) for col in range(4)]


def force(actor: Actor) -> None:
    actor.find("**/+Character").node().forceUpdate()


def skinned_point(vdata, row: int) -> Vec3:
    verts = GeomVertexReader(vdata, "vertex")
    blends = GeomVertexReader(vdata, "transform_blend")
    verts.setRow(row)
    blends.setRow(row)
    point = Point3(verts.getData3())
    table = vdata.getTransformBlendTable()
    if table is None:
        return Vec3(point)
    blend = table.getBlend(blends.getData1i())
    accum = Vec3(0, 0, 0)
    for index in range(blend.getNumTransforms()):
        mat = Mat4()
        blend.getTransform(index).getMatrix(mat)
        accum += mat.xformPoint(point) * blend.getWeight(index)
    return accum


def expand(geom: Geom, state, yup: bool) -> tuple[list[float], list[float], list[float]]:
    """Triangle list in the same order the playground exporter writes."""
    vdata = geom.getVertexData()
    positions = []
    uvs = []
    colors = []
    tex_matrix = None
    tex_attrib = state.getAttrib(TextureAttrib.getClassSlot())
    if tex_attrib is not None and tex_attrib.getNumOnStages() > 0:
        stage = tex_attrib.getOnStage(0)
        matrix_attrib = state.getAttrib(TexMatrixAttrib.getClassSlot())
        if matrix_attrib is not None and matrix_attrib.hasStage(stage):
            tex_matrix = matrix_attrib.getTransform(stage).getMat()
    has_uv = vdata.hasColumn("texcoord")
    has_color = vdata.hasColumn("color")
    uv_reader = GeomVertexReader(vdata, "texcoord") if has_uv else None
    color_reader = GeomVertexReader(vdata, "color") if has_color else None

    def uv_of(row: int) -> tuple[float, float]:
        uv_reader.setRow(row)
        value = uv_reader.getData2()
        u, v = value.x, value.y
        if tex_matrix is not None:
            transformed = tex_matrix.xform(Vec3(u, v, 1))
            u, v = transformed.x, transformed.y
        return (u, 1.0 - v)

    def color_of(row: int) -> tuple[float, float, float, float]:
        color_reader.setRow(row)
        value = color_reader.getData4()
        return (value.x, value.y, value.z, value.w)

    for prim_index in range(geom.getNumPrimitives()):
        primitive = geom.getPrimitive(prim_index).decompose()
        for vertex_index in range(primitive.getNumVertices()):
            row = primitive.getVertex(vertex_index)
            point = skinned_point(vdata, row)
            if yup:
                point = Vec3(point.x, point.z, -point.y)
            positions.extend((point.x, point.y, point.z))
            if has_uv:
                u, v = uv_of(row)
                uvs.extend((u, v))
            if has_color:
                colors.extend(color_of(row))
    return positions, uvs, colors


def bake_fish() -> None:
    actor = Actor(
        "phase_4/models/props/exteriorfish-zero.bam",
        {"swim": "phase_4/models/props/exteriorfish-swim.bam"},
    )
    control = actor.getAnimControl("swim")
    frames = []
    for frame in range(control.getNumFrames()):
        actor.pose("swim", frame)
        force(actor)
        sample = {}
        for name in ("joint_fish1", "joint_fish2"):
            joint = next(j for j in actor.getJoints() if j.getName() == name)
            sample[name] = cells(joint.getTransform())
        frames.append(sample)
    payload = {"fps": control.getFrameRate(), "frames": frames}
    path = OUT / "fish_swim.json"
    path.write_text(json.dumps(payload, separators=(",", ":")))
    print("fish", control.getNumFrames(), "frames", path.stat().st_size)


def bake_telescope() -> None:
    actor = Actor(
        "phase_3.5/models/props/HQ_telescope-mod.bam",
        {"anim": "phase_3.5/models/props/HQ_telescope-chan.bam"},
    )
    control = actor.getAnimControl("anim")
    body = None
    for geom_np in actor.findAllMatches("**/+GeomNode"):
        vdata = geom_np.node().getGeom(0).getVertexData()
        if vdata.getTransformBlendTable() is not None:
            body = geom_np
            break
    tip = actor.find("**/joint_thirdSection")
    state = body.getNetState().compose(body.node().getGeomState(0))
    frames = []
    tips = []
    uvs = []
    colors = []
    for frame in range(control.getNumFrames()):
        actor.pose("anim", frame)
        force(actor)
        positions, frame_uvs, frame_colors = expand(body.node().getGeom(0), state, False)
        if frame == 0:
            uvs = frame_uvs
            colors = frame_colors
            print("telescope verts", len(positions) // 3, "uv", len(uvs) // 2, "color", len(colors) // 4)
        frames.append([round(v, 5) for v in positions])
        tips.append(cells(tip.getTransform().getMat()))
    payload = {
        "fps": control.getFrameRate(),
        "uv": [round(v, 5) for v in uvs],
        "color": [round(v, 5) for v in colors],
        "frames": frames,
        "tip": tips,
    }
    path = OUT / "telescope.json"
    path.write_text(json.dumps(payload, separators=(",", ":")))
    print("telescope", control.getNumFrames(), "frames", path.stat().st_size)


def baked_copy(source: NodePath, yup: bool, space_root: NodePath) -> NodePath:
    """A GeomNode whose vertices are the posed positions, Y-up when requested."""
    baked = GeomNode(source.getName() or "geom")
    src = source.node()
    # Unskinned geoms still sit under a joint or model node. Skinned vertices are
    # already in character space, so only the rigid ones need that transform.
    net = source.getTransform(space_root).getMat()
    for index in range(src.getNumGeoms()):
        geom = src.getGeom(index).makeCopy()
        vdata = GeomVertexData(geom.getVertexData())
        reader = GeomVertexReader(vdata, "vertex")
        writer = GeomVertexWriter(vdata, "vertex")
        table = vdata.getTransformBlendTable()
        blend_reader = GeomVertexReader(vdata, "transform_blend") if table is not None else None
        for row in range(vdata.getNumRows()):
            reader.setRow(row)
            point = Point3(reader.getData3())
            if table is not None:
                blend_reader.setRow(row)
                blend = table.getBlend(blend_reader.getData1i())
                accum = Vec3(0, 0, 0)
                for blend_index in range(blend.getNumTransforms()):
                    mat = Mat4()
                    blend.getTransform(blend_index).getMatrix(mat)
                    accum += mat.xformPoint(point) * blend.getWeight(blend_index)
                point = Point3(accum)
            else:
                point = net.xformPoint(point)
            if yup:
                point = Point3(point.x, point.z, -point.y)
            writer.setRow(row)
            writer.setData3(point)
        geom.setVertexData(vdata)
        baked.addGeom(geom, src.getGeomState(index))
    return NodePath(baked)


def export_model(root: NodePath, path: Path) -> None:
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    path.write_bytes(writer.pack())
    print("wrote", path.name, path.stat().st_size)


def bake_butterfly() -> None:
    actor = Actor(
        "phase_4/models/props/SZ_butterfly-mod.bam",
        {
            "flutter": "phase_4/models/props/SZ_butterfly-flutter.bam",
            "land": "phase_4/models/props/SZ_butterfly-land.bam",
        },
    )
    flutter = actor.getAnimControl("flutter")
    root = NodePath("Butterfly")
    step = 2
    for frame in range(0, flutter.getNumFrames(), step):
        actor.pose("flutter", frame)
        force(actor)
        frame_np = root.attachNewNode(f"flutter_{frame // step:02d}")
        _attach_butterfly(actor, frame_np)
    actor.pose("land", actor.getAnimControl("land").getNumFrames() // 2)
    force(actor)
    _attach_butterfly(actor, root.attachNewNode("landed"))
    export_model(root, OUT / "butterfly.glb")


def _attach_butterfly(actor: Actor, frame_np: NodePath) -> None:
    for geom_np in actor.findAllMatches("**/+GeomNode"):
        parent_name = geom_np.getParent().getName()
        name = geom_np.getName() or parent_name or "body"
        if name in ("", "flutterby"):
            name = parent_name or "body"
        copy = baked_copy(geom_np, True, actor)
        copy.setName(exporter.sanitize(name))
        copy.reparentTo(frame_np)


def bake_icecream() -> None:
    model = base.loader.loadModel("phase_4/models/props/icecream.bam")
    root = NodePath("Icecream")
    for geom_np in model.findAllMatches("**/+GeomNode"):
        baked_copy(geom_np, True, model).reparentTo(root)
    export_model(root, OUT / "icecream.glb")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bake_fish()
    bake_telescope()
    bake_butterfly()
    bake_icecream()


if __name__ == "__main__":
    main()
