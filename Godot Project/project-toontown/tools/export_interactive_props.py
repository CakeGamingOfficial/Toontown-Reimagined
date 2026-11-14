"""Bake street hydrant, mailbox, and trash-can clips, and the zone bonuses.

The street glb already has each prop in its bind pose. These files are the
original idle, fight, victory, and sad reels in that same vertex order, so
the street mesh can play them. A cell-0 prop gives its zone the original
track bonus: hydrant squirt, mailbox throw, trash can toon-up.
"""
from __future__ import annotations

import ast
import json
import shutil
import struct
import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
stub = types.ModuleType("panda3d.toontown")
stub.DNAStorage = object
stub.loadDNAFile = lambda *_args, **_kwargs: None
sys.modules["panda3d.toontown"] = stub

from panda3d.core import Filename, GeomNode, GeomVertexData, GeomVertexReader, GeomVertexRewriter, Loader, NodePath, Point3, Thread, getModelPath, loadPrcFileData

import export_toontown_central as exporter

loadPrcFileData("", "model-cache-dir")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "streets" / "props"
MODELS = Filename.from_os_specific(r"C:\Users\fukuy\Downloads\resources-master\TTO Resource files")
DNA = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code\toontown\hood")

HOODS = {
    "ttc": "ToontownCentral",
    "dod": "DonaldsDock",
    "dga": "DaisyGardens",
    "mml": "MinniesMelodyland",
    "tbr": "TheBrrrgh",
    "ddl": "DonaldsDreamland",
}
PHASE = {
    "ttc": "phase_5",
    "dod": "phase_6",
    "dga": "phase_8",
    "mml": "phase_6",
    "tbr": "phase_8",
    "ddl": "phase_8",
}
# Donald's Dock hydrants are the Toontown Central actor.
SKIP = {("dod", "hydrant")}
KINDS = ("hydrant", "mailbox", "trashcan")
TRACK = {"hydrant": 5, "mailbox": 4, "trashcan": 0}
TABLES = {
    "hydrant": "HydrantInteractiveProp.py",
    "mailbox": "MailboxInteractiveProp.py",
    "trashcan": "TrashcanInteractiveProp.py",
}
STREETS = [
    ("silly_street", "phase_5/dna/toontown_central_2100.dna"),
    ("loopy_lane", "phase_5/dna/toontown_central_2200.dna"),
    ("punchline_place", "phase_5/dna/toontown_central_2300.dna"),
    ("barnacle_boulevard", "phase_6/dna/donalds_dock_1100.dna"),
    ("seaweed_street", "phase_6/dna/donalds_dock_1200.dna"),
    ("lighthouse_lane", "phase_6/dna/donalds_dock_1300.dna"),
    ("oak_street", "phase_8/dna/daisys_garden_5100.dna"),
    ("elm_street", "phase_8/dna/daisys_garden_5200.dna"),
    ("maple_street", "phase_8/dna/daisys_garden_5300.dna"),
    ("baritone_boulevard", "phase_6/dna/minnies_melody_land_4100.dna"),
    ("alto_avenue", "phase_6/dna/minnies_melody_land_4200.dna"),
    ("tenor_terrace", "phase_6/dna/minnies_melody_land_4300.dna"),
    ("sleet_street", "phase_8/dna/the_burrrgh_3100.dna"),
    ("walrus_way", "phase_8/dna/the_burrrgh_3200.dna"),
    ("polar_place", "phase_8/dna/the_burrrgh_3300.dna"),
    ("pajama_place", "phase_8/dna/donalds_dreamland_9100.dna"),
    ("lullaby_lane", "phase_8/dna/donalds_dreamland_9200.dna"),
]

_KEEP: list[NodePath] = []


def load_model(relative: str) -> NodePath:
    node = Loader.getGlobalPtr().loadSync(Filename(MODELS, relative))
    if node is None:
        raise RuntimeError("missing " + relative)
    path = NodePath(node)
    _KEEP.append(path)
    return path


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


def snapshot(root: NodePath):
    saved = []
    for path in root.findAllMatches("**/+GeomNode"):
        node = path.node()
        for index in range(node.getNumGeoms()):
            saved.append((node, index, GeomVertexData(node.getGeom(index).getVertexData())))
    return saved


def restore(saved) -> None:
    for node, index, data in saved:
        node.modifyGeom(index).setVertexData(GeomVertexData(data))


def body_node(model: NodePath) -> NodePath:
    high = model.find("**/*_high")
    if high.isEmpty():
        raise RuntimeError("no high lod on " + model.getName())
    for child in high.getChildren():
        if not child.node().isOfType(GeomNode.getClassType()):
            continue
        if "dropshadow" in child.getName():
            continue
        return child
    raise RuntimeError("no body geom on " + model.getName())


def bind_anim(model: NodePath, relative: str):
    anim = load_model(relative)
    bundle_node = anim.find("**/+AnimBundleNode")
    if bundle_node.isEmpty():
        raise RuntimeError("no anim bundle " + relative)
    character = model.find("**/+Character")
    control = character.node().getBundle(0).bindAnim(bundle_node.node().getBundle(), -1)
    return control


def posed_frames(model: NodePath, saved, control, body: NodePath, frame_count: int):
    character = model.find("**/+Character")
    bundle = character.node().getBundle(0)
    frames = []
    for frame in range(frame_count):
        restore(saved)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        bake_skinning(model)
        surfaces = exporter.expanded_positions(body)
        if not surfaces:
            raise RuntimeError("no body surface")
        frames.append(surfaces)
    restore(saved)
    bundle.setControlEffect(control, 0.0)
    return frames


def write_clip(path: Path, frames: list, fps: float) -> None:
    # frames[frame][surface] is the expanded vertex list.
    blob = bytearray()
    blob += b"IPROP2\0\0"
    surface_count = len(frames[0])
    blob += struct.pack("<IfI", len(frames), float(fps), surface_count)
    for surface in range(surface_count):
        verts = frames[0][surface]
        blob += struct.pack("<I", len(verts))
        for frame in frames:
            blob += b"".join(struct.pack("<3f", *point) for point in frame[surface])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


def copy_sound(anim_name: str, phase: str, dest: Path) -> bool:
    sound = anim_name.replace("tt_a_ara", "tt_s_ara") + ".ogg"
    source = Path(str(MODELS.to_os_specific())) / phase / "audio" / "sfx" / sound
    if not source.exists():
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    return True


def class_tables(kind: str) -> dict:
    text = (SOURCE / TABLES[kind]).read_text(encoding="utf-8")
    for hood, name in HOODS.items():
        text = text.replace("ToontownGlobals." + name, repr(hood))
    found = {}
    for node in ast.parse(text).body:
        if not isinstance(node, ast.ClassDef):
            continue
        for stmt in node.body:
            if not isinstance(stmt, ast.Assign):
                continue
            for target in stmt.targets:
                if isinstance(target, ast.Name) and target.id.startswith("ZoneTo"):
                    found[target.id] = ast.literal_eval(stmt.value)
    return found


def clip_entry(model: NodePath, saved, phase: str, anim_name: str, folder: Path, file_name: str) -> dict | None:
    relative = "%s/models/char/%s.bam" % (phase, anim_name)
    if not (Path(str(MODELS.to_os_specific())) / relative).exists():
        print("missing", relative, flush=True)
        return None
    control = bind_anim(model, relative)
    frame_count = control.getNumFrames()
    fps = control.getFrameRate()
    if frame_count <= 0:
        print("empty", relative, flush=True)
        return None
    body = body_node(model)
    frames = posed_frames(model, saved, control, body, frame_count)
    write_clip(folder / (file_name + ".iprop"), frames, fps)
    heard = copy_sound(anim_name, phase, folder / (file_name + ".ogg"))
    print(" ", file_name, frame_count, "frames", fps, "fps", "sound" if heard else "silent", flush=True)
    return {"file": file_name, "frames": frame_count, "fps": fps, "sound": heard}


def export_actor(hood: str, kind: str, tables: dict) -> dict | None:
    if (hood, kind) in SKIP:
        return None
    phase = PHASE[hood]
    model_name = "tt_r_ara_%s_%s.bam" % (hood, kind)
    relative = "%s/models/char/%s" % (phase, model_name)
    print(hood, kind, flush=True)
    model = load_model(relative)
    saved = snapshot(model)
    folder = OUT / ("%s_%s" % (hood, kind))
    idles = []
    for index, info in enumerate(tables["ZoneToIdles"][hood]):
        anim_name, min_loop, max_loop, settle, min_pause, max_pause = info
        entry = clip_entry(model, saved, phase, anim_name, folder, "idle%d" % index)
        if entry is None:
            continue
        entry["min_loop"] = int(min_loop)
        entry["max_loop"] = int(max_loop)
        entry["min_pause"] = int(min_pause)
        entry["max_pause"] = int(max_pause)
        entry["settle"] = ""
        if settle:
            settled = clip_entry(model, saved, phase, settle, folder, "settle%d" % index)
            if settled is not None:
                entry["settle"] = settled["file"]
        idles.append(entry)
    catalog = {"verts": [len(surface) for surface in posed_probe(model)], "idles": idles}
    singles = {
        "into": tables["ZoneToIdleIntoFightAnims"].get(hood, ""),
        "victory": tables["ZoneToVictoryAnims"].get(hood, ""),
        "sad": tables["ZoneToSadAnims"].get(hood, ""),
    }
    for key, anim_name in singles.items():
        if not anim_name:
            continue
        entry = clip_entry(model, saved, phase, anim_name, folder, key)
        if entry is not None:
            catalog[key] = entry
    fights = []
    for index, anim_name in enumerate(tables["ZoneToFightAnims"].get(hood, ())):
        entry = clip_entry(model, saved, phase, anim_name, folder, "fight%d" % index)
        if entry is not None:
            fights.append(entry)
    catalog["fights"] = fights
    return catalog


def posed_probe(model: NodePath):
    return exporter.expanded_positions(body_node(model))


def export_bonuses() -> None:
    bonuses: dict[str, dict[str, int]] = {}
    for slug, relative in STREETS:
        text = (DNA / relative).read_text(encoding="utf-8")
        zone = ""
        depth = 0
        prop_depth = -1
        prop_name = ""
        cell = None
        zones: dict[str, int] = {}
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith('visgroup "'):
                zone = stripped.split('"', 2)[1]
            if stripped.startswith('interactive_prop "'):
                prop_depth = depth
                prop_name = stripped.split('"', 2)[1]
                cell = None
            if prop_depth >= 0 and stripped.startswith("cell_id"):
                cell = int(stripped.split("[", 1)[1].split("]", 1)[0].strip())
            depth += line.count("[") - line.count("]")
            if prop_depth >= 0 and depth <= prop_depth:
                kind = ""
                for name in KINDS:
                    if name in prop_name:
                        kind = name
                if kind and cell == 0 and zone and zone not in zones:
                    zones[zone] = TRACK[kind]
                elif kind and cell == 0 and zone in zones:
                    print("two props in", slug, zone, flush=True)
                prop_depth = -1
                prop_name = ""
        bonuses[slug] = zones
        print(slug, "bonus zones", len(zones), flush=True)
    (OUT / "bonuses.json").write_text(json.dumps(bonuses, separators=(",", ":")), encoding="utf-8")


def main() -> None:
    getModelPath().appendDirectory(MODELS)
    OUT.mkdir(parents=True, exist_ok=True)
    export_bonuses()
    catalog = {}
    for kind in KINDS:
        tables = class_tables(kind)
        for hood in HOODS:
            if (hood, kind) in SKIP:
                continue
            entry = export_actor(hood, kind, tables)
            if entry is not None:
                catalog["%s_%s" % (hood, kind)] = entry
    (OUT / "catalog.json").write_text(json.dumps(catalog, separators=(",", ":")), encoding="utf-8")
    print("catalog", len(catalog), flush=True)


if __name__ == "__main__":
    main()
