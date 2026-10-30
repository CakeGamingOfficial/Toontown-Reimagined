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
uniform float hole_clip = 0.0;
uniform float hole_floor = 0.0;
// Same overhead light as the body, so the muzzle is not a flat card on a shaded head.
uniform vec3 light_direction = vec3(-0.1, 1.0, 0.5);
uniform float ambient = 0.72;
uniform float key_light = 0.28;
uniform float wrap = 0.8;
varying vec3 hole_world;

void vertex() {
	VERTEX += NORMAL * surface_push;
	hole_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (hole_clip > 0.5 && hole_world.y < hole_floor) {
		discard;
	}
	vec4 color = albedo_color;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV);
	}
	vec3 normal_view = normalize(NORMAL);
	vec3 light_view = normalize(light_direction);
	float wrapped = clamp((dot(normal_view, light_view) + wrap) / (1.0 + wrap), 0.0, 1.0);
	ALBEDO = color.rgb * (ambient + key_light * wrapped);
	if (scissor_threshold > 0.0) {
		ALPHA = color.a;
		ALPHA_SCISSOR_THRESHOLD = scissor_threshold;
	}
}
