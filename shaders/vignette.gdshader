shader_type canvas_item;
// Soft vignette with triangular-noise dithering: noise of about half an
// output LSB (relative to the dark background) removes banding in corners.

uniform float strength = 0.55;
uniform float inner = 0.42;
uniform float outer = 0.95;
uniform float dither_amp = 0.045;
uniform vec3 tint = vec3(0.0);   // overload: a warm rim light at the edges
uniform float glow = 0.0;

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.0, 1.25);
	float d = length(uv) * 1.414;
	float v = smoothstep(inner, outer, d) * strength;
	float n = ign(FRAGCOORD.xy) + ign(FRAGCOORD.xy + vec2(47.0, 17.0)) - 1.0;
	float rim = smoothstep(0.62, 1.12, d) * glow;
	float a = max(v, rim);
	vec3 c = tint * (rim / max(v + rim, 1e-4));
	COLOR = vec4(c, clamp(a + n * dither_amp * step(0.001, a), 0.0, 1.0));
}
