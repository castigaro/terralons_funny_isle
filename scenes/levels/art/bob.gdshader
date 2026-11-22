shader_type canvas_item;
// Boat bob: the sprite rises and sinks by amplitude pixels and rocks by tilt_deg around pivot_y, phase hashed from the origin.

uniform float amplitude = 3.0;
uniform float speed = 0.9;
uniform float tilt_deg = 1.5;
uniform float pivot_y = 0.0;

const vec2 HASH_DOT = vec2(127.1, 311.7);
const float HASH_SCALE = 43758.5453;

void vertex() {
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = fract(sin(dot(floor(origin), HASH_DOT)) * HASH_SCALE) * 6.2831853;
	float wave = sin(TIME * speed + phase);
	float a = radians(tilt_deg) * wave;
	vec2 p = VERTEX - vec2(0.0, pivot_y);
	VERTEX = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p + vec2(0.0, pivot_y);
	VERTEX.y += wave * amplitude;
}
