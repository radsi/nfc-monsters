shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float start_angle : hint_range(0.0, 360.0) = 283.5;

void fragment() {
    vec2 uv = UV - vec2(0.5);

    float angle = atan(uv.y, uv.x);
    angle = mod(-angle + PI * 0.5 + TAU, TAU);

    float start = radians(start_angle);
    angle = mod(angle - start + TAU, TAU);

    float limit = progress * TAU;

    if (angle > limit) {
        discard;
    }

    COLOR = texture(TEXTURE, UV);
}