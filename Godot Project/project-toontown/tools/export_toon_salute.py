"""Build a salute clip from the standing pose and the raised-hand victory frame.

The victory dance's opening is the original resistance salute, but it also
bobs the head and keeps going into a cheer. This clip only eases from idle
to that raised hand, holds, and eases back. Legs stay on the standing frame.
"""

import os
import struct

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "toons", "anims")
UP = 12
HOLD = 14
DOWN = 12
PEAK = 9


def smooth(t):
	t = max(0.0, min(1.0, t))
	return t * t * (3.0 - 2.0 * t)


def weights(count):
	out = []
	for index in range(count):
		if index < UP:
			out.append(smooth(index / float(UP - 1)))
		elif index < UP + HOLD:
			out.append(1.0)
		else:
			out.append(1.0 - smooth((index - (UP + HOLD)) / float(DOWN - 1)))
	return out


def read_clip(path):
	with open(path, "rb") as handle:
		magic = handle.read(8)
		frames, nodes = struct.unpack("<II", handle.read(8))
		parts = []
		for _node in range(nodes):
			name_len = struct.unpack("<H", handle.read(2))[0]
			name = handle.read(name_len).decode("utf-8")
			surface_count = struct.unpack("<I", handle.read(4))[0]
			surfaces = []
			for _surface in range(surface_count):
				vertex_count = struct.unpack("<I", handle.read(4))[0]
				has_uv = struct.unpack("<B", handle.read(1))[0]
				uvs = handle.read(vertex_count * 8) if has_uv else b""
				raw = handle.read(frames * vertex_count * 12)
				surfaces.append((vertex_count, has_uv, uvs, raw))
			parts.append((name, surfaces))
		joint_count = struct.unpack("<I", handle.read(4))[0]
		joints = []
		for _joint in range(joint_count):
			name_len = struct.unpack("<H", handle.read(2))[0]
			name = handle.read(name_len).decode("utf-8")
			bind = handle.read(64)
			raw = handle.read(frames * 64)
			joints.append((name, bind, raw))
		return magic, frames, parts, joints


def frame_bytes(raw, vertex_count, index):
	stride = vertex_count * 12
	return raw[index * stride:(index + 1) * stride]


def mix_frame(down, up, vertex_count, weight):
	if weight <= 0.0:
		return down
	if weight >= 1.0:
		return up
	down_vals = struct.unpack("<%df" % (vertex_count * 3), down)
	up_vals = struct.unpack("<%df" % (vertex_count * 3), up)
	mixed = [(1.0 - weight) * a + weight * b for a, b in zip(down_vals, up_vals)]
	return struct.pack("<%df" % len(mixed), *mixed)


def joint_frame(raw, index):
	return raw[index * 64:(index + 1) * 64]


def mix_joint(down, up, weight):
	if weight <= 0.0:
		return down
	if weight >= 1.0:
		return up
	a = struct.unpack("<16f", down)
	b = struct.unpack("<16f", up)
	mixed = []
	for row in range(3):
		start = row * 4
		axis = tuple((1.0 - weight) * a[start + i] + weight * b[start + i] for i in range(3))
		length = (axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]) ** 0.5 or 1.0
		mixed.extend((axis[0] / length, axis[1] / length, axis[2] / length, 0.0))
	mixed.extend((
		(1.0 - weight) * a[12] + weight * b[12],
		(1.0 - weight) * a[13] + weight * b[13],
		(1.0 - weight) * a[14] + weight * b[14],
		1.0,
	))
	return struct.pack("<16f", *mixed)


def write_clip(path, magic, parts, joints):
	frame_count = len(parts[0][1][0][3])
	blob = bytearray(magic)
	blob += struct.pack("<II", frame_count, len(parts))
	for name, surfaces in parts:
		encoded = name.encode("utf-8")
		blob += struct.pack("<H", len(encoded))
		blob += encoded
		blob += struct.pack("<I", len(surfaces))
		for vertex_count, has_uv, uvs, frames in surfaces:
			blob += struct.pack("<IB", vertex_count, has_uv)
			if has_uv:
				blob += uvs
			for frame in frames:
				blob += frame
	blob += struct.pack("<I", len(joints))
	for name, bind, frames in joints:
		encoded = name.encode("utf-8")
		blob += struct.pack("<H", len(encoded))
		blob += encoded
		blob += bind
		for frame in frames:
			blob += frame
	with open(path, "wb") as handle:
		handle.write(blob)


def torso_salute(stem):
	idle_magic, idle_frames, idle_parts, idle_joints = read_clip(os.path.join(ROOT, stem + ".idle"))
	magic, victory_frames, victory_parts, victory_joints = read_clip(os.path.join(ROOT, stem + ".victory"))
	if victory_frames <= PEAK:
		raise RuntimeError("%s victory has no salute frame" % stem)
	idle_by_name = {name: surfaces for name, surfaces in idle_parts}
	count = UP + HOLD + DOWN
	curve = weights(count)
	parts = []
	for name, surfaces in victory_parts:
		if name not in idle_by_name:
			raise RuntimeError("%s idle is missing %s" % (stem, name))
		idle_surfaces = idle_by_name[name]
		if len(idle_surfaces) != len(surfaces):
			raise RuntimeError("%s %s surface count differs" % (stem, name))
		built = []
		for index, surface in enumerate(surfaces):
			vertex_count, has_uv, uvs, raw = surface
			idle_count = idle_surfaces[index][0]
			if idle_count != vertex_count:
				raise RuntimeError("%s %s vertex count differs" % (stem, name))
			down = frame_bytes(idle_surfaces[index][3], vertex_count, 0)
			up = frame_bytes(raw, vertex_count, PEAK)
			frames = [mix_frame(down, up, vertex_count, weight) for weight in curve]
			built.append((vertex_count, has_uv, uvs, frames))
		parts.append((name, built))
	idle_joint_raw = {name: raw for name, _bind, raw in idle_joints}
	joints = []
	for name, bind, raw in victory_joints:
		up = joint_frame(raw, PEAK)
		if name in idle_joint_raw and idle_frames > 0:
			down = joint_frame(idle_joint_raw[name], 0)
		else:
			down = joint_frame(raw, 0)
		frames = [mix_joint(down, up, weight) for weight in curve]
		joints.append((name, bind, frames))
	write_clip(os.path.join(ROOT, stem + ".salute"), magic, parts, joints)


def legs_salute(stem):
	magic, _frames, parts, joints = read_clip(os.path.join(ROOT, stem + ".idle"))
	held_parts = []
	for name, surfaces in parts:
		built = []
		for vertex_count, has_uv, uvs, raw in surfaces:
			built.append((vertex_count, has_uv, uvs, [frame_bytes(raw, vertex_count, 0)]))
		held_parts.append((name, built))
	held_joints = []
	for name, bind, raw in joints:
		held_joints.append((name, bind, [joint_frame(raw, 0)]))
	write_clip(os.path.join(ROOT, stem + ".salute"), magic, held_parts, held_joints)


def main():
	torsos = ["torso_ss", "torso_sd", "torso_ms", "torso_md", "torso_ls", "torso_ld"]
	legs = ["legs_s", "legs_m", "legs_l"]
	for stem in torsos:
		torso_salute(stem)
		print("wrote", stem + ".salute")
	for stem in legs:
		legs_salute(stem)
		print("wrote", stem + ".salute")


if __name__ == "__main__":
	main()
