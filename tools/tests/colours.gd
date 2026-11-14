extends "res://tools/tests/harness.gd"
## The colour harmony's rules (v8.4), checked on the colours the game
## builds for every world (see Pal's colour harmony):
##   - the creatures keep to their family's bounds, from green to rose:
##     never gold (the ball's) nor coral (danger's);
##   - the wall keeps to the cool side of the wheel;
##   - every creature stands clear of the wall behind it;
##   - no two kinds come too close in colour;
##   - a kind keeps its lightness from world to world, so it reads the same
##     in every world and in greyscale.

const CORAL_HUE := 39.0
const GOLD_HUE := 84.0
const MIN_CONTRAST := 2.0       # the darkest creature against the middle of the wall
const MIN_DE := 0.05            # OKLab distance between any two kinds
const KIND_N := 16


func _test() -> void:
	var pal: Script = load("res://scripts/pal.gd")
	var harmony: Array = pal.get("HARMONY")
	var medic: int = pal.get("KIND_MEDIC")
	var mirror: int = pal.get("KIND_MIRROR")
	var keep := [pal.get("_theme_from"), pal.get("_theme_to"), pal.get("_theme_k")]
	var lightness := []
	for w in harmony.size():
		pal.set_theme(w, true)
		var name: String = harmony[w][0]
		var mid: Color = pal.world("top").lerp(pal.world("low"), 0.5)
		var worst_contrast := INF
		var worst_de := INF
		var nearest_warm := 360.0
		var out_of_family := 0
		var light_row := []
		var labs := []
		for k in KIND_N:
			var c: Color = pal.kind_color(k)
			var lch: Vector3 = pal.to_oklch(c)
			light_row.append(lch.x)
			labs.append(Vector3(lch.x, lch.y * cos(deg_to_rad(lch.z)), lch.y * sin(deg_to_rad(lch.z))))
			if k != medic:
				worst_contrast = minf(worst_contrast, _contrast(c, mid))
			if k != medic and k != mirror and lch.y > 0.04:
				nearest_warm = minf(nearest_warm, minf(pal.hue_gap(lch.z, CORAL_HUE), pal.hue_gap(lch.z, GOLD_HUE)))
				if lch.z < float(pal.get("HUE_LO")) - 2.0 or lch.z > float(pal.get("HUE_HI")) + 2.0:
					out_of_family += 1
		for a in KIND_N:
			for b in range(a + 1, KIND_N):
				worst_de = minf(worst_de, (labs[a] - labs[b]).length())
		lightness.append(light_row)
		var warm_wall := 0
		for key: String in ["top", "low", "haze", "aura_a", "aura_b", "ground"]:
			var h: float = pal.to_oklch(pal.world(key)).z
			if pal.hue_gap(h, CORAL_HUE) < 50.0 or pal.hue_gap(h, GOLD_HUE) < 40.0:
				warm_wall += 1
		check(out_of_family == 0, "%s: every creature keeps to its family, from green to rose" % name)
		check(nearest_warm >= 45.0, "%s: no creature comes near gold or coral (nearest %.0f degrees)" % [name, nearest_warm])
		check(warm_wall == 0, "%s: the wall keeps to the cool side" % name)
		check(worst_contrast >= MIN_CONTRAST, "%s: every creature stands clear of the wall (weakest %.2f : 1)" % [name, worst_contrast])
		check(worst_de >= MIN_DE, "%s: no two kinds come too close in colour (closest %.3f)" % [name, worst_de])
	var drift := 0.0
	for k in KIND_N:
		for w in range(1, lightness.size()):
			drift = maxf(drift, absf(float(lightness[w][k]) - float(lightness[0][k])))
	check(drift <= 0.03, "a kind keeps its lightness from world to world (largest change %.3f)" % drift)
	pal.set("_theme_from", keep[0])
	pal.set("_theme_to", keep[1])
	pal.set("_theme_k", keep[2])
	finish()


## Contrast between two colours as for text (WCAG): 1 to 21.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
