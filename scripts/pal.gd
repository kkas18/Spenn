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
# Order: RING, HEAVY, SPLIT, ROD, DROP, SHIELD, BOSS, REEL, SHADE, MEDIC, MIRROR, PIPP, PAKKIS,
# CAPTAIN (navy steel), SEER (violet), SNEAK (moss)
# (Pipp is a pastel lilac chick, Pakkis a pastel pink knot: soft, childlike tones)
const THEMES := [
	# Emalje: cobalt, verdigris and plum, muted like fired enamel
	[Color("5486D8"), Color("2F7D5A"), Color("4BB4C4"), Color("8A68C9"), Color("98D2E4"), Color("7E9CC9"), Color("A8508F"), Color("A9C46E"), Color("D98AA8"), Color("E9EAE4"), Color("B3C3D6"), Color("CDC0EE"), Color("EDB9C6"), Color("3E4E7A"), Color("9A5BB0"), Color("6F9A5B")],
	# Patina: greener, like old copper
	[Color("5D9ED4"), Color("347A4F"), Color("53C0BC"), Color("7E6EC5"), Color("9BDBDF"), Color("7E9CC9"), Color("A5559B"), Color("B5C073"), Color("D58DB4"), Color("E9EAE4"), Color("B3C3D6"), Color("C5C0E9"), Color("E8B9CD"), Color("415978"), Color("8C60AC"), Color("7A975E")],
	# Blekk: deeper and richer
	[Color("4475C7"), Color("257350"), Color("3CA4B4"), Color("7A59B9"), Color("86C0D2"), Color("7E9CC9"), Color("9B4382"), Color("99B45F"), Color("C87997"), Color("E9EAE4"), Color("B3C3D6"), Color("BAADDB"), Color("DAA6B3"), Color("354570"), Color("8C4DA2"), Color("638E4F")],
	# Lyng: warmer, toward heather
	[Color("546CD8"), Color("2F7D6A"), Color("4B9CC4"), Color("9D68C9"), Color("98C3E4"), Color("7E9CC9"), Color("A8507D"), Color("98C46E"), Color("D98A98"), Color("E9EAE4"), Color("B3C3D6"), Color("D6C0EE"), Color("EDB9BC"), Color("3E427A"), Color("AB5BB0"), Color("629A5B")],
	# Frost: paler and lighter
	[Color("76A1E7"), Color("438668"), Color("6AC4D2"), Color("A184D7"), Color("B3E5F4"), Color("7E9CC9"), Color("B4689E"), Color("BBD288"), Color("E8A5BE"), Color("E9EAE4"), Color("B3C3D6"), Color("E2D7FF"), Color("FED1DC"), Color("4F5D83"), Color("A974BC"), Color("80A56F")],
]
const THEME_TIME := 2.0

# Worlds: the light the stage is washed in, one for each theme above (they
# change together, wave by wave). The wall behind the rail is no longer a
# dark room with one lamp but a lit backcloth: deep colour at the top
# opening toward the footlights, slow curtains of a second and third
# colour drifting across it, a glow gathering above the line. Every world
# stays dark enough for white text, the gold ball and the creatures to
# stand clear of it (the wall's luma keeps under about 0.3), and none is
# coral: that is still danger's colour alone.
#   top, low     the wall from the rail down to the line
#   lamp         the light falling from the upper left
#   aura_a/b     the two colours of the drifting curtains
#   haze         the glow above the line (the footlights)
#   ground       the floor around the slingshot
#   rim          the light the creatures catch on their edges
const WORLDS := [
	# Blåtime: cobalt deepening to indigo, a cool white light
	{"top": Color(0.050, 0.075, 0.200), "low": Color(0.105, 0.180, 0.400), "lamp": Color(0.55, 0.70, 1.00),
		"aura_a": Color(0.08, 0.42, 0.62), "aura_b": Color(0.34, 0.24, 0.72), "haze": Color(0.30, 0.50, 0.95),
		"ground": Color(0.050, 0.068, 0.150), "rim": Color(0.55, 0.75, 1.00)},
	# Dyphav: teal water, light falling in from above
	{"top": Color(0.022, 0.105, 0.150), "low": Color(0.040, 0.250, 0.300), "lamp": Color(0.55, 1.00, 0.95),
		"aura_a": Color(0.05, 0.55, 0.50), "aura_b": Color(0.10, 0.30, 0.70), "haze": Color(0.15, 0.70, 0.75),
		"ground": Color(0.025, 0.085, 0.110), "rim": Color(0.45, 0.95, 0.90)},
	# Nordlys: night green, with violet in the curtains
	{"top": Color(0.020, 0.085, 0.085), "low": Color(0.035, 0.250, 0.150), "lamp": Color(0.62, 1.00, 0.70),
		"aura_a": Color(0.10, 0.80, 0.36), "aura_b": Color(0.52, 0.24, 0.86), "haze": Color(0.22, 0.80, 0.42),
		"ground": Color(0.025, 0.080, 0.065), "rim": Color(0.60, 1.00, 0.72)},
	# Skumring: violet running to magenta
	{"top": Color(0.095, 0.050, 0.210), "low": Color(0.290, 0.110, 0.360), "lamp": Color(1.00, 0.72, 0.92),
		"aura_a": Color(0.72, 0.22, 0.60), "aura_b": Color(0.26, 0.26, 0.82), "haze": Color(0.80, 0.36, 0.78),
		"ground": Color(0.085, 0.045, 0.130), "rim": Color(1.00, 0.65, 0.95)},
	# Morgen: a warm sun through the upper left over rose and plum; the
	# footlights stay cool, so the coral of danger is never mistaken
	{"top": Color(0.150, 0.070, 0.160), "low": Color(0.400, 0.170, 0.270), "lamp": Color(1.00, 0.78, 0.52),
		"aura_a": Color(0.78, 0.40, 0.26), "aura_b": Color(0.46, 0.24, 0.70), "haze": Color(0.56, 0.40, 0.92),
		"ground": Color(0.090, 0.055, 0.105), "rim": Color(1.00, 0.84, 0.62)},
]

static var _theme_from := 0
static var _theme_to := 0
static var _theme_k := 1.0


static var _vivid: Array = []    # THEMES with every colour through vivid(), worked out once


static func kind_color(kind: int) -> Color:
	if _vivid.is_empty():
		for theme: Array in THEMES:
			var row: Array[Color] = []
			for c: Color in theme:
				row.append(vivid(c))
			_vivid.append(row)
	if _theme_k >= 1.0:
		return _vivid[_theme_to][kind]
	var a: Color = _vivid[_theme_from][kind]
	return a.lerp(_vivid[_theme_to][kind], smoothstep(0.0, 1.0, _theme_k))


## The enamels a touch richer and lighter than they were fired: on a lit
## wall the muted ones looked grey. Hue is kept, so the kinds stay as far
## apart as the themes set them.
static func vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.16 + 0.03), minf(1.0, c.v * 1.07 + 0.02), c.a)


## A number that changes whenever the world's colours do (while one world
## eases into the next, and when another is set): whoever passes them on
## to a shader sends them again only then.
static func world_stamp() -> float:
	return _theme_k + _theme_to * 2.0 + _theme_from * 64.0


## One of the current world's colours (see WORLDS), easing with the theme.
static func world(key: String) -> Color:
	var b: Color = WORLDS[_theme_to % WORLDS.size()][key]
	if _theme_k >= 1.0:
		return b
	var a: Color = WORLDS[_theme_from % WORLDS.size()][key]
	return a.lerp(b, smoothstep(0.0, 1.0, _theme_k))


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
