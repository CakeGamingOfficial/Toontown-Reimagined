"""Turn the original Mickey sign font into a Godot bitmap font.

MickeyFont.bam is a textured quad for each glyph, not a TrueType file.
ImpressBT.ttf is copied separately; that file is both the interface font
and the toon font.
"""

import json
import shutil
from pathlib import Path

from panda3d.core import Filename, FontPool, GeomVertexReader, PNMImage, TextureAttrib, loadPrcFileData


ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "Original Toontown Assets" / "Game Assets"
OUT = ROOT / "Godot Project" / "project-toontown" / "assets" / "toons" / "fonts"
FONT_DIR = ASSETS / "phase_3" / "models" / "fonts"


def glyph_quad(glyph):
    geom = glyph.get_geom(0)
    if geom is None or geom.get_vertex_data().get_num_rows() < 3:
        return None
    data = geom.get_vertex_data()
    if not data.has_column("vertex") or not data.has_column("texcoord"):
        return None
    points = []
    uvs = []
    vertex = GeomVertexReader(data, "vertex")
    texcoord = GeomVertexReader(data, "texcoord")
    while not vertex.is_at_end():
        point = vertex.get_data3()
        uv = texcoord.get_data2()
        # Copy immediately. Panda reuses the returned vector objects.
        points.append((point.x, point.y, point.z))
        uvs.append((uv.x, uv.y))
    if len(uvs) < 3:
        return None
    return points, uvs


def main() -> None:
    loadPrcFileData("", "window-type none")
    loadPrcFileData("", "audio-library-name null")
    folder = Filename.from_os_specific(str(FONT_DIR))
    loadPrcFileData("", "model-path " + folder.get_fullpath())
    font = FontPool.load_font("MickeyFont.bam")
    if font is None or not font.is_valid():
        raise SystemExit("MickeyFont.bam did not load")

    texture = None
    quads = {}
    for code in range(32, 127):
        glyph = font.get_glyph(code)
        if glyph is None:
            continue
        quad = glyph_quad(glyph)
        if quad is None:
            continue
        quads[code] = (glyph, quad)
        if texture is None:
            texture = glyph.get_state().get_attrib(TextureAttrib).get_texture()
    if texture is None:
        raise SystemExit("MickeyFont has no glyph texture")

    source = PNMImage()
    texture.store(source)
    width = source.get_x_size()
    height = source.get_y_size()
    image = PNMImage(width, height, 4)
    for y in range(height):
        for x in range(width):
            gray = source.get_gray(x, y)
            alpha = source.get_alpha(x, y)
            image.set_xel_a(x, y, gray, gray, gray, alpha)

    scales = []
    measured = {}
    for code, (glyph, (points, uvs)) in quads.items():
        u0 = min(uv[0] for uv in uvs)
        u1 = max(uv[0] for uv in uvs)
        v0 = min(uv[1] for uv in uvs)
        v1 = max(uv[1] for uv in uvs)
        pixel_w = (u1 - u0) * width
        span = max(point[0] for point in points) - min(point[0] for point in points)
        if pixel_w > 1.0 and span > 0.001:
            scales.append(pixel_w / span)
        measured[code] = (glyph, points, u0, u1, v0, v1)
    scale = sorted(scales)[len(scales) // 2]

    glyphs = []
    for code, (glyph, points, u0, u1, v0, v1) in measured.items():
        x_min = min(point[0] for point in points)
        z_min = min(point[2] for point in points)
        z_max = max(point[2] for point in points)
        px = round(u0 * width)
        py = round((1.0 - v1) * height)
        pw = max(round((u1 - u0) * width), 1)
        ph = max(round((v1 - v0) * height), 1)
        glyphs.append({
            "cp": code,
            "advance": glyph.get_advance() * scale,
            "ox": x_min * scale,
            "oy": -z_max * scale,
            "w": (max(point[0] for point in points) - x_min) * scale,
            "h": (z_max - z_min) * scale,
            "uv": [px, py, pw, ph],
        })

    present = {item["cp"] for item in glyphs}
    for code in range(ord("a"), ord("z") + 1):
        upper = code - 32
        if code not in present and upper in present:
            source_glyph = next(item for item in glyphs if item["cp"] == upper)
            copy = dict(source_glyph)
            copy["cp"] = code
            copy["uv"] = list(source_glyph["uv"])
            glyphs.append(copy)

    glyphs.append({
        "cp": 32,
        "advance": font.get_space_advance() * scale,
        "ox": 0.0,
        "oy": 0.0,
        "w": 0.0,
        "h": 0.0,
        "uv": [0, 0, 0, 0],
    })
    glyphs.sort(key=lambda item: item["cp"])

    ascent = max(-item["oy"] for item in glyphs)
    descent = max(item["oy"] + item["h"] for item in glyphs)
    OUT.mkdir(parents=True, exist_ok=True)
    image_path = OUT / "mickey_font.png"
    image.write(Filename.from_os_specific(str(image_path)))
    payload = {
        "size": round(font.get_line_height() * scale),
        "ascent": ascent,
        "descent": descent,
        "glyphs": glyphs,
    }
    (OUT / "mickey_font.json").write_text(json.dumps(payload), encoding="utf-8")
    shutil.copyfile(FONT_DIR / "ImpressBT.ttf", OUT / "ImpressBT.ttf")
    print(f"glyphs {len(glyphs)} size {payload['size']} ascent {ascent:.1f} descent {descent:.1f}")


if __name__ == "__main__":
    main()
