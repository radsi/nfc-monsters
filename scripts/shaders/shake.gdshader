shader_type canvas_item;

uniform float strength = 5.0;
uniform float speed = 20.0;

void fragment() {
    vec2 uv = UV;

    float shake_x = sin(TIME * speed + uv.y * 30.0) * strength / 1000.0;
    float shake_y = cos(TIME * speed + uv.x * 30.0) * strength / 1000.0;

    uv += vec2(shake_x, shake_y);

    vec4 tex = texture(TEXTURE, uv);

    COLOR = tex * COLOR;
}