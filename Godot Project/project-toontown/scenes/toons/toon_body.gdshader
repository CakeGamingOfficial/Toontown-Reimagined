shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// Soft key light, the way the original client lit a toon: a sun from the
// upper front, with enough fill that the shadow side stays colored.
// Clothes pass a shell push so the body underneath cannot show through.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float shell = 0.0;
// Upper left of a toon facing the camera, so a straight-on head still
// shows the roundness the original chooser and Make a Toon screens have.
uniform vec3 light_direction = vec3(-0.55, 0.72, 0.28);
uniform float ambient = 0.42;
uniform float key_light = 0.58;
uniform float wrap = 0.28;

void vertex() {
	VERTEX += NORMAL * shell;
}

void fragment() {
	vec3 color = albedo_color.rgb;
	if (use_albedo_texture > 0.5) {
		color *= texture(albedo_texture, UV).rgb;
	}
	color *= COLOR.rgb;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float wrapped = clamp((dot(world_normal, normalize(light_direction)) + wrap) / (1.0 + wrap), 0.0, 1.0);
	ALBEDO = color * (ambient + key_light * wrapped);
}
