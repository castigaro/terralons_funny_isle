shader_type canvas_item;
// Water: samples a repeating standalone texture in world space with TIME distortion and moving highlight bands.

uniform vec4 water_tint : source_color = vec4(1.0);
uniform vec4 highlight : source_color = vec4(1.0, 1.0, 1.0, 0.2);
uniform float wave_amp = 5.0;
uniform float wave_freq = 0.02;
uniform float wave_speed = 1.4;
uniform float band_speed = 1.1;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos;
	p.x += sin(world_pos.y * wave_freq + TIME * wave_speed) * wave_amp;
	p.y += cos(world_pos.x * wave_freq + TIME * wave_speed * 0.8) * wave_amp;
	vec4 c = texture(TEXTURE, p * TEXTURE_PIXEL_SIZE);
	vec3 rgb = mix(c.rgb, water_tint.rgb, 0.35);
	float band = smoothstep(0.93, 1.0, sin(world_pos.x * 0.015 + world_pos.y * 0.01 - TIME * band_speed));
	rgb = mix(rgb, highlight.rgb, band * highlight.a * 3.0);
	COLOR = vec4(rgb, 1.0);
}
