"""Build scenes/quests/ttc_quests.json from the original QuestDict.

Covers TT_TIER + 2 and TT_TIER + 3: the Central reward track and the
final gag-training chain. Donald's Dock and later playgrounds stay out.
"""

import ast
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "Original Toontown Assets", "Source Code")
LOCALIZER = os.path.join(SRC, "toontown", "toonbase", "TTLocalizerEnglish.py")
QUESTS = os.path.join(SRC, "toontown", "quest", "Quests.py")
SUITS = os.path.join(SRC, "toontown", "battle", "SuitBattleGlobals.py")
NPCS = os.path.join(SRC, "toontown", "toon", "NPCToons.py")
SHOPS = os.path.join(
    os.path.dirname(__file__), "..", "assets", "interiors", "shops", "shops.json"
)
OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "quests", "ttc_quests.json")

ANY = 1
NA = 2
SAME = 3
ANY_FISH = 4
TOON_HQ = 1000
ANYWHERE = 1

HOODS = {
    2000: ("in", "Toontown Central"),
    1000: ("in", "Donald's Dock"),
    5000: ("in", "Daisy Gardens"),
    4000: ("in", "Minnie's Melodyland"),
    3000: ("in", "The Brrrgh"),
    9000: ("in", "Donald's Dreamland"),
}

TRACKS = {
    "c": (0, "a Bossbot", "Bossbots"),
    "l": (1, "a Lawbot", "Lawbots"),
    "m": (2, "a Cashbot", "Cashbots"),
    "s": (3, "a Sellbot", "Sellbots"),
}


def grab(text, start):
    openers = {"(": ")", "[": "]", "{": "}"}
    closer = openers[text[start]]
    depth = 0
    i = start
    in_str = ""
    escape = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == in_str:
                in_str = ""
        elif ch in ("'", '"'):
            in_str = ch
        elif ch == closer and depth == 1 and False:
            pass
        if not in_str:
            if ch in openers:
                depth += 1
            elif ch in openers.values():
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        i += 1
    raise RuntimeError("unbalanced at %d" % start)


def load_localizer():
    text = open(LOCALIZER, encoding="utf-8").read()
    ns = {}
    index = 0
    lines = text.splitlines(True)
    offset = 0
    while offset < len(text):
        line_end = text.find("\n", offset)
        if line_end < 0:
            line_end = len(text)
        line = text[offset:line_end]
        stripped = line.lstrip()
        if stripped.startswith(("def ", "class ", "from ", "import ", "OL.", "@", "for ", "if ", "while ")):
            offset = line_end + 1
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*) = ", line)
        if not match:
            offset = line_end + 1
            continue
        value_at = offset + match.end() - 1
        # The value starts at the character after "= ".
        value_at = text.find("=", offset) + 1
        while value_at < len(text) and text[value_at] in " \t":
            value_at += 1
        if value_at >= len(text):
            break
        if text[value_at] in "({[":
            try:
                block = grab(text, value_at)
            except RuntimeError:
                offset = line_end + 1
                continue
            segment = match.group(1) + " = " + block
            offset = value_at + len(block)
        else:
            segment = text[offset:line_end]
            offset = line_end + 1
        try:
            exec(segment, ns)
        except Exception:
            pass
    return ns


def load_suits(ns):
    text = open(SUITS, encoding="utf-8").read()
    start = text.find("SuitAttributes = {")
    block = grab(text, start + len("SuitAttributes = "))
    # Only the name fields. Replace the localizer lookups with strings we have.
    names = {}
    for match in re.finditer(
        r"'([a-z0-9]+)': \{'name': TTLocalizer\.(\w+),\s*'singularname': TTLocalizer\.(\w+),\s*'pluralname': TTLocalizer\.(\w+)",
        text,
    ):
        code, _full, single, plural = match.groups()
        names[code] = (
            str(ns.get(single, code)),
            str(ns.get(plural, code)),
        )
    return names


def load_npc_zones():
    text = open(NPCS, encoding="utf-8").read()
    zones = {}
    for match in re.finditer(r"^\s*(\d+): \((\d+),", text, re.M):
        zones[int(match.group(1))] = int(match.group(2))
    for match in re.finditer(r"NPCToonDict\[(\d+)\] = \((\d+),", text):
        zones[int(match.group(1))] = int(match.group(2))
    return zones


def load_shops():
    data = json.load(open(SHOPS, encoding="utf-8"))
    by_npc = {}
    for zone, row in data.items():
        if not str(zone).isdigit():
            continue
        for npc in row.get("npcs", []):
            by_npc[int(npc["id"])] = {
                "name": npc.get("name", ""),
                "zone": int(zone),
                "street": int(row.get("street", 0)),
                "title": row.get("title", ""),
            }
    return by_npc


def subst_quest(body):
    reps = [
        ("TT_TIER + 3", "3"),
        ("TT_TIER + 2", "2"),
        ("ToontownGlobals.ToontownCentral", "2000"),
        ("ToontownGlobals.DonaldsDock", "1000"),
        ("ToontownGlobals.DaisyGardens", "5000"),
        ("ToontownGlobals.MinniesMelodyland", "4000"),
        ("ToontownGlobals.TheBrrrgh", "3000"),
        ("ToontownGlobals.DonaldsDreamland", "9000"),
        ("AnyFish", "4"),
        ("Anywhere", "1"),
        ("ToonHQ", "1000"),
        ("VeryEasy", "100"),
        ("VeryHard", "20"),
        ("Start", "1"),
        ("Cont", "0"),
        ("Same", "3"),
        ("Easy", "75"),
        ("Medium", "50"),
        ("Hard", "25"),
        ("Any", "1"),
        ("NA", "2"),
        ("OBSOLETE", "'OBSOLETE'"),
        ("DefaultDialog", "0"),
        ("CogNewbieQuest", "'CogNewbieQuest'"),
        ("CogLevelQuest", "'CogLevelQuest'"),
        ("CogTrackQuest", "'CogTrackQuest'"),
        ("RecoverItemQuest", "'RecoverItemQuest'"),
        ("DeliverItemQuest", "'DeliverItemQuest'"),
        ("BuildingQuest", "'BuildingQuest'"),
        ("VisitQuest", "'VisitQuest'"),
        ("CogQuest", "'CogQuest'"),
    ]
    body = re.sub(r"TTLocalizer\.QuestDialogDict\[(\d+)\]", r"\1", body)
    for old, new in reps:
        body = re.sub(r"\b%s\b" % re.escape(old), new, body)
    body = re.sub(r"\bTT_TIER\b", "0", body)
    return body


def parse_quests(text):
    start = text.find("QuestDict = {")
    end = text.find("\nTier2QuestsDict", start)
    block = text[start:end]
    quests = {}
    for match in re.finditer(r"^ (\d+): \(", block, re.M):
        qid = int(match.group(1))
        body = grab(block, match.end() - 1)
        replaced = subst_quest(body)
        try:
            quests[qid] = ast.literal_eval(replaced)
        except Exception:
            if "TT_TIER + 2" in body or "TT_TIER + 3" in body:
                print("skip", qid)
    return quests


def pages(value):
    if value is None:
        return []
    if isinstance(value, tuple):
        value = value[0] if value else ""
    if not isinstance(value, str):
        return []
    value = value.replace("\x01", "").replace("\x02", "")
    value = re.sub(r"\x01[^\x01\x02]*\x01", "", value)
    parts = [part.strip() for part in value.split("\x07")]
    return [part for part in parts if part]


def fill_names(text, npc_name, where):
    text = text.replace("_avName_", "friend")
    text = text.replace("_toNpcName_", npc_name or "a Toon")
    if where:
        text = text.replace("_where_", " " + where)
    else:
        text = text.replace("_where_", "")
    return re.sub(r" +", " ", text).strip()


def cap_first(text):
    text = text.strip()
    if not text:
        return text
    return text[0].upper() + text[1:]


def quest_info(qid, kind_name, desc, ns, suits, items, loc_where, loc_phrase, npc_info):
    args = desc[1:]
    info = {
        "headline": "WANTED",
        "caption": "ToonTask",
        "where": "Anywhere",
        "kind": "cog",
        "cog": "any",
        "goal": 1,
        "speech": "",
    }
    if kind_name == "CogQuest":
        loc, num, cog = args[0], int(args[1]), args[2]
        info["goal"] = num
        info["hood"] = int(loc) if loc in HOODS else 0
        info["zone"] = int(loc) if loc not in HOODS and loc != ANYWHERE else 0
        info["where"] = loc_where(loc)
        if cog == ANY:
            cog_name = "Cog" if num == 1 else "Cogs"
            single = "a Cog"
        else:
            single, plural = suits.get(cog, (cog, cog))
            cog_name = single if num == 1 else plural
            info["cog"] = cog
        if num == 1:
            info["caption"] = cap_first(cog_name if cog == ANY else single)
            speech_name = single if cog != ANY else "a Cog"
            info["speech"] = "I need to defeat %s%s." % (speech_name, loc_phrase(loc) and (" " + loc_phrase(loc).strip() and ""))
            info["speech"] = ns["QuestsCogQuestSCStringS"] % {
                "cogName": single if cog != ANY else "a Cog",
                "cogLoc": (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
            }
        else:
            info["caption"] = ns["QuestsCogQuestDefeatDesc"] % {"numCogs": num, "cogName": cog_name}
            info["speech"] = ns["QuestsCogQuestSCStringP"] % {
                "cogName": cog_name,
                "cogLoc": (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
            }
        return info
    if kind_name == "CogTrackQuest":
        loc, num, track = args[0], int(args[1]), args[2]
        _index, single, plural = TRACKS[track]
        info["goal"] = num
        info["dept"] = track
        info["hood"] = int(loc) if loc in HOODS else 0
        info["zone"] = int(loc) if loc not in HOODS and loc != ANYWHERE else 0
        info["where"] = loc_where(loc)
        shown = single if num == 1 else plural
        if num == 1:
            info["caption"] = cap_first(single)
            info["speech"] = ns["QuestsCogTrackQuestSCStringS"] % {
                "cogText": single,
                "cogLoc": (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
            }
        else:
            info["caption"] = ns["QuestsCogTrackDefeatDesc"] % {"numCogs": num, "trackName": plural}
            info["speech"] = ns["QuestsCogTrackQuestSCStringP"] % {
                "cogText": plural,
                "cogLoc": (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
            }
        return info
    if kind_name == "CogLevelQuest":
        loc, num, level = args[0], int(args[1]), int(args[2])
        info["goal"] = num
        info["level"] = level
        info["hood"] = int(loc) if loc in HOODS else 0
        info["zone"] = int(loc) if loc not in HOODS and loc != ANYWHERE else 0
        info["where"] = loc_where(loc)
        name = "Cog" if num == 1 else "Cogs"
        pattern = ns["QuestsCogLevelQuestDesc"] if num == 1 else ns["QuestsCogLevelQuestDescC"]
        info["caption"] = cap_first(pattern % {"count": num, "level": level, "name": name})
        info["speech"] = "I need to defeat %s%s." % (
            info["caption"][0].lower() + info["caption"][1:],
            (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
        )
        return info
    if kind_name == "RecoverItemQuest":
        loc = args[0]
        num = int(args[1])
        item = int(args[2])
        chance = int(args[3])
        holder = args[4]
        holder_type = args[5] if len(args) > 5 else "type"
        info["kind"] = "recover"
        info["headline"] = ns.get("QuestsRecoverItemQuestHeadline", "RECOVER")
        info["goal"] = num
        info["chance"] = chance
        info["hood"] = int(loc) if loc in HOODS else 0
        info["zone"] = int(loc) if loc not in HOODS and loc != ANYWHERE else 0
        info["where"] = loc_where(loc)
        row = items.get(item, ["Item", "Items", "a "])
        if num == 1:
            item_name = cap_first(row[2] + row[0])
        else:
            item_name = ns["QuestsItemNameAndNum"] % {"num": num, "name": row[1]}
        if holder == ANY:
            holder_name = ns.get("TheCogs", "The Cogs")
            info["holder"] = "any"
        elif holder == ANY_FISH:
            holder_name = ns.get("AFish", "a fish")
            info["holder"] = "fish"
        elif holder_type == "level":
            holder_name = ns["QuestsRecoverItemQuestHolderString"] % {
                "level": ns.get("Level", "Level"),
                "holder": int(holder),
                "cogs": ns.get("Cogs", "Cogs"),
            }
            info["holder"] = str(int(holder))
            info["holder_type"] = "level"
        elif holder_type == "track":
            holder_name = TRACKS[holder][2]
            info["holder"] = holder
            info["holder_type"] = "track"
        else:
            _single, plural = suits.get(holder, (str(holder), str(holder)))
            holder_name = plural
            info["holder"] = holder
            info["cog"] = holder
        info["caption"] = item_name
        info["holder_name"] = holder_name
        info["speech"] = ns["QuestsRecoverItemQuestRecoverFromSCString"] % {
            "item": item_name[0].lower() + item_name[1:],
            "holder": holder_name,
            "loc": (" " + loc_phrase(loc)) if loc_phrase(loc) else "",
        }
        return info
    if kind_name == "VisitQuest":
        info["kind"] = "visit"
        info["headline"] = ns.get("QuestsVisitQuestHeadline", "VISIT")
        info["goal"] = 1
        info["cog"] = ""
        info["show_count"] = False
        return info
    if kind_name == "DeliverItemQuest":
        item = int(args[0])
        row = items.get(item, ["Item", "Items", "a "])
        item_name = cap_first(row[2] + row[0])
        info["kind"] = "visit"
        info["headline"] = ns.get("QuestsDeliverItemQuestHeadline", "DELIVER")
        info["caption"] = item_name
        info["goal"] = 1
        info["cog"] = ""
        info["speech"] = ns["QuestsDeliverItemQuestSCString"] % {
            "article": row[2],
            "itemName": row[0],
        }
        return info
    print("unhandled", qid, kind_name)
    return None


def main():
    ns = load_localizer()
    suits = load_suits(ns)
    npc_zones = load_npc_zones()
    shops = load_shops()
    names = ns.get("NPCToonNames", {})
    streets = ns.get("GlobalStreetNames", {})
    items = ns.get("QuestsItemDict", {})
    dialogs = ns.get("QuestDialogDict", {})
    print("dialogs", len(dialogs), "suits", len(suits), "npc names", len(names))

    text = open(QUESTS, encoding="utf-8").read()
    quests = parse_quests(text)
    wanted = {}
    for qid, row in quests.items():
        tier = row[0]
        if tier in (2, 3) and row[5] != "OBSOLETE" and row[1] != "OBSOLETE":
            wanted[qid] = row
    print("ttc quests", len(wanted))

    def npc_info(npc_id):
        if npc_id in shops:
            row = shops[npc_id]
            street = streets.get(row["street"], ("", "", ""))[-1]
            where = row["title"]
            if street:
                where = "%s\n%s" % (row["title"], street)
            return row["name"], where, row["zone"]
        zone = npc_zones.get(npc_id, 0)
        name = names.get(npc_id, "a Toon")
        street_zone = (zone // 100) * 100
        street = streets.get(street_zone, ("", "", ""))[-1]
        if not street:
            street = streets.get((zone // 1000) * 1000, ("", "", "Toontown Central"))[-1]
        return name, street, zone

    def loc_phrase(loc):
        if loc == ANYWHERE:
            return ""
        if loc in HOODS:
            phrase, place = HOODS[loc]
            return "%s %s" % (phrase, place)
        if loc in streets:
            phrase = streets[loc][1]
            place = streets[loc][2]
            return "%s %s" % (phrase, place)
        return ""

    def loc_where(loc):
        phrase = loc_phrase(loc)
        if not phrase:
            return "Anywhere"
        return cap_first(phrase)

    def final_reward(qid, seen):
        if qid in seen or qid not in wanted:
            return 0
        seen.add(qid)
        row = wanted[qid]
        nxt = row[6]
        reward = row[5]
        if nxt == NA:
            if reward == ANY:
                return "any"
            if reward == NA:
                return 0
            return int(reward)
        if isinstance(nxt, tuple):
            return final_reward(nxt[0], seen)
        return final_reward(int(nxt), seen)

    out_quests = {}
    by_reward = {}
    npc_out = {}
    skipped = {}
    for qid, row in sorted(wanted.items()):
        _tier, start, desc, src, dest, reward, nxt, dialog_id = row
        kind_name = desc[0]
        info = quest_info(
            qid, kind_name, desc, ns, suits, items, loc_where, loc_phrase, npc_info
        )
        if info is None:
            skipped[kind_name] = skipped.get(kind_name, 0) + 1
            continue
        info["start"] = bool(start == 1)
        if src == SAME:
            info["from"] = -1
        elif src == ANY:
            info["from"] = 0
        else:
            info["from"] = int(src)
        info["same"] = dest == SAME
        if dest == SAME:
            info["npc"] = 0
        elif dest == ANY:
            info["npc"] = TOON_HQ
        else:
            info["npc"] = int(dest)
        own = 0 if reward in (NA, ANY) else int(reward)
        info["reward"] = own
        info["final"] = final_reward(qid, set())
        if nxt == NA:
            info["next"] = 0
        elif isinstance(nxt, tuple):
            info["next"] = [int(item) for item in nxt]
        else:
            info["next"] = int(nxt)
        dest_id = info["npc"]
        dest_name, dest_where, dest_zone = ("", "", 0)
        if dest_id not in (0, TOON_HQ):
            dest_name, dest_where, dest_zone = npc_info(dest_id)
            npc_out[str(dest_id)] = {
                "name": dest_name,
                "where": dest_where,
                "zone": dest_zone,
                "live": dest_id in shops or dest_id in (2001, 2005),
            }
            if info["kind"] == "visit":
                info["caption"] = dest_name
                info["where"] = dest_where
                info["speech"] = "I need to see %s." % dest_name
        dialog = dialogs.get(dialog_id) if dialog_id else None
        lines = []
        busy = []
        after = []
        if isinstance(dialog, dict):
            quest_text = dialog.get("QUEST", dialog.get(1, ""))
            busy_text = dialog.get("INCOMPLETE_PROGRESS", dialog.get("INCOMPLETE", ""))
            after_text = dialog.get("COMPLETE", "")
            lines = [fill_names(part, dest_name, "") for part in pages(quest_text)]
            busy = [fill_names(part, dest_name, "") for part in pages(busy_text)]
            after = [fill_names(part, dest_name, "") for part in pages(after_text)]
        if not lines and info.get("speech"):
            lines = [info["speech"]]
        if not busy:
            busy = ["Come back when you are finished with your ToonTask."]
        if not after and own:
            after = ["Nice work! Here is your reward..."]
        info["lines"] = lines
        info["busy"] = busy
        info["after"] = after
        info["show_count"] = int(info.get("goal", 1)) > 1 and info["kind"] in ("cog", "recover")
        out_quests[str(qid)] = info
        if info["start"] and info["final"] not in (0,):
            key = "any" if info["final"] == "any" else str(info["final"])
            by_reward.setdefault(key, []).append(qid)

    print("written quests", len(out_quests), "skipped", skipped)
    print("rewards", {key: len(ids) for key, ids in sorted(by_reward.items(), key=lambda item: str(item[0]))})
    payload = {"quests": out_quests, "npcs": npc_out, "by_reward": by_reward}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=1, ensure_ascii=True)
        handle.write("\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
