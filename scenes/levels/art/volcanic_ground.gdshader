shader_type canvas_item;
// Volcanic ground for the tile layers of Volcano Cliffs: warm sand pixels become a textured basalt ramp, green grass
// pixels become scorched ash and the remaining stone pixels a warm grey; alpha stays, so tile shapes stay seamless.

uniform vec4 rock_low : source_color = vec4(0.18, 0.14, 0.13, 1.0);
uniform vec4 rock_high : source_color = vec4(0.48, 0.39, 0.33, 1.0);
uniform vec4 ash_tint : source_color = vec4(0.42, 0.42, 0.29, 1.0);
uniform vec4 stone_tint : source_color = vec4(0.82, 0.72, 0.65, 1.0);
uniform sampler2D detail_tex : repeat_enable, filter_linear;
uniform float detail_world_px = 256.0;
uniform float detail_strength = 0.9;
uniform float luma_gain = 3.0;
uniform float sand_luma_mean = 0.913;

// volcanic-ground-begin (mirrored by scripts/levels/volcanic_ground.gd)
const float GREEN_MIN = 0.04;
const float GREEN_FULL = 0.12;
const float WARM_MIN = 0.06;
const float WARM_FULL = 0.12;
const float LUMA_MIN = 0.45;
const float LUMA_FULL = 0.6;
const float ASH_BASE = 0.7;
const float ASH_SPREAD = 0.7;
const float GRASS_LUMA = 0.64;
// volcanic-ground-end

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	float wg = smoothstep(GREEN_MIN, GREEN_FULL, c.g - max(c.r, c.b));
	float ws = smoothstep(WARM_MIN, WARM_FULL, c.r - c.b) * smoothstep(LUMA_MIN, LUMA_FULL, luma) * (1.0 - wg);
	float wst = (1.0 - ws) * (1.0 - wg);
	float d = texture(detail_tex, world / detail_world_px).r - 0.5;
	float t = clamp(0.5 + (luma - sand_luma_mean) * luma_gain + d * detail_strength, 0.0, 1.0);
	vec3 rock = mix(rock_low.rgb, rock_high.rgb, t);
	float tg = clamp(0.5 + (luma - GRASS_LUMA) * luma_gain + d * detail_strength, 0.0, 1.0);
	vec3 ash = ash_tint.rgb * (ASH_BASE + ASH_SPREAD * tg);
	vec3 stone = stone_tint.rgb * luma;
	vec3 rgb = mix(c.rgb, rock, ws);
	rgb = mix(rgb, ash, wg);
	rgb = mix(rgb, stone, wst);
	COLOR = vec4(rgb, c.a);
}
