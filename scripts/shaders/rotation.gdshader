shader_type canvas_item;

uniform float rotation_speed = 2.0;

void fragment() {
    vec2 uv = UV - vec2(0.5);

    float angle = TIME * rotation_speed;

    mat2 rot = mat2(
        vec2(cos(angle), sin(angle)),
        vec2(-sin(angle), cos(angle))
    );

    uv = rot * uv;
    uv += vec2(0.5);

    vec4 tex = texture(TEXTURE, uv);

    COLOR = tex * COLOR;
}