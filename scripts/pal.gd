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

# Target hues (see PLAN.md): silhouettes carry identity, hue + lightness second.
# Lightness is spread so every type separates in greyscale.
const BLUE := Color("5E8FC7")    # 210° ring
const GREEN := Color("3F7A5E")   # 150° heavy (double ring)
const TEAL := Color("7CC4C4")    # 180° splitter (hexagon)
const PURPLE := Color("7661A6")  # 265° rod
const DROP := Color("C3D2E2")    # 210° pale, fast drop
const CORAL := Color("D9765A")   # 15° danger only

const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW := Color(0, 0, 0, 0.35)
const LIGHT_DIR := Vector2(-0.7071, -0.7071)


static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(pos, r, col, true, -1.0, true)


static func ring(ci: CanvasItem, pos: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(pos, r, 0.0, TAU, maxi(24, int(r * 1.2)), col, w, true)


static func shadow_disc(ci: CanvasItem, pos: Vector2, r: float) -> void:
	disc(ci, pos + SHADOW_OFFSET, r, SHADOW)


## Frame-rate independent lerp factor: `per_frame` is the factor at 60 fps.
static func damp(per_frame: float, delta: float) -> float:
	return 1.0 - pow(1.0 - per_frame, delta * 60.0)
