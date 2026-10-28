shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	// middayskyB repeats along U and clamps along V. The cap's V sits outside
	// 0..1, and Godot's sampler repeats both axes, so the horizon gradient
	// tiles into rectangular patches overhead.
	uv.y = clamp(uv.y, 0.0, 1.0);
	ALBEDO = texture(albedo_tex, uv).rgb * COLOR.rgb * albedo_color.rgb;
}
