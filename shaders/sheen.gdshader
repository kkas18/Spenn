shader_type canvas_item;
// A band of light gliding diagonally across the title letters. Only bright
// pixels catch it, so shadows and dark edges stay as they are.

uniform float sweep = -9999.0;   // x of the band's centre at y = 0 (world px)
uniform float width = 70.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float d = (world.x + world.y * 0.45) - sweep;
	float band = exp(-d * d / (width * width)) + 0.5 * exp(-(d + 60.0) * (d + 60.0) / 300.0);
	c.rgb += vec3(1.0, 0.96, 0.88) * band * 0.55 * smoothstep(0.3, 0.6, lum) * c.a;
	COLOR = c;
}
