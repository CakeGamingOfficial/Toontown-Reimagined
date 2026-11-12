"""Export each fishing genus the way FishPhoto frames it.

The zero model is the mesh. intro plays once, then swim loops. The photo rig
(pitch, heading, scale, and the 2-unit camera distance) is baked into the glb
root, so a Godot camera at the origin looking down -Z sees the same fish.
Vertex frames stay in the geom's local space and are written beside the glb.
"""
from __future__ import annotations

import struct
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, GeomNode, GeomVertexReader, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "props" / "fish"

# genus, model, intro, swim, pos or None, scale, heading, pitch, play rate.
# FishGlobals.FishFileDict and FishAudioFileDict.
FISH = (
    (0, "balloonFish", "balloonFish-swim", "balloonFish-swim", (0.0, 0.0, 0.0), 1.0, 0, 0, 1.23),
    (2, "catFish", "catFish-swim", "catFish-swim", (1.2, -2.0, 0.5), 0.22, -35, 10, 1.26),
    (4, "clownFish", "clownFish-swim", "clownFish-swim", (0.12, 0.0, -0.15), 0.38, -35, 20, 1.0),
    (6, "frozenFish", "frozenFish-swim", "frozenFish-swim", (0.0, 0.0, 0.0), 0.5, -35, 20, 1.0),
    (8, "starFish", "starFish-swim", "starFish-swimLOOP", (0.0, 0.0, -0.38), 0.36, -35, 20, 1.25),
    (10, "holeyMackerel", "holeyMackerel-swim", "holeyMackerel-swim", None, 0.4, 0, 0, 1.0),
    (12, "dogFish", "dogFish-swim", "dogFish-swim", (0.8, -1.0, 0.275), 0.33, -38, 10, 1.25),
    (14, "amoreEel", "amoreEel-swim", "amoreEel-swim", (0.425, 0.0, 1.15), 0.5, 0, 60, 1.0),
    (16, "nurseShark", "nurseShark-swim", "nurseShark-swim", (0.0, 0.0, -0.15), 0.3, -40, 10, 1.0),
    (18, "kingCrab", "kingCrab-swim", "kingCrab-swimLOOP", None, 0.4, 0, 0, 1.0),
    (20, "moonFish", "moonFish-swim", "moonFish-swimLOOP", (-1.2, 14.0, -2.0), 0.33, 0, -10, 1.0),
    (22, "seaHorse", "seaHorse-swim", "seaHorse-swim", (-0.57, 0.0, -2.1), 0.23, 33, -10, 1.26),
    (24, "poolShark", "poolShark-swim", "poolShark-swim", (-0.45, 0.0, -1.8), 0.33, 45, 0, 1.0),
    (26, "BearAcuda", "BearAcuda-swim", "BearAcuda-swim", (0.65, 0.0, -3.3), 0.2, -35, 20, 1.0),
    (28, "cutThroatTrout", "cutThroatTrout-swim", "cutThroatTrout-swim", (-0.2, 0.0, -0.1), 0.5, 35, 20, 1.0),
    (30, "pianoTuna", "pianoTuna-swim", "pianoTuna-swim", (0.3, 0.0, 0.0), 0.6, 40, 30, 1.0),
    (32, "PBJfish", "PBJfish-swim", "PBJfish-swim", (0.0, 0.0, 0.72), 0.31, -35, 10, 1.25),
    (34, "devilRay", "devilRay-swim", "devilRay-swim", (0.0, 0.0, 0.0), 0.4, -35, 20, 1.0),
)


def _geom_nodes(root: NodePath) -> list[NodePath]:
    found: list[NodePath] = []

    def walk(node: NodePath) -> None:
        if node.node().isOfType(GeomNode.getClassType()):
            found.append(node)
        for child in exporter.visit_children(node):
            walk(child)

    walk(root)
    return found


def _center(actor: NodePath) -> tuple[float, float, float]:
    bounds = actor.getTightBounds()
    if bounds is None:
        return (0.0, 0.0, 0.0)
    low, high = bounds
    return (
        -0.5 * (low.x + high.x),
        -0.5 * (low.y + high.y),
        -0.5 * (low.z + high.z),
    )


def _surfaces(actor: NodePath) -> list[list[tuple]]:
    # One entry per geom, matching fish_0, fish_1, ... Each entry is a list of
    # (positions, uvs, colors) in the same primitive order as the glb.
    groups = []
    for node in _geom_nodes(actor):
        surfaces = []
        geom_node = node.node()
        for geom_index in range(geom_node.getNumGeoms()):
            geom = exporter.bake_skin(geom_node.getGeom(geom_index))
            state = node.getNetState().compose(geom_node.getGeomState(geom_index))
            vdata = geom.getVertexData()
            if vdata.getNumRows() == 0:
                continue
            triangles = exporter.triangle_indices(geom)
            if len(triangles) < 3:
                continue
            positions = exporter.read_column(vdata, "vertex", exporter.copy3)
            out_pos = exporter.position_strip(positions, triangles, state, node)
            out_uv: list[tuple[float, float]] = []
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
            out_color: list[tuple[float, float, float, float]] = []
            if vdata.hasColumn("color"):
                raw_color = exporter.read_column(vdata, "color", exporter.copy4)
                out_color = [raw_color[index] for index in triangles]
            surfaces.append((out_pos, out_uv, out_color))
        if surfaces:
            groups.append(surfaces)
    return groups


def _pose(actor: NodePath, saved, control, frame: int) -> list[list[tuple]]:
    idle.restore(actor, saved)
    character = actor.find("**/+Character")
    bundle = character.node().getBundle(0)
    bundle.setControlEffect(control, 1.0)
    control.pose(frame)
    bundle.forceUpdate()
    idle.bake_skinning(actor)
    return _surfaces(actor)


def _write_bin(path: Path, intro: list, swim: list, fps: float) -> None:
    same = swim is intro
    intro_count = len(intro)
    swim_count = intro_count if same else len(swim)
    frames = intro if same else intro + swim
    blob = bytearray(b"FISH200\0")
    blob += struct.pack("<IIfI", intro_count, swim_count, fps, len(intro[0]))
    for surfaces in intro[0]:
        blob += struct.pack("<I", len(surfaces))
        for positions, uvs, colors in surfaces:
            flags = (1 if uvs else 0) | (2 if colors else 0)
            blob += struct.pack("<IB", len(positions), flags)
            if uvs:
                blob += b"".join(struct.pack("<2f", *uv) for uv in uvs)
            if colors:
                blob += b"".join(struct.pack("<4f", *color) for color in colors)
    blob += struct.pack("<I", len(frames))
    for frame in frames:
        for surfaces in frame:
            for positions, _uvs, _colors in surfaces:
                blob += b"".join(struct.pack("<3f", *point) for point in positions)
    path.write_bytes(blob)


def _export_one(genus: int, model: str, intro_name: str, swim_name: str, pos, scale: float, heading: float, pitch: float, play_rate: float) -> None:
    from direct.actor.Actor import Actor

    actor = Actor(
        f"phase_4/models/char/{model}-zero.bam",
        {
            "intro": f"phase_4/models/char/{intro_name}.bam",
            "swim": f"phase_4/models/char/{swim_name}.bam",
        },
    )
    actor.setTwoSided(True)
    for index, node in enumerate(_geom_nodes(actor)):
        node.setName(f"fish_{index}")
    saved = idle.snapshot(actor)
    intro_control = actor.getAnimControl("intro")
    swim_control = actor.getAnimControl("swim")
    intro_frames = [_pose(actor, saved, intro_control, frame) for frame in range(intro_control.getNumFrames())]
    if intro_name == swim_name:
        swim_frames = intro_frames
    else:
        swim_frames = [_pose(actor, saved, swim_control, frame) for frame in range(swim_control.getNumFrames())]
    idle.restore(actor, saved)
    _pose(actor, saved, intro_control, 0)
    if pos is None:
        pos = _center(actor)
    actor.setPos(pos[0], pos[1], pos[2])
    scale_np = NodePath("scale")
    rotate = NodePath("rotate")
    pitch_np = NodePath("pitch")
    actor.reparentTo(scale_np)
    scale_np.reparentTo(rotate)
    rotate.reparentTo(pitch_np)
    scale_np.setScale(scale)
    rotate.setH(heading)
    pitch_np.setP(pitch)
    pitch_np.setY(2.0)
    root = NodePath(f"genus_{genus}")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    pitch_np.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    glb = OUT / f"genus_{genus}.glb"
    glb.write_bytes(writer.pack(f"genus_{genus}"))
    rate = intro_control.getFrameRate()
    if rate <= 0.0:
        rate = 24.0
    _write_bin(OUT / f"genus_{genus}.bin", intro_frames, swim_frames, rate * play_rate)
    print(
        f"genus {genus} intro={len(intro_frames)} swim={len(swim_frames)} meshes={writer.mesh_count} fps={rate * play_rate:.2f}",
        flush=True,
    )
    actor.cleanup()


def main() -> None:
    from direct.showbase.ShowBase import ShowBase

    loadPrcFileData("", "window-type none")
    ShowBase()
    getModelPath().prependDirectory(idle.ASSETS)
    OUT.mkdir(parents=True, exist_ok=True)
    for row in FISH:
        _export_one(*row)


if __name__ == "__main__":
    main()
