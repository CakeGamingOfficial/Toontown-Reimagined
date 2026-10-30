shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// Same fill as toon_body.gdshader, drawn in the transparent pass so the local
// player can see through their own ghost. Other cameras never get this mesh.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float shell = 0.0;
uniform vec3 light_direction = vec3(0.1, 0.35, 1.0);
uniform float ambient = 0.82;
uniform float key_light = 0.18;
uniform float wrap = 0.8;
uniform float gloss = 0.0;
uniform float hole_clip = 0.0;
uniform float hole_floor = 0.0;
uniform float ghost_alpha = 0.4;
varying vec3 hole_world;

void vertex() {
	VERTEX += NORMAL * shell;
	hole_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (hole_clip > 0.5 && hole_world.y < hole_floor) {
		discard;
	}
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
	ALPHA = ghost_alpha;
}
