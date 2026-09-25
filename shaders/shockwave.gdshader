shader_type canvas_item;
// Screen-space shock rings: each one bends the picture outward in a thin,
// expanding band (a refraction, not a glow) and fades as it grows. Up to
// four at once; unused slots have strength 0 and cost almost nothing.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 waves[4];        // xy: centre (px), z: radius (px), w: strength
uniform vec2 size = vec2(720.0, 1280.0);
uniform float width = 26.0;

void fragment() {
	vec2 px = SCREEN_UV * size;
	vec2 off = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) continue;
		vec2 d = px - w.xy;
		float r = length(d);
		float band = 1.0 - smoothstep(0.0, width, abs(r - w.z));
		off += normalize(d + 0.0001) * band * w.w;
	}
	COLOR = texture(screen, SCREEN_UV - off / size);
}
