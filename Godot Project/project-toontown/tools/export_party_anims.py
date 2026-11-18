"""Bake party decoration clips. Joints are local matrices in the glTF layout.

Skinned bandstands and the tube cog also store a position-keyed influence
table so the player can deform the imported bind-pose meshes.
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

from panda3d.core import (  # noqa: E402
    CharacterJoint,
    Filename,
    GeomNode,
    GeomVertexReader,
    InternalName,
    JointVertexTransform,
    Loader,
    Mat4,
    NodePath,
    loadPrcFileData,
)

from export_toontown_central import (  # noqa: E402
    position_strip,
    read_column,
    triangle_indices,
    visit_children,
    copy3,
)


ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
OUT = ROOT / "assets" / "parties" / "decor" / "anims"

CLIPS = (
    ("gag_globe", "phase_13/models/parties/tt_m_ara_pty_gagGlobe_model.bam", "phase_13/models/parties/tt_m_ara_pty_gagGlobe.bam"),
    ("bean_banner", "phase_13/models/parties/tt_m_ara_pty_bannerJellybean_model.bam", "phase_13/models/parties/tt_m_ara_pty_bannerJellybean.bam"),
    ("heart_banner", "phase_13/models/parties/tt_m_ara_pty_bannerValentine_model.bam", "phase_13/models/parties/tt_m_ara_pty_bannerValentine.bam"),
    ("flying_heart", "phase_13/models/parties/tt_m_ara_pty_heartWing_model.bam", "phase_13/models/parties/tt_m_ara_pty_heartWing.bam"),
    ("banner_victory", "phase_13/models/parties/tt_m_ara_pty_bannerVictory_model.bam", "phase_13/models/parties/tt_m_ara_pty_bannerVictory.bam"),
    ("cannon_victory", "phase_13/models/parties/tt_m_ara_pty_cannonVictory_model.bam", "phase_13/models/parties/tt_m_ara_pty_cannonVictory.bam"),
    ("hydra", "phase_13/models/parties/tt_a_ara_pty_hydra_default.bam", "phase_13/models/parties/tt_a_ara_pty_hydra_dance.bam"),
    ("stage_winter", "phase_13/models/parties/tt_r_ara_pty_winterProps.bam", "phase_13/models/parties/tt_a_ara_pty_hydra_dance.bam"),
    ("tube_cog", "phase_5.5/models/estate/tt_a_ara_pty_tubeCogVictory_default.bam", "phase_5.5/models/estate/tt_a_ara_pty_tubeCogVictory_wave.bam"),
)


def load_model(loader: Loader, relative: str) -> NodePath | None:
    path = ASSETS.joinpath(*relative.split("/"))
    node = loader.loadSync(Filename.from_os_specific(str(path)))
    if node is None:
        print("missing", path, flush=True)
        return None
    return NodePath(node)


def joint_names(bundle) -> list[str]:
    names: list[str] = []

    def walk(group) -> None:
        if group.is_of_type(CharacterJoint.get_class_type()):
            names.append(group.get_name())
        for index in range(group.get_num_children()):
            walk(group.get_child(index))

    walk(bundle)
    return names


def matrix_cells(mat) -> list[float]:
    cells = [mat.getCell(row, col) for row in range(4) for col in range(4)]
    return [
        cells[0], cells[1], cells[2],
        cells[4], cells[5], cells[6],
        cells[8], cells[9], cells[10],
        cells[12], cells[13], cells[14],
    ]


def local_cells(node: NodePath) -> list[float]:
    return matrix_cells(node.getTransform(node.getParent()).getMat())


def net_cells(joint) -> list[float]:
    mat = Mat4()
    joint.get_net_transform(mat)
    return matrix_cells(mat)


def geom_nodes(root: NodePath) -> list[NodePath]:
    found: list[NodePath] = []

    def walk(node: NodePath) -> None:
        if node.node().is_of_type(GeomNode.get_class_type()):
            name = node.get_name()
            if name and "collision" not in name and "_med" not in name and "_low" not in name:
                found.append(node)
        for child in visit_children(node):
            walk(child)

    walk(root)
    return found


def surface_weights(geom_node: GeomNode, names: dict[str, int]) -> list[dict[tuple[int, int, int], tuple]]:
    surfaces = []
    for geom_index in range(geom_node.get_num_geoms()):
        geom = geom_node.get_geom(geom_index)
        vdata = geom.get_vertex_data()
        table = vdata.get_transform_blend_table()
        if vdata.get_num_rows() == 0 or table is None:
            continue
        if not vdata.has_column(InternalName.get_transform_blend()):
            continue
        triangles = triangle_indices(geom)
        if len(triangles) < 3:
            continue
        positions = read_column(vdata, "vertex", copy3)
        posed = position_strip(positions, triangles, geom_node.get_geom_state(geom_index), NodePath(geom_node))
        reader = GeomVertexReader(vdata, InternalName.get_transform_blend())
        row_weights = []
        for row in range(vdata.get_num_rows()):
            reader.set_row(row)
            blend = table.get_blend(reader.get_data1i())
            influences = []
            for slot in range(blend.get_num_transforms()):
                transform = blend.get_transform(slot)
                if not transform.is_of_type(JointVertexTransform.get_class_type()):
                    continue
                joint = names.get(transform.get_joint().get_name())
                if joint is None:
                    continue
                influences.append((joint, blend.get_weight(slot)))
            influences.sort(key=lambda item: item[1], reverse=True)
            influences = influences[:4]
            padded = [(0, 0.0)] * 4
            for index, influence in enumerate(influences):
                padded[index] = influence
            row_weights.append(tuple(padded))
        unique: dict[tuple[int, int, int], tuple] = {}
        for corner, row in enumerate(triangles):
            point = posed[corner]
            key = (round(point[0] * 64), round(point[1] * 64), round(point[2] * 64))
            if key not in unique:
                unique[key] = (point, row_weights[row])
        surfaces.append(unique)
    return surfaces


def pack_clip(path: Path, fps: float, space: int, frames: list[list[list[float]]], names: list[str], skins: list[tuple[str, list]]) -> None:
    blob = bytearray(b"PTYJNT1\0")
    blob += struct.pack("<IfHB", len(frames), fps, len(names), space)
    for index, name in enumerate(names):
        raw = name.encode("utf-8")
        blob += struct.pack("<H", len(raw))
        blob += raw
        for frame in frames:
            blob += struct.pack("<12f", *frame[index])
    blob += struct.pack("<H", len(skins))
    for mesh_name, surfaces in skins:
        raw = mesh_name.encode("utf-8")
        blob += struct.pack("<H", len(raw))
        blob += raw
        blob += struct.pack("<H", len(surfaces))
        for surface in surfaces:
            blob += struct.pack("<I", len(surface))
            for point, influences in surface.values():
                blob += struct.pack("<3f", *point)
                joints = []
                weights = []
                for joint, weight in influences:
                    joints.append(joint)
                    weights.append(weight)
                blob += struct.pack("<4B4f", *joints, *weights)
    path.write_bytes(blob)


def export_one(loader: Loader, name: str, model_rel: str, anim_rel: str) -> bool:
    model = load_model(loader, model_rel)
    anim = load_model(loader, anim_rel)
    if model is None or anim is None:
        return False
    character = model.find("**/+Character")
    bundle_node = anim.find("**/+AnimBundleNode")
    if character.is_empty() or bundle_node.is_empty():
        print("no character", name, flush=True)
        return False
    part = character.node().get_bundle(0)
    control = part.bind_anim(bundle_node.node().get_bundle(), -1)
    names = joint_names(part)
    index_of = {joint_name: index for index, joint_name in enumerate(names)}
    skins = []
    for geom in geom_nodes(model):
        surfaces = surface_weights(geom.node(), index_of)
        if surfaces:
            skins.append((geom.get_name(), surfaces))
    space = 1 if skins else 0
    nodes = []
    bundle_joints = []
    for joint_name in names:
        found = model.find("**/" + joint_name)
        nodes.append(None if found.is_empty() else found)
        located = character.node().find_joint(joint_name)
        bundle_joints.append(None if located is None else located)
    if space == 0:
        missing = [joint_name for joint_name, node in zip(names, nodes) if node is None]
        if missing:
            print(name, "missing joints", missing, flush=True)
    frame_count = control.get_num_frames()
    frames: list[list[list[float]]] = []
    peak = 0.0
    for frame_index in range(frame_count):
        control.pose(frame_index)
        part.force_update()
        posed = []
        for index, node in enumerate(nodes):
            if space == 1:
                cells = net_cells(bundle_joints[index])
            elif node is None:
                cells = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
            else:
                cells = local_cells(node)
            posed.append(cells)
            peak = max(peak, abs(cells[9]), abs(cells[10]), abs(cells[11]))
        frames.append(posed)
    moved = 0.0
    if frame_count > 1:
        for index in range(len(names)):
            for cell in range(12):
                moved = max(moved, abs(frames[0][index][cell] - frames[frame_count // 2][index][cell]))
    dest = OUT / f"{name}.pty"
    pack_clip(dest, control.get_frame_rate(), space, frames, names, skins)
    print(
        f"wrote {dest.name} space={'net' if space else 'local'} frames={frame_count} "
        f"fps={control.get_frame_rate():.0f} joints={len(names)} skins={len(skins)} "
        f"motion={moved:.3f} bytes={dest.stat().st_size}",
        flush=True,
    )
    return True


def main() -> int:
    loadPrcFileData("", "notify-level-error")
    OUT.mkdir(parents=True, exist_ok=True)
    loader = Loader.getGlobalPtr()
    failed = False
    for name, model_rel, anim_rel in CLIPS:
        if not export_one(loader, name, model_rel, anim_rel):
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
