"""Build Clarabelle's issue from the original catalog lists, and crop catalog_gui."""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
PROJECT = TOOLS.parent
SOURCE = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Source Code")
GAME = Path(r"G:\Toontown-Reimagined\Original Toontown Assets\Game Assets")
GUI = PROJECT / "assets" / "gui" / "catalog"
CLOTHES = PROJECT / "assets" / "toons" / "clothes" / "catalog"
FONTS = PROJECT / "assets" / "gui" / "catalog" / "fonts"
ISSUE = PROJECT / "assets" / "catalog" / "issue.json"

ARTICLES = {
    "ABoysShirt": ("m", "shirt", False),
    "AGirlsShirt": ("f", "shirt", False),
    "AShirt": ("", "shirt", False),
    "ABoysShorts": ("m", "bottom", False),
    "AGirlsShorts": ("f", "bottom", False),
    "AGirlsSkirt": ("f", "bottom", True),
    "AShorts": ("", "bottom", False),
}
ARTICLE_NAMES = ("Shirt", "Shirt", "Shirt", "Shorts", "Shorts", "Skirt", "Shorts")
ACCESSORY_ARTICLES = {
    "AHat": ("", "hat"),
    "AGlasses": ("", "glasses"),
    "ABackpack": ("", "backpack"),
    "AShoes": ("", "shoes"),
    "ABoysHat": ("m", "hat"),
    "ABoysGlasses": ("m", "glasses"),
    "ABoysBackpack": ("m", "backpack"),
    "ABoysShoes": ("m", "shoes"),
    "AGirlsHat": ("f", "hat"),
    "AGirlsGlasses": ("f", "glasses"),
    "AGirlsBackpack": ("f", "backpack"),
    "AGirlsShoes": ("f", "shoes"),
}
PRICES = {
    "APriceTest": 5,
    "APriceBasic": 250,
    "APriceBasicPlus": 400,
    "APriceCool": 800,
    "APriceAwesome": 1500,
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def bracket(text: str, start: int, open_ch: str, close_ch: str) -> str:
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == open_ch:
            depth += 1
        elif char == close_ch:
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    raise RuntimeError("unclosed " + open_ch)


def quoted_list(text: str, name: str) -> list[str]:
    marker = name + " = ["
    start = text.index(marker) + len(marker) - 1
    body = bracket(text, start, "[", "]")
    return re.findall(r"'([^']+)'", body)


def top_tuples(body: str) -> list[str]:
    # body includes the outer parentheses.
    inner = body[1:-1]
    rows = []
    depth = 0
    began = None
    for index, char in enumerate(inner):
        if char == "(":
            if depth == 0:
                began = index
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0 and began is not None:
                rows.append(inner[began : index + 1])
                began = None
    return rows


def style_shirt(dna: str, style: str) -> tuple[int, int, list[tuple[int, int]]]:
    match = re.search(r"'%s':\s*\[(\d+),\s*(\d+),\s*\[(.*?)\]" % re.escape(style), dna, re.S)
    if match is None:
        raise RuntimeError("missing shirt " + style)
    colors = [(int(a), int(b)) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(3))]
    return int(match.group(1)), int(match.group(2)), colors


def style_bottom(dna: str, style: str) -> tuple[int, list[int]]:
    match = re.search(r"'%s':\s*\[(\d+),\s*\[(.*?)\]" % re.escape(style), dna, re.S)
    if match is None:
        raise RuntimeError("missing bottom " + style)
    colors = [int(value) for value in re.findall(r"\d+", match.group(2))]
    return int(match.group(1)), colors


def copy_map(relative: str) -> str:
    source = GAME / Path(relative)
    if not source.is_file():
        print("missing map", relative, flush=True)
        return ""
    CLOTHES.mkdir(parents=True, exist_ok=True)
    dest = CLOTHES / source.name
    if not dest.exists() or dest.stat().st_size != source.stat().st_size:
        shutil.copyfile(source, dest)
    return "res://assets/toons/clothes/catalog/" + source.name


def clothing_table(dna: str, localizer: str) -> dict[int, dict]:
    names = dict(re.findall(r"(\d+):\s*'((?:\\'|[^'])*)'", localizer[localizer.index("ClothingTypeNames"):]))
    types = {}
    block = dna
    for match in re.finditer(
        r"(\d+):\s*\((A\w+),\s*'([^']+)',\s*(\d+)",
        read(SOURCE / "toontown" / "catalog" / "CatalogClothingItem.py"),
    ):
        clothing_id = int(match.group(1))
        article, style, price = match.group(2), match.group(3), int(match.group(4))
        gender, piece, skirt = ARTICLES[article]
        try:
            built = _clothing_entry(block, clothing_id, article, style, price, gender, piece, skirt, names)
        except (RuntimeError, IndexError, KeyError) as error:
            print("skip clothing", clothing_id, error, flush=True)
            continue
        types[clothing_id] = built
    return types


def _clothing_entry(block, clothing_id, article, style, price, gender, piece, skirt, names) -> dict:
        if piece == "shirt":
            tex, sleeve, colors = style_shirt(block, style)
            top = copy_map(quoted_list(block, "Shirts")[tex])
            sleeve_map = copy_map(quoted_list(block, "Sleeves")[sleeve])
            color = colors[0][0] if colors else 0
            entry = {
                "kind": "clothing",
                "id": clothing_id,
                "name": names.get(str(clothing_id), ARTICLE_NAMES[list(ARTICLES).index(article)]),
                "price": price,
                "gender": gender,
                "piece": "shirt",
                "tex": tex,
                "color": color,
                "map": top,
                "sleeve": sleeve_map,
                "skirt": False,
                "colors": colors,
            }
        else:
            tex, colors = style_bottom(block, style)
            color = colors[0] if colors else 0
            if article == "ABoysShorts":
                path = quoted_list(block, "BoyShorts")[tex]
            else:
                bottoms = re.findall(
                    r"\('([^']+)',\s*(SHORTS|SKIRT)\)",
                    bracket(block, block.index("GirlBottoms = ["), "[", "]"),
                )
                path, flag = bottoms[tex]
                skirt = flag == "SKIRT"
            if article == "ABoysShorts":
                skirt = False
            entry = {
                "kind": "clothing",
                "id": clothing_id,
                "name": names.get(str(clothing_id), ARTICLE_NAMES[list(ARTICLES).index(article)]),
                "price": price,
                "gender": gender,
                "piece": "bottom",
                "tex": tex,
                "color": color,
                "map": copy_map(path),
                "sleeve": "",
                "skirt": skirt,
                "colors": colors,
            }
        return entry


def accessory_table(localizer: str) -> dict[int, dict]:
    styles = dict(
        re.findall(
            r"'([a-z0-9_]+)':\s*'((?:\\'|[^'])*)'",
            localizer[localizer.index("accessoryStyleDescription"): localizer.index("AccessoryNamePrefix")],
        )
    )
    table = {}
    text = read(SOURCE / "toontown" / "catalog" / "CatalogAccessoryItemGlobals.py")
    for match in re.finditer(
        r"(\d+):\s*\((A\w+),\s*'([^']+)',\s*(APrice\w+|\d+)",
        text,
    ):
        article = ACCESSORY_ARTICLES.get(match.group(2))
        if article is None:
            continue
        gender, slot = article
        code = match.group(3)
        price_token = match.group(4)
        price = PRICES[price_token] if price_token in PRICES else int(price_token)
        table[int(match.group(1))] = {
            "kind": "accessory",
            "id": int(match.group(1)),
            "name": styles.get(code, code),
            "price": price,
            "gender": gender,
            "slot": slot,
        }
    return table


def emote_table() -> dict[int, dict]:
    text = read(SOURCE / "otp" / "otpbase" / "OTPLocalizerEnglish.py")
    body = bracket(text, text.index("EmoteList = ["), "[", "]")
    names = re.findall(r"'((?:\\'|[^'])*)'", body)
    return {
        index: {"kind": "emote", "id": index, "name": name, "price": 550, "gender": ""}
        for index, name in enumerate(names)
    }


def phrase_table() -> dict[int, dict]:
    text = read(SOURCE / "otp" / "otpbase" / "OTPLocalizerEnglish.py")
    body = bracket(text, text.index("CustomSCStrings = {"), "{", "}")
    table = {}
    for key, line in re.findall(r"(\d+):\s*'((?:\\'|[^'])*)'", body):
        index = int(key)
        table[index] = {
            "kind": "phrase",
            "id": index,
            "name": line.replace("\\'", "'"),
            "price": 150 if index >= 10000 else 100,
            "gender": "",
        }
    return table


def nametag_table() -> dict[int, dict]:
    text = read(SOURCE / "toontown" / "toonbase" / "TTLocalizerEnglish.py")
    fonts = re.findall(r"'([^']+)'", bracket(text, text.index("NametagFonts = ("), "(", ")"))
    names = re.findall(r"'([^']+)'", bracket(text, text.index("NametagFontNames = ("), "(", ")"))
    FONTS.mkdir(parents=True, exist_ok=True)
    table = {}
    for index, (font, name) in enumerate(zip(fonts, names)):
        source = GAME / Path(font)
        dest = FONTS / source.name
        if source.is_file() and (not dest.exists() or dest.stat().st_size != source.stat().st_size):
            shutil.copyfile(source, dest)
        table[index] = {
            "kind": "nametag",
            "id": index,
            "name": name + " Nametag",
            "price": 500,
            "gender": "",
            "font": "res://assets/gui/catalog/fonts/" + source.name,
        }
    return table


def apply_color(entry: dict, color_index: int) -> dict:
    copy = dict(entry)
    colors = copy.pop("colors", [])
    if colors:
        index = color_index if 0 <= color_index < len(colors) else 0
        chosen = colors[index]
        copy["color"] = int(chosen[0] if isinstance(chosen, (list, tuple)) else chosen)
        copy["color_index"] = index
    return copy


def collect(row: str, clothes, accessories, emotes, phrases, nametags, extras=None) -> list[dict]:
    found = []
    tables = [
        ("clothing", clothes, r"CatalogClothingItem\((\d+),\s*(\d+)"),
        ("accessory", accessories, r"CatalogAccessoryItem\((\d+)\)"),
        ("emote", emotes, r"CatalogEmoteItem\((\d+)"),
        ("phrase", phrases, r"CatalogChatItem\((\d+)\)"),
        ("nametag", nametags, r"CatalogNametagItem\((\d+)\)"),
    ]
    for kind, table in (extras or {}).items():
        if kind == "furniture":
            tables.append((kind, table, r"CatalogFurnitureItem\((\d+)"))
            tables.append((kind, table, r"CatalogAnimatedFurnitureItem\((\d+)"))
        elif kind == "wallpaper":
            tables.append((kind, table, r"CatalogWallpaperItem\((\d+)"))
        elif kind == "flooring":
            tables.append((kind, table, r"CatalogFlooringItem\((\d+)"))
        elif kind == "moulding":
            tables.append((kind, table, r"CatalogMouldingItem\((\d+)"))
        elif kind == "wainscoting":
            tables.append((kind, table, r"CatalogWainscotingItem\((\d+)"))
        elif kind == "window":
            tables.append((kind, table, r"CatalogWindowItem\((\d+)"))
        elif kind == "trick":
            tables.append((kind, table, r"CatalogPetTrickItem\((\d+)"))
    seen = set()
    for kind, table, pattern in tables:
        for match in re.finditer(pattern, row):
            item_id = int(match.group(1))
            item = table.get(item_id)
            if item is None:
                continue
            copy = apply_color(item, int(match.group(2)) if kind == "clothing" else 0)
            token = (copy["kind"], copy["id"], int(copy.get("color_index", 0)))
            if token in seen:
                continue
            seen.add(token)
            found.append(copy)
    return found


def expand_pools(generator: str, clothes: dict, phrases: dict) -> tuple[dict, dict]:
    clothing_pools = {}
    for key, args in re.findall(r"(\d+): getAllClothes\(([^)]*)\)", generator):
        pool = []
        seen = set()
        for item in re.findall(r"\d+", args):
            clothing_id = int(item)
            if clothing_id not in clothes or clothing_id in seen:
                continue
            seen.add(clothing_id)
            entry = clothes[clothing_id]
            count = len(entry.get("colors") or [0])
            for index in range(count):
                pool.append(apply_color(entry, index))
        clothing_pools[int(key)] = pool
    chat_pools = {}
    for key, args in re.findall(r"(\d+): getChatRange\(([^)]*)\)", generator):
        numbers = [int(item) for item in re.findall(r"\d+", args)]
        spans = list(zip(numbers[0::2], numbers[1::2]))
        pool = []
        for phrase_id in sorted(phrases):
            if phrase_id == 11009:
                continue
            if any(start <= phrase_id <= end for start, end in spans):
                pool.append(phrases[phrase_id])
        chat_pools[int(key)] = pool
    return clothing_pools, chat_pools


def fill_week(row: str, week_index: int, found: list[dict], clothes_pools: dict, chat_pools: dict) -> None:
    import random

    picker = random.Random(week_index + 1)
    bare = re.sub(r"\([^()]*\)", "", row)
    picks = [(1, int(key)) for key in re.findall(r"\b(\d+)\b", bare)]
    picks += [(int(count), int(key)) for count, key in re.findall(r"\((\d+),\s*(\d+)\)", row)]
    seen = {(item["kind"], item["id"]) for item in found}
    for count, key in picks:
        pool = clothes_pools.get(key, chat_pools.get(key, []))
        if not pool:
            continue
        choice = pool[:]
        picker.shuffle(choice)
        for item in choice[:count]:
            token = (item["kind"], item["id"])
            if token in seen:
                continue
            seen.add(token)
            found.append(dict(item))


def split_fields(body: str) -> list[str]:
    inner = body[1:-1]
    fields = []
    depth = 0
    start = 0
    for index, char in enumerate(inner):
        if char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        elif char == "," and depth == 0:
            fields.append(inner[start:index].strip())
            start = index + 1
    fields.append(inner[start:].strip())
    return fields


def name_map(text: str, label: str) -> dict[int, str]:
    body = bracket(text, text.index(label + " = {"), "{", "}")
    return {
        int(key): value.replace("\\'", "'")
        for key, value in re.findall(r"(\d+):\s*'((?:\\'|[^'])*)'", body)
    }


def typed_items(path: Path, dict_name: str, price_field: int, kind: str, names: dict[int, str]) -> dict[int, dict]:
    text = read(path)
    body = bracket(text, text.index(dict_name + " = {"), "{", "}")
    table = {}
    for match in re.finditer(r"(\d+):\s*\(", body):
        item_id = int(match.group(1))
        fields = split_fields(bracket(body, match.end() - 1, "(", ")"))
        price = 0
        if price_field < len(fields):
            numbers = re.findall(r"-?\d+", fields[price_field])
            if numbers:
                price = int(numbers[0])
        table[item_id] = {
            "kind": kind,
            "id": item_id,
            "name": names.get(item_id, kind.title()),
            "price": price,
            "gender": "",
        }
    return table


def surface_tables(localizer: str) -> dict[str, dict]:
    catalog = SOURCE / "toontown" / "catalog"
    furniture = typed_items(catalog / "CatalogFurnitureItem.py", "FurnitureTypes", 3, "furniture", name_map(localizer, "FurnitureNames"))
    return {
        "furniture": furniture,
        "wallpaper": typed_items(catalog / "CatalogWallpaperItem.py", "WallpaperTypes", 3, "wallpaper", name_map(localizer, "WallpaperNames")),
        "flooring": typed_items(catalog / "CatalogFlooringItem.py", "FlooringTypes", 3, "flooring", name_map(localizer, "FlooringNames")),
        "moulding": typed_items(catalog / "CatalogMouldingItem.py", "MouldingTypes", 3, "moulding", name_map(localizer, "MouldingNames")),
        "wainscoting": typed_items(catalog / "CatalogWainscotingItem.py", "WainscotingTypes", 2, "wainscoting", name_map(localizer, "WainscotingNames")),
        "window": typed_items(catalog / "CatalogWindowItem.py", "WindowViewTypes", 1, "window", name_map(localizer, "WindowViewNames")),
        "trick": {
            index: {"kind": "trick", "id": index, "name": name, "price": 500, "gender": ""}
            for index, name in name_map(read(SOURCE / "toontown" / "toonbase" / "TTLocalizerEnglish.py"), "PetTrickStrings").items()
        },
    }


def surface_pools(generator: str, tables: dict[str, dict]) -> dict[int, list[dict]]:
    pools = {}
    callers = {
        "getWallpapers": "wallpaper",
        "getFloorings": "flooring",
        "getAllMouldings": "moulding",
        "getAllWainscotings": "wainscoting",
        "getAllPetTricks": "trick",
    }
    for key, fn, args in re.findall(r"(\d+): (getWallpapers|getFloorings|getAllMouldings|getAllWainscotings|getAllPetTricks)\(([^)]*)\)", generator):
        kind = callers[fn]
        table = tables[kind]
        if fn == "getAllPetTricks":
            pools[int(key)] = [dict(item) for item in table.values()]
            continue
        pools[int(key)] = [dict(table[int(item)]) for item in re.findall(r"\d+", args) if int(item) in table]
    return pools


def sprinkle(rows: list[list[dict]], months: list[dict], items: list[dict]) -> None:
    present = set()
    for row in rows:
        for item in row:
            present.add((item["kind"], item["id"]))
    for month in months:
        for item in month["items"]:
            present.add((item["kind"], item["id"]))
    missing = [item for item in items if (item["kind"], item["id"]) not in present]
    if not rows:
        return
    for index, item in enumerate(missing):
        rows[index % len(rows)].append(dict(item))


def weeks() -> tuple[list, list, list]:
    dna = read(SOURCE / "toontown" / "toon" / "ToonDNA.py")
    localizer = read(SOURCE / "toontown" / "toonbase" / "TTLocalizerEnglish.py")
    clothes = clothing_table(dna, localizer)
    accessories = accessory_table(localizer)
    emotes = emote_table()
    phrases = phrase_table()
    nametags = nametag_table()
    extras = surface_tables(localizer)
    generator = read(SOURCE / "toontown" / "catalog" / "CatalogGenerator.py")
    weekly_at = generator.index("WeeklySchedule = (")
    weekly = bracket(generator, generator.index("(", weekly_at), "(", ")")
    clothes_pools, chat_pools = expand_pools(generator, clothes, phrases)
    more_pools = surface_pools(generator, extras)
    rows = []
    for week_index, row in enumerate(top_tuples(weekly)):
        found = collect(row, clothes, accessories, emotes, phrases, nametags, extras)
        fill_week(row, week_index, found, clothes_pools, chat_pools)
        fill_week(row, week_index + 9001, found, more_pools, {})
        if "nextAvailablePole" in row:
            found.append({"kind": "pole", "id": -1, "name": "Fishing Rod", "price": 0, "gender": ""})
        if "nextAvailableCloset" in row:
            found.append(dict(extras["furniture"][502], gender="m"))
            found.append(dict(extras["furniture"][512], gender="f"))
        # generateWeeklyCatalog adds the 50-item trunk on every week.
        found.append(dict(extras["furniture"][4000], gender="m"))
        found.append(dict(extras["furniture"][4010], gender="f"))
        rows.append(found)
    monthly_at = generator.index("MonthlySchedule = (")
    monthly = bracket(generator, generator.index("(", monthly_at), "(", ")")
    months = []
    for month_index, row in enumerate(top_tuples(monthly)):
        numbers = [int(value) for value in re.findall(r"\d+", row.split("(", 1)[1][:80])]
        if len(numbers) < 4:
            continue
        found = collect(row, clothes, accessories, emotes, phrases, nametags, extras)
        fill_week(row, month_index + 5000, found, more_pools, chat_pools)
        months.append({"start": numbers[0:2], "end": numbers[2:4], "items": found})
    wardrobe = []
    seen_colors = set()
    for clothing_id in sorted(clothes):
        entry = clothes[clothing_id]
        count = len(entry.get("colors") or [0])
        for index in range(count):
            painted = apply_color(entry, index)
            token = (painted["id"], painted["color"], painted["piece"])
            if token in seen_colors:
                continue
            seen_colors.add(token)
            wardrobe.append(painted)
    sprinkle(rows, months, [apply_color(clothes[item_id], 0) for item_id in sorted(clothes)])
    sprinkle(rows, months, [dict(item) for item in accessories.values()])
    return rows, months, wardrobe


def render_page(root) -> None:
    from direct.showbase.ShowBase import ShowBase
    from panda3d.core import (
        Filename,
        FrameBufferProperties,
        GraphicsOutput,
        GraphicsPipe,
        OrthographicLens,
        PNMImage,
        Texture,
        WindowProperties,
    )

    hidden = (
        "arrowDown1", "arrowRollover", "arrowUp", "arrow_Down", "arrow_Rollover", "arrow_up",
        "hangup", "hangup_rollover", "new", "new1", "new2", "previous1", "previous2",
        "giftButtonDown", "giftButtonUp", "gift_names", "cover",
    )
    for name in hidden:
        node = root.find("**/" + name)
        if not node.isEmpty():
            node.hide()
    base = ShowBase(windowType="offscreen")
    root.reparentTo(base.render)
    root.setLightOff(1)
    width = 4.0
    height = 3.0
    center_z = -0.0359
    pixels_w = 1280
    pixels_h = int(round(pixels_w * height / width))
    lens = OrthographicLens()
    lens.setFilmSize(width, height)
    lens.setNearFar(0.1, 100.0)
    fb = FrameBufferProperties()
    fb.setRgbaBits(8, 8, 8, 8)
    fb.setDepthBits(24)
    props = WindowProperties.size(pixels_w, pixels_h)
    buffer = base.graphicsEngine.makeOutput(
        base.pipe, "catalog", -100, fb, props, GraphicsPipe.BFRefuseWindow, base.win.getGsg(), base.win
    )
    if buffer is None:
        raise RuntimeError("catalog buffer failed")
    buffer.setClearColorActive(True)
    buffer.setClearColor((0, 0, 0, 0))
    camera = base.makeCamera(buffer, lens=lens)
    camera.reparentTo(base.render)
    camera.setPos(0.0, -10.0, center_z)
    camera.setHpr(0.0, 0.0, 0.0)
    texture = Texture()
    buffer.addRenderTexture(texture, GraphicsOutput.RTMCopyRam)
    base.graphicsEngine.renderFrame()
    base.graphicsEngine.renderFrame()
    image = PNMImage()
    if not texture.store(image):
        raise RuntimeError("catalog store failed")
    path = GUI / "background.png"
    if not image.write(Filename.from_os_specific(str(path))):
        raise RuntimeError("write failed")
    print("page", image.getXSize(), image.getYSize(), flush=True)


def export_gui() -> None:
    sys.path.insert(0, str(TOOLS))
    from panda3d.core import getModelPath, loadPrcFileData
    import export_dialog

    loadPrcFileData("", "window-type offscreen")
    loadPrcFileData("", "audio-library-name null")
    getModelPath().prependDirectory(export_dialog.ASSETS)
    root = export_dialog.load("phase_5.5/models/gui/catalog_gui.bam")
    GUI.mkdir(parents=True, exist_ok=True)
    render_page(root)
    wanted = {
        "bean_bank": "bean_bank.png",
        "hangup": "hangup.png",
        "hangup_rollover": "hangup_hover.png",
        "arrow_up": "next_up.png",
        "arrow_Down": "next_down.png",
        "arrow_Rollover": "next_hover.png",
        "arrowUp": "prev_up.png",
        "arrowDown1": "prev_down.png",
        "arrowRollover": "prev_hover.png",
        "clarabelle_frame": "clarabelle_frame.png",
    }
    for name, file_name in wanted.items():
        node = root.find("**/" + name)
        if node.isEmpty():
            print("missing", name, flush=True)
            continue
        export_dialog.crop_card(node, GUI / file_name)
        low, high = node.getTightBounds()
        print("bounds", name, tuple(round(v, 4) for v in low), tuple(round(v, 4) for v in high), flush=True)


def main() -> int:
    weekly, monthly, clothes = weeks()
    ISSUE.parent.mkdir(parents=True, exist_ok=True)
    ISSUE.write_text(json.dumps({"weeks": weekly, "months": monthly, "clothes": clothes}, indent=1), encoding="utf-8")
    print("weeks", len(weekly), "months", len(monthly), "clothes", len(clothes), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
