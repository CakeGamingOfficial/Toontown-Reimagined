shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// Face cards sit on the head shell. A tiny push along the normal keeps the
// muzzle, nose, and eyes from z-fighting, and alpha scissor drops the empty
// part of an eye card without sending it through the transparent pass.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float scissor_threshold = 0.0;
uniform float surface_push = 0.0;

void vertex() {
	VERTEX += NORMAL * surface_push;
}

void fragment() {
	vec4 color = albedo_color;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV);
	}
	ALBEDO = color.rgb;
	if (scissor_threshold > 0.0) {
		ALPHA = color.a;
		ALPHA_SCISSOR_THRESHOLD = scissor_threshold;
	}
}
