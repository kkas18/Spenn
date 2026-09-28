shader_type canvas_item;
// Screen-space shock rings: each one bends the picture outward in a thin,
// expanding band (a refraction, not a glow) and fades as it grows. Up to
// four at once; unused slots have strength 0 and cost almost nothing.
// `chroma` splits red and blue apart toward the edges for a moment on the
// biggest impacts (a lens caught off guard).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 waves[4];        // xy: centre (px), z: radius (px), w: strength
uniform vec2 size = vec2(720.0, 1280.0);
uniform float width = 26.0;
uniform float chroma = 0.0;   // px of red/blue split at the screen edge

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
	vec2 uv = SCREEN_UV - off / size;
	if (chroma > 0.01) {
		vec2 ca = (SCREEN_UV - 0.5) * 2.0 * chroma / size;
		COLOR = vec4(texture(screen, uv + ca).r, texture(screen, uv).g, texture(screen, uv - ca).b, 1.0);
	} else {
		COLOR = texture(screen, uv);
	}
}
