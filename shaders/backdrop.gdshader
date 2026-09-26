shader_type canvas_item;
// The room behind the rail. One light source: a lamp above the beam on the
// left, casting a soft cone down through the field (with slow, faint shafts
// of dust in it). Below the danger line the ground takes over, with a pool
// of light around the slingshot. Large, slow mottling gives the wall a
// material; fine static grain and triangular dithering keep every gradient
// clean on 8-bit panels. As a target nears the line, a coral warmth rises
// from it.

uniform vec4 base : source_color = vec4(0.050, 0.058, 0.076, 1.0);
uniform vec4 lift : source_color = vec4(0.085, 0.094, 0.118, 1.0);
uniform vec4 lamp : source_color = vec4(0.30, 0.32, 0.38, 1.0);
uniform vec4 ground : source_color = vec4(0.064, 0.068, 0.082, 1.0);
uniform vec4 warn : source_color = vec4(0.914, 0.518, 0.384, 1.0);
uniform vec2 size = vec2(720.0, 1280.0);
uniform float rail_y = 150.0;
uniform float danger_y = 920.0;
uniform float danger = 0.0;
uniform float time = 0.0;
uniform float grain = 0.010;
uniform float heat = 0.0;      // overload: the lamp burns gold
uniform vec4 gold : source_color = vec4(0.83, 0.66, 0.31, 1.0);

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
	// Wall: dark, lifted toward the upper left.
	float d0 = distance(px / size.y, vec2(0.08, 0.0)) / 0.95;
	vec3 col = mix(base.rgb, lift.rgb, pow(1.0 - smoothstep(0.0, 1.0, d0), 2.0));
	// Lamp cone from above the beam, spreading down and fading with distance.
	vec2 lp = vec2(size.x * 0.32, rail_y - 60.0);
	vec2 dv = px - lp;
	float dist = length(dv);
	float ang = abs(atan(dv.x, max(dv.y, 0.001)));
	// The beam hides the lamp: light only below it, easing in under it.
	float below = smoothstep(rail_y, rail_y + 40.0, px.y);
	float cone = (1.0 - smoothstep(0.28, 0.78, ang)) * exp(-dist / (size.y * 0.62)) * below;
	// Faint shafts drifting through the cone.
	float shafts = 0.75 + 0.25 * vnoise(vec2(ang * 9.0 + time * 0.05, dist * 0.004 - time * 0.03));
	// The lamp breathes: a slow, barely-there swell, never a flicker.
	float breath = 0.94 + 0.06 * sin(time * 0.55) * sin(time * 0.23 + 1.3);
	vec3 lc = mix(lamp.rgb, gold.rgb * 0.9, heat * 0.6);
	col += lc * cone * (0.16 + 0.08 * heat) * shafts * breath;
	// Ground below the danger line, with a soft horizon.
	float g = smoothstep(danger_y - 6.0, danger_y + 90.0, px.y);
	col = mix(col, ground.rgb, g * 0.85);
	// The floor in perspective: faint boards running toward a vanishing
	// point high above the slingshot, and seams that crowd together toward
	// the far edge (the danger line), so the ground reads as a plane.
	if (g > 0.0) {
		float v = max(px.y - danger_y, 0.0) / max(size.y - danger_y, 1.0);
		float persp = 0.12 + v;
		float u = (px.x - size.x * 0.5) / persp / 90.0;
		float fu = abs(fract(u) - 0.5);
		float board = 1.0 - smoothstep(0.0, 0.035 / persp * 0.12 + 0.01, 0.5 - fu);
		float zz = 1.0 / persp;
		float fz = abs(fract(zz * 0.9) - 0.5);
		float seam = 1.0 - smoothstep(0.0, 0.06, 0.5 - fz);
		float fade = smoothstep(0.0, 0.25, v) * g;
		col -= vec3(0.032) * max(1.0 - board, 0.0) * fade;
		col -= vec3(0.022) * max(1.0 - seam, 0.0) * fade * (1.0 - v * 0.5);
	}
	// Light pooled around the slingshot.
	vec2 sp = vec2(size.x * 0.5, size.y * 0.9);
	float pool = exp(-length((px - sp) * vec2(1.0, 2.2)) / (size.x * 0.38));
	col += lamp.rgb * pool * 0.07 * g;
	// Wall material: slow, large mottling.
	col *= 1.0 + (vnoise(px / 210.0) - 0.5) * 0.07 + (vnoise(px / 57.0) - 0.5) * 0.025;
	// Coral warmth rising from the line as a target nears it.
	float up = danger_y - px.y;
	float w = exp(-max(up, 0.0) / 70.0) * (1.0 - smoothstep(0.0, 40.0, -up));
	col = mix(col, warn.rgb * 0.55, w * danger * 0.32);
	// Static grain and triangular dither.
	col += (hash(floor(FRAGCOORD.xy)) - 0.5) * grain;
	float n = ign(FRAGCOORD.xy) + ign(FRAGCOORD.xy + vec2(31.0, 11.0)) - 1.0;
	col += n / 255.0;
	COLOR = vec4(col, 1.0);
}
