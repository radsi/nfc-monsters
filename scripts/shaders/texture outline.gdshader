shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;

	float outline = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) {
				continue;
			}

			outline = max(
				outline,
				texture(TEXTURE, UV + vec2(float(x), float(y)) * pixel).a
			);
		}
	}

	if (tex.a < 0.01 && outline > 0.01) {
		COLOR = outline_color;
	} else {
		COLOR = tex;
	}
}