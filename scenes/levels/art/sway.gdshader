shader_type canvas_item;
// Foliage sway with a phase hashed from the instance origin, so every prop sways differently.
// pivot_mode 0 bends a side-view sprite from its base; pivot_mode 1 turns a centred top-down crown around its centre.

uniform float amplitude = 5.0;
uniform float speed = 1.6;
uniform float base_y = 1.0;
uniform int pivot_mode = 0;
uniform float turn_deg = 3.0;

// sway-hash-begin (mirrored by scripts/levels/sway_phase.gd)
const vec2 HASH_DOT = vec2(127.1, 311.7);
const float HASH_SCALE = 43758.5453;
const int PIVOT_BASE = 0;
const int PIVOT_CENTRE = 1;
// sway-hash-end

float origin_hash(vec2 p) {
	return fract(sin(dot(p, HASH_DOT)) * HASH_SCALE);
}

void vertex() {
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = origin_hash(floor(origin)) * 6.2831853;
	float wave = sin(TIME * speed + phase);
	if (pivot_mode == PIVOT_CENTRE) {
		float a = radians(turn_deg) * wave;
		VERTEX = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX;
		VERTEX.x += wave * amplitude * 0.5;
	} else {
		float bend = pow(clamp(base_y - UV.y, 0.0, 1.0), 1.5);
		VERTEX.x += wave * amplitude * bend;
	}
}
