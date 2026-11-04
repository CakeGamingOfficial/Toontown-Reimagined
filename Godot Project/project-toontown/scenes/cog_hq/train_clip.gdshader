shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float clip_x = -313.3;
uniform bool use_tex = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The train tunnels open on this plane. Anything past the mouth is inside
	// the tunnel and is not drawn.
	if (world_pos.x < clip_x) {
		discard;
	}
	vec4 tex = vec4(1.0);
	if (use_tex) {
		tex = texture(albedo_tex, UV);
	}
	ALBEDO = tex.rgb * albedo_color.rgb;
	if (tex.a * albedo_color.a < 0.5) {
		discard;
	}
}
