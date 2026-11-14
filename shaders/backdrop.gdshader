shader_type canvas_item;
// The wall behind the rail: a lit backcloth. Deep colour at the top opens
// toward the line; slow curtains of two more colours drift across it; a
// light falls in a cone from above the beam on the left (the scene's one
// light: every shadow leans away from it); a glow gathers above the line
// like footlights. A kill lights the air around it for a moment. Below the
// line the floor takes over, with a pool of light around the slingshot.
// Fine grain and triangular dithering keep every gradient clean on 8-bit
// panels. As a target nears the line, a coral warmth rises from it.
// The colours come from the world the wave is played in (see Pal.WORLDS).

uniform vec4 sky_top : source_color = vec4(0.050, 0.075, 0.200, 1.0);
uniform vec4 sky_low : source_color = vec4(0.105, 0.180, 0.400, 1.0);
uniform vec4 lamp : source_color = vec4(0.55, 0.70, 1.00, 1.0);
uniform vec4 aura_a : source_color = vec4(0.08, 0.42, 0.62, 1.0);
uniform vec4 aura_b : source_color = vec4(0.34, 0.24, 0.72, 1.0);
uniform vec4 haze : source_color = vec4(0.30, 0.50, 0.95, 1.0);
uniform vec4 ground : source_color = vec4(0.050, 0.068, 0.150, 1.0);
uniform vec4 warn : source_color = vec4(0.914, 0.518, 0.384, 1.0);
uniform float aura_amt = 1.0;  // 0: the curtains are still and faint (reduced motion keeps them, unmoving)
uniform vec2 size = vec2(720.0, 1280.0);
uniform float rail_y = 150.0;
uniform float danger_y = 920.0;
uniform float danger = 0.0;
uniform float time = 0.0;
uniform float grain = 0.010;
uniform float heat = 0.0;      // overload: the light burns gold
uniform vec4 gold : source_color = vec4(0.83, 0.66, 0.31, 1.0);
// Light from what just happened (a kill, a cleared wave): xy where, z how
// far it reaches (px), w how strong it is now.
uniform vec4 pulse_at[4];
uniform vec4 pulse_col[4];

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 px = UV * size;
	float span = max(danger_y - rail_y, 1.0);
	float h = (px.y - rail_y) / span;      // 0 at the rail, 1 at the line
	float hc = clamp(h, 0.0, 1.0);
	// The wall: deep at the top, opening toward the line; behind the top
	// bar it sinks back so the instruments sit on a quiet ground.
	vec3 col = mix(sky_top.rgb, sky_low.rgb, smoothstep(0.0, 1.0, hc));
	col *= mix(0.5, 1.0, smoothstep(-0.14, 0.03, h));
	// Curtains of colour, drifting: two slow fields, the second choosing
	// between the world's two colours.
	float drift = time * aura_amt;
	float n1 = vnoise(vec2(px.x / 340.0 + drift * 0.021, px.y / 700.0 - drift * 0.011));
	float n2 = vnoise(vec2(px.x / 260.0 - drift * 0.016, px.y / 520.0 + 9.0 + drift * 0.007));
	float curtain = smoothstep(0.30, 0.92, n1 * 0.65 + n2 * 0.35);
	vec3 aura = mix(aura_a.rgb, aura_b.rgb, smoothstep(0.22, 0.78, n2));
	float on_wall = smoothstep(-0.04, 0.16, h) * (1.0 - smoothstep(0.74, 1.04, h));
	col += aura * curtain * on_wall * (0.14 + 0.26 * aura_amt);
	// The light from above the beam, spreading down and fading with distance.
	vec2 lp = vec2(size.x * 0.32, rail_y - 60.0);
	vec2 dv = px - lp;
	float dist = length(dv);
	float ang = abs(atan(dv.x, max(dv.y, 0.001)));
	// The beam hides the lamp: light only below it, easing in under it.
	float below = smoothstep(rail_y, rail_y + 40.0, px.y);
	float cone = (1.0 - smoothstep(0.26, 0.86, ang)) * exp(-dist / (size.y * 0.66)) * below;
	// Faint shafts drifting through the cone.
	float shafts = 0.7 + 0.3 * vnoise(vec2(ang * 9.0 + time * 0.05, dist * 0.004 - time * 0.03));
	// The light breathes: a slow, barely-there swell, never a flicker.
	float breath = 0.94 + 0.06 * sin(time * 0.55) * sin(time * 0.23 + 1.3);
	vec3 lc = mix(lamp.rgb, gold.rgb * 1.1, heat * 0.7);
	col += lc * cone * (0.21 + 0.10 * heat) * shafts * breath;
	// Footlights: a glow gathering above the line.
	float g = smoothstep(danger_y - 6.0, danger_y + 90.0, px.y);
	float foot = exp(-max(danger_y - px.y, 0.0) / (span * 0.20));
	col += mix(haze.rgb, gold.rgb, heat * 0.5) * foot * 0.26 * (1.0 - g);
	// What just happened lights the air around it. Together the pulses
	// never lift the wall by more than a third: words and creatures in
	// front of it must stay as clear as they were.
	vec3 lit = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float w = pulse_at[i].w;
		if (w > 0.001) {
			vec2 d = px - pulse_at[i].xy;
			float r = pulse_at[i].z;
			lit += pulse_col[i].rgb * w * exp(-dot(d, d) / (r * r));
		}
	}
	float most = max(lit.r, max(lit.g, lit.b));
	col += lit * (min(most, 0.34) / max(most, 0.0001)) * (1.0 - g * 0.6);
	// The floor below the line, with a soft horizon.
	vec3 floor_col = ground.rgb;
	// In perspective: faint boards running toward a vanishing point high
	// above the slingshot, and seams that crowd together toward the far
	// edge (the line), so the ground reads as a plane.
	if (g > 0.0) {
		float v = max(px.y - danger_y, 0.0) / max(size.y - danger_y, 1.0);
		float persp = 0.12 + v;
		float u = (px.x - size.x * 0.5) / persp / 90.0;
		float fu = abs(fract(u) - 0.5);
		float board = 1.0 - smoothstep(0.0, 0.035 / persp * 0.12 + 0.01, 0.5 - fu);
		float zz = 1.0 / persp;
		float fz = abs(fract(zz * 0.9) - 0.5);
		float seam = 1.0 - smoothstep(0.0, 0.06, 0.5 - fz);
		float fade = smoothstep(0.0, 0.25, v);
		// A polished floor: it carries the wall's wash back as a soft
		// reflection, strongest at the far edge and gone by the near one,
		// broken by the boards.
		vec3 wash = mix(sky_low.rgb, haze.rgb, 0.35);
		floor_col += wash * (0.50 * exp(-v / 0.16) + 0.15 * (1.0 - v));
		floor_col *= 1.0 - 0.30 * max(1.0 - board, 0.0) * fade;
		floor_col *= 1.0 - 0.22 * max(1.0 - seam, 0.0) * fade * (1.0 - v * 0.5);
		// Light pooled around the slingshot.
		vec2 sp = vec2(size.x * 0.5, size.y * 0.9);
		float pool = exp(-length((px - sp) * vec2(1.0, 2.2)) / (size.x * 0.42));
		floor_col += mix(lamp.rgb, gold.rgb, heat * 0.6) * pool * 0.20;
	}
	col = mix(col, floor_col, g * 0.92);
	// The cloth's weave: slow, large mottling.
	col *= 1.0 + (vnoise(px / 210.0) - 0.5) * 0.08;
	// Coral warmth rising from the line as a target nears it.
	float up = danger_y - px.y;
	float w = exp(-max(up, 0.0) / 70.0) * (1.0 - smoothstep(0.0, 40.0, -up));
	col = mix(col, warn.rgb * 0.7, w * danger * 0.42);
	// Static grain and triangular dither.
	col += (hash(floor(FRAGCOORD.xy)) - 0.5) * grain;
	float n = ign(FRAGCOORD.xy) + ign(FRAGCOORD.xy + vec2(31.0, 11.0)) - 1.0;
	col += n / 255.0;
	COLOR = vec4(col, 1.0);
}
