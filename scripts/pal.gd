class_name Pal
extends RefCounted
## Palette, light direction and small drawing helpers shared by every visual.
## One light source from the upper left: every shadow falls down/right.

const BG := Color("0E1015")
const BG_LIFT := Color("141820")
const INK := Color("D9DDE3")
const INK_DIM := Color("8A929D")
const INK_FAINT := Color("6E7682")   # ~4.5:1 on the background: faint, still readable

# Gold is the only warm colour: the ball and power.
const GOLD := Color("D4A94F")
const GOLD_LIGHT := Color("E6C47C")
const GOLD_DARK := Color("8F6B2C")
const GOLD_WARM := Color("DE8F3E")

# Hardware (fork, rail): cool slate, two tones.
const METAL := Color("3F4652")
const METAL_LIGHT := Color("69717E")
const METAL_DARK := Color("1D2127")
const BAND := Color("B8793C")       # amber latex
const BAND_DARK := Color("4A2C14")
const POUCH := Color("6A4630")      # leather
const STRING := Color("59616D")
const HEMP := Color("A88A62")      # the creatures' cords: undyed hemp

# Target hues: silhouettes carry identity, hue + lightness second. Hues sit
# ≥40° apart (spec hues nudged ≤15° so blue/teal/green clear 40°), and
# luma steps of ~0.11 keep every type apart in greyscale.
const GREEN := Color("2F7D5A")   # 153°, luma .40 – heavy (double ring), verdigris
const PURPLE := Color("8A68C9")   # 261°, luma .46 – rod, violet enamel
const BLUE := Color("5486D8")   # 218°, luma .50 – ring, cobalt
const TEAL := Color("4BB4C4")   # 188°, luma .63 – splitter (hexagon), turquoise
const DROP := Color("98D2E4")   # 194°, luma .78 – fast drop, pale sky
const CORAL := Color("E98462")   # 15° – danger only
const FLOW := Color("BDF4FF")    # icy white-cyan – flow (a hot streak) only
const ARMOR := Color("7E9CC9")   # 215°, luma .60 – Vokter body (ring + plate), steel blue
const BOSS := Color("A8508F")   # 317°, luma .40 – Spinneren (filled hexagon), plum
const REEL := Color("A9C46E")   # 79°, luma .72 – Snelle (spoked reel), sage
const SHADE := Color("D98AA8")   # 337°, luma .62 – Skygge (crescent), dusty rose
const MEDIC := Color("E9EAE4")   # pearl, luma .92 – Legen (ring with a cross badge)
const MEDIC_BADGE := Color("4FC79A")   # mint: its badge and its bubbles
const MIRROR := Color("B3C3D6")   # silver, luma .76 – Speilet (polished hexagon)
const EYE := Color("E4E7EC")

# ------------------------------------------------------------ colour harmony
# Every world is a chord of three: the stage, the creatures and the gold of
# the ball each hold their own part of the colour wheel. The creatures'
# family is centred 80 to 140 degrees round from the stage's hue, and gold
# keeps clear of both. So each world reads as one palette, the creatures
# stand clear of the wall behind them, and the ball stands out of both.
#
# The colours are set in OKLCH (lightness, chroma, hue: a colour space made
# to match the eye), so a kind keeps its lightness and strength from world
# to world and only its hue turns with the world.
#   - The stage is one family of hues, dark and quiet.
#   - The creatures are another family, FAMILY degrees to either side of the
#     world's creature hue. The muted kinds take the end nearer the stage's
#     hue and sit back; the vivid ones take the far end and stand out.
#   - Steel, pearl and silver stay materials: all but grey.
#   - Nothing on the stage or in a family comes near gold (the ball's) or
#     coral (danger's). The families keep from green round to rose, and the
#     stage keeps to the cool side (the lamp may be warm: it is a light,
#     not a surface).
# Before v8.4 the same blues, greens and teals hung in every world.
#
# Name, and the hues (degrees) of the stage, the creatures, the lamp and the
# footlights (the haze above the line).
const HARMONY := [
	["Blåtime", 250.0, 168.0, 250.0, 250.0],    # cobalt; emerald and teal
	["Dyphav", 205.0, 318.0, 205.0, 205.0],     # teal water; orchid and rose
	["Nordlys", 160.0, 297.0, 160.0, 160.0],    # night green; violet
	["Skumring", 295.0, 205.0, 295.0, 295.0],   # violet dusk; aqua
	["Morgen", 330.0, 245.0, 75.0, 290.0],      # rose under a warm sun; sky blue.
	# Its footlights are cool, so danger's coral glow at the line is never
	# taken for the morning's rose.
]
const FAMILY := 29.0            # degrees of hue to either side of the creature hue
const HUE_LO := 132.0           # the families' bounds: below it greens turn olive
const HUE_HI := 350.0           # (toward gold), above it rose runs into coral
const COOL_LO := 129.0          # the stage's bounds: it keeps out of the warm part
const COOL_HI := 339.0          # of the wheel, gold's and coral's
# The stage: lightness, chroma, degrees from the stage hue (lamp and rim
# take the lamp's hue). The wall keeps dark enough for white text, the gold
# ball and the creatures to stand clear of it.
#   top, low     the wall from the rail down to the line
#   lamp         the light falling from the upper left
#   aura_a/b     the two colours of the drifting curtains
#   haze         the glow above the line (the footlights)
#   ground       the floor around the slingshot
#   rim          the light the creatures catch on their edges
const STAGE := {
	"top": [0.30, 0.040, 6.0], "low": [0.44, 0.055, 0.0], "lamp": [0.90, 0.060, 0.0],
	"aura_a": [0.64, 0.070, -22.0], "aura_b": [0.58, 0.080, 22.0], "haze": [0.74, 0.080, -6.0],
	"ground": [0.25, 0.025, 4.0], "rim": [0.90, 0.070, 0.0],
}
# A kind's place in its family: degrees from the creature hue (minus: toward
# the dark end, plus: toward the bright one), lightness, chroma. Since v8.6
# the creatures are soft and light against a muted wall, each drawn with a
# dark contour, and their faces carry their character: a kind is told by
# its shape and its face first, its colour second. Kinds of the same shape
# (the rings; the hexagons; the round ones) sit well apart in colour.
# Order: RING, HEAVY, SPLIT, ROD, DROP, SHIELD (steel), BOSS, REEL, SHADE,
# MEDIC (pearl), MIRROR (silver: it shows the stage), PIPP, PAKKIS, CAPTAIN,
# SEER, SNEAK
const KIND_LCH := [
	[-6.0, 0.74, 0.115], [-24.0, 0.64, 0.095], [14.0, 0.84, 0.090], [27.0, 0.70, 0.130],
	[4.0, 0.80, 0.095], [-6.0, 0.78, 0.040], [29.0, 0.60, 0.125], [-16.0, 0.88, 0.085],
	[24.0, 0.76, 0.105], [0.0, 0.95, 0.010], [0.0, 0.86, 0.025], [29.0, 0.92, 0.065],
	[-29.0, 0.84, 0.080], [-12.0, 0.58, 0.075], [10.0, 0.65, 0.120], [-28.0, 0.70, 0.065],
]
const KIND_MEDIC := 9
const KIND_MIRROR := 10
# The variants keep to the family too: each is its kind moved a little in
# hue, lightness and chroma (they used to be four colours of their own).
# Order: STD, BOB (lighter, fresher), TWIN (paler), BIG (deeper), HOPPER
# (brighter and stronger).
const VARIANT_LCH := [[0.0, 0.0, 0.0], [12.0, 0.10, -0.010], [-8.0, 0.13, -0.045], [-10.0, -0.10, 0.020], [18.0, 0.08, 0.030]]
const THEME_TIME := 2.0

static var _theme_from := 0
static var _theme_to := 0
static var _theme_k := 1.0
static var _worlds: Array = []   # per world: its stage colours by key (see STAGE)
static var _kinds: Array = []    # per world, per variant: the kinds' colours


## A colour from lightness (0..1), chroma (0..0.4) and hue (degrees) in
## OKLCH. Where the screen cannot show it, the chroma gives way and the
## lightness and hue are kept.
static func oklch(l: float, c: float, h: float) -> Color:
	var a := cos(deg_to_rad(h))
	var b := sin(deg_to_rad(h))
	var rgb := _oklab_to_linear(l, c * a, c * b)
	if not _shown(rgb):
		var lo := 0.0
		var hi := c
		for i in 20:
			var mid := (lo + hi) * 0.5
			if _shown(_oklab_to_linear(l, mid * a, mid * b)):
				lo = mid
			else:
				hi = mid
		rgb = _oklab_to_linear(l, lo * a, lo * b)
	return Color(_gamma(rgb.x), _gamma(rgb.y), _gamma(rgb.z))


## Lightness, chroma and hue (degrees) of a colour: the reverse of oklch().
static func to_oklch(col: Color) -> Vector3:
	var r := _linear(col.r)
	var g := _linear(col.g)
	var b := _linear(col.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	var ok_l := 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	var ok_a := 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	var ok_b := 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	return Vector3(ok_l, Vector2(ok_a, ok_b).length(), fposmod(rad_to_deg(atan2(ok_b, ok_a)), 360.0))


static func _oklab_to_linear(l: float, a: float, b: float) -> Vector3:
	var l_ := l + 0.3963377774 * a + 0.2158037573 * b
	var m_ := l - 0.1055613458 * a - 0.0638541728 * b
	var s_ := l - 0.0894841775 * a - 1.2914855480 * b
	l_ = l_ * l_ * l_
	m_ = m_ * m_ * m_
	s_ = s_ * s_ * s_
	return Vector3(
		4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
		-1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
		-0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)


static func _shown(rgb: Vector3) -> bool:
	return rgb.x >= -0.0001 and rgb.x <= 1.0001 and rgb.y >= -0.0001 and rgb.y <= 1.0001 and rgb.z >= -0.0001 and rgb.z <= 1.0001


static func _gamma(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return 12.92 * v if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


## The smallest turn between two hues (degrees, 0..180).
static func hue_gap(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)


## Which way a world's family runs: 1 when its dark end is the lower hue,
## -1 when it is the higher. The dark end is the one nearer the stage's hue.
static func family_dir(world_i: int) -> float:
	var stage: float = HARMONY[world_i][1]
	var mid: float = HARMONY[world_i][2]
	return 1.0 if hue_gap(mid - FAMILY, stage) < hue_gap(mid + FAMILY, stage) else -1.0


## The hue of `kind` (and `variant`) in a world, kept inside the family's
## bounds.
static func kind_hue(world_i: int, kind: int, variant := 0) -> float:
	var off: float = float(KIND_LCH[kind][0]) + float(VARIANT_LCH[variant][0])
	return clampf(float(HARMONY[world_i][2]) + family_dir(world_i) * off, HUE_LO, HUE_HI)


## `h` kept on the cool side of the wheel (see COOL_LO, COOL_HI).
static func cool_hue(h: float) -> float:
	h = fposmod(h, 360.0)
	if h >= COOL_LO and h <= COOL_HI:
		return h
	return COOL_HI if hue_gap(h, COOL_HI) < hue_gap(h, COOL_LO) else COOL_LO


static func _build() -> void:
	for w in HARMONY.size():
		var stage_hue: float = HARMONY[w][1]
		var lamp_hue: float = HARMONY[w][3]
		var haze_hue: float = HARMONY[w][4]
		var world := {}
		for key: String in STAGE:
			var e: Array = STAGE[key]
			if key == "lamp" or key == "rim":
				world[key] = oklch(e[0], e[1], lamp_hue + float(e[2]))
			else:
				world[key] = oklch(e[0], e[1], cool_hue((haze_hue if key == "haze" else stage_hue) + float(e[2])))
		_worlds.append(world)
		var by_variant: Array = []
		for v in VARIANT_LCH.size():
			var row: Array[Color] = []
			for k in KIND_LCH.size():
				var l: float = clampf(float(KIND_LCH[k][1]) + float(VARIANT_LCH[v][1]), 0.3, 0.93)
				var c: float = maxf(0.0, float(KIND_LCH[k][2]) + float(VARIANT_LCH[v][2]))
				if k == KIND_MEDIC:
					row.append(oklch(l, c, 100.0))            # pearl: a breath of warmth
				elif k == KIND_MIRROR:
					row.append(oklch(l, c, stage_hue))        # silver: it shows the room
				else:
					row.append(oklch(l, c, kind_hue(w, k, v)))
			by_variant.append(row)
		_kinds.append(by_variant)


## The colour of a kind (and one of its variants) in the current world,
## easing with it from wave to wave.
static func kind_color(kind: int, variant := 0) -> Color:
	if _kinds.is_empty():
		_build()
	var b: Color = _kinds[_theme_to][variant][kind]
	if _theme_k >= 1.0:
		return b
	var a: Color = _kinds[_theme_from][variant][kind]
	return a.lerp(b, smoothstep(0.0, 1.0, _theme_k))


## A number that changes whenever the world's colours do (while one world
## eases into the next, and when another is set): whoever passes them on
## to a shader sends them again only then.
static func world_stamp() -> float:
	return _theme_k + _theme_to * 2.0 + _theme_from * 64.0


## One of the current world's colours (see STAGE), easing with the theme.
static func world(key: String) -> Color:
	if _worlds.is_empty():
		_build()
	var b: Color = _worlds[_theme_to][key]
	if _theme_k >= 1.0:
		return b
	var a: Color = _worlds[_theme_from][key]
	return a.lerp(b, smoothstep(0.0, 1.0, _theme_k))


## Start easing to world `i` (or straight there with `instant`).
static func set_theme(i: int, instant := false) -> void:
	i = posmod(i, HARMONY.size())
	_theme_from = i if instant else _theme_to
	_theme_to = i
	_theme_k = 1.0 if instant else 0.0


static func next_theme() -> void:
	set_theme(_theme_to + 1)


static func theme_tick(real_dt: float) -> void:
	if _theme_k < 1.0:
		_theme_k = minf(1.0, _theme_k + real_dt / THEME_TIME)
const PUPIL := Color("0E1015")

const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW := Color(0, 0, 0, 0.35)
const LIGHT_DIR := Vector2(-0.7071, -0.7071)


const SOFT_SHADOW := Color(0, 0, 0, 0.2)

static var _soft_tex: ImageTexture


## Wide, blurred contact shadow (radial falloff texture, built once).
static func soft_shadow_tex() -> ImageTexture:
	if _soft_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


## Soft shadow for a body of half-extent `half`, drawn in the current
## transform; callers pass an offset already along the shared light direction.
static func soft_shadow(ci: CanvasItem, center: Vector2, half: Vector2, alpha := 1.0) -> void:
	var h := half * 1.45
	ci.draw_texture_rect(soft_shadow_tex(), Rect2(center - h, h * 2.0), false, Color(SOFT_SHADOW, SOFT_SHADOW.a * alpha))


static var _circle_tex: ImageTexture


## A white disc with a smooth edge and mipmaps, built once. Discs drawn
## from it are plain textured rects, which the renderer batches: dozens of
## eyes, rivets and beads cost a single draw call instead of one each.
## 256 px, so even large discs on a high-density screen keep a one-pixel
## edge (mipmaps take care of the small ones).
static func circle_tex() -> ImageTexture:
	if _circle_tex == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := n * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(c - 1.5 - d + 0.5, 0.0, 1.0)))
		img.generate_mipmaps()
		_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex


static var _glint_tex: ImageTexture


## A glint: a small four-pointed star with a soft core, for the sparkle a
## kill throws off (drawn additively, so it reads as light).
static func glint_tex() -> ImageTexture:
	if _glint_tex == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := n * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c) / c
				var ax := absf(d.x)
				var ay := absf(d.y)
				# Two thin crossing rays that taper to their tips, and a core.
				var ray := maxf(exp(-ay * 14.0) * maxf(0.0, 1.0 - ax), exp(-ax * 14.0) * maxf(0.0, 1.0 - ay))
				var core := exp(-d.length_squared() * 9.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(ray * 0.85 + core, 0.0, 1.0) * clampf((1.0 - maxf(ax, ay)) * 6.0, 0.0, 1.0)))
		img.generate_mipmaps()
		_glint_tex = ImageTexture.create_from_image(img)
	return _glint_tex


static var _paper_tex: ImageTexture


## A slip of paper (confetti): a small white rectangle with a soft edge.
static func paper_tex() -> ImageTexture:
	if _paper_tex == null:
		var img := Image.create(14, 9, false, Image.FORMAT_RGBA8)
		for y in 9:
			for x in 14:
				var edge := minf(minf(x, 13 - x), minf(y, 8 - y))
				img.set_pixel(x, y, Color(1, 1, 1, clampf(edge + 0.35, 0.0, 1.0)))
		_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex


static var _hoop_tex: ImageTexture


## A thin ring (inner radius 58 % of the outer), for eyelets and hoops,
## batched like the discs.
static func hoop_tex() -> ImageTexture:
	if _hoop_tex == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := n * 0.5
		var ro := c - 1.5
		var ri := ro * 0.58
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(minf(ro - d, d - ri) + 0.5, 0.0, 1.0)))
		img.generate_mipmaps()
		_hoop_tex = ImageTexture.create_from_image(img)
	return _hoop_tex


static func hoop(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(hoop_tex(), Rect2(pos.x - r, pos.y - r, r * 2.0, r * 2.0), false, col)


## A filled disc. Drawn a hair larger than `r` to make up for the soft
## (filtered) edge, so it matches an antialiased circle of radius `r`.
static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var e := r + 0.45
	ci.draw_texture_rect(circle_tex(), Rect2(pos.x - e, pos.y - e, e * 2.0, e * 2.0), false, col)


static func ring(ci: CanvasItem, pos: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(pos, r, 0.0, TAU, maxi(24, int(r * 1.2)), col, w, true)


static func shadow_disc(ci: CanvasItem, pos: Vector2, r: float) -> void:
	disc(ci, pos + SHADOW_OFFSET, r, SHADOW)


## Frame-rate independent lerp factor: `per_frame` is the factor at 60 fps.
static func damp(per_frame: float, delta: float) -> float:
	return 1.0 - pow(1.0 - per_frame, delta * 60.0)
