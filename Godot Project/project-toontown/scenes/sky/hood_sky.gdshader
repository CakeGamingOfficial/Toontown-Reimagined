shader_type sky;

// A hood sky painted on panels in the original game. crop picks the part of
// the texture the panels actually used. The zenith is a separate cap so the
// wrap does not pinch into rays.
uniform sampler2D sky_tex : source_color, repeat_enable, filter_linear;
uniform sampler2D zenith_tex : source_color, repeat_enable, filter_linear;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
uniform float repeats = 6.0;
uniform int zenith_mode = 0;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = dir.y;
	float horiz = length(dir.xz);
	vec3 top;
	if (zenith_mode == 1) {
		top = texture(zenith_tex, dir.xz * 1.6 + vec2(0.5)).rgb;
	} else {
		top = texture(zenith_tex, vec2(crop.x + crop.z * 0.5, crop.y + 0.02)).rgb;
	}
	vec3 color = top;
	if (horiz > 0.2) {
		float around = atan(dir.z, dir.x) / TAU;
		float down = clamp(1.0 - height, 0.0, 1.0);
		float u = crop.x + fract(around * repeats) * crop.z;
		float v = crop.y + down * crop.w;
		vec3 band = texture(sky_tex, vec2(u, v)).rgb;
		float cover = smoothstep(0.2, 0.55, horiz);
		color = mix(top, band, cover);
	}
	COLOR = color;
}
