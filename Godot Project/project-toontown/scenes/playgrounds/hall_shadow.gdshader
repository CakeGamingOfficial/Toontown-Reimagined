shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, specular_disabled, ambient_light_disabled;

// The facade shadow sits just off the wall. Nudge it forward, but less than
// the windows and door, and do not write depth so those cards stay on top.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 1.0;
uniform float depth_units = 0.1;

vec3 _linear(vec3 color) {
	// The importer flags these vertex colors as sRGB. StandardMaterial decodes
	// them; a ShaderMaterial has to do the same or the shadow turns pale.
	vec3 result = color;
	result.r = color.r <= 0.04045 ? color.r / 12.92 : pow((color.r + 0.055) / 1.055, 2.4);
	result.g = color.g <= 0.04045 ? color.g / 12.92 : pow((color.g + 0.055) / 1.055, 2.4);
	result.b = color.b <= 0.04045 ? color.b / 12.92 : pow((color.b + 0.055) / 1.055, 2.4);
	return result;
}

void vertex() {
	VERTEX += NORMAL * depth_units;
}

void fragment() {
	vec4 tint = COLOR;
	tint.rgb = _linear(tint.rgb);
	vec4 color = albedo_color * tint;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
