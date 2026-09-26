shader_type canvas_item;
// Final look for the room (not the HUD): a soft bloom where things are
// bright, shadows lifted toward a deep plum instead of near-black, warm
// cream highlights, a touch less saturation and a fine moving film grain.
// Dreamy and warm, while the ball's gold and the danger coral still read.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int taps = 12;            // bloom samples (0 turns it off)
uniform float bloom = 0.32;
uniform float radius = 9.0;       // px, at the 720-wide design size
uniform float scale = 1.0;        // screen px per design px
uniform vec3 shadow_tint = vec3(0.10, 0.065, 0.13);
uniform vec3 highlight_tint = vec3(1.05, 0.99, 0.9);
uniform float saturation = 0.92;
uniform float grain = 0.010;
uniform float time = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (taps > 0) {
		// Bloom: a ring of taps at two radii, only what is bright passes.
		vec3 b = vec3(0.0);
		for (int i = 0; i < taps; i++) {
			float a = float(i) * 2.39996;
			float r = radius * scale * (i % 2 == 0 ? 1.0 : 2.1);
			vec3 s = texture(screen, SCREEN_UV + vec2(cos(a), sin(a)) * r * SCREEN_PIXEL_SIZE).rgb;
			b += max(s - vec3(0.42), vec3(0.0));
		}
		c += b / float(taps) * bloom * vec3(1.0, 0.93, 0.84);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Shadows lifted toward plum; highlights warmed toward cream.
	c += shadow_tint * (1.0 - smoothstep(0.0, 0.32, l)) * 0.4;
	c *= mix(vec3(1.0), highlight_tint, smoothstep(0.3, 0.9, l));
	float l2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l2), c, saturation);
	c += (hash(FRAGCOORD.xy + fract(time * 7.13) * 91.7) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
