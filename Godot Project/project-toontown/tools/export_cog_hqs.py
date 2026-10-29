"""Export the Cog HQ courtyards, lobbies, and boss arenas from the original models.

The mints, DA offices, and cog golf courses are not exported. Front Factory and
Side Factory share one interior; each scene is shifted so its entrance sits at
the origin, where the fly camera looks.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from panda3d.core import Filename, Loader, NodePath, getModelPath, loadPrcFileData

from export_toontown_central import GltfWriter, Z_UP_TO_Y_UP, panda_path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Game Assets"
)
SCENE_DIR = ROOT / "scenes" / "cog_hq"
ASSET_DIR = ROOT / "assets" / "cog_hq"
AUDIO = "assets/cog_hq/audio"
SKY_GLB = "assets/cog_hq/sky/cog_sky.glb"

NBRHOOD = "phase_9/audio/bgm/encntr_suit_HQ_nbrhood.ogg"
FACTORY = "phase_9/audio/bgm/CHQ_FACT_bg.ogg"
BATTLE = "phase_7/audio/bgm/encntr_suit_winning_indoor.ogg"
LAW = "phase_11/audio/bgm/LB_courtyard.ogg"
JURY = "phase_11/audio/bgm/LB_juryBG.ogg"
BOSS_ENTRY = "phase_12/audio/bgm/Bossbot_Entry_v1.ogg"
CEO = "phase_12/audio/bgm/BossBot_CEO_v1.ogg"


def copy_music(relative: str) -> str:
    name = Path(relative).name
    dest_rel = f"{AUDIO}/{name}"
    source = ASSETS / relative
    dest = ROOT / dest_rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if source.exists() and (not dest.exists() or dest.stat().st_size != source.stat().st_size):
        shutil.copy2(source, dest)
        print("copied", dest_rel, flush=True)
    elif not source.exists():
        print("missing music", relative, flush=True)
    return dest_rel


def load_model(relative: str) -> NodePath:
    loader = Loader.getGlobalPtr()
    loaded = loader.loadSync(panda_path(relative))
    if loaded is None:
        raise RuntimeError(f"missing model {relative}")
    node = NodePath(loaded)
    node.setName(Path(relative).stem)
    return node


def export_node(node: NodePath, dest: Path, scene_name: str) -> None:
    root = NodePath(scene_name)
    root.setMat(Z_UP_TO_Y_UP)
    node.copyTo(root)
    writer = GltfWriter()
    writer.add_node(root, None)
    payload = writer.pack(scene_name)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    center = node.getBounds().getCenter()
    print(
        f"wrote {dest.name} ({len(payload) / (1024 * 1024):.1f} MB) "
        f"panda_center=({center.x:.1f},{center.y:.1f},{center.z:.1f}) "
        f"r={node.getBounds().getRadius():.1f}",
        flush=True,
    )


def write_scene(slug: str, root_name: str, glb_rel: str, music_rel: str, sky_kind: str, mesh_sky: bool, shift_x: float, shift_z: float, eye: float, distance: float, face: str = "north", camera: str | None = None, lift: float = 0.0) -> None:
    scene_path = SCENE_DIR / f"{slug}.tscn"
    scene_path.parent.mkdir(parents=True, exist_ok=True)
    resources = [
        f'[ext_resource type="PackedScene" path="res://{glb_rel}" id="1_geom"]',
        '[ext_resource type="Script" path="res://scenes/playgrounds/playground_collision.gd" id="2_collision"]',
        '[ext_resource type="Script" path="res://scenes/playgrounds/fly_camera.gd" id="3_fly"]',
        '[ext_resource type="Script" path="res://scenes/playgrounds/neighborhood.gd" id="4_hood"]',
    ]
    steps = 5
    sky_node = ""
    if mesh_sky:
        resources.append(f'[ext_resource type="PackedScene" path="res://{SKY_GLB}" id="5_sky"]')
        steps = 6
        sky_node = '\n[node name="CogSky" parent="." instance=ExtResource("5_sky")]\n'
    scene_path.write_text(
        "\n".join([
            f"[gd_scene load_steps={steps} format=3]",
            "",
            *resources,
            "",
            '[sub_resource type="Environment" id="Environment_day"]',
            "background_mode = 1",
            "background_color = Color(0.28, 0.32, 0.38, 1)",
            "ambient_light_source = 2",
            "ambient_light_color = Color(1, 1, 1, 1)",
            "",
            f'[node name="{root_name}" type="Node3D"]',
            'script = ExtResource("4_hood")',
            f'music_path = "res://{music_rel}"',
            f'sky_kind = "{sky_kind}"',
            "",
            '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]',
            'environment = SubResource("Environment_day")',
            "",
            '[node name="Geometry" parent="." instance=ExtResource("1_geom")]',
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {shift_x:.3f}, {lift:.3f}, {shift_z:.3f})",
            'script = ExtResource("2_collision")',
            sky_node.rstrip(),
            '[node name="Camera" type="Camera3D" parent="."]',
            (
                f"transform = {camera}"
                if camera
                else (
                    f"transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, {eye}, {-distance})"
                    if face == "south"
                    else f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {eye}, {distance})"
                )
            ),
            "current = true",
            "far = 4000.0",
            'script = ExtResource("3_fly")',
            "",
        ]),
        encoding="utf-8",
    )
    print("wrote", scene_path.name, flush=True)


def shift_for(node: NodePath, focus) -> tuple[float, float]:
    """Godot XZ translation that puts a panda (x, y) point on the origin."""
    if focus is None:
        center = node.getBounds().getCenter()
        focus = (center.x, center.y)
    panda_x, panda_y = focus
    return -panda_x, panda_y


def build_sellbot_vp() -> NodePath:
    room = load_model("phase_9/models/cogHQ/BossRoomHQ.bam")
    elevator = load_model("phase_9/models/cogHQ/cogHQ_elevator.bam")
    entrance = room.find("**/elevatorEntrance")
    if entrance.isEmpty():
        elevator.reparentTo(room)
    else:
        entrance.getChildren().detach()
        elevator.reparentTo(entrance)
    return room


def build_cashbot_cfo() -> NodePath:
    group = NodePath("CashbotCfo")
    mid = load_model("phase_10/models/cogHQ/MidVault.bam")
    end = load_model("phase_10/models/cogHQ/EndVault.bam")
    mid.setPos(0, -222, -70.7)
    end.setPos(84, -201, -6)
    mid.reparentTo(group)
    end.reparentTo(group)
    elevator = load_model("phase_10/models/cogHQ/CFOElevator.bam")
    origin = mid.find("**/elevator_origin")
    elevator.reparentTo(origin if not origin.isEmpty() else mid)
    return group


def build_lawbot_cj() -> NodePath:
    room = load_model("phase_11/models/lawbotHQ/LawbotCourtroom3.bam")
    room.setPos(0, 0, -71.601)
    elevator = load_model("phase_11/models/lawbotHQ/LB_Elevator.bam")
    origin = room.find("**/elevator_origin")
    elevator.reparentTo(origin if not origin.isEmpty() else room)
    scale = load_model("phase_11/models/lawbotHQ/scale.bam")
    scale.setPosHpr(-3, 12, 71.601, 90, 0, 0)
    scale.setScale(1.75, 1.75, 1.5)
    scale.reparentTo(room)
    return room


def build_bossbot_ceo() -> NodePath:
    room = load_model("phase_12/models/bossbotHQ/BanquetInterior_1.bam")
    elevator = load_model("phase_12/models/bossbotHQ/BB_Inside_Elevator.bam")
    origin = room.find("**/elevator_origin")
    elevator.reparentTo(origin if not origin.isEmpty() else room)
    return room


# focus is a panda (x, y) point to park at the origin. None uses the bounds center.
# mesh_sky follows the camera on outdoor cog backdrops. Cashbot uses the Toontown sky.
JOBS = [
    {"slug": "sellbot_courtyard", "root": "SellbotCourtyard", "model": "phase_9/models/cogHQ/SellbotHQExterior.bam", "music": NBRHOOD, "sky": "cog", "mesh_sky": True, "focus": (5.0, -145.4), "eye": 28, "distance": 120},
    {"slug": "sellbot_factory_exterior", "root": "SellbotFactoryExterior", "model": "phase_9/models/cogHQ/SellbotFactoryExterior.bam", "music": NBRHOOD, "sky": "cog", "mesh_sky": True, "focus": (62.8, -85.6), "face": "south", "eye": 8, "distance": 36},
    {"slug": "sellbot_factory", "root": "SellbotFactory", "model": "phase_9/models/cogHQ/SelbotLegFactory.bam", "scenes": [
        {"slug": "sellbot_front_factory", "root": "SellbotFrontFactory", "focus": (20.7, 26.2), "music": FACTORY, "sky": "cog", "mesh_sky": False, "eye": 8, "distance": 24},
        {"slug": "sellbot_side_factory", "root": "SellbotSideFactory", "focus": (-644.2, 371.1), "music": FACTORY, "sky": "cog", "mesh_sky": False, "eye": 8, "distance": 24},
    ]},
    {"slug": "sellbot_lobby", "root": "SellbotLobby", "model": "phase_9/models/cogHQ/SellbotHQLobby.bam", "music": NBRHOOD, "sky": "cog", "mesh_sky": False, "eye": 12, "distance": 36},
    {"slug": "sellbot_vp", "root": "SellbotVp", "build": build_sellbot_vp, "music": BATTLE, "sky": "cog", "mesh_sky": True, "eye": 24, "distance": 80},
    {"slug": "cashbot_trainyard", "root": "CashbotTrainyard", "model": "phase_10/models/cogHQ/CashBotShippingStation.bam", "music": NBRHOOD, "sky": "tt", "mesh_sky": False, "focus": (177.3, -103.4), "eye": 40, "distance": 180},
    {"slug": "cashbot_lobby", "root": "CashbotLobby", "model": "phase_10/models/cogHQ/VaultLobby.bam", "music": NBRHOOD, "sky": "tt", "mesh_sky": False, "focus": (113.6, -99.2), "lift": -33.2, "eye": 10, "distance": 22},
    {"slug": "cashbot_cfo", "root": "CashbotCfo", "build": build_cashbot_cfo, "music": BATTLE, "sky": "tt", "mesh_sky": False, "focus": (108.8, -230.6), "eye": 12, "distance": 36, "camera": "Transform3D(0.682318, 0.139884, -0.717547, 0, 0.981523, 0.191346, 0.731055, -0.130559, 0.669711, -30, 12, 28)"},
    {"slug": "lawbot_courtyard", "root": "LawbotCourtyard", "model": "phase_11/models/lawbotHQ/LawbotPlaza.bam", "music": LAW, "sky": "cog", "mesh_sky": True, "focus": (-179.7, -190.1), "eye": 22, "distance": 80},
    {"slug": "lawbot_da_lobby", "root": "LawbotDaLobby", "model": "phase_11/models/lawbotHQ/LB_DA_Lobby.bam", "music": LAW, "sky": "cog", "mesh_sky": True, "focus": (106.0, -263.0), "lift": -51.2, "eye": 6, "distance": 18},
    {"slug": "lawbot_lobby", "root": "LawbotLobby", "model": "phase_11/models/lawbotHQ/LB_CH_Lobby.bam", "music": LAW, "sky": "cog", "mesh_sky": False, "focus": (124.6, -108.6), "lift": -33.4, "eye": 8, "distance": 18},
    {"slug": "lawbot_cj", "root": "LawbotCj", "build": build_lawbot_cj, "music": JURY, "sky": "cog", "mesh_sky": False, "focus": (21.2, 77.8), "eye": 14, "distance": 45},
    {"slug": "bossbot_country_club", "root": "BossbotCountryClub", "model": "phase_12/models/bossbotHQ/CogGolfHub.bam", "music": BOSS_ENTRY, "sky": "cog", "mesh_sky": True, "focus": (65.7, 134.1), "eye": 24, "distance": 100},
    {"slug": "bossbot_lobby", "root": "BossbotLobby", "model": "phase_12/models/bossbotHQ/CogGolfCourtyard.bam", "music": BOSS_ENTRY, "sky": "cog", "mesh_sky": True, "focus": (66.0, 134.1), "eye": 22, "distance": 90},
    {"slug": "bossbot_ceo", "root": "BossbotCeo", "build": build_bossbot_ceo, "music": CEO, "sky": "cog", "mesh_sky": False, "focus": (-10.6, 0.5), "eye": 12, "distance": 36},
]


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    getModelPath().prependDirectory(Filename.from_os_specific(str(ASSETS)))
    force = "--force" in sys.argv
    wanted = {arg for arg in sys.argv[1:] if not arg.startswith("--")}
    sky_path = ROOT / SKY_GLB
    if force or not sky_path.exists():
        export_node(load_model("phase_9/models/cogHQ/cog_sky.bam"), sky_path, "CogSky")
    failed = []
    for job in JOBS:
        scenes = job.get("scenes", [job])
        if wanted and job["slug"] not in wanted and not any(scene["slug"] in wanted for scene in scenes):
            continue
        print("====", job["slug"], flush=True)
        try:
            glb_rel = f"assets/cog_hq/{job['slug']}.glb"
            glb = ROOT / glb_rel
            node = None
            if force or not glb.exists():
                if "build" in job:
                    node = job["build"]()
                else:
                    node = load_model(job["model"])
                export_node(node, glb, job["root"])
            else:
                print("keep", glb.name, flush=True)
                if "build" in job:
                    node = job["build"]()
                else:
                    node = load_model(job["model"])
            for scene in scenes:
                if wanted and scene["slug"] not in wanted and job["slug"] not in wanted:
                    continue
                music_rel = copy_music(scene["music"])
                shift_x, shift_z = shift_for(node, scene.get("focus"))
                write_scene(
                    scene["slug"],
                    scene["root"],
                    glb_rel,
                    music_rel,
                    scene["sky"],
                    scene["mesh_sky"],
                    shift_x,
                    shift_z,
                    scene["eye"],
                    scene["distance"],
                    scene.get("face", "north"),
                    scene.get("camera"),
                    scene.get("lift", 0.0),
                )
            if node is not None:
                node.removeNode()
        except Exception as error:
            failed.append(job["slug"])
            print("FAILED", job["slug"], error, flush=True)
    if failed:
        print("failed:", ", ".join(failed), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
