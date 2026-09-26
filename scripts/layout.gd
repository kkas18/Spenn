class_name Layout
extends RefCounted
## Screen layout in viewport pixels, derived from the visible rect and the
## device safe area. Every placement in the game reads from here.

const TOP_BAR_FRAC := 0.11     # top bar: pause · score · record
const PLAY_FRAC := 0.60        # target field height
const ARC_GAP := 22.0          # power arc radius beyond max pull
const MIN_GESTURE_DP := 24.0   # assumed gesture strip when the OS reports none
const ARC_CLEARANCE_DP := 24.0 # clearance between power arc and gesture strip

var size := Vector2(720, 1280)
var dp := 2.0                  # viewport px per density-independent px
var safe_top := 0.0
var safe_bottom := 0.0
var top_bar_h := 0.0           # includes safe_top
var score_baseline := 0.0
var rail_y := 0.0
var danger_y := 0.0
var play_h := 0.0
var center_x := 360.0
var fork_y := 0.0              # y of the fork tips / pouch rest line
var fork_half := 62.0          # half distance between fork tips
var crotch_y := 0.0
var handle_end_y := 0.0
var max_pull := 130.0           # how far the pouch itself moves (visual)
var drag_range := 330.0         # finger travel for full power: ~3.5 cm on any phone
var arc_radius := 152.0
var ammo_x := 0.0
var ammo_top := 0.0
var ammo_step := 28.0
var margin := 24.0             # screen-edge margin for popups and sparks
var scale := 1.0               # size.y / 1280, for speeds and distances


static func compute(vp: Viewport) -> Layout:
	var l := Layout.new()
	l.size = vp.get_visible_rect().size
	l.scale = l.size.y / 1280.0
	l.center_x = l.size.x * 0.5
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		if win.y > 0.0:
			# The safe area is reported in screen pixels and ignores stretch.
			var s := l.size.y / win.y
			var safe := Rect2(DisplayServer.get_display_safe_area())
			l.safe_top = maxf(0.0, safe.position.y) * s
			l.safe_bottom = maxf(0.0, win.y - safe.end.y) * s
			var dpi := DisplayServer.screen_get_dpi()
			l.dp = (dpi / 160.0) * s if dpi > 0 else l.size.x / 360.0
	else:
		l.dp = l.size.x / 360.0
	l._place()
	return l


func _place() -> void:
	var h := size.y
	var content_h := h * TOP_BAR_FRAC
	top_bar_h = safe_top + content_h
	score_baseline = safe_top + content_h * 0.50
	rail_y = top_bar_h + 4.0
	play_h = h * PLAY_FRAC
	danger_y = rail_y + play_h

	# Slingshot sits as high as the power arc allows: the arc's lowest point
	# keeps ARC_CLEARANCE_DP above the (reported or assumed) gesture strip.
	var gesture := maxf(safe_bottom, MIN_GESTURE_DP * dp)
	var floor_y := h - gesture - ARC_CLEARANCE_DP * dp
	max_pull = clampf(h * 0.09, 100.0, 150.0)
	# Power follows the finger over a physical distance, not the pouch's
	# short visual travel, so a small pull really is a soft shot.
	drag_range = clampf(220.0 * dp, 220.0, 480.0)
	arc_radius = max_pull + ARC_GAP
	var min_fork := danger_y + 70.0
	if floor_y - arc_radius < min_fork:
		arc_radius = maxf(80.0, floor_y - min_fork)
		max_pull = arc_radius - ARC_GAP
	fork_y = floor_y - arc_radius
	fork_half = 62.0
	crotch_y = fork_y + 64.0
	handle_end_y = minf(fork_y + h * 0.13, h - gesture - 10.0)

	# Ammo: a rack of spare balls left of the shaft, clear of every band.
	ammo_step = 26.0
	ammo_x = center_x - fork_half - 88.0
	ammo_top = fork_y + 22.0
	margin = 24.0


## Leftmost x the pouch may reach, so a band can never cross the ammo stack.
func pouch_min_x() -> float:
	return ammo_x + 34.0


func pouch_rest() -> Vector2:
	return Vector2(center_x, fork_y + 6.0)
