extends "res://tools/tests/harness.gd"
## The screen layout on the phones people have: tall and short, dense and
## coarse, with and without a camera cut-out or a reported gesture strip.
## On each, the slingshot must sit on the screen with the field above it,
## and a full pull must be within a finger's reach.

# name, screen px (w, h), dpi, safe top px, safe bottom px
const PHONES := [
	["Galaxy S23", 1080, 2340, 425, 80, 0],
	["Galaxy A54", 1080, 2340, 403, 80, 0],
	["Pixel 7", 1080, 2400, 416, 90, 48],
	["Galaxy S24 Ultra", 1440, 3120, 505, 100, 0],
	["a budget phone", 720, 1600, 270, 50, 0],
	["an old 16:9 phone", 1080, 1920, 420, 0, 0],
	["a 21:9 phone", 1080, 2520, 450, 90, 0],
	["a tablet", 1600, 2560, 280, 0, 0],
	["a folding phone, open", 1812, 2176, 373, 0, 0],
]


func _test() -> void:
	var layout_script := load("res://scripts/layout.gd") as Script
	for p: Array in PHONES:
		var l: RefCounted = layout_script.new()
		# The view keeps 720 px across, or 1280 px down on a wider screen
		# (stretch "expand"), and the rest follows from the screen's shape.
		var s: float = 720.0 / float(p[1])
		if float(p[2]) * s < 1280.0:
			s = 1280.0 / float(p[2])
		l.size = Vector2(float(p[1]) * s, float(p[2]) * s)
		l.scale = l.size.y / 1280.0
		l.center_x = l.size.x * 0.5
		l.dp = float(p[3]) / 160.0 * s
		l.safe_top = float(p[4]) * s
		l.safe_bottom = float(p[5]) * s
		l._place()
		var who: String = p[0]
		var strip: float = l.size.y - maxf(l.safe_bottom, l.MIN_GESTURE_DP * l.dp)
		var rest: Vector2 = l.pouch_rest()
		check(l.rail_y > l.safe_top and l.danger_y > l.rail_y + 500.0, "%s: the field lies under the top bar and is deep enough" % who)
		check(l.fork_y >= l.danger_y + 60.0, "%s: the slingshot stands clear below the line (%.0f px)" % [who, l.fork_y - l.danger_y])
		check(rest.y + l.max_pull <= strip, "%s: the pulled pouch stays above the gesture strip" % who)
		check(rest.y + l.drag_range <= strip, "%s: a full pull from the pouch fits above the gesture strip (%.0f of %.0f px)" % [who, l.drag_range, strip - rest.y])
		var cm: float = l.drag_range / l.dp / 160.0 * 2.54
		check(cm >= 1.3 and cm <= 3.6, "%s: a full pull is a comfortable length (%.1f cm)" % [who, cm])
		check(l.ammo_x - 14.0 >= 0.0 and l.pouch_min_x() < rest.x, "%s: the rack is on the screen, left of the pouch" % who)
		check(l.handle_end_y <= l.size.y, "%s: the handle ends on the screen" % who)
	finish()
