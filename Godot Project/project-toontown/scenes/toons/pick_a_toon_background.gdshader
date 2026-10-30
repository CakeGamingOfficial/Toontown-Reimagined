shader_type canvas_item;

// The painted card is 4:3. On a wider window the sides are not a flat fill:
// they continue the field just inside the card's rim, which is what sits
// past the squares in the original screenshot.
uniform sampler2D background_texture : source_color, filter_linear, repeat_disable;
// Card rectangle in screen UV: position xy, size zw.
uniform vec4 card = vec4(0.1, 0.0, 0.8, 1.0);

void fragment() {
	vec2 local = (UV - card.xy) / card.zw;
	float x = local.x;
	float y = clamp(local.y, 0.0, 1.0);
	// Pixels 0-8 and 506-511 are the card's dark rim. Past the squares, and
	// anywhere the window is wider than the card, sample the field inside it.
	if (x < 0.016) {
		x = 0.02;
	} else if (x > 0.988) {
		x = 0.984;
	}
	COLOR = texture(background_texture, vec2(x, y));
}
