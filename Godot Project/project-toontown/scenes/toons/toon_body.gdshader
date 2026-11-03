shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, ambient_light_disabled;

// Clothes pass a shell push so the body underneath cannot show through.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_texture = 0.0;
uniform float shell = 0.0;
// Display brightness. The face stays at full color. The back is only a little dimmer.
uniform float front_light = 1.0;
uniform float back_light = 0.82;
// How far a glove palm drops. White gloves read as a light gray on the inside.
uniform float palm_shadow = 0.75;
// The skull's smoothed normals point the other way from the body. -1 flips it back.
uniform float face_sign = 1.0;
// Nose only. Fur and the muzzle stay matte; the original nose carries a highlight.
uniform float gloss = 0.0;
// Hands only. The palm faces the body, and that side is pulled toward gray.
uniform float glove = 0.0;
// TeleportOut clips the body on a plane at the toon's feet. The mesh is still
// in Panda's Z-up space; the actor basis has already turned that into world Y.
uniform float hole_clip = 0.0;
uniform float hole_floor = 0.0;
varying vec3 hole_world;
// Mesh space is still Panda's: +Y is the face, +X is the toon's right.
varying vec3 model_normal;
varying float model_x;

void vertex() {
	model_normal = NORMAL;
	model_x = VERTEX.x;
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
	vec3 n = normalize(model_normal);
	float facing = clamp(n.y * face_sign * 0.5 + 0.5, 0.0, 1.0);
	float shade = mix(back_light, front_light, facing);
	if (glove > 0.5) {
		float inward = clamp(-sign(model_x) * n.x, 0.0, 1.0);
		shade *= mix(1.0, palm_shadow, smoothstep(0.25, 0.85, inward));
	}
	vec3 perceptual = pow(max(color, vec3(0.0)), vec3(0.454545));
	perceptual *= shade;
	vec3 lit = pow(max(perceptual, vec3(0.0)), vec3(2.2));
	if (gloss > 0.0) {
		vec3 light_view = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * vec3(0.0, 1.0, 0.0));
		vec3 half_dir = normalize(light_view + normalize(-VERTEX));
		float spec = pow(clamp(dot(normalize(NORMAL), half_dir), 0.0, 1.0), 40.0);
		lit += vec3(spec * gloss);
	}
	ALBEDO = lit;
}
