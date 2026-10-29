"""Build the SpeedChat tree from the original localizer and TTChatInputSpeedChat."""
from __future__ import annotations

import json
import sys
from pathlib import Path

SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")
OUT = Path(__file__).resolve().parents[1] / "assets" / "gui" / "speedchat" / "menu.json"

sys.path.insert(0, str(SOURCE))
from otp.otpbase import OTPLocalizerEnglish as L  # noqa: E402

TEXT = dict(L.SpeedChatStaticTextToontown)
TEXT.update(L.SpeedChatStaticTextCommon)

EMOTES = [
    ("Wave", "%s waves."),
    ("Happy", "%s is happy."),
    ("Sad", "%s is sad."),
    ("Angry", "%s is angry."),
    ("Sleepy", "%s is sleepy."),
]


def phrase(item) -> dict:
    emote = None
    if isinstance(item, dict):
        key = next(iter(item))
        emote = item[key]
        item = key
    spoken = TEXT[item]
    row = {"text": spoken, "say": spoken}
    if emote is not None:
        row["emote"] = int(emote)
    return row


def menu(title: str, children: list) -> dict:
    items = []
    for child in children:
        if isinstance(child, list) and isinstance(child[0], str):
            items.append(menu(child[0], child[1:]))
        else:
            items.append(phrase(child))
    return {"title": title, "items": items}


def main() -> None:
    emotions = {
        "title": L.SCMenuEmotions,
        "items": [{"text": name, "say": whisper, "emote": index} for index, (name, whisper) in enumerate(EMOTES)],
    }
    hello = menu(L.SCMenuHello, [{100: 0}, {101: 0}, {102: 0}, {103: 0}, {104: 0}, {105: 0}, 106, 107, 108, 109])
    bye = menu(L.SCMenuBye, [{200: 0}, {201: 0}, {202: 0}, 203, 204, 205, 206, 208, 209, 207])
    happy = menu(L.SCMenuHappy, [{300: 1}, {301: 1}, {302: 1}, 303, {304: 1}, 305, 306, 307, 308, 309, 310, 311, {312: 1}, {313: 1}, {314: 1}, 315])
    sad = menu(L.SCMenuSad, [{400: 2}, {401: 2}, {402: 2}, 403, 404, 405, 406, 407, 408, 409, 410])
    friendly = menu(L.SCMenuFriendly, [
        [L.SCMenuFriendlyYou, 600, 601, 602, 603],
        [L.SCMenuFriendlyILike, 700, 701, 702, 703, 704, 705],
        500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 515, 511, 512, 513, 514,
    ])
    sorry = menu(L.SCMenuSorry, [801, 800, 802, 803, 804, 811, 814, 815, 817, 812, 813, 818, 805, 806, 807, 816, 808, {809: 5}, 810])
    stinky = menu(L.SCMenuStinky, [{900: 3}, {901: 3}, {902: 3}, {903: 3}, 904, {905: 3}, 907])
    places = menu(L.SCMenuPlaces, [
        [L.SCMenuPlacesPlayground, 1100, 1101, 1105, 1106, 1107, 1108, 1109, 1110, 1111, 1117, 1125, 1126],
        [L.SCMenuPlacesCogs, 1102, 1103, 1104, 1114, 1115, 1116, 1119, 1120, 1121, 1122, 1123, 1124, 1127, 1128, 1129, 1130],
        [L.SCMenuPlacesEstate, 1112, 1113, 1013, 1118, 1016],
        [L.SCMenuParties, 5300, 5301, 5302, 5303],
        [L.SCMenuPlacesWait, 1015, 1007, 1008, 1010, 1011, 1014, 1017],
        1000, 1001, 1002, 1003, 1004, 1005, 1006, 1009, 1012,
    ])
    tasks = menu(L.SCMenuToontasks, [
        [L.SCMenuToontasksYouShouldChoose, 1300, 1301, 1302, 1303, 1304],
        [L.SCMenuToontasksINeedMore, 1206, 1210, 1211, 1212, 1207, 1213, 1214, 1215],
        1200, 1201, 1202, 1208, 1203, 1209, 1204, 1205,
    ])
    tasks["items"].insert(0, {"title": L.SCMenuToontasksMyTasks, "dynamic": "tasks"})
    battle = menu(L.SCMenuBattle, [
        [L.SCMenuBattleGags, 1500, 1501, 1502, 1503, 1504, 1505, 1506, 1401, 1402, 1413],
        [L.SCMenuBattleTaunts, 1403, 1406, 1520, 1521, 1522, 1523, 1524, 1525, 1526, 1407, 1408],
        [L.SCMenuBattleStrategy, 1414, 1550, 1551, 1552, 1415, 1553, 1554, 1555, 1556, 1557, 1558, 1559],
        1400, 1416, 1404, 1405, 1409, 1410, 1411, 1412,
    ])
    shop = menu(L.SCMenuGagShop, [1600, 1601, 1602, 1603, 1604, 1605, 1606])
    root = {
        "items": [
            emotions, hello, bye, happy, sad, friendly, sorry, stinky, places, tasks, battle, shop,
            phrase({1: 17}),
            phrase({2: 18}),
            phrase(3),
        ]
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(root, indent=1), encoding="utf-8")
    print(f"wrote {OUT} items={len(root['items'])}")


if __name__ == "__main__":
    main()
