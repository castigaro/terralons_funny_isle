shader_type canvas_item;
// Tints only the green (grass) pixels of a ground layer, so the sand baked into grass edge tiles stays unchanged
// and edge tiles stay seamless against the plain sand layer.

uniform vec4 grass_tint : source_color = vec4(1.0);

// grass-tint-begin (mirrored by scripts/levels/grass_tint.gd)
const float GREEN_MIN = 0.04;
const float GREEN_FULL = 0.12;
// grass-tint-end

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float w = smoothstep(GREEN_MIN, GREEN_FULL, c.g - max(c.r, c.b));
	COLOR = vec4(mix(c.rgb, c.rgb * grass_tint.rgb, w * grass_tint.a), c.a);
}
