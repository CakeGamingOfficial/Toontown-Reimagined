shader_type spatial;
render_mode unshaded, specular_disabled, ambient_light_disabled;

// The window and door cards have no vertex colors. Multiplying COLOR drops
// their alpha to zero and the cutout throws the whole card away. A fragment
// depth write also hides them on the compatibility renderer, so the card is
// nudged along its normal instead. The extra fraction of a foot stays in
// front of the wall from across the playground.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 1.0;
uniform float scissor_threshold = 0.5;
uniform float depth_units = 0.28;

void vertex() {
	VERTEX += NORMAL * depth_units;
}

void fragment() {
	vec4 color = albedo_color;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV);
	}
	if (color.a < scissor_threshold) {
		discard;
	}
	ALBEDO = color.rgb;
}
