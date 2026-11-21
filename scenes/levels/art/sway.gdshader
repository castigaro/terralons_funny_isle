shader_type canvas_item;
// Sway bent from the sprite base; the phase is a hash of the instance origin, so every prop sways differently.

uniform float amplitude = 5.0;
uniform float speed = 1.6;
uniform float base_y = 1.0;

// sway-hash-begin (mirrored by scripts/levels/sway_phase.gd)
const vec2 HASH_DOT = vec2(127.1, 311.7);
const float HASH_SCALE = 43758.5453;
// sway-hash-end

float origin_hash(vec2 p) {
	return fract(sin(dot(p, HASH_DOT)) * HASH_SCALE);
}

void vertex() {
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = origin_hash(floor(origin)) * 6.2831853;
	float bend = pow(clamp(base_y - UV.y, 0.0, 1.0), 1.5);
	VERTEX.x += sin(TIME * speed + phase) * amplitude * bend;
}
