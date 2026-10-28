shader_type sky;

uniform sampler2D gradient_tex : source_color, repeat_disable, filter_linear;
uniform sampler2D cloud_tex : source_color, repeat_enable, filter_linear;
uniform float cloud_scroll = 0.0;

// Lod 0 on purpose. The longitude wraps once around the sky, and a mipmap
// sample at that wrap turns into the vertical seam.
vec4 sample_cloud(float u, float v) {
	return textureLod(cloud_tex, vec2(u, v), 0.0);
}

vec4 cloud_tile(float u, float v) {
	vec4 primary = sample_cloud(u, v);
	vec4 offset = sample_cloud(u + 0.5, v);
	float edge = abs(fract(u) - 0.5) * 2.0;
	float blend = smoothstep(0.35, 0.95, edge);
	float primary_weight = (1.0 - blend) * primary.a;
	float offset_weight = blend * offset.a;
	float alpha = primary_weight + offset_weight;
	vec3 rgb = (primary.rgb * primary_weight + offset.rgb * offset_weight) / max(alpha, 0.0001);
	return vec4(rgb, alpha);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = dir.y;
	float lift = pow(clamp(height, 0.0, 1.0), 0.65);
	vec3 color = texture(gradient_tex, vec2(0.5, 1.0 - lift)).rgb;
	// The source gradient is a pale sky blue. Pull red and green down so the
	// same horizon-to-zenith fade reads as a deeper blue.
	color = mix(color, vec3(color.r * 0.62, color.g * 0.82, min(color.b * 1.06 + 0.03, 1.0)), 0.7);

	// The sheet pinches into rays well before straight up, so that cap stays gradient.
	float horiz = length(dir.xz);
	if (horiz > 0.7) {
		float around = atan(dir.z, dir.x) / TAU;
		float turns = cloud_scroll / 360.0;
		float down = clamp(1.0 - height, 0.04, 0.96);
		// 3 and 2 copies around the sky, down from 4 and 3.
		vec4 first = cloud_tile(around * 3.0 + turns, down);
		vec4 second = cloud_tile(around * 2.0 - turns * 0.8 + 0.37, clamp(down * 0.9 + 0.05, 0.04, 0.96));
		float cover = smoothstep(0.7, 0.92, horiz) * smoothstep(-0.02, 0.06, height);
		color = mix(color, first.rgb, first.a * cover);
		color = mix(color, second.rgb, second.a * cover);
	}
	COLOR = color;
}
