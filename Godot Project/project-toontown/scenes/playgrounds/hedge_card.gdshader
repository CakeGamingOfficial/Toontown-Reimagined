shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// The leaf card repeats along its length. Only the vertical edge is clamped:
// those vertices sit a hair outside 0..1, and repeat wraps a hard strip from
// the other end of the map onto the top of every hedge.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);

void fragment() {
	if (UV.y < 0.0 || UV.y > 1.0) {
		discard;
	}
	vec4 tex = texture(albedo_texture, vec2(UV.x, clamp(UV.y, 0.0, 1.0)));
	// Opaque leaves write depth, so the back of the same hedge cannot show
	// through the front. The holes in the leaf map stay open.
	if (tex.a < 0.5) {
		discard;
	}
	ALBEDO = tex.rgb * albedo_color.rgb * COLOR.rgb;
}
