"""Export street cog suits, their animations, and each street's suit graph.

Models and clips come from the original suit BAMs. want-new-cogs is off, and
the Cog HQ bosses are left out. Street graphs are the DNA STREETPOINTs, shifted
the same way the street mesh was, plus each visgroup's battle cell.

Boss sit and tray clips (phase 12) belong to the C.E.O. and are not exported.
"""
from __future__ import annotations

import json
import os
import shutil
import struct
import sys
from pathlib import Path

_add_dll = os.add_dll_directory


def _safe_add_dll(path):
    if os.path.isdir(path):
        return _add_dll(path)

    class _Dummy:
        def close(self):
            return None

        def __enter__(self):
            return None

        def __exit__(self, *_args):
            return False

    return _Dummy()


os.add_dll_directory = _safe_add_dll

from panda3d.core import Filename, NodePath, Texture, Vec4, getModelPath, loadPrcFileData
from panda3d.toontown import DNAStorage, DNASuitPoint, loadDNAFile

import export_make_a_toon as toon_export
import export_neighborhoods
import export_toon_walk as walk_export
import export_toontown_central as exporter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    r"C:\Users\Kyle\Desktop\Programming\Projects\Miscellaneous\Project Toontown"
    r"\Original Toontown Assets\Game Assets"
)
SUITS = ROOT / "assets" / "cogs" / "suits"
ANIMS = ROOT / "assets" / "cogs" / "anims"
PROPS = ROOT / "assets" / "cogs" / "props"
AUDIO = ROOT / "assets" / "cogs" / "audio"

# SuitHoodInfo rows for the playground streets. Count is (min + max) // 2,
# which is baseNumSuits. Track weights are Bossbot, Lawbot, Cashbot, Sellbot.
# Levels are the planner's level list. HQ rows are not included.
STREETS = [
    {
        "slug": "silly_street",
        "zone": 2100,
        "count": 10,
        "tracks": [25, 25, 25, 25],
        "levels": [1, 2, 3],
        "shift": "none",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_4/dna/storage_TT.dna",
            "phase_5/dna/storage_town.dna",
            "phase_5/dna/storage_TT_town.dna",
            "phase_5/dna/toontown_central_2100.dna",
        ],
        "out": "assets/neighborhoods/toontown_central/streets/silly_street_suits.json",
    },
    {
        "slug": "loopy_lane",
        "zone": 2200,
        "count": 6,
        "tracks": [10, 70, 10, 10],
        "levels": [1, 2, 3],
        "shift": "none",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_4/dna/storage_TT.dna",
            "phase_5/dna/storage_town.dna",
            "phase_5/dna/storage_TT_town.dna",
            "phase_5/dna/toontown_central_2200.dna",
        ],
        "out": "assets/neighborhoods/toontown_central/streets/loopy_lane_suits.json",
    },
    {
        "slug": "punchline_place",
        "zone": 2300,
        "count": 6,
        "tracks": [10, 10, 40, 40],
        "levels": [1, 2, 3],
        "shift": "none",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_4/dna/storage_TT.dna",
            "phase_5/dna/storage_town.dna",
            "phase_5/dna/storage_TT_town.dna",
            "phase_5/dna/toontown_central_2300.dna",
        ],
        "out": "assets/neighborhoods/toontown_central/streets/punchline_place_suits.json",
    },
    {
        "slug": "barnacle_boulevard",
        "zone": 1100,
        "count": 3,
        "tracks": [90, 10, 0, 0],
        "levels": [2, 3, 4],
        "shift": "bounds",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_DD.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_DD_town.dna",
            "phase_6/dna/donalds_dock_1100.dna",
        ],
        "out": "assets/neighborhoods/donalds_dock/streets/barnacle_boulevard_suits.json",
    },
    {
        "slug": "seaweed_street",
        "zone": 1200,
        "count": 3,
        "tracks": [0, 0, 90, 10],
        "levels": [3, 4, 5, 6],
        "shift": "bounds",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_DD.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_DD_town.dna",
            "phase_6/dna/donalds_dock_1200.dna",
        ],
        "out": "assets/neighborhoods/donalds_dock/streets/seaweed_street_suits.json",
    },
    {
        "slug": "lighthouse_lane",
        "zone": 1300,
        "count": 3,
        "tracks": [40, 40, 10, 10],
        "levels": [3, 4, 5, 6],
        "shift": "bounds",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_DD.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_DD_town.dna",
            "phase_6/dna/donalds_dock_1300.dna",
        ],
        "out": "assets/neighborhoods/donalds_dock/streets/lighthouse_lane_suits.json",
    },
    {
        "slug": "oak_street",
        "zone": 5300,
        "count": 3,
        "tracks": [5, 5, 5, 85],
        "levels": [3, 4, 5, 6],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_DG.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_DG_town.dna",
            "phase_8/dna/daisys_garden_5300.dna",
        ],
        "out": "assets/neighborhoods/daisy_gardens/streets/oak_street_suits.json",
    },
    {
        "slug": "elm_street",
        "zone": 5100,
        "count": 3,
        "tracks": [0, 20, 10, 70],
        "levels": [2, 3, 4],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_DG.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_DG_town.dna",
            "phase_8/dna/daisys_garden_5100.dna",
        ],
        "out": "assets/neighborhoods/daisy_gardens/streets/elm_street_suits.json",
    },
    {
        "slug": "maple_street",
        "zone": 5200,
        "count": 3,
        "tracks": [10, 70, 0, 20],
        "levels": [3, 4, 5, 6],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_DG.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_DG_town.dna",
            "phase_8/dna/daisys_garden_5200.dna",
        ],
        "out": "assets/neighborhoods/daisy_gardens/streets/maple_street_suits.json",
    },
    {
        "slug": "baritone_boulevard",
        "zone": 4200,
        "count": 3,
        "tracks": [0, 0, 90, 10],
        "levels": [3, 4, 5, 6],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_MM.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_MM_town.dna",
            "phase_6/dna/minnies_melody_land_4200.dna",
        ],
        "out": "assets/neighborhoods/minnies_melodyland/streets/baritone_boulevard_suits.json",
    },
    {
        "slug": "alto_avenue",
        "zone": 4100,
        "count": 3,
        "tracks": [0, 0, 50, 50],
        "levels": [2, 3, 4],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_MM.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_MM_town.dna",
            "phase_6/dna/minnies_melody_land_4100.dna",
        ],
        "out": "assets/neighborhoods/minnies_melodyland/streets/alto_avenue_suits.json",
    },
    {
        "slug": "tenor_terrace",
        "zone": 4300,
        "count": 3,
        "tracks": [50, 50, 0, 0],
        "levels": [3, 4, 5, 6],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_6/dna/storage_MM.dna",
            "phase_5/dna/storage_town.dna",
            "phase_6/dna/storage_MM_town.dna",
            "phase_6/dna/minnies_melody_land_4300.dna",
        ],
        "out": "assets/neighborhoods/minnies_melodyland/streets/tenor_terrace_suits.json",
    },
    {
        "slug": "sleet_street",
        "zone": 3200,
        "count": 3,
        "tracks": [10, 20, 30, 40],
        "levels": [5, 6, 7],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_BR.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_BR_town.dna",
            "phase_8/dna/the_burrrgh_3200.dna",
        ],
        "out": "assets/neighborhoods/the_burrrgh/streets/sleet_street_suits.json",
    },
    {
        "slug": "walrus_way",
        "zone": 3100,
        "count": 3,
        "tracks": [90, 10, 0, 0],
        "levels": [5, 6, 7],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_BR.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_BR_town.dna",
            "phase_8/dna/the_burrrgh_3100.dna",
        ],
        "out": "assets/neighborhoods/the_burrrgh/streets/walrus_way_suits.json",
    },
    {
        "slug": "polar_place",
        "zone": 3300,
        "count": 3,
        "tracks": [5, 85, 5, 5],
        "levels": [7, 8, 9],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_BR.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_BR_town.dna",
            "phase_8/dna/the_burrrgh_3300.dna",
        ],
        "out": "assets/neighborhoods/the_burrrgh/streets/polar_place_suits.json",
    },
    {
        "slug": "pajama_place",
        "zone": 9200,
        "count": 3,
        "tracks": [5, 5, 85, 5],
        "levels": [6, 7, 8, 9],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_DL.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_DL_town.dna",
            "phase_8/dna/donalds_dreamland_9200.dna",
        ],
        "out": "assets/neighborhoods/donalds_dreamland/streets/pajama_place_suits.json",
    },
    {
        "slug": "lullaby_lane",
        "zone": 9100,
        "count": 3,
        "tracks": [25, 25, 25, 25],
        "levels": [6, 7, 8, 9],
        "shift": "floor",
        "dna": [
            "phase_4/dna/storage.dna",
            "phase_8/dna/storage_DL.dna",
            "phase_5/dna/storage_town.dna",
            "phase_8/dna/storage_DL_town.dna",
            "phase_8/dna/donalds_dreamland_9100.dna",
        ],
        "out": "assets/neighborhoods/donalds_dreamland/streets/lullaby_lane_suits.json",
    },
]

# Shared clips every suit loads. File stem, phase. Phase 0 means the body's phase.
SHARED = [
    ("walk", "walk", 0),
    ("neutral", "neutral", 0),
    ("lose", "lose", 0),
    ("pie-small", "pie-small", 0),
    ("squirt-small", "squirt-small", 0),
    ("drop-react", "anvil-drop", 5),
    ("flatten", "drop", 5),
    ("sidestep-left", "sidestep-left", 5),
    ("sidestep-right", "sidestep-right", 5),
    ("squirt-large", "squirt-large", 5),
    ("landing", "landing", 5),
    ("reach", "walknreach", 5),
    ("rake-react", "rake", 5),
    ("hypnotized", "hypnotize", 5),
    ("soak", "soak", 5),
]

# key, file stem, phase. Same lists as Suit.py. CEO clips are not here.
ATTACKS = {
    "f": [("throw-paper", "throw-paper", 3.5), ("phone", "phone", 3.5), ("shredder", "shredder", 3.5)],
    "p": [("pencil-sharpener", "pencil-sharpener", 5), ("pen-squirt", "pen-squirt", 5), ("hold-eraser", "hold-eraser", 5), ("finger-wag", "finger-wag", 5), ("hold-pencil", "hold-pencil", 5)],
    "ym": [("throw-paper", "throw-paper", 5), ("golf-club-swing", "golf-club-swing", 5), ("magic3", "magic3", 5), ("rubber-stamp", "rubber-stamp", 5), ("smile", "smile", 5)],
    "mm": [("speak", "speak", 5), ("effort", "effort", 5), ("magic1", "magic1", 5), ("pen-squirt", "fountain-pen", 5), ("finger-wag", "finger-wag", 5)],
    "ds": [("magic1", "magic1", 5), ("magic2", "magic2", 5), ("throw-paper", "throw-paper", 5), ("magic3", "magic3", 5)],
    "hh": [("pen-squirt", "fountain-pen", 7), ("glower", "glower", 5), ("throw-paper", "throw-paper", 5), ("magic1", "magic1", 5), ("roll-o-dex", "roll-o-dex", 5)],
    "cr": [("pickpocket", "pickpocket", 5), ("throw-paper", "throw-paper", 3.5), ("glower", "glower", 5)],
    "tbc": [("cigar-smoke", "cigar-smoke", 8), ("glower", "glower", 5), ("song-and-dance", "song-and-dance", 8), ("golf-club-swing", "golf-club-swing", 5)],
    "bf": [("pickpocket", "pickpocket", 5), ("rubber-stamp", "rubber-stamp", 5), ("shredder", "shredder", 3.5), ("watercooler", "watercooler", 5)],
    "b": [("effort", "effort", 5), ("throw-paper", "throw-paper", 5), ("throw-object", "throw-object", 5), ("magic1", "magic1", 5)],
    "dt": [("rubber-stamp", "rubber-stamp", 5), ("throw-paper", "throw-paper", 5), ("speak", "speak", 5), ("finger-wag", "fingerwag", 5)],
    "ac": [("throw-object", "throw-object", 5), ("roll-o-dex", "roll-o-dex", 5), ("stomp", "stomp", 5), ("phone", "phone", 5), ("throw-paper", "throw-paper", 5)],
    "bs": [("magic1", "magic1", 5), ("throw-paper", "throw-paper", 5), ("finger-wag", "fingerwag", 5)],
    "sd": [("magic2", "magic2", 5), ("quick-jump", "jump", 6), ("stomp", "stomp", 5), ("magic3", "magic3", 5), ("hold-pencil", "hold-pencil", 5), ("throw-paper", "throw-paper", 5)],
    "le": [("speak", "speak", 5), ("throw-object", "throw-object", 5), ("glower", "glower", 5), ("throw-paper", "throw-paper", 5)],
    "bw": [("finger-wag", "fingerwag", 5), ("cigar-smoke", "cigar-smoke", 8), ("gavel", "gavel", 8), ("magic1", "magic1", 5), ("throw-object", "throw-object", 5), ("throw-paper", "throw-paper", 5)],
    "sc": [("throw-paper", "throw-paper", 3.5), ("watercooler", "watercooler", 5), ("pickpocket", "pickpocket", 5)],
    "pp": [("throw-paper", "throw-paper", 5), ("glower", "glower", 5), ("finger-wag", "fingerwag", 5)],
    "tw": [("throw-paper", "throw-paper", 3.5), ("glower", "glower", 5), ("magic2", "magic2", 5), ("finger-wag", "finger-wag", 5)],
    "bc": [("phone", "phone", 5), ("hold-pencil", "hold-pencil", 5)],
    "nc": [("phone", "phone", 5), ("throw-object", "throw-object", 5)],
    "mb": [("magic1", "magic1", 5), ("throw-paper", "throw-paper", 3.5)],
    "ls": [("throw-paper", "throw-paper", 5), ("throw-object", "throw-object", 5), ("hold-pencil", "hold-pencil", 5)],
    "rb": [("glower", "glower", 5), ("magic1", "magic1", 5), ("golf-club-swing", "golf-club-swing", 5)],
    "cc": [("speak", "speak", 5), ("glower", "glower", 5), ("phone", "phone", 3.5), ("finger-wag", "finger-wag", 5)],
    "tm": [("speak", "speak", 5), ("throw-paper", "throw-paper", 5), ("pickpocket", "pickpocket", 5), ("roll-o-dex", "roll-o-dex", 5), ("finger-wag", "finger-wag", 5)],
    "nd": [("pickpocket", "pickpocket", 5), ("roll-o-dex", "roll-o-dex", 5), ("magic3", "magic3", 5), ("smile", "smile", 5)],
    "gh": [("speak", "speak", 5), ("pen-squirt", "fountain-pen", 5), ("rubber-stamp", "rubber-stamp", 5)],
    "ms": [("effort", "effort", 5), ("throw-paper", "throw-paper", 5), ("stomp", "stomp", 5), ("quick-jump", "jump", 6)],
    "tf": [("phone", "phone", 5), ("smile", "smile", 5), ("throw-object", "throw-object", 5), ("glower", "glower", 5)],
    "m": [("speak", "speak", 5), ("magic2", "magic2", 5), ("magic1", "magic1", 5), ("golf-club-swing", "golf-club-swing", 5)],
    "mh": [("magic1", "magic1", 5), ("smile", "smile", 5), ("golf-club-swing", "golf-club-swing", 5), ("song-and-dance", "song-and-dance", 5)],
}

# code, name, dept, body, scale, height, hand rgba, head pieces, head texture, head color
# Scale is getGeomNode().setScale from generateSuit. aSize 6.06, bSize 5.29, cSize 4.14.
CORP = (0.95, 0.75, 0.75, 1.0)
LEGAL = (0.75, 0.75, 0.95, 1.0)
MONEY = (0.65, 0.95, 0.85, 1.0)
SALES = (0.95, 0.75, 0.95, 1.0)
COGS = [
    ("f", "Flunky", "c", "c", 4.0 / 4.14, 4.88, CORP, ("flunky", "glasses"), "", None),
    ("p", "Pencil Pusher", "c", "b", 3.35 / 5.29, 5.0, CORP, ("pencilpusher",), "", None),
    ("ym", "Yesman", "c", "a", 4.125 / 6.06, 5.28, CORP, ("yesman",), "", None),
    ("mm", "Micromanager", "c", "c", 2.5 / 4.14, 3.25, CORP, ("micromanager",), "", None),
    ("ds", "Downsizer", "c", "b", 4.5 / 5.29, 6.08, CORP, ("beancounter",), "", None),
    ("hh", "Head Hunter", "c", "a", 6.5 / 6.06, 7.45, CORP, ("headhunter",), "", None),
    ("cr", "Corporate Raider", "c", "c", 6.75 / 4.14, 8.23, (0.85, 0.55, 0.55, 1.0), ("flunky",), "phase_3.5/maps/corporate-raider.png", None),
    ("tbc", "The Big Cheese", "c", "a", 7.0 / 6.06, 9.34, (0.75, 0.95, 0.75, 1.0), ("bigcheese",), "", None),
    ("bf", "Bottom Feeder", "l", "c", 4.0 / 4.14, 4.81, LEGAL, ("tightwad",), "phase_3.5/maps/bottom-feeder.png", None),
    ("b", "Bloodsucker", "l", "b", 4.375 / 5.29, 6.17, (0.95, 0.95, 1.0, 1.0), ("movershaker",), "phase_4/maps/blood-sucker.png", None),
    ("dt", "Double Talker", "l", "a", 4.25 / 6.06, 5.63, LEGAL, ("twoface",), "phase_4/maps/double-talker.png", None),
    ("ac", "Ambulance Chaser", "l", "b", 4.35 / 5.29, 6.39, LEGAL, ("ambulancechaser",), "", None),
    ("bs", "Back Stabber", "l", "a", 4.5 / 6.06, 6.71, LEGAL, ("backstabber",), "", None),
    ("sd", "Spin Doctor", "l", "b", 5.65 / 5.29, 7.9, (0.5, 0.8, 0.75, 1.0), ("telemarketer",), "phase_4/maps/spin-doctor.png", None),
    ("le", "Legal Eagle", "l", "a", 7.125 / 6.06, 8.27, (0.25, 0.25, 0.5, 1.0), ("legaleagle",), "", None),
    ("bw", "Big Wig", "l", "a", 7.0 / 6.06, 8.69, LEGAL, ("bigwig",), "", None),
    ("sc", "Short Change", "m", "c", 3.6 / 4.14, 4.77, MONEY, ("coldcaller",), "", None),
    ("pp", "Penny Pincher", "m", "a", 3.55 / 6.06, 5.26, (1.0, 0.5, 0.6, 1.0), ("pennypincher",), "", None),
    ("tw", "Tightwad", "m", "c", 4.5 / 4.14, 5.41, MONEY, ("tightwad",), "", None),
    ("bc", "Bean Counter", "m", "b", 4.4 / 5.29, 5.95, MONEY, ("beancounter",), "", None),
    ("nc", "Number Cruncher", "m", "a", 5.25 / 6.06, 7.22, MONEY, ("numbercruncher",), "", None),
    ("mb", "Money Bags", "m", "c", 5.3 / 4.14, 6.97, MONEY, ("moneybags",), "", None),
    ("ls", "Loan Shark", "m", "b", 6.5 / 5.29, 8.58, (0.5, 0.85, 0.75, 1.0), ("loanshark",), "", None),
    ("rb", "Robber Baron", "m", "a", 7.0 / 6.06, 8.95, MONEY, ("yesman",), "phase_4/maps/robber-baron.png", None),
    ("cc", "Cold Caller", "s", "c", 3.5 / 4.14, 4.63, (0.55, 0.65, 1.0, 1.0), ("coldcaller",), "", (0.25, 0.35, 1.0, 1.0)),
    ("tm", "Telemarketer", "s", "b", 3.75 / 5.29, 5.24, SALES, ("telemarketer",), "", None),
    ("nd", "Name Dropper", "s", "a", 4.35 / 6.06, 5.98, SALES, ("numbercruncher",), "phase_4/maps/name-dropper.png", None),
    ("gh", "Glad Hander", "s", "c", 4.75 / 4.14, 6.4, SALES, ("gladhander",), "", None),
    ("ms", "Mover & Shaker", "s", "b", 4.75 / 5.29, 6.7, SALES, ("movershaker",), "", None),
    ("tf", "Two-Face", "s", "a", 5.25 / 6.06, 6.95, SALES, ("twoface",), "", None),
    ("m", "The Mingler", "s", "a", 5.75 / 6.06, 7.61, SALES, ("twoface",), "phase_4/maps/mingler.png", None),
    ("mh", "Mr. Hollywood", "s", "a", 7.0 / 6.06, 8.95, SALES, ("yesman",), "", None),
]

# The standing mesh is always phase_3.5 suitX-mod. ModelDict's phase is the
# walk/neutral/lose phase, and suitA/B heads live in phase 4.
BODIES = {
    "a": ("phase_3.5/models/char/suitA-mod.bam", "phase_4/models/char/suitA-heads.bam", "phase_4/models/char/suitA-neutral.bam", "4"),
    "b": ("phase_3.5/models/char/suitB-mod.bam", "phase_4/models/char/suitB-heads.bam", "phase_4/models/char/suitB-neutral.bam", "4"),
    "c": ("phase_3.5/models/char/suitC-mod.bam", "phase_3.5/models/char/suitC-heads.bam", "phase_3.5/models/char/suitC-neutral.bam", "3.5"),
}
MEDALLION = {"c": "CorpIcon", "l": "LegalIcon", "m": "MoneyIcon", "s": "SalesIcon"}
MEDALLION_COLOR = {
    "c": Vec4(0.863, 0.776, 0.769, 1.0),
    "s": Vec4(0.843, 0.745, 0.745, 1.0),
    "l": Vec4(0.749, 0.776, 0.824, 1.0),
    "m": Vec4(0.749, 0.769, 0.749, 1.0),
}
JOINTS = ("joint_head", "joint_attachMeter")


def exposed_joints(model: NodePath) -> list[str]:
    # The character root is also named suitA. Posing that node would swing
    # the whole glb. Bone cards hang off the exposed ModelNodes.
    from panda3d.core import Character

    found = model.find("**/+Character")
    if found.isEmpty():
        return []
    names: list[str] = []

    def walk(part) -> None:
        if part.getType().getName() == "CharacterJoint":
            node = model.find("**/" + part.getName())
            if (
                not node.isEmpty()
                and not node.node().isOfType(Character.getClassType())
                and part.getName() not in names
            ):
                names.append(part.getName())
        for index in range(part.getNumChildren()):
            walk(part.getChild(index))

    walk(found.node().getBundle(0))
    return names


def panda_file(relative: str) -> str:
    return str(Filename.from_os_specific(str(ASSETS / relative)))


def load_model(relative: str) -> NodePath:
    model = toon_export.load_model(relative)
    if model is None:
        raise RuntimeError("missing " + relative)
    return model


def read_texture(relative: str) -> Texture:
    tex = Texture()
    if not tex.read(Filename.from_os_specific(str(ASSETS / relative))):
        raise RuntimeError("missing " + relative)
    tex.setMinfilter(Texture.FTLinearMipmapLinear)
    tex.setMagfilter(Texture.FTLinear)
    return tex


def godot_point(x: float, y: float, z: float, shift_x: float, shift_y: float) -> list[float]:
    # The street mesh was slid by (shift_x, shift_y) in Panda, then turned Y-up.
    return [round(x + shift_x, 3), round(z, 3), round(-(y + shift_y), 3)]


def load_street(files: list[str]) -> tuple[NodePath, DNAStorage]:
    store = DNAStorage()
    node = None
    for relative in files:
        print("loading", relative, flush=True)
        node = loadDNAFile(store, panda_file(relative), 0)
    if node is None:
        raise RuntimeError("DNA loader returned nothing")
    geom = NodePath(node.getParent(0) if node.getNumParents() == 1 else node)
    return geom, store


def street_shift(geom: NodePath, kind: str) -> tuple[float, float]:
    if kind == "none":
        return 0.0, 0.0
    if kind == "floor":
        return export_neighborhoods.floor_shift(geom)
    center = geom.getBounds().getCenter()
    return -center.x, -center.y


def export_streets() -> None:
    for street in STREETS:
        geom, store = load_street(street["dna"])
        shift_x, shift_y = street_shift(geom, street["shift"])
        print(street["slug"], "shift", round(shift_x, 2), round(shift_y, 2), flush=True)
        by_index: dict[int, dict] = {}
        for index in range(store.getNumSuitPoints()):
            point = store.getSuitPointAtIndex(index)
            if point.getPointType() != DNASuitPoint.STREETPOINT:
                continue
            pos = point.getPos()
            by_index[point.getIndex()] = {
                "pos": godot_point(pos.x, pos.y, pos.z, shift_x, shift_y),
            }
        order = sorted(by_index)
        remap = {point_index: slot for slot, point_index in enumerate(order)}
        points = [by_index[point_index]["pos"] for point_index in order]
        edges: list[list[int]] = []
        seen: set[tuple[int, int]] = set()
        cells = []
        for group_index in range(store.getNumDNAVisGroups()):
            group = store.getDNAVisGroup(group_index)
            zone = store.getDNAVisGroupName(group_index).split(":", 1)[0]
            for edge_index in range(group.getNumSuitEdges()):
                edge = group.getSuitEdge(edge_index)
                start = edge.getStartPoint().getIndex()
                end = edge.getEndPoint().getIndex()
                if start not in remap or end not in remap or start == end:
                    continue
                pair = (remap[start], remap[end])
                if pair in seen:
                    continue
                seen.add(pair)
                edges.append([pair[0], pair[1]])
            for cell_index in range(group.getNumBattleCells()):
                cell = group.getBattleCell(cell_index)
                pos = cell.getPos()
                cells.append({
                    "zone": zone,
                    "pos": godot_point(pos.x, pos.y, pos.z, shift_x, shift_y),
                    "width": round(cell.getWidth(), 3),
                    "height": round(cell.getHeight(), 3),
                })
        payload = {
            "zone": street["zone"],
            "count": street["count"],
            "tracks": street["tracks"],
            "levels": street["levels"],
            "max_type": 6,
            "points": points,
            "edges": edges,
            "cells": cells,
        }
        dest = ROOT / street["out"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
        print(
            f"wrote {street['slug']} points={len(points)} edges={len(edges)} cells={len(cells)}",
            flush=True,
        )


def paint_suit(model: NodePath, cog: tuple) -> None:
    _code, _name, dept, _body, _scale, _height, hand, heads, texture, head_color = cog
    body = cog[3]
    _mod, head_file, _neutral, _phase = BODIES[body]
    for part, filename in (
        ("torso", f"phase_3.5/maps/{dept}_blazer.png"),
        ("arms", f"phase_3.5/maps/{dept}_sleeve.png"),
        ("legs", f"phase_3.5/maps/{dept}_leg.png"),
    ):
        piece = model.find("**/" + part)
        if piece.isEmpty():
            raise RuntimeError(cog[0] + " missing " + part)
        piece.setTexture(read_texture(filename), 1)
    hands = model.find("**/hands")
    if not hands.isEmpty():
        hands.setColor(Vec4(*hand))
    head_model = load_model(head_file)
    joint = model.find("**/joint_head")
    if joint.isEmpty():
        raise RuntimeError(cog[0] + " has no joint_head")
    for head_name in heads:
        found = head_model.find("**/" + head_name)
        if found.isEmpty():
            raise RuntimeError(cog[0] + " missing head " + head_name)
        part = found.copyTo(joint)
        if texture:
            part.setTexture(read_texture(texture), 1)
        if head_color is not None:
            part.setColor(Vec4(*head_color))
    head_model.removeNode()
    chest = model.find("**/joint_attachMeter")
    icons = load_model("phase_3/models/gui/cog_icons.bam")
    medallion = icons.find("**/" + MEDALLION[dept])
    if chest.isEmpty() or medallion.isEmpty():
        raise RuntimeError(cog[0] + " missing medallion")
    badge = medallion.copyTo(chest)
    badge.setPosHprScale(0.02, 0.05, 0.04, 180.0, 0.0, 0.0, 0.51, 0.51, 0.51)
    badge.setColor(MEDALLION_COLOR[dept])
    icons.removeNode()


def pose_neutral(model: NodePath, neutral_file: str):
    saved = walk_export.snapshot(model)
    control = walk_export.bind_anim(model, neutral_file)
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(control, 1.0)
    control.pose(0)
    bundle.forceUpdate()
    toon_export.bake_skinning(model)
    return saved, control


def export_suit(cog: tuple) -> None:
    code = cog[0]
    dest = SUITS / f"{code}.glb"
    if dest.exists() and dest.stat().st_size > 0:
        print("keep", dest.name, flush=True)
        return
    body = cog[3]
    mod, _heads, neutral, _phase = BODIES[body]
    model = load_model(mod)
    paint_suit(model, cog)
    pose_neutral(model, neutral)
    model.setScale(cog[4])
    root = NodePath(code)
    root.setMat(exporter.Z_UP_TO_Y_UP)
    model.reparentTo(root)
    writer = exporter.GltfWriter()
    writer.add_node(root, None)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(writer.pack(cog[1]))
    print(f"wrote {dest.name} ({dest.stat().st_size / 1024:.0f} KB)", flush=True)


def anim_path(body: str, stem: str, phase) -> str:
    phase_text = BODIES[body][3] if phase == 0 else str(phase)
    # Neutral is overridden onto the body's own neutral file.
    if stem == "neutral":
        return BODIES[body][2]
    return f"phase_{phase_text}/models/char/suit{body.upper()}-{stem}.bam"


def clips_for(body: str) -> list[tuple[str, str]]:
    found: dict[str, str] = {}
    for key, stem, phase in SHARED:
        found[key] = anim_path(body, stem, phase)
    for cog in COGS:
        if cog[3] != body:
            continue
        for key, stem, phase in ATTACKS[cog[0]]:
            # Later cogs reuse an attack key at a phase that is not on disk.
            # Keep the file that actually exists.
            relative = anim_path(body, stem, phase)
            if key not in found or ((ASSETS / relative).exists() and not (ASSETS / found[key]).exists()):
                found[key] = relative
    return list(found.items())


def bake_clip(model: NodePath, saved, relative: str, dest: Path) -> tuple[int, float]:
    if not (ASSETS / relative).exists():
        print("missing", relative, flush=True)
        return 0, 0.0
    control = walk_export.bind_anim(model, relative)
    frame_count = control.getNumFrames()
    rate = control.getFrameRate()
    if frame_count <= 0:
        print("empty", relative, flush=True)
        return 0, 0.0
    # A suited body is skinned, so the head and chest joints are enough.
    # A skelecog's bone cards are rigid children of the exposed joints, and
    # those cards do not move in the vertex clip. Every exposed joint has to
    # be in the file or the bones stay in the bind pose.
    names = exposed_joints(model) if "robot_" in dest.parent.name else []
    if not names:
        for name in JOINTS:
            if not model.find("**/" + name).isEmpty():
                names.append(name)
    walked = []
    joint_frames = {name: [] for name in names}
    neutral = BODIES_NEUTRAL[model.getTag("suit_body")]
    for frame in range(frame_count):
        walk_export.restore(model, saved)
        bundle = model.find("**/+Character").node().getBundle(0)
        bundle.setControlEffect(neutral, 0.0)
        bundle.setControlEffect(control, 1.0)
        control.pose(frame)
        bundle.forceUpdate()
        toon_export.bake_skinning(model)
        walked.append(walk_export.collect_named(model))
        for joint_name, matrix in walk_export.joint_matrices(model, tuple(names)):
            joint_frames[joint_name].append(matrix)
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(control, 0.0)
    nodes = []
    for node_index, (node_name, surfaces) in enumerate(walked[0]):
        packed = []
        for surface_index, (_base, uvs) in enumerate(surfaces):
            frames = []
            for frame in walked:
                _name, frame_surfaces = frame[node_index]
                posed, _uv = frame_surfaces[surface_index]
                frames.append(posed)
            packed.append((uvs, frames))
        nodes.append((node_name, packed))
    # Bind is neutral frame 0, matching the standing glb, not this clip's first frame.
    bind = {}
    walk_export.restore(model, saved)
    bundle = model.find("**/+Character").node().getBundle(0)
    bundle.setControlEffect(neutral, 1.0)
    neutral.pose(0)
    bundle.forceUpdate()
    for joint_name, matrix in walk_export.joint_matrices(model, tuple(names)):
        bind[joint_name] = matrix
    walk_export.write_walk(
        dest,
        frame_count,
        nodes,
        [(name, bind[name], joint_frames[name]) for name in names],
    )
    return frame_count, rate


BODIES_NEUTRAL: dict = {}


def export_anims() -> dict:
    timing: dict[str, dict] = {}
    for body, (mod, _heads, neutral_file, _phase) in BODIES.items():
        model = load_model(mod)
        model.setTag("suit_body", body)
        saved, neutral = pose_neutral(model, neutral_file)
        # pose_neutral bakes frame 0 into the verts. snapshot was taken before
        # that, and bake_clip restores it before every frame.
        BODIES_NEUTRAL[body] = neutral
        timing[body] = {}
        for key, relative in clips_for(body):
            dest = ANIMS / body / f"{key}.walk"
            if dest.exists() and dest.stat().st_size > 0:
                # The sidecar header starts TWALK3, pad, then the frame count.
                frames = struct.unpack_from("<I", dest.read_bytes()[:16], 8)[0]
                timing[body][key] = {"frames": frames, "fps": 24.0}
                print("keep", body, key, flush=True)
                continue
            print("bake", body, key, relative, flush=True)
            frames, rate = bake_clip(model, saved, relative, dest)
            if frames:
                timing[body][key] = {"frames": frames, "fps": round(rate, 3)}
                print(f"  {frames} frames @ {rate}", flush=True)
        model.removeNode()
    return timing


def export_propeller() -> dict:
    info = {"frames": 0, "fps": 24.0, "spin_frame": 8}
    dest = PROPS / "propeller.glb"
    if not dest.exists():
        model = load_model("phase_4/models/props/propeller-mod.bam")
        # Leave it in the joint's Z-up space. The suit root already turns Y-up.
        root = NodePath("propeller")
        model.reparentTo(root)
        writer = exporter.GltfWriter()
        writer.add_node(root, None)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(writer.pack("propeller"))
        print(f"wrote propeller.glb ({dest.stat().st_size / 1024:.0f} KB)", flush=True)
    clip = PROPS / "propeller.walk"
    if not clip.exists():
        model = load_model("phase_4/models/props/propeller-mod.bam")
        saved = walk_export.snapshot(model)
        relative = "phase_4/models/props/propeller-chan.bam"
        if (ASSETS / relative).exists():
            try:
                control = walk_export.bind_anim(model, relative)
            except RuntimeError as exc:
                print("propeller anim skipped", exc, flush=True)
                control = None
            if control is not None:
                frame_count = control.getNumFrames()
                info["frames"] = frame_count
                info["fps"] = control.getFrameRate()
                walked = []
                for frame in range(frame_count):
                    walk_export.restore(model, saved)
                    bundle = model.find("**/+Character").node().getBundle(0)
                    bundle.setControlEffect(control, 1.0)
                    control.pose(frame)
                    bundle.forceUpdate()
                    toon_export.bake_skinning(model)
                    walked.append(walk_export.collect_named(model))
                nodes = []
                for node_index, (node_name, surfaces) in enumerate(walked[0]):
                    packed = []
                    for surface_index, (_base, uvs) in enumerate(surfaces):
                        frames = [frame[node_index][1][surface_index][0] for frame in walked]
                        packed.append((uvs, frames))
                    nodes.append((node_name, packed))
                walk_export.write_walk(clip, frame_count, nodes, [])
                print(f"wrote propeller.walk frames={frame_count}", flush=True)
    for name in ("ENC_propeller_in.ogg", "ENC_propeller_out.ogg"):
        source = ASSETS / "phase_5" / "audio" / "sfx" / name
        target = AUDIO / name
        if source.exists() and not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            print("copied", name, flush=True)
    return info


def write_catalog(timing: dict, propeller: dict) -> None:
    dest = ROOT / "assets" / "cogs" / "catalog.json"
    if dest.exists() and (not timing or not propeller.get("frames")):
        previous = json.loads(dest.read_text(encoding="utf-8"))
        if not timing:
            timing = previous.get("timing", {})
        if not propeller.get("frames"):
            propeller = previous.get("propeller", propeller)
    cogs = []
    for index, cog in enumerate(COGS):
        code, name, dept, body, scale, height, _hand, _heads, _texture, _color = cog
        attacks = [{"key": key, "file": key} for key, _stem, _phase in ATTACKS[code]]
        cogs.append({
            "code": code,
            "name": name,
            "dept": dept,
            "body": body,
            "type": index % 8 + 1,
            "scale": round(scale, 5),
            "height": height,
            "attacks": attacks,
        })
    payload = {
        "walk_speed": 4.8,
        "from_sky": 6.5,
        "to_sky": 6.5,
        "min_path": 40,
        "max_path": 300,
        "landing_ground_frame": 28,
        "depts": ["c", "l", "m", "s"],
        "cogs": cogs,
        "timing": timing,
        "propeller": propeller,
    }
    dest = ROOT / "assets" / "cogs" / "catalog.json"
    dest.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("wrote catalog", flush=True)


def main() -> int:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    loadPrcFileData("", "default-model-extension .bam")
    loadPrcFileData("", "model-cache-dir")
    asset_root = Filename.from_os_specific(str(ASSETS))
    toon_export.ASSETS = asset_root
    getModelPath().prependDirectory(asset_root)
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("streets", "all"):
        export_streets()
    timing: dict = {}
    propeller = {"frames": 0, "fps": 24.0, "spin_frame": 8}
    if mode in ("suits", "all"):
        for cog in COGS:
            export_suit(cog)
    if mode in ("props", "all"):
        propeller = export_propeller()
    if mode in ("anims", "all"):
        timing = export_anims()
    if mode in ("catalog", "suits", "anims", "props", "all"):
        write_catalog(timing, propeller)
    return 0


if __name__ == "__main__":
    sys.exit(main())
