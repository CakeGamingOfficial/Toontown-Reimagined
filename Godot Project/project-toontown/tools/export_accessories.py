"""Export catalog accessories and the leg shoe geoms they swap in.

Hats, glasses, and backpacks are separate models. Toon.generateHat parents
them to the head. Backpacks go on def_joint_attachFlower. Shoes are geoms
already in the legs, so the leg parts and their locomotion clips keep them.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
import types
from pathlib import Path

_toontown = types.ModuleType("panda3d.toontown")
_toontown.DNAStorage = object
_toontown.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = _toontown

from panda3d.core import Filename, NodePath, getModelPath, loadPrcFileData

import export_toon_idle as idle
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")
GAME = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
DEST = ROOT / "assets" / "toons" / "accessories"
MAPS = DEST / "maps"
PARTS = ROOT / "assets" / "toons" / "parts"
SLOTS = {
    "AHat": "hat",
    "ABoysHat": "hat",
    "AGirlsHat": "hat",
    "AGlasses": "glasses",
    "ABoysGlasses": "glasses",
    "AGirlsGlasses": "glasses",
    "ABackpack": "backpack",
    "ABoysBackpack": "backpack",
    "AGirlsBackpack": "backpack",
    "AShoes": "shoes",
    "ABoysShoes": "shoes",
    "AGirlsShoes": "shoes",
}
SHOE_MESH = ["feet", "shoes", "boots_short", "boots_long"]
LEG_JOBS = (
    ("walk", "phase_3.5", "_walk.bam"),
    ("idle", "phase_3", "_neutral.bam"),
    ("run", "phase_3", "_run.bam"),
    ("jump", "phase_3.5", "_jump-zhang.bam"),
    ("rjump", "phase_3.5", "_leap_zhang.bam"),
    ("land", "phase_3.5", "_jump-zend.bam"),
    ("rland", "phase_3.5", "_leap_zend.bam"),
    ("sad-neutral", "phase_4", "_sad-neutral.bam"),
    ("sad-walk", "phase_4", "_losewalk.bam"),
)


def bracket(text: str, start: int, open_char: str, close_char: str) -> str:
    depth = 0
    for index in range(start, len(text)):
        if text[index] == open_char:
            depth += 1
        elif text[index] == close_char:
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    raise RuntimeError("unbalanced " + open_char)


def quoted_list(text: str, name: str) -> list:
    start = text.index(name + " = [")
    body = bracket(text, start + len(name) + 3, "[", "]")
    items = []
    for match in re.finditer(r"None|'([^']+)'", body):
        items.append(match.group(1))
    return items


def style_dict(text: str, name: str) -> dict[str, list[int]]:
    start = text.index(name + " = {")
    body = bracket(text, start + len(name) + 3, "{", "}")
    return {
        key: [int(a), int(b), int(c)]
        for key, a, b, c in re.findall(r"'([^']+)':\s*\[(\d+),\s*(\d+),\s*(\d+)\]", body)
    }


def xform(pos, hpr, scale) -> list[float]:
    node = NodePath("accessory")
    node.setPosHprScale(
        pos[0], pos[1], pos[2],
        hpr[0], hpr[1], hpr[2],
        scale[0], scale[1], scale[2],
    )
    mat = node.getMat()
    return [round(mat.getCell(row, col), 6) for row in range(4) for col in range(4)]


def table_matrices(table: dict) -> dict:
    return {
        key: xform(value[0], value[1], value[2])
        for key, value in table.items()
    }


def extra_matrices(table: dict) -> dict:
    return {
        str(index): table_matrices(heads)
        for index, heads in table.items()
    }


def copy_texture(relative: str) -> str:
    if not relative:
        return ""
    source = GAME / Path(relative)
    if not source.is_file():
        print("missing texture", relative)
        return ""
    MAPS.mkdir(parents=True, exist_ok=True)
    dest = MAPS / source.name
    if not dest.exists() or dest.stat().st_size != source.stat().st_size:
        shutil.copyfile(source, dest)
    return "res://assets/toons/accessories/maps/" + source.name


def export_model(relative: str, written: dict[str, str]) -> str:
    if relative in written:
        return written[relative]
    root = idle.load_model(relative + ".bam")
    if root is None:
        print("missing model", relative)
        written[relative] = ""
        return ""
    idle.bake_skinning(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    DEST.mkdir(parents=True, exist_ok=True)
    path = DEST / (Path(relative).name + ".glb")
    path.write_bytes(writer.pack(path.stem))
    res = "res://assets/toons/accessories/" + path.name
    written[relative] = res
    print("model", path.name, flush=True)
    return res


def export_legs() -> None:
    idle.KEEP_SHOES = True
    for name, model, neutral in idle.PARTS:
        if not name.startswith("legs_"):
            continue
        root = idle.load_model(model)
        if root is None:
            print("missing", model)
            continue
        saved = idle.snapshot(root)
        control, _rate = idle.bind_anim(root, neutral)
        idle.posed_surfaces(root, saved, control, 0)
        writer = exporter.GltfWriter()
        writer.add_node(root, None)
        path = PARTS / f"{name}.glb"
        path.write_bytes(writer.pack(name))
        print("legs", path.name, flush=True)
        for suffix, phase, ending in LEG_JOBS:
            try:
                idle.export_part(name, model, idle.anim_path(model, phase, ending), suffix)
            except RuntimeError as error:
                print("skip", name, suffix, error, flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    idle.ASSETS = Filename.from_os_specific(str(GAME))
    getModelPath().prependDirectory(idle.ASSETS)
    dna = (SOURCE / "toontown" / "toon" / "ToonDNA.py").read_text(encoding="utf-8", errors="replace")
    models = {
        "hat": quoted_list(dna, "HatModels"),
        "glasses": quoted_list(dna, "GlassesModels"),
        "backpack": quoted_list(dna, "BackpackModels"),
    }
    textures = {
        "hat": quoted_list(dna, "HatTextures"),
        "glasses": quoted_list(dna, "GlassesTextures"),
        "backpack": quoted_list(dna, "BackpackTextures"),
        "shoes": quoted_list(dna, "ShoesTextures"),
    }
    styles = {
        "hat": style_dict(dna, "HatStyles"),
        "glasses": style_dict(dna, "GlassesStyles"),
        "backpack": style_dict(dna, "BackpackStyles"),
        "shoes": style_dict(dna, "ShoesStyles"),
    }
    globals_text = (SOURCE / "toontown" / "toon" / "AccessoryGlobals.py").read_text(encoding="utf-8")
    namespace: dict = {}
    exec(globals_text, namespace)
    catalog = (SOURCE / "toontown" / "catalog" / "CatalogAccessoryItemGlobals.py").read_text(encoding="utf-8")
    written: dict[str, str] = {}
    items = {}
    for item_id, article, code in re.findall(r"(\d+):\s*\((A\w+),\s*'([^']+)'", catalog):
        slot = SLOTS.get(article)
        if slot is None or code not in styles[slot]:
            continue
        index, tex_index, _color = styles[slot][code]
        if slot == "shoes":
            mesh = SHOE_MESH[index] if index < len(SHOE_MESH) else ""
            texture = textures["shoes"][tex_index] if tex_index < len(textures["shoes"]) else None
            copied = copy_texture(texture or "")
            longer = ""
            if index == 3 and texture:
                long_name = texture[:-4] + "LL.png"
                longer = copy_texture(long_name)
            items[item_id] = {
                "slot": "shoes",
                "mesh": mesh,
                "texture": copied,
                "long_texture": longer,
                "index": index,
            }
            continue
        model = models[slot][index] if index < len(models[slot]) else None
        if not model:
            continue
        texture = ""
        if tex_index and tex_index < len(textures[slot]) and textures[slot][tex_index]:
            texture = copy_texture(textures[slot][tex_index])
        items[item_id] = {
            "slot": slot,
            "model": export_model(model, written),
            "texture": texture,
            "index": index,
            "hide_ears": slot == "hat" and index == 54,
            "hide_lashes": slot == "glasses" and index in (15, 16),
        }
    document = {
        "items": items,
        "hat": table_matrices(namespace["HatTransTable"]),
        "hat_extra": extra_matrices(namespace["ExtendedHatTransTable"]),
        "glasses": table_matrices(namespace["GlassesTransTable"]),
        "glasses_extra": extra_matrices(namespace["ExtendedGlassesTransTable"]),
        "backpack": table_matrices(namespace["BackpackTransTable"]),
        "backpack_extra": extra_matrices(namespace["ExtendedBackpackTransTable"]),
    }
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "catalog.json").write_text(json.dumps(document), encoding="utf-8")
    print("items", len(items), flush=True)
    export_legs()
    return 0


if __name__ == "__main__":
    sys.exit(main())
