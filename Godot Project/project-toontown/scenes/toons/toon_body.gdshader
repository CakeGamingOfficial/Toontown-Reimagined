shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// Soft key light, the way the original client lit a toon: a sun from the
// upper front, with enough fill that the shadow side stays colored.
// Clothes pass a shell push so the body underneath cannot show through.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float shell = 0.0;
// View space: left, up, and toward the camera. A world light lit the
// Create a Toon face from the side because that camera is not on +Z.
uniform vec3 light_direction = vec3(-0.45, 0.75, 0.5);
uniform float ambient = 0.42;
uniform float key_light = 0.58;
uniform float wrap = 0.28;
// Nose only. Fur and the muzzle stay matte; the original nose carries a highlight.
uniform float gloss = 0.0;

void vertex() {
	VERTEX += NORMAL * shell;
}

void fragment() {
	vec3 color = albedo_color.rgb;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV).rgb;
	}
	color *= COLOR.rgb;
	vec3 normal_view = normalize(NORMAL);
	vec3 light_view = normalize(light_direction);
	float wrapped = clamp((dot(normal_view, light_view) + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 lit = color * (ambient + key_light * wrapped);
	if (gloss > 0.0) {
		vec3 half_dir = normalize(light_view + normalize(-VERTEX));
		float spec = pow(clamp(dot(normal_view, half_dir), 0.0, 1.0), 40.0);
		lit += vec3(spec * gloss);
	}
	ALBEDO = lit;
}
