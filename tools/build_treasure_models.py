"""Turn each playground treasure picture into a solid rounded model."""

import json
import math
import os
import struct
import zlib

ROOT = os.path.join(
	os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
	"Godot Project",
	"project-toontown",
	"assets",
	"neighborhoods",
)

# Picture size is the original card. u grows to the right, v grows down the art.
TREASURES = [
	("toontown_central/props/icecream", 2.2, 3.0, 0.6328, 0.8692, 0.5973, 0.8320),
	("donalds_dock/props/starfish_treasure", 3.0, 3.0, 0.5078, 0.7442, 0.0072, 0.4922),
	("daisy_gardens/props/flower_treasure", 3.0, 3.0, 0.0078, 0.2442, 0.5075, 0.7422),
	("minnies_melodyland/props/music_treasure", 2.5297, 3.0, 0.7578, 0.9942, 0.5075, 0.7422),
	("the_burrrgh/props/snowflake_treasure", 3.0, 3.0, 0.0078, 0.3703, 0.5072, 0.9922),
	("donalds_dreamland/props/zzz_treasure", 3.0277, 1.5138, 0.0078, 0.4963, 0.5075, 0.7422),
	("acorn_acres/props/acorn_treasure", 2.2, 2.0, 0.0078, 0.2442, 0.2575, 0.4922),
]


def load_png(path):
	data = open(path, "rb").read()
	width, height = struct.unpack(">II", data[16:24])
	color = data[25]
	if color != 6:
		raise SystemExit("need an rgba png: %s" % path)
	position = 8
	idat = b""
	while position < len(data):
		length, kind = struct.unpack(">I4s", data[position : position + 8])
		chunk = data[position + 8 : position + 8 + length]
		if kind == b"IDAT":
			idat += chunk
		position += 12 + length
		if kind == b"IEND":
			break
	raw = zlib.decompress(idat)
	rows = []
	cursor = 0
	previous = bytearray(width * 4)

	def paeth(left, above, corner):
		guess = left + above - corner
		dl = abs(guess - left)
		da = abs(guess - above)
		dc = abs(guess - corner)
		if dl <= da and dl <= dc:
			return left
		if da <= dc:
			return above
		return corner

	for _y in range(height):
		filter_kind = raw[cursor]
		cursor += 1
		row = bytearray(raw[cursor : cursor + width * 4])
		cursor += width * 4
		if filter_kind == 1:
			for index in range(len(row)):
				left = row[index - 4] if index >= 4 else 0
				row[index] = (row[index] + left) & 255
		elif filter_kind == 2:
			for index in range(len(row)):
				row[index] = (row[index] + previous[index]) & 255
		elif filter_kind == 3:
			for index in range(len(row)):
				left = row[index - 4] if index >= 4 else 0
				row[index] = (row[index] + ((left + previous[index]) // 2)) & 255
		elif filter_kind == 4:
			for index in range(len(row)):
				left = row[index - 4] if index >= 4 else 0
				above = previous[index]
				corner = previous[index - 4] if index >= 4 else 0
				row[index] = (row[index] + paeth(left, above, corner)) & 255
		rows.append(row)
		previous = row
	return width, height, rows


def sample(rows, width, height, x, y):
	x = min(max(int(x), 0), width - 1)
	y = min(max(int(y), 0), height - 1)
	index = x * 4
	row = rows[y]
	return row[index + 3]


def build(stem, card_w, card_h, u0, u1, v0, v1):
	png_path = os.path.join(ROOT, stem + "_0.png")
	width, height, rows = load_png(png_path)
	x0 = int(math.floor(u0 * width))
	x1 = int(math.ceil(u1 * width))
	y0 = int(math.floor(v0 * height))
	y1 = int(math.ceil(v1 * height))
	crop_w = max(x1 - x0, 1)
	crop_h = max(y1 - y0, 1)
	alpha = []
	mask = []
	for y in range(crop_h):
		alpha_row = []
		row = []
		for x in range(crop_w):
			cover = sample(rows, width, height, x0 + x, y0 + y)
			alpha_row.append(cover)
			row.append(cover > 24)
		alpha.append(alpha_row)
		mask.append(row)

	def inside(x, y):
		if x < 0 or y < 0 or x >= crop_w or y >= crop_h:
			return False
		return mask[y][x]

	# The painted edge is only partly opaque. Sample a solid texel instead,
	# or the rim blends into the empty part of the sheet and cuts apart.
	source = [[(x, y) for x in range(crop_w)] for y in range(crop_h)]
	for y in range(crop_h):
		for x in range(crop_w):
			if not mask[y][x] or alpha[y][x] > 200:
				continue
			found = None
			for radius in range(1, 6):
				for oy in range(-radius, radius + 1):
					for ox in range(-radius, radius + 1):
						if max(abs(ox), abs(oy)) != radius:
							continue
						sx = x + ox
						sy = y + oy
						if inside(sx, sy) and alpha[sy][sx] > 200:
							found = (sx, sy)
							break
					if found is not None:
						break
				if found is not None:
					break
			if found is not None:
				source[y][x] = found

	# Distance to the empty part of the picture. The middle of a shape is
	# farther from that edge, so it becomes the thick part of the model.
	huge = 1.0e6
	dist = []
	for y in range(crop_h):
		row = []
		for x in range(crop_w):
			row.append(0.0 if not mask[y][x] else huge)
		dist.append(row)
	for y in range(crop_h):
		for x in range(crop_w):
			value = dist[y][x]
			if x > 0:
				value = min(value, dist[y][x - 1] + 1.0)
			if y > 0:
				value = min(value, dist[y - 1][x] + 1.0)
			if x > 0 and y > 0:
				value = min(value, dist[y - 1][x - 1] + 1.4142)
			if x + 1 < crop_w and y > 0:
				value = min(value, dist[y - 1][x + 1] + 1.4142)
			dist[y][x] = value
	for y in range(crop_h - 1, -1, -1):
		for x in range(crop_w - 1, -1, -1):
			value = dist[y][x]
			if x + 1 < crop_w:
				value = min(value, dist[y][x + 1] + 1.0)
			if y + 1 < crop_h:
				value = min(value, dist[y + 1][x] + 1.0)
			if x + 1 < crop_w and y + 1 < crop_h:
				value = min(value, dist[y + 1][x + 1] + 1.4142)
			if x > 0 and y + 1 < crop_h:
				value = min(value, dist[y + 1][x - 1] + 1.4142)
			dist[y][x] = value
	# Blur the distance so the pixel grid does not become ridges on the side.
	sigma = 3.4
	radius = 8
	curve = [math.exp(-0.5 * (offset / sigma) ** 2) for offset in range(-radius, radius + 1)]

	def blur_axis(source, horizontal):
		blurred = [row[:] for row in source]
		for y in range(crop_h):
			for x in range(crop_w):
				if not mask[y][x]:
					blurred[y][x] = 0.0
					continue
				total = 0.0
				weight = 0.0
				for offset, amount in enumerate(curve):
					delta = offset - radius
					nx = x + delta if horizontal else x
					ny = y if horizontal else y + delta
					sample_dist = source[ny][nx] if inside(nx, ny) else 0.0
					total += sample_dist * amount
					weight += amount
				blurred[y][x] = total / weight
		return blurred

	dist = blur_axis(dist, True)
	dist = blur_axis(dist, False)
	dist = blur_axis(dist, True)
	dist = blur_axis(dist, False)

	res = 3
	grid_w = crop_w * res
	grid_h = crop_h * res
	pixel = 0.5 * (card_w / float(crop_w) + card_h / float(crop_h))
	depth_cap = 0.46 * min(card_w, card_h)

	def field(fx, fy):
		sx = fx - 0.5
		sy = fy - 0.5
		ix = int(math.floor(sx))
		iy = int(math.floor(sy))
		tx = sx - ix
		ty = sy - iy

		def at(px, py):
			if inside(px, py):
				return dist[py][px]
			return 0.0

		d00 = at(ix, iy)
		d10 = at(ix + 1, iy)
		d01 = at(ix, iy + 1)
		d11 = at(ix + 1, iy + 1)
		top = d00 + (d10 - d00) * tx
		bottom = d01 + (d11 - d01) * tx
		return top + (bottom - top) * ty

	def thickness(depth):
		if depth <= 0.08:
			return 0.0
		half = pixel * 4.8 * math.sqrt(depth)
		if half > depth_cap:
			return depth_cap
		return half

	def place(fx, fy):
		px = -card_w * 0.5 + (fx / float(crop_w)) * card_w
		py = card_h * (1.0 - fy / float(crop_h))
		return px, py

	def uv_of(fx, fy, depth):
		ix = min(max(int(math.floor(fx)), 0), crop_w - 1)
		iy = min(max(int(math.floor(fy)), 0), crop_h - 1)
		if not inside(ix, iy) or depth < 1.2 or alpha[iy][ix] <= 200:
			if not inside(ix, iy):
				found = None
				for radius in range(1, 4):
					for oy in range(-radius, radius + 1):
						for ox in range(-radius, radius + 1):
							if inside(ix + ox, iy + oy):
								found = (ix + ox, iy + oy)
								break
						if found is not None:
							break
					if found is not None:
						break
				if found is None:
					return u0, v0
				ix, iy = found
			sx, sy = source[iy][ix]
			return (x0 + sx + 0.5) / float(width), (y0 + sy + 0.5) / float(height)
		cx = min(max(fx, 0.5), crop_w - 0.5)
		cy = min(max(fy, 0.5), crop_h - 0.5)
		return (x0 + cx) / float(width), (y0 + cy) / float(height)

	positions = []
	normals = []
	uvs = []
	indices = []
	front = {}
	back = {}
	peak_box = [0.0]
	res = 4

	def add_vert(px, py, pz, pu, pv, normal):
		positions.append((px, py, pz))
		normals.append(normal)
		uvs.append((pu, pv))
		return len(positions) - 1

	def rounded_normal(fx, fy, front_side):
		step = 0.8
		slope_x = thickness(field(fx + step, fy)) - thickness(field(fx - step, fy))
		slope_y = thickness(field(fx, fy + step)) - thickness(field(fx, fy - step))
		slope_x /= step * 2.0
		slope_y /= step * 2.0
		span_x = card_w / float(crop_w)
		span_y = -card_h / float(crop_h)
		nx = span_y * slope_x
		ny = span_x * slope_y
		nz = -span_y * span_x
		if not front_side:
			nz = -nz
		length = math.sqrt(nx * nx + ny * ny + nz * nz)
		if length < 1.0e-8:
			return (0.0, 0.0, 1.0 if front_side else -1.0)
		return (nx / length, ny / length, nz / length)

	def vertex(i, j):
		key = (i, j)
		if key in front:
			return
		fx = i / float(res)
		fy = j / float(res)
		depth = field(fx, fy)
		px, py = place(fx, fy)
		pu, pv = uv_of(fx, fy, depth)
		half = thickness(depth)
		if half > peak_box[0]:
			peak_box[0] = half
		if half < 0.02:
			# The outline is one shared point so the shell closes without a cut.
			shared = add_vert(px, py, 0.0, pu, pv, rounded_normal(fx, fy, True))
			front[key] = shared
			back[key] = shared
			return
		front[key] = add_vert(px, py, half, pu, pv, rounded_normal(fx, fy, True))
		back[key] = add_vert(px, py, -half, pu, pv, rounded_normal(fx, fy, False))

	def tri(a, b, c):
		if a == b or b == c or c == a:
			return
		indices.extend((a, b, c))

	def stitch(ax, ay, bx, by, ox, oy):
		fa = front[(ax, ay)]
		fb = front[(bx, by)]
		ba = back[(ax, ay)]
		bb = back[(bx, by)]
		if fa == ba and fb == bb:
			return
		out_x = ox / float(crop_w) * card_w
		out_y = -oy / float(crop_h) * card_h
		ax0, ay0, az0 = positions[fa]
		bx0, by0, bz0 = positions[fb]
		cx0, cy0, cz0 = positions[bb]
		nx = (by0 - ay0) * (cz0 - az0) - (bz0 - az0) * (cy0 - ay0)
		ny = (bz0 - az0) * (cx0 - ax0) - (bx0 - ax0) * (cz0 - az0)
		nz = (bx0 - ax0) * (cy0 - ay0) - (by0 - ay0) * (cx0 - ax0)
		if nx * out_x + ny * out_y < 0.0:
			tri(fa, bb, fb)
			tri(fa, ba, bb)
		else:
			tri(fa, fb, bb)
			tri(fa, bb, ba)

	grid_w = crop_w * res
	grid_h = crop_h * res
	for j in range(grid_h):
		for i in range(grid_w):
			if not inside(i // res, j // res):
				continue
			vertex(i, j)
			vertex(i + 1, j)
			vertex(i + 1, j + 1)
			vertex(i, j + 1)
			a = front[(i, j)]
			b = front[(i + 1, j)]
			c = front[(i + 1, j + 1)]
			d = front[(i, j + 1)]
			tri(a, d, c)
			tri(a, c, b)
			a = back[(i, j)]
			b = back[(i + 1, j)]
			c = back[(i + 1, j + 1)]
			d = back[(i, j + 1)]
			tri(a, b, c)
			tri(a, c, d)
			for ax, ay, bx, by, ox, oy in (
				(i, j, i + 1, j, 0, -1),
				(i + 1, j, i + 1, j + 1, 1, 0),
				(i + 1, j + 1, i, j + 1, 0, 1),
				(i, j + 1, i, j, -1, 0),
			):
				if inside((i + ox) // res, (j + oy) // res):
					continue
				stitch(ax, ay, bx, by, ox, oy)

	peak = peak_box[0]
	light_x, light_y, light_z = 0.22, 0.86, 0.46
	light_len = math.sqrt(light_x * light_x + light_y * light_y + light_z * light_z)
	light_x /= light_len
	light_y /= light_len
	light_z /= light_len
	colors = []
	for normal in normals:
		lit = normal[0] * light_x + normal[1] * light_y + normal[2] * light_z
		if lit < 0.0:
			lit = 0.0
		shade = 0.62 + 0.38 * lit
		colors.append((shade, shade, shade, 1.0))
	return positions, normals, uvs, colors, indices, peak


def pad(blob):
	while len(blob) % 4:
		blob += b"\x00"
	return blob


def write_glb(path, png_name, positions, normals, uvs, colors, indices):
	def pack_vec(values, count):
		out = bytearray()
		for item in values:
			out += struct.pack("<" + "f" * count, *item)
		return out

	def pack_color(values):
		out = bytearray()
		for item in values:
			out += bytes(max(0, min(255, int(round(channel * 255.0)))) for channel in item)
		return out

	blobs = [
		pack_vec(positions, 3),
		pack_vec(normals, 3),
		pack_vec(uvs, 2),
		pack_color(colors),
		b"".join(struct.pack("<I", index) for index in indices),
	]
	buffer = b""
	views = []
	offset = 0
	for blob in blobs:
		buffer += pad(blob)
		views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(blob)})
		offset += (len(blob) + 3) & ~3
	mins = [min(item[axis] for item in positions) for axis in range(3)]
	maxs = [max(item[axis] for item in positions) for axis in range(3)]
	umin = min(item[0] for item in uvs)
	umax = max(item[0] for item in uvs)
	vmin = min(item[1] for item in uvs)
	vmax = max(item[1] for item in uvs)
	gltf = {
		"asset": {"version": "2.0", "generator": "build_treasure_models.py"},
		"buffers": [{"byteLength": len(buffer)}],
		"bufferViews": views,
		"accessors": [
			{"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": mins, "max": maxs},
			{"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
			{"bufferView": 2, "componentType": 5126, "count": len(uvs), "type": "VEC2", "min": [umin, vmin], "max": [umax, vmax]},
			{"bufferView": 3, "componentType": 5121, "normalized": True, "count": len(colors), "type": "VEC4"},
			{"bufferView": 4, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
		],
		"images": [{"uri": png_name}],
		"samplers": [{
			"magFilter": 9729,
			"minFilter": 9729,
			"wrapS": 33071,
			"wrapT": 33071,
		}],
		"textures": [{"sampler": 0, "source": 0}],
		"materials": [{
			"name": "treasure",
			"pbrMetallicRoughness": {
				"baseColorTexture": {"index": 0},
				"metallicFactor": 0.0,
				"roughnessFactor": 1.0,
			},
			"doubleSided": False,
		}],
		"meshes": [{
			"name": "treasure",
			"primitives": [{
				"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2, "COLOR_0": 3},
				"indices": 4,
				"material": 0,
			}],
		}],
		"nodes": [{"name": "treasure", "mesh": 0}],
		"scenes": [{"nodes": [0]}],
		"scene": 0,
	}
	json_blob = pad(json.dumps(gltf, separators=(",", ":")).encode("utf-8"))
	out = bytearray()
	out += struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(json_blob) + 8 + len(buffer))
	out += struct.pack("<II", len(json_blob), 0x4E4F534A)
	out += json_blob
	out += struct.pack("<II", len(buffer), 0x004E4942)
	out += buffer
	struct.pack_into("<I", out, 8, len(out))
	open(path, "wb").write(out)


def main():
	for stem, card_w, card_h, u0, u1, v0, v1 in TREASURES:
		positions, normals, uvs, colors, indices, peak = build(
			stem, card_w, card_h, u0, u1, v0, v1
		)
		png_name = os.path.basename(stem) + "_0.png"
		dest = os.path.join(ROOT, stem + "_solid.glb")
		write_glb(dest, png_name, positions, normals, uvs, colors, indices)
		print("%s verts %d tris %d depth %.2f" % (
			os.path.basename(dest), len(positions), len(indices) // 3, peak * 2.0
		))


if __name__ == "__main__":
	main()
