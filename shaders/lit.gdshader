shader_type canvas_item;
// One light for the whole scene, up and to the left and a little in front,
// shared by every target and the slingshot. Geometry carries a surface
// normal per vertex in UV (the x and y of a unit normal; z is implied), so
// bodies shade as smooth solids and strings as small cylinders, and every
// silhouette is antialiased from the normal's length reaching 1. UV.x also
// selects the material, in bands 4 apart:
//   0 jelly · 1 contact shadow · 2 cord · 3 wire · 4 painted shell
//   5 membrane (the recessed inside of a ring) · 6 polished metal
//   7 twisted steel cable
// Strings carry their running length in UV.y: cords show a soft braid,
// cables a tight twist of strands.
// A whole layer (string, shadow, body) is one draw call.

const vec3 SUN = vec3(-0.46, -0.62, 0.64);
// Where the viewer is, relative to straight on (the phone's tilt): the
// highlights slide across the surfaces as you lean, as on real gloss.
uniform vec2 view = vec2(0.0);
// Moving lights: the balls in flight glow warm and light what they pass,
// on the side that faces them (xy: canvas position, z: reach, w: strength).
uniform vec4 lights[3];
uniform vec3 light_col = vec3(1.0, 0.78, 0.42);
varying vec2 world;

// Warm light from the balls on a surface with normal `n` at `world`.
vec3 ball_light(vec3 n) {
	vec3 g = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		vec4 lt = lights[i];
		if (lt.w <= 0.0) {
			continue;
		}
		vec2 d = lt.xy - world;
		float dl = length(d);
		float att = lt.w * pow(max(0.0, 1.0 - dl / lt.z), 2.0);
		vec3 ld = normalize(vec3(d / max(dl, 1.0), 0.55));
		g += light_col * att * max(dot(n, ld), 0.0);
	}
	return g;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float band = floor(UV.x * 0.25 + 0.5);
	if (band != 2.0 && band != 3.0 && band != 7.0) {
		// Carry the normal into world space (rotation and squash of the
		// body, and of the command's own transform) so the light stays put
		// while bodies swing and spin. Strings are already in world space.
		vec2 n = vec2(UV.x - band * 4.0, UV.y);
		float len = length(n);
		vec2 w = (MODEL_MATRIX * vec4(n, 0.0, 0.0)).xy;
		float lw = length(w);
		n = lw > 1e-5 ? w * (len / lw) : vec2(0.0);
		UV = vec2(band * 4.0 + n.x, n.y);
	}
}

// 1 inside, easing to 0 over the last ~1.2 px before the rim (r = 1).
float edge(float r) {
	float aa = max(fwidth(r) * 1.2, 1e-4);
	return 1.0 - smoothstep(1.0 - aa, 1.0, r);
}

void fragment() {
	float band = floor(UV.x * 0.25 + 0.5);
	vec2 q = vec2(UV.x - band * 4.0, UV.y);
	vec3 L = normalize(SUN);
	vec3 H = normalize(L + normalize(vec3(view, 1.0)));
	vec4 c = COLOR;
	if (band == 1.0) {
		// Contact shadow: soft, darkest under the body's middle.
		COLOR = vec4(0.0, 0.0, 0.0, c.a * (1.0 - smoothstep(0.3, 1.0, length(q))));
	} else if (band == 2.0 || band == 3.0 || band == 7.0) {
		// Strings: a cylinder across their width (they hang near vertical).
		float w = clamp(q.x, -1.0, 1.0);
		vec3 n = vec3(w, 0.0, sqrt(1.0 - w * w));
		float d = clamp(dot(n, L), 0.0, 1.0);
		bool wire = band != 2.0;
		float s = pow(max(dot(n, H), 0.0), wire ? 28.0 : 10.0) * (wire ? 0.5 : 0.12);
		vec3 col = c.rgb * (0.45 + 0.7 * d) + s;
		if (band == 2.0) {
			// Braided cord: soft diagonal plaits.
			col *= 0.9 + 0.1 * sin(q.y * 1.3 + w * 2.4);
		} else if (band == 7.0) {
			// Cable: strands laid in a tight helix, each catching the light.
			float h = fract(q.y * 0.42 + w * 0.45);
			col *= 0.72 + 0.4 * smoothstep(0.0, 0.5, h) * (1.0 - smoothstep(0.5, 1.0, h));
		}
		col += c.rgb * ball_light(n) * 0.8;
		COLOR = vec4(col, c.a * edge(abs(q.x)));
	} else if (band == 5.0) {
		// Recessed membrane: in its own shadow on the upper left rim,
		// catching the light on the lower right.
		float k = dot(q, normalize(L.xy));
		COLOR = vec4(c.rgb * (0.86 - 0.3 * k), c.a);
	} else {
		float r2 = dot(q, q);
		float r = sqrt(r2);
		vec3 n = vec3(q, sqrt(max(0.0, 1.0 - r2)));
		float ndl = dot(n, L);
		vec3 col;
		if (band == 6.0) {
			// Polished metal: little diffuse, a sharp highlight and a hint of
			// the room reflected (lighter facing up, darker facing down).
			float env = 0.5 - 0.5 * clamp(n.y + view.y, -1.0, 1.0);
			float s = pow(max(dot(n, H), 0.0), 40.0) * 0.9;
			col = c.rgb * (0.4 + 0.35 * clamp(ndl, 0.0, 1.0) + 0.4 * env) + s;
		} else {
			bool jelly = band == 0.0;
			// Wrapped diffuse: a soft terminator, never a hard black side.
			float d = clamp(ndl * 0.7 + 0.3, 0.0, 1.0);
			float s = pow(max(dot(n, H), 0.0), jelly ? 42.0 : 22.0) * (jelly ? 0.55 : 0.3);
			col = c.rgb * (0.42 + 0.78 * d) + s;
			if (jelly) {
				// Light passing through the thin rim on the shadow side.
				col += c.rgb * pow(1.0 - n.z, 3.0) * clamp(0.2 - ndl, 0.0, 1.0) * 0.8;
			}
		}
		vec3 g = ball_light(n);
		col += c.rgb * g * 0.85 + g * 0.08;
		COLOR = vec4(col, c.a * edge(r));
	}
}
