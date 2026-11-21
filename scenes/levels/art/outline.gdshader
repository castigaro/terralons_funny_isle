shader_type canvas_item;
// Alpha-dilation outline for sprites without a drawn outline; the quad grows by outline_px so it is never clipped.

uniform vec4 outline_color : source_color = vec4(0.23, 0.17, 0.13, 1.0);
uniform float outline_px = 3.0;

void vertex() {
	vec2 grow = (UV * 2.0 - 1.0) * outline_px;
	VERTEX += grow;
	UV += grow * TEXTURE_PIXEL_SIZE;
}

float inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.a *= inside(UV);
	vec2 o = TEXTURE_PIXEL_SIZE * outline_px;
	vec2 d = o * 0.707;
	vec2 taps[8] = vec2[8](vec2(o.x, 0.0), vec2(-o.x, 0.0), vec2(0.0, o.y), vec2(0.0, -o.y),
			d, -d, vec2(d.x, -d.y), vec2(-d.x, d.y));
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 uv = UV + taps[i];
		a = max(a, texture(TEXTURE, uv).a * inside(uv));
	}
	COLOR = mix(vec4(outline_color.rgb, a * outline_color.a), c, c.a);
}
