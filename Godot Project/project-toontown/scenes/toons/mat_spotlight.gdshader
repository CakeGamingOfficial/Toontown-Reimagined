shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, ambient_light_disabled;

// A soft column, bright through the middle and gone at the edges, so the
// beam reads on the wall behind the toon without fogging the whole room.
void fragment() {
	vec2 q = (UV - vec2(0.35, 0.35)) / vec2(0.16, 0.28);
	float beam = clamp(1.0 - dot(q, q), 0.0, 1.0);
	ALBEDO = vec3(1.0);
	ALPHA = beam * beam * 0.16;
}
