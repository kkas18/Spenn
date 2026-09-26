shader_type canvas_item;
// Pause / game-over scrim: the live game stays visible underneath, but
// blurred (5x5 weighted taps), desaturated and dimmed. Driven by `amount`.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float blur = 0.0;
uniform float dim = 0.62;
uniform float desat = 0.55;

void fragment() {
	vec3 c = vec3(0.0);
	if (blur > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE * blur;
		float w = 0.0;
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				float k = 1.0 / (1.0 + float(x * x + y * y));
				c += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * k;
				w += k;
			}
		}
		c /= w;
	} else {
		c = texture(screen_tex, SCREEN_UV).rgb;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desat * amount);
	c *= 1.0 - dim * amount;
	COLOR = vec4(c, 1.0);
}
