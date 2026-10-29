"""Export the remaining playgrounds and streets from the original DNA.

Each playground keeps the sky the original hood used. Its streets share that
sky. Chip 'n Dale's MiniGolf is the golf zone, not Acorn Acres. Cog HQs are
left out. Streets are slid onto the origin so the fly camera's look-at still
frames the block. Playgrounds stay where the DNA put them.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from panda3d.core import CollisionNode, CollisionPolygon, Filename, Loader, NodePath, getModelPath, loadPrcFileData
from panda3d.toontown import DNAStorage, loadDNAFile

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP, panda_path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Game Assets"
)
STORAGE = "phase_4/dna/storage.dna"
TOWN = "phase_5/dna/storage_town.dna"

SKY_FILES = [
    ("phase_6/maps/lateday_sky3.png", "assets/neighborhoods/minnies_melodyland/sky/lateday_sky3.png"),
    ("phase_3.5/maps/phase_3.5_palette_3cmla_1.png", "assets/neighborhoods/the_burrrgh/sky/phase_3.5_palette_3cmla_1.png"),
    ("phase_3.5/maps/sky_oc_blue2.png", "assets/neighborhoods/the_burrrgh/sky/sky_oc_blue2.png"),
    ("phase_8/maps/nightsky.png", "assets/neighborhoods/donalds_dreamland/sky/nightsky.png"),
    ("phase_8/maps/nightskytop.png", "assets/neighborhoods/donalds_dreamland/sky/nightskytop.png"),
]

# sky: tt is TT_sky, mm is the sunset panels, br is the overcast panels, dl is the night sky.
JOBS = [
    {
        "slug": "daisy_gardens",
        "root": "DaisyGardens",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/daisy_gardens",
        "sky": "tt",
        "music": "phase_8/audio/bgm/DG_nbrhood.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DG.dna", "phase_8/dna/storage_DG_sz.dna", "phase_8/dna/daisys_garden_sz.dna"],
        "center": False,
        "camera": (70, 18, 90),
    },
    {
        "slug": "oak_street",
        "root": "OakStreet",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/daisy_gardens/streets",
        "sky": "tt",
        "music": "phase_8/audio/bgm/DG_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DG.dna", TOWN, "phase_8/dna/storage_DG_town.dna", "phase_8/dna/daisys_garden_5300.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "elm_street",
        "root": "ElmStreet",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/daisy_gardens/streets",
        "sky": "tt",
        "music": "phase_8/audio/bgm/DG_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DG.dna", TOWN, "phase_8/dna/storage_DG_town.dna", "phase_8/dna/daisys_garden_5100.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "maple_street",
        "root": "MapleStreet",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/daisy_gardens/streets",
        "sky": "tt",
        "music": "phase_8/audio/bgm/DG_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DG.dna", TOWN, "phase_8/dna/storage_DG_town.dna", "phase_8/dna/daisys_garden_5200.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "minnies_melodyland",
        "root": "MinniesMelodyland",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/minnies_melodyland",
        "sky": "mm",
        "music": "phase_6/audio/bgm/MM_nbrhood.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_MM.dna", "phase_6/dna/storage_MM_sz.dna", "phase_6/dna/minnies_melody_land_sz.dna"],
        "center": False,
        "camera": (70, 18, 90),
    },
    {
        "slug": "tenor_terrace",
        "root": "TenorTerrace",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/minnies_melodyland/streets",
        "sky": "mm",
        "music": "phase_6/audio/bgm/MM_SZ.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_MM.dna", TOWN, "phase_6/dna/storage_MM_town.dna", "phase_6/dna/minnies_melody_land_4300.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "baritone_boulevard",
        "root": "BaritoneBoulevard",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/minnies_melodyland/streets",
        "sky": "mm",
        "music": "phase_6/audio/bgm/MM_SZ.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_MM.dna", TOWN, "phase_6/dna/storage_MM_town.dna", "phase_6/dna/minnies_melody_land_4200.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "alto_avenue",
        "root": "AltoAvenue",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/minnies_melodyland/streets",
        "sky": "mm",
        "music": "phase_6/audio/bgm/MM_SZ.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_MM.dna", TOWN, "phase_6/dna/storage_MM_town.dna", "phase_6/dna/minnies_melody_land_4100.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "the_burrrgh",
        "root": "TheBrrrgh",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/the_burrrgh",
        "sky": "br",
        "music": "phase_8/audio/bgm/TB_nbrhood.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_BR.dna", "phase_8/dna/storage_BR_sz.dna", "phase_8/dna/the_burrrgh_sz.dna"],
        "center": False,
        "camera": (70, 18, 90),
    },
    {
        "slug": "polar_place",
        "root": "PolarPlace",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/the_burrrgh/streets",
        "sky": "br",
        "music": "phase_8/audio/bgm/TB_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_BR.dna", TOWN, "phase_8/dna/storage_BR_town.dna", "phase_8/dna/the_burrrgh_3300.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "walrus_way",
        "root": "WalrusWay",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/the_burrrgh/streets",
        "sky": "br",
        "music": "phase_8/audio/bgm/TB_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_BR.dna", TOWN, "phase_8/dna/storage_BR_town.dna", "phase_8/dna/the_burrrgh_3100.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "sleet_street",
        "root": "SleetStreet",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/the_burrrgh/streets",
        "sky": "br",
        "music": "phase_8/audio/bgm/TB_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_BR.dna", TOWN, "phase_8/dna/storage_BR_town.dna", "phase_8/dna/the_burrrgh_3200.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "donalds_dreamland",
        "root": "DonaldsDreamland",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/donalds_dreamland",
        "sky": "dl",
        "music": "phase_8/audio/bgm/DL_nbrhood.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DL.dna", "phase_8/dna/storage_DL_sz.dna", "phase_8/dna/donalds_dreamland_sz.dna"],
        "center": False,
        "camera": (70, 18, 90),
    },
    {
        "slug": "pajama_place",
        "root": "PajamaPlace",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/donalds_dreamland/streets",
        "sky": "dl",
        "music": "phase_8/audio/bgm/DL_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DL.dna", TOWN, "phase_8/dna/storage_DL_town.dna", "phase_8/dna/donalds_dreamland_9200.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "lullaby_lane",
        "root": "LullabyLane",
        "scene_dir": "scenes/streets",
        "asset_dir": "assets/neighborhoods/donalds_dreamland/streets",
        "sky": "dl",
        "music": "phase_8/audio/bgm/DL_SZ.ogg",
        "dna": [STORAGE, "phase_8/dna/storage_DL.dna", TOWN, "phase_8/dna/storage_DL_town.dna", "phase_8/dna/donalds_dreamland_9100.dna"],
        "center": True,
        "camera": (0, 18, 140),
    },
    {
        "slug": "goofy_speedway",
        "root": "GoofySpeedway",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/goofy_speedway",
        "sky": "tt",
        "music": "phase_6/audio/bgm/GS_SZ.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_GS.dna", "phase_6/dna/storage_GS_sz.dna", "phase_6/dna/goofy_speedway_sz.dna"],
        "center": False,
        "camera": (70, 25, 120),
    },
    {
        "slug": "chip_n_dales_minigolf",
        "root": "ChipNDalesMinigolf",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/chip_n_dales_minigolf",
        "sky": "tt",
        "music": "phase_6/audio/bgm/GZ_SZ.ogg",
        "dna": [STORAGE, "phase_6/dna/storage_GZ.dna", "phase_6/dna/storage_GZ_sz.dna", "phase_6/dna/golf_zone_sz.dna"],
        "center": False,
        "camera": (40, 18, 80),
    },
    {
        "slug": "toon_estate",
        "root": "ToonEstate",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/toon_estate",
        "sky": "tt",
        "music": "phase_4/audio/bgm/TC_nbrhood.ogg",
        "dna": [STORAGE, "phase_5.5/dna/storage_estate.dna", "phase_5.5/dna/estate_1.dna"],
        "center": False,
        "camera": (70, 22, 110),
    },
    {
        "slug": "tutorial_zone",
        "root": "TutorialZone",
        "scene_dir": "scenes/playgrounds",
        "asset_dir": "assets/neighborhoods/tutorial_zone",
        "sky": "tt",
        "music": "phase_3.5/audio/bgm/TC_SZ.ogg",
        "dna": [STORAGE, "phase_3.5/dna/storage_tutorial.dna", "phase_3.5/dna/tutorial_street.dna"],
        "center": True,
        "camera": (0, 12, 40),
    },
]


def copy_file(source_rel: str, dest_rel: str) -> None:
    source = ASSETS / source_rel
    dest = ROOT / dest_rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not source.exists():
        print("missing", source, flush=True)
        return
    if not dest.exists() or dest.stat().st_size != source.stat().st_size:
        shutil.copy2(source, dest)
        print("copied", dest_rel, flush=True)


# HouseGlobals.houseDrops, and the five catalog houses. The sixth lot uses the
# default house again. Type 5 in the original is the test house.
ESTATE_HOUSES = [
    "phase_5.5/models/estate/houseA.bam",
    "phase_5.5/models/estate/tt_m_ara_est_house_tiki.bam",
    "phase_5.5/models/estate/tt_m_ara_est_house_tepee.bam",
    "phase_5.5/models/estate/tt_m_ara_est_house_castle.bam",
    "phase_5.5/models/estate/tt_m_ara_est_house_cupcake.bam",
    "phase_5.5/models/estate/houseA.bam",
]
ESTATE_DROPS = [
    (-56.7788, -42.8756, 4.06471, -90, 0, 0),
    (83.3909, -77.5085, 0.0708361, 116.565, 0, 0),
    (-69.077, -119.496, 0.025, 77.1957, 0, 0),
    (63.4545, 11.0656, 8.05158, 356.6, 0, 0),
    (43.9315, 76.72, 0.0377455, 248.962, 0, 0),
    (-36.9122, 36.3429, 2.49382, 36.8699, 0, 0),
]


def attach_estate_houses(geom: NodePath) -> None:
    loader = Loader.getGlobalPtr()
    for index, (relative, drop) in enumerate(zip(ESTATE_HOUSES, ESTATE_DROPS)):
        loaded = loader.loadSync(panda_path(relative))
        if loaded is None:
            print("missing house", relative, flush=True)
            continue
        house = NodePath(loaded)
        house.setName(f"esHouse_{index}")
        house.reparentTo(geom)
        x, y, z, heading, pitch, roll = drop
        house.setPosHpr(x, y, z, heading, pitch, roll)
        print("house", index, relative, flush=True)


def load_geom(files: list[str]) -> tuple[NodePath, DNAStorage]:
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    store = DNAStorage()
    node = None
    for relative in files:
        print("loading", relative, flush=True)
        node = loadDNAFile(store, panda_path(relative), 0)
    if node is None:
        raise RuntimeError("DNA loader returned nothing")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)
    return geom, store


def _zone_name(path: NodePath) -> str:
    current = path
    while not current.isEmpty():
        name = current.getName().split(":", 1)[0]
        if name.isdigit() and len(name) == 4:
            return name
        current = current.getParent()
    return ""


def floor_shift(geom: NodePath) -> tuple[float, float]:
    """Slide the street so its floors sit on the origin, not the bounding sphere.

    A far-off prop pulls the sphere center away from the block the camera
    should look at. The floor cells are the block.
    """
    xs: list[float] = []
    ys: list[float] = []
    for collision_path in geom.findAllMatches("**/+CollisionNode"):
        node = collision_path.node()
        if not node.isOfType(CollisionNode.getClassType()):
            continue
        if not node.getIntoCollideMask().getBit(1):
            continue
        for solid_index in range(node.getNumSolids()):
            solid = node.getSolid(solid_index)
            if not solid.isOfType(CollisionPolygon.getClassType()):
                continue
            for point_index in range(solid.getNumPoints()):
                world = collision_path.getMat(geom).xformPoint(solid.getPoint(point_index))
                xs.append(world.x)
                ys.append(world.y)
    if not xs:
        center = geom.getBounds().getCenter()
        return -center.x, -center.y
    return -sum(xs) / len(xs), -sum(ys) / len(ys)


def write_zones(path: Path, geom: NodePath, store: DNAStorage, shift_x: float, shift_y: float) -> None:
    zones: dict[str, dict] = {}
    for index in range(store.getNumDNAVisGroups()):
        owner = store.getDNAVisGroupName(index).split(":", 1)[0]
        visible = []
        for visible_index in range(store.getNumVisiblesInDNAVisGroup(index)):
            name = store.getVisibleName(index, visible_index).split(":", 1)[0]
            if name not in visible:
                visible.append(name)
        if owner not in visible:
            visible.append(owner)
        zones[owner] = {"vis": visible, "polygons": []}

    for collision_path in geom.findAllMatches("**/+CollisionNode"):
        node = collision_path.node()
        if not node.isOfType(CollisionNode.getClassType()):
            continue
        if not node.getIntoCollideMask().getBit(1):
            continue
        owner = _zone_name(collision_path)
        if owner not in zones:
            continue
        for solid_index in range(node.getNumSolids()):
            solid = node.getSolid(solid_index)
            if not solid.isOfType(CollisionPolygon.getClassType()):
                continue
            polygon = []
            for point_index in range(solid.getNumPoints()):
                world = collision_path.getMat(geom).xformPoint(solid.getPoint(point_index))
                polygon.append([
                    round(world.x + shift_x, 3),
                    round(-world.y - shift_y, 3),
                ])
            if len(polygon) >= 3:
                zones[owner]["polygons"].append(polygon)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(zones, separators=(",", ":")), encoding="utf-8")
    cells = sum(len(zone["polygons"]) for zone in zones.values())
    print(f"wrote {path} zones={len(zones)} floor_cells={cells}", flush=True)


def write_scene(job: dict, music_rel: str, zones_rel: str) -> None:
    glb_rel = f"{job['asset_dir']}/{job['slug']}.glb"
    scene_path = ROOT / job["scene_dir"] / f"{job['slug']}.tscn"
    scene_path.parent.mkdir(parents=True, exist_ok=True)
    x, y, z = job["camera"]
    zones_line = f'zones_path = "res://{zones_rel}"\n' if zones_rel else ""
    scene_path.write_text(
        "\n".join([
            "[gd_scene load_steps=5 format=3]",
            "",
            f'[ext_resource type="PackedScene" path="res://{glb_rel}" id="1_geom"]',
            '[ext_resource type="Script" path="res://scenes/playgrounds/playground_collision.gd" id="2_collision"]',
            '[ext_resource type="Script" path="res://scenes/playgrounds/fly_camera.gd" id="3_fly"]',
            '[ext_resource type="Script" path="res://scenes/playgrounds/neighborhood.gd" id="4_hood"]',
            "",
            '[sub_resource type="Environment" id="Environment_day"]',
            "background_mode = 1",
            "background_color = Color(0.05098, 0.286275, 0.72549, 1)",
            "ambient_light_source = 2",
            "ambient_light_color = Color(1, 1, 1, 1)",
            "",
            f'[node name="{job["root"]}" type="Node3D"]',
            'script = ExtResource("4_hood")',
            f'music_path = "res://{music_rel}"',
            f'sky_kind = "{job["sky"]}"',
            zones_line.rstrip(),
            "",
            '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]',
            'environment = SubResource("Environment_day")',
            "",
            '[node name="Geometry" parent="." instance=ExtResource("1_geom")]',
            'script = ExtResource("2_collision")',
            "",
            '[node name="Camera" type="Camera3D" parent="."]',
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})",
            "current = true",
            "far = 4000.0",
            'script = ExtResource("3_fly")',
            "",
        ]),
        encoding="utf-8",
    )
    print("wrote", scene_path, flush=True)


def export_job(job: dict, force: bool) -> None:
    asset_dir = ROOT / job["asset_dir"]
    asset_dir.mkdir(parents=True, exist_ok=True)
    music_name = Path(job["music"]).name
    music_rel = f"{job['asset_dir']}/audio/{music_name}" if job["scene_dir"].endswith("playgrounds") else (
        str(Path(job["asset_dir"]).parent / "audio" / music_name).replace("\\", "/")
    )
    # Streets share the playground's audio folder, one level up from streets/.
    if job["asset_dir"].endswith("streets"):
        music_rel = str(Path(job["asset_dir"]).parent.as_posix() + f"/audio/{music_name}")
        music_rel = music_rel.replace("assets/", "assets/") 
    copy_file(job["music"], music_rel)
    zones_rel = ""
    glb = asset_dir / f"{job['slug']}.glb"
    if glb.exists() and not force:
        print("keep", glb, flush=True)
        if job["center"]:
            zones_rel = f"{job['asset_dir']}/{job['slug']}_zones.json"
        write_scene(job, music_rel, zones_rel)
        return

    try:
        geom, store = load_geom(job["dna"])
    except Exception:
        if job["slug"] != "tutorial_zone":
            raise
        print("retry tutorial without the shared storage file", flush=True)
        geom, store = load_geom(job["dna"][1:])
    if job["slug"] == "toon_estate":
        attach_estate_houses(geom)
    shift_x = 0.0
    shift_y = 0.0
    if job["center"]:
        shift_x, shift_y = floor_shift(geom)
        geom.setPos(shift_x, shift_y, 0)
        print("centered by floor shift", round(shift_x, 2), round(shift_y, 2), flush=True)
        zones_path = asset_dir / f"{job['slug']}_zones.json"
        write_zones(zones_path, geom, store, shift_x, shift_y)
        zones_rel = f"{job['asset_dir']}/{job['slug']}_zones.json"

    root = NodePath(job["root"])
    root.setMat(Z_UP_TO_Y_UP)
    geom.copyTo(root)
    print("export bounds", root.getBounds(), flush=True)
    writer = GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(job["root"])
    glb.write_bytes(payload)
    print(
        f"wrote {glb} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"nodes={len(writer.nodes)} meshes={writer.mesh_count} tris={writer.tri_count}",
        flush=True,
    )
    write_scene(job, music_rel, zones_rel)
    root.removeNode()
    geom.removeNode()


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    force = "--force" in sys.argv
    wanted = {arg for arg in sys.argv[1:] if not arg.startswith("--")}
    for source, dest in SKY_FILES:
        copy_file(source, dest)
    failed = []
    for job in JOBS:
        if wanted and job["slug"] not in wanted:
            continue
        print("====", job["slug"], flush=True)
        try:
            export_job(job, force)
        except Exception as error:
            failed.append(job["slug"])
            print("FAILED", job["slug"], error, flush=True)
    if failed:
        print("failed:", ", ".join(failed), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
