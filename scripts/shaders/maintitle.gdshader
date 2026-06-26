shader_type canvas_item;

uniform highp float spin_rotation_speed = -2.0;
uniform highp float move_speed = 5.0;
uniform highp vec2 offset = vec2(0., 0.);
uniform highp vec4 colour_1 : source_color = vec4(1, 1, 1, 1.0);
uniform highp vec4 colour_2 : source_color = vec4(0.9, 0.15, 0.5, 1.0);
uniform highp vec4 colour_3 : source_color = vec4(0.086, 0.137, 0.145, 1.0);
uniform highp float contrast = 6.5;
uniform highp float lighting = 0.22;
uniform highp float spin_amount = 0.1;
uniform highp float pixel_filter = 740.;
uniform bool is_rotating = false;

#define SPIN_EASE 1.0

vec4 effect(vec2 uv, vec2 screenSize){

    highp float pixel_size = length(screenSize.xy) / pixel_filter;

    uv = (floor(uv * (1.0/pixel_size)) * pixel_size);

    highp float uv_len = length(uv);

    highp float speed = spin_rotation_speed * 0.2;

    if(is_rotating){
        speed = TIME * speed;
    }

    speed += 302.2;

    highp float angle = atan(uv.y, uv.x) + speed;

    highp vec2 mid = vec2(0.5);

    uv = vec2(
        uv_len * cos(angle) + mid.x,
        uv_len * sin(angle) + mid.y
    ) - mid;

    uv *= 30.0;

    speed = TIME * move_speed;

    highp vec2 uv2 = vec2(uv.x + uv.y);

    for(int i=0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv += 0.5 * vec2(
            cos(uv2.y + speed),
            sin(uv2.x - speed)
        );
    }

 highp float c = sin(length(uv) + TIME) * 0.5 + 0.5;
	return vec4(c, c, c, 1.0);

    return vec4(c, c, c, 1.0);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    vec4 fx = effect(UV, TEXTURE_PIXEL_SIZE);

    vec3 palette =
    colour_1.rgb * fx.r +
    colour_2.rgb * fx.g +
    colour_3.rgb * fx.b;

	COLOR.rgb = fx.rgb * palette;
	COLOR.a = tex.a;
}