shader_type spatial;
render_mode unshaded, depth_draw_always, shadows_disabled, specular_disabled;

// CogHood draws the cog sky in the background bin. Godot 4 is reverse-Z,
// so a value near 0 is the far plane: the courtyard wins wherever it exists,
// and the hills stay visible only past it.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	float alpha = tex.a * albedo_color.a;
	if (alpha_scissor > 0.0 && alpha < alpha_scissor) {
		discard;
	}
	ALPHA = 1.0;
	DEPTH = 0.0001;
}
