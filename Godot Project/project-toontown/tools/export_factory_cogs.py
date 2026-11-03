"""Write the Sellbot factory suit list the original level planner spawns.

SellbotLegFactoryCogs.CogData is the active list. ReserveCogData stays out
unless level-reserve-suits is on, and that config defaults to off. Paths are
GoonPathData.Paths['sellbotFactory'] for each path entity the suits use.
"""
from __future__ import annotations

import json
import os
import sys
import types
from pathlib import Path

from panda3d.core import Filename, NodePath, Texture, Vec3, Vec4, getModelPath, loadPrcFileData

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")
COGS = SOURCE / "toontown" / "coghq" / "SellbotLegFactoryCogs.py"
SPEC = SOURCE / "toontown" / "coghq" / "SellbotLegFactorySpec.py"
PATHS = SOURCE / "toontown" / "suit" / "GoonPathData.py"
OUT = ROOT / "assets" / "cog_hq" / "sellbot_factory_cogs.json"
USER_ASSETS = Path(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
ROBOTS = {
    "a": (
        "phase_5/models/char/cogA_robot-zero.bam",
        "phase_4/models/char/suitA-neutral.bam",
        "phase_4/models/char/suitA-walk.bam",
    ),
    "b": (
        "phase_5/models/char/cogB_robot-zero.bam",
        "phase_4/models/char/suitB-neutral.bam",
        "phase_4/models/char/suitB-walk.bam",
    ),
    "c": (
        "phase_5/models/char/cogC_robot-zero.bam",
        "phase_3.5/models/char/suitC-neutral.bam",
        "phase_3.5/models/char/suitC-walk.bam",
    ),
}


class _Vec:
    def __init__(self, x=0, y=0, z=0, w=0):
        self.values = (float(x), float(y), float(z), float(w))

    def __getitem__(self, index: int) -> float:
        return self.values[index]


class _Text:
    def __getattr__(self, _name: str) -> str:
        return ""


class _Globals:
    def __getattr__(self, _name: str) -> int:
        return 0


def _point(value) -> list[float]:
    return [round(float(value[0]), 3), round(float(value[1]), 3), round(float(value[2]), 3)]


def _load_spec() -> dict:
    source = SPEC.read_text(encoding="utf-8")
    source = source.split("GlobalEntities", 1)[1]
    namespace = {"Point3": _Vec, "Vec3": _Vec, "Vec4": _Vec, "TTLocalizer": _Text()}
    exec("GlobalEntities" + source, namespace)
    return namespace["GlobalEntities"]


def _load_cogs() -> list[dict]:
    source = COGS.read_text(encoding="utf-8")
    source = source.replace("from .SpecImports import *", "")
    namespace = {"Point3": _Vec, "Vec3": _Vec, "Vec4": _Vec}
    exec(source, namespace)
    return namespace["CogData"]


def _load_paths() -> dict:
    source = PATHS.read_text(encoding="utf-8")
    source = source.replace("from panda3d.core import *", "")
    source = source.replace("from toontown.toonbase import ToontownGlobals", "")
    namespace = {"Vec3": Vec3, "Point3": Vec3, "ToontownGlobals": _Globals()}
    exec(source, namespace)
    return namespace["Paths"]["sellbotFactory"]


def write_json() -> None:
    entities = _load_spec()
    table = _load_paths()
    suits = []
    needed: dict[int, dict] = {}
    for spec in _load_cogs():
        path_id = spec.get("path")
        suits.append({
            "parent": int(spec["parentEntId"]),
            "pos": _point(spec.get("pos", (0, 0, 0))),
            "h": round(float(spec.get("h", 0.0)), 3),
            "behavior": str(spec.get("behavior", "walk")),
            "path": int(path_id) if path_id else 0,
			"level": int(spec.get("level", 1)),
			"skeleton": int(spec.get("skeleton", 0)),
			"cell": int(spec.get("battleCell", 0)),
        })
        if not path_id:
            continue
        ent = entities.get(path_id, {})
        index = int(ent.get("pathIndex", -1))
        points = table.get(index, [])
        needed[int(path_id)] = {
            "scale": float(ent.get("pathScale", 1.0) or 1.0),
            "points": [_point(point) for point in points],
        }
    payload = {"cogs": suits, "paths": {str(key): value for key, value in needed.items()}}
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(
        f"wrote {OUT.name}: {len(suits)} cogs, {sum(1 for cog in suits if cog['skeleton'])} skelecogs, {len(needed)} paths",
        flush=True,
    )


def _shim_dll_directory() -> None:
    # This interpreter has no os.add_dll_directory. The suit exporter reads it
    # at import, so the shim has to be in place first.
    if hasattr(os, "add_dll_directory"):
        return

    def _add_dll_directory(_path):
        class _Dummy:
            def close(self):
                return None

            def __enter__(self):
                return None

            def __exit__(self, *_args):
                return False

        return _Dummy()

    os.add_dll_directory = _add_dll_directory


def _stub_toontown() -> None:
    fake = types.ModuleType("panda3d.toontown")
    fake.DNAStorage = object
    fake.DNASuitPoint = object
    fake.loadDNAFile = lambda *_args, **_kwargs: None
    sys.modules["panda3d.toontown"] = fake


def export_robots() -> None:
    _shim_dll_directory()
    _stub_toontown()
    sys.path.insert(0, str(TOOLS))
    # export_street_cogs installs the dll-directory shim, then loads the
    # glTF writer and the suit baker.
    import export_street_cogs as suits

    toon_export = suits.toon_export
    exporter = suits.exporter

    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    asset_root = Filename.from_os_specific(str(USER_ASSETS))
    toon_export.ASSETS = asset_root
    suits.ASSETS = USER_ASSETS
    getModelPath().prependDirectory(asset_root)
    for body, (model_file, neutral_file, walk_file) in ROBOTS.items():
        model = toon_export.load_model(model_file)
        if model is None:
            print("missing", model_file, flush=True)
            continue
        _paint_robot(model, toon_export)
        model.setTag("suit_body", body)
        saved, neutral = suits.pose_neutral(model, neutral_file)
        suits.BODIES_NEUTRAL[body] = neutral
        _write_robot(exporter, model, body)
        clip_dir = ROOT / "assets" / "cogs" / "anims" / f"robot_{body}"
        clip_dir.mkdir(parents=True, exist_ok=True)
        for key, relative in (("neutral", neutral_file), ("walk", walk_file)):
            frames, rate = suits.bake_clip(model, saved, relative, clip_dir / f"{key}.walk")
            print(f"robot_{body} {key}: {frames} frames @ {rate}", flush=True)


def _paint_robot(model: NodePath, toon_export) -> None:
    tie = model.find("**/tie")
    if not tie.isEmpty():
        tex = Texture()
        tie_file = USER_ASSETS / "phase_5" / "maps" / "cog_robot_tie_sales.jpg"
        if tex.read(Filename.from_os_specific(str(tie_file))):
            tex.setMinfilter(Texture.FTLinearMipmapLinear)
            tex.setMagfilter(Texture.FTLinear)
            tie.setTexture(tex, 1)
    icons = toon_export.load_model("phase_3/models/gui/cog_icons.bam")
    chest = model.find("**/joint_attachMeter")
    badge = icons.find("**/SalesIcon") if icons is not None else NodePath()
    if icons is not None and not chest.isEmpty() and not badge.isEmpty():
        icon = badge.copyTo(chest)
        icon.setPosHprScale(0.02, 0.05, 0.04, 180.0, 0.0, 0.0, 0.51, 0.51, 0.51)
        icon.setColor(Vec4(0.843, 0.745, 0.745, 1.0))
    if icons is not None:
        icons.removeNode()


def _write_robot(exporter, model: NodePath, body: str) -> None:
    # Suit.makeSkeleton scales the robot by the suit scale times 1.0173.
    # The suit scale is applied when the cog is spawned. This factor stays
    # on the mesh, the same way a normal suit's scale is baked into its glb.
    copy = model.copyTo(NodePath("robot"))
    copy.setScale(1.0173)
    root = NodePath(f"robot_{body}")
    root.setMat(exporter.Z_UP_TO_Y_UP)
    copy.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest = ROOT / "assets" / "cogs" / "suits" / f"robot_{body}.glb"
    dest.write_bytes(writer.pack("Skelecog"))
    print(f"wrote {dest.name} ({dest.stat().st_size / 1024:.0f} KB)", flush=True)


if __name__ == "__main__":
    write_json()
    if "robots" in sys.argv:
        export_robots()
