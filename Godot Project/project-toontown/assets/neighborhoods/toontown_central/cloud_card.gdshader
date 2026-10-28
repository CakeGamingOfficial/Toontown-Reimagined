shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// The cloud sheet is clamped in the original. Repeating it pulls the opposite
// edge into the seam and leaves bright specks.
uniform sampler2D albedo_tex : source_color, repeat_disable, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * COLOR.rgb * albedo_color.rgb;
	ALPHA = tex.a * COLOR.a * albedo_color.a;
}
