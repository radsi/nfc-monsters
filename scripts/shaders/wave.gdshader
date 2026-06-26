shader_type canvas_item;

uniform float amplitude = 10.0;
uniform float frequency = 5.0;
uniform float speed = 2.0;

uniform float min_height = 0.0;
uniform float height_range = 1.0;

uniform float min_width = 0.0;
uniform float width_range = 1.0;

uniform bool vertical = true;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;

    float height_mask = smoothstep(min_height, min_height + height_range, uv.y);
    float width_mask = smoothstep(min_width, min_width + width_range, uv.x);
    float mask = height_mask * width_mask;

    float wave;
    
    if (vertical) {
        wave = sin((uv.x * frequency) + TIME * speed) * amplitude * mask;
        uv.y += wave / TEXTURE_PIXEL_SIZE.y;
    } else {
        wave = sin((uv.y * frequency) + TIME * speed) * amplitude * mask;
        uv.x += wave / TEXTURE_PIXEL_SIZE.x;
    }

    vec4 tex = texture(TEXTURE, uv);
    COLOR = tex * tint;
}