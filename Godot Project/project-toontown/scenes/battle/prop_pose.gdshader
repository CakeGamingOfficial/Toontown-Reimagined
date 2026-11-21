shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// A gag prop's own texture and color. CUSTOM0 is the next frame's position
// and TANGENT is its normal, so the prop moves at the display rate.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float alpha_scissor = 0.0;
uniform float pose_blend = 0.0;

void vertex() {
	if (pose_blend > 0.001) {
		VERTEX = mix(VERTEX, CUSTOM0.xyz, pose_blend);
		NORMAL = normalize(mix(NORMAL, TANGENT.xyz, pose_blend));
	}
}

void fragment() {
	vec4 sampled = albedo_color;
	if (use_albedo_texture > 0.5) {
		sampled *= texture(albedo_texture, UV);
	}
	if (alpha_scissor > 0.0 && sampled.a < alpha_scissor) {
		discard;
	}
	ALBEDO = sampled.rgb;
}
