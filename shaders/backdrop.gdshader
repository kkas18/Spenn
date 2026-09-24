shader_type canvas_item;
// Matte backdrop: a soft light falloff from the upper left (the scene's one
// light), fine static grain, and triangular dithering so the gradient never
// bands on 8-bit panels. No glow: the lift is a few levels at most.

uniform vec4 base : source_color = vec4(0.055, 0.063, 0.082, 1.0);
uniform vec4 lift : source_color = vec4(0.092, 0.102, 0.126, 1.0);
uniform vec2 light_pos = vec2(0.12, 0.02);
uniform float reach = 1.05;
uniform float grain = 0.010;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 uv = UV * vec2(1.0, 1.6);
	float d = distance(uv, light_pos * vec2(1.0, 1.6)) / reach;
	float light = 1.0 - smoothstep(0.0, 1.0, d);
	vec3 col = mix(base.rgb, lift.rgb, light * light);
	// Static grain: fixed per pixel, so the surface reads as matte material.
	col += (hash(floor(FRAGCOORD.xy)) - 0.5) * grain;
	// Triangular dither, ±1 LSB.
	float n = ign(FRAGCOORD.xy) + ign(FRAGCOORD.xy + vec2(31.0, 11.0)) - 1.0;
	col += n / 255.0;
	COLOR = vec4(col, 1.0);
}
