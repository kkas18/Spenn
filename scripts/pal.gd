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

# Colour themes: enamels, fired and a little muted, so the creatures sit in
# the same room as the brass, gunmetal and leather around them. Every wave
# the enemies change into another curated set,
# easing over two seconds. Each theme keeps the rules of the base one: the
# kinds sit apart in hue and in lightness (they read in greyscale too),
# nothing is gold (that is the ball's) or coral (that is danger), and the
# Vokter (steel), Legen (pearl) and Speilet (silver) keep their materials.
# Order: RING, HEAVY, SPLIT, ROD, DROP, SHIELD, BOSS, REEL, SHADE, MEDIC, MIRROR, PIPP, PAKKIS
# (Pipp is a pastel lilac chick, Pakkis a pastel pink knot: soft, childlike tones)
const THEMES := [
	# Emalje: cobalt, verdigris and plum, muted like fired enamel
	[Color("5486D8"), Color("2F7D5A"), Color("4BB4C4"), Color("8A68C9"), Color("98D2E4"), Color("7E9CC9"), Color("A8508F"), Color("A9C46E"), Color("D98AA8"), Color("E9EAE4"), Color("B3C3D6"), Color("CDC0EE"), Color("EDB9C6")],
	# Patina: greener, like old copper
	[Color("5D9ED4"), Color("347A4F"), Color("53C0BC"), Color("7E6EC5"), Color("9BDBDF"), Color("7E9CC9"), Color("A5559B"), Color("B5C073"), Color("D58DB4"), Color("E9EAE4"), Color("B3C3D6"), Color("C5C0E9"), Color("E8B9CD")],
	# Blekk: deeper and richer
	[Color("4475C7"), Color("257350"), Color("3CA4B4"), Color("7A59B9"), Color("86C0D2"), Color("7E9CC9"), Color("9B4382"), Color("99B45F"), Color("C87997"), Color("E9EAE4"), Color("B3C3D6"), Color("BAADDB"), Color("DAA6B3")],
	# Lyng: warmer, toward heather
	[Color("546CD8"), Color("2F7D6A"), Color("4B9CC4"), Color("9D68C9"), Color("98C3E4"), Color("7E9CC9"), Color("A8507D"), Color("98C46E"), Color("D98A98"), Color("E9EAE4"), Color("B3C3D6"), Color("D6C0EE"), Color("EDB9BC")],
	# Frost: paler and lighter
	[Color("76A1E7"), Color("438668"), Color("6AC4D2"), Color("A184D7"), Color("B3E5F4"), Color("7E9CC9"), Color("B4689E"), Color("BBD288"), Color("E8A5BE"), Color("E9EAE4"), Color("B3C3D6"), Color("E2D7FF"), Color("FED1DC")],
]
const THEME_TIME := 2.0

static var _theme_from := 0
static var _theme_to := 0
static var _theme_k := 1.0


static func kind_color(kind: int) -> Color:
	var a: Color = THEMES[_theme_from][kind]
	if _theme_k >= 1.0:
		return THEMES[_theme_to][kind]
	return a.lerp(THEMES[_theme_to][kind], smoothstep(0.0, 1.0, _theme_k))


## Start easing to theme `i` (or straight there with `instant`).
static func set_theme(i: int, instant := false) -> void:
	i = posmod(i, THEMES.size())
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
