class_name Tok
extends RefCounted
## Design tokens for the presentation layer. Every screen reads colour,
## radius, spacing and type size from here, so menus, HUD, intro and results
## share one visual system. Gameplay art keeps its own palette in `Pal`.

# Colour
const BACKGROUND := Pal.BG
const SURFACE := Color("161A21")
const SURFACE_HI := Color("1B2029")
const SURFACE_LO := Color("12151B")
const TILE := Color("141820")
const BORDER := Color("2A303A")
const BORDER_HI := Color("363D49")
const PRIMARY := Pal.GOLD
const PRIMARY_HI := Pal.GOLD_LIGHT
const PRIMARY_LO := Pal.GOLD_DARK
const ON_PRIMARY := Pal.BG
const TEXT_PRIMARY := Pal.INK
const TEXT_SECONDARY := Pal.INK_DIM
const TEXT_FAINT := Pal.INK_FAINT
const SUCCESS := Color("8FC2A6")
const DANGER := Pal.CORAL
const SCRIM := Color(0.03, 0.035, 0.045)
const GLASS := Color(0.106, 0.125, 0.161, 0.88)   # panels over the blurred scrim
const HAIRLINE := Color(1, 1, 1, 0.06)
const SHADOW := Pal.SHADOW

# Radius
const RADIUS_S := 8
const RADIUS_M := 14
const RADIUS_L := 22
const RADIUS_XL := 40
const RADIUS_PILL := 64        # more than half any button: a pill

# Spacing
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 40

# Type scale (px at the 720-wide design size)
const TYPE_CAPTION := 12
const TYPE_LABEL := 14
const TYPE_BUTTON := 17
const TYPE_BODY := 26          # mixed-case Nunito in panels
const TYPE_TITLE := 36
const TYPE_DISPLAY := 64
const TYPE_HERO := 96
const TRACKING := 2

# Touch
const TOUCH_MIN_DP := 48.0
