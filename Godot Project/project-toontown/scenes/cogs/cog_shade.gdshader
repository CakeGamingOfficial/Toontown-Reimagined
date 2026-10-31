shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float use_vertex_color = 0.0;
// Glasses and the medallion. 0 keeps the whole surface.
uniform float cutout = 0.0;
// View space, from the upper right, so a white head gets the same falloff
// the original suit has instead of sitting fullbright under the street lights.
uniform vec3 light_direction = vec3(0.45, 0.8, 0.35);
uniform float ambient = 0.58;
uniform float key_light = 0.48;
uniform float wrap = 0.6;

void fragment() {
	vec4 sampled = vec4(1.0);
	if (use_albedo_texture > 0.5) {
		sampled = texture(albedo_texture, UV);
	}
	if (cutout > 0.0 && sampled.a < cutout) {
		discard;
	}
	// Fly in and out stay in the opaque pass. A real alpha blend was the frame drop.
	if (albedo_color.a < 0.99) {
		float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (dither > albedo_color.a) {
			discard;
		}
	}
	vec3 tint = albedo_color.rgb;
	if (use_vertex_color > 0.5) {
		tint *= COLOR.rgb;
	}
	vec3 color = tint * sampled.rgb;
	vec3 normal_view = normalize(NORMAL);
	vec3 light_view = normalize(light_direction);
	float wrapped = clamp((dot(normal_view, light_view) + wrap) / (1.0 + wrap), 0.0, 1.0);
	ALBEDO = color * (ambient + key_light * wrapped);
}
