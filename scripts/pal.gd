class_name Pal
extends RefCounted
## Palette, light direction and small drawing helpers shared by every visual.
## One light source from the upper left: every shadow falls down/right.

const BG := Color("0E1015")
const BG_LIFT := Color("141820")
const INK := Color("D9DDE3")
const INK_DIM := Color("8A929D")
const INK_FAINT := Color("4A515C")

# Gold is the only warm colour: the ball and power.
const GOLD := Color("D4A94F")
const GOLD_LIGHT := Color("E6C47C")
const GOLD_DARK := Color("8F6B2C")
const GOLD_WARM := Color("DE8F3E")

# Hardware (fork, rail): cool slate, two tones.
const METAL := Color("3F4652")
const METAL_LIGHT := Color("69717E")
const METAL_DARK := Color("1D2127")
const BAND := Color("5D6470")
const BAND_DARK := Color("2E333B")
const POUCH := Color("474D57")
const STRING := Color("59616D")

# Target hues: silhouettes carry identity, hue + lightness second. Hues sit
# ≥40° apart (spec hues nudged ≤15° so blue/teal/green clear 40°), and
# luma steps of ~0.11 keep every type apart in greyscale.
const GREEN := Color("2FA66A")   # 145°, luma .45 – heavy (double ring), emerald
const PURPLE := Color("9A6BFF")   # 260°, luma .50 – rod, violet
const BLUE := Color("4F8BFF")   # 220°, luma .55 – ring, azure
const TEAL := Color("33D1C6")   # 175°, luma .66 – splitter (hexagon), turquoise
const DROP := Color("8FE3FF")   # 195°, luma .82 – fast drop, sky
const CORAL := Color("E98462")   # 15° – danger only
const ARMOR := Color("7E9CC9")   # 215°, luma .60 – Vokter body (ring + plate), steel blue
const BOSS := Color("D05BE0")   # 290°, luma .52 – Spinneren (filled hexagon), orchid
const REEL := Color("9FD85A")   # 90°, luma .73 – Snelle (spoked reel), lime
const SHADE := Color("FF7FB6")   # 335°, luma .64 – Skygge (crescent), rose
const EYE := Color("E4E7EC")
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


static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(pos, r, col, true, -1.0, true)


static func ring(ci: CanvasItem, pos: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(pos, r, 0.0, TAU, maxi(24, int(r * 1.2)), col, w, true)


static func shadow_disc(ci: CanvasItem, pos: Vector2, r: float) -> void:
	disc(ci, pos + SHADOW_OFFSET, r, SHADOW)


## Frame-rate independent lerp factor: `per_frame` is the factor at 60 fps.
static func damp(per_frame: float, delta: float) -> float:
	return 1.0 - pow(1.0 - per_frame, delta * 60.0)
