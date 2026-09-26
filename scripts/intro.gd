class_name Intro
extends Control
## Launch sequence: dark ground → emblem (fade + 96→100 % with ease-out, the
## ball's highlight sweeping into place with a sound accent) → localized
## title (per-letter stagger: opacity, tracking, blur→sharp, 8 px rise) →
## tagline → hold → the lamp flickers on (the dark ground blinks twice and
## lifts) to reveal the live menu world.
## Full length on first launch; a short version after that, and a tap skips.

signal exiting                 # the ground starts to fade: bring in the menu
signal finished

const FULL := {"logo": 0.3, "logo_d": 0.9, "accent": 0.85, "title": 1.2, "title_d": 0.6,
	"tag": 1.7, "exit": 2.6, "exit_d": 1.0}
const SHORT := {"logo": 0.1, "logo_d": 0.45, "accent": 0.35, "title": 0.25, "title_d": 0.4,
	"tag": 0.45, "exit": 0.9, "exit_d": 0.6}

var hud: Hud
var _tl: Dictionary = FULL
var _t := -1.0
var _skippable := false
var _accent_done := false
var _exit_sent := false
var _clicks := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func play(full: bool) -> void:
	_tl = FULL if full and not Prefs.reduced_motion else SHORT
	_skippable = Prefs.intro_seen
	_t = 0.0
	_accent_done = false
	_exit_sent = false
	_clicks = 0
	visible = true


func _gui_input(e: InputEvent) -> void:
	var press: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)
	if press and _skippable and _t < _tl.exit:
		accept_event()
		skip()


func skip() -> void:
	if _t < _tl.exit:
		_t = _tl.exit


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta / maxf(Engine.time_scale, 0.001)
	if not _accent_done and _t >= _tl.accent:
		_accent_done = true
		Sfx.play("reveal")
		Music.start()
	if not _exit_sent and _t >= _tl.exit:
		_exit_sent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		exiting.emit()
	# The lamp's switch: a click as each flicker starts.
	var u: float = (_t - _tl.exit) / _tl.exit_d
	if _clicks < 2 and u >= [0.0, 0.16][_clicks] and not Prefs.reduced_motion:
		Sfx.play("click", 0.6 + 0.1 * _clicks, -6.0)
		_clicks += 1
	if _t >= _tl.exit + _tl.exit_d:
		_t = -1.0
		visible = false
		Prefs.mark_intro_seen()
		finished.emit()
		return
	queue_redraw()


func _k(start: float, d: float, e := Motion.Ease.ENTER) -> float:
	return Motion.ease_value(e, (_t - start) / d)


func _draw() -> void:
	if hud == null or hud.l == null or _t < 0.0:
		return
	var l := hud.l
	var w := l.size.x
	var u: float = (_t - _tl.exit) / _tl.exit_d
	var out := _k(_tl.exit, _tl.exit_d * 0.15, Motion.Ease.EXIT)
	# The lamp comes on: the dark ground blinks twice and lifts away,
	# revealing the menu world.
	draw_rect(Rect2(Vector2.ZERO, l.size), Color(Tok.BACKGROUND, _ground(u)))
	var fade := 1.0 - out
	var rise := -14.0 * out
	# Emblem: the slingshot mark on a brass medallion.
	var lk := _k(_tl.logo, _tl.logo_d)
	var c := Vector2(w * 0.5, l.size.y * 0.35 + rise)
	var s := lerpf(0.96, 1.0, lk)
	var a := lk * fade
	if a > 0.0:
		_emblem(c, 1.6 * s, a)
	# Title: letters arrive one after another, tracking in and sharpening.
	var disp := hud.display_font()
	var word := Loc.t("game.title")
	var fs := 84
	var ty := c.y + 206.0
	var n := word.length()
	var total := 0.0
	for i in n:
		total += disp.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for i in n:
		var lt := _k(_tl.title + i * 0.06, _tl.title_d)
		var track := lerpf(26.0, 10.0, lt)
		var width := total + track * (n - 1)
		var x := w * 0.5 - width * 0.5
		for j in i:
			x += disp.get_string_size(word[j], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + track
		var la := lt * fade
		if la <= 0.0:
			continue
		var y := ty + lerpf(8.0, 0.0, lt)
		var col := Tok.PRIMARY if i == Loc.title_accent() else Tok.TEXT_PRIMARY
		var blur := lerpf(4.0, 0.0, lt)
		if blur > 0.3:
			for g in [-1.0, 1.0]:
				draw_string(disp, Vector2(x + g * blur, y), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, la * 0.25))
		draw_string(disp, Vector2(x + 3, y + 3), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * la))
		draw_string(disp, Vector2(x, y), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, la))
	# Tagline: a quiet sentence under a short brass rule.
	var body := hud.body_font()
	var tg := _k(_tl.tag, 0.5) * fade
	if tg > 0.0:
		var ry := ty + 34.0
		var half := 28.0 * tg
		draw_line(Vector2(w * 0.5 - half, ry), Vector2(w * 0.5 + half, ry), Color(Tok.PRIMARY, 0.7 * tg), 1.4, true)
		draw_string(body, Vector2(0, ry + 38.0 + (1.0 - tg) * 6.0), Hud.sentence(Loc.t("game.tagline")), HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(Tok.TEXT_SECONDARY, tg))
	if _skippable and _t > 0.4 and _t < _tl.exit:
		var hk := minf(1.0, (_t - 0.4) / 0.4) * 0.7
		draw_string(body, Vector2(0, l.size.y - l.safe_bottom - 60.0), Hud.sentence(Loc.t("menu.skip")), HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color(Tok.TEXT_FAINT, hk))


## Opacity of the dark ground at exit progress `u`: a flicker (dim, back,
## dimmer, back) and then a slow lift. A plain fade with reduced motion.
func _ground(u: float) -> float:
	if u <= 0.0:
		return 1.0
	if Prefs.reduced_motion:
		return 1.0 - Motion.ease_value(Motion.Ease.EXIT, u)
	if u < 0.08:
		return 0.5
	if u < 0.16:
		return 0.93
	if u < 0.22:
		return 0.3
	if u < 0.3:
		return 0.8
	return 0.8 * (1.0 - Motion.ease_value(Motion.Ease.STANDARD, (u - 0.3) / 0.7))


## The mark: a brass medallion with the fork engraved in its face, the
## amber band drawn back and the gold ball in the pouch, lit from the upper
## left. The ball's highlight travels in from the right and settles as the
## accent lands; a glint runs round the rim with it.
func _emblem(c: Vector2, s: float, a: float) -> void:
	draw_set_transform(c, 0.0, Vector2(s, s))
	const R := 58.0
	Hud.brass_disc(self, Vector2.ZERO, R, Color("0E1015"), a)
	# The fork: a Y in brass, set in a dark groove.
	var fork := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := lerpf(-24.0, 24.0, t)
		fork.append(Vector2(x, -26.0 + 30.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	var top := Vector2(0, 4)
	var foot := Vector2(0, 34)
	for layer in 3:
		var off: Vector2 = [Vector2(2, 3), Vector2.ZERO, Vector2(-0.6, -0.6)][layer]
		var col: Color = [Color(0, 0, 0, 0.5 * a), Color(Hud.TopBar.BRASS_DEEP, a), Color(Tok.PRIMARY, a)][layer]
		var wd: float = [9.0, 9.0, 6.0][layer]
		var moved := PackedVector2Array()
		for p in fork:
			moved.append(p + off)
		draw_polyline(moved, col, wd, true)
		draw_line(top + off, foot + off, col, wd + 1.0, true)
		draw_circle(foot + off, (wd + 1.0) * 0.5, col, true, -1.0, true)
	draw_polyline(fork.slice(0, 7), Color(Tok.PRIMARY_HI, 0.7 * a), 1.3, true)
	for tip in [fork[0], fork[12]]:
		draw_circle(tip, 4.2, Color(Tok.PRIMARY_HI, a), true, -1.0, true)
	# The band, drawn back to the ball.
	var bc := Vector2(0, -12)
	for tip in [fork[0], fork[12]]:
		draw_line(tip + Vector2(0.8, 1.5), bc + Vector2(0.8, 1.5), Color(0, 0, 0, 0.4 * a), 2.6, true)
		draw_line(tip, bc, Color(Pal.BAND, a), 3.0, true)
	draw_circle(bc + Vector2(2, 2.5), 9.5, Color(0, 0, 0, 0.4 * a), true, -1.0, true)
	draw_circle(bc, 9.5, Color(Pal.GOLD_DARK, a), true, -1.0, true)
	draw_circle(bc - Vector2(0.8, 0.8), 8.2, Color(Pal.GOLD, a), true, -1.0, true)
	var sweep := _k(_tl.logo + 0.2, _tl.accent - _tl.logo - 0.1, Motion.Ease.STANDARD)
	var hl := bc + Vector2(lerpf(5.0, -3.0, sweep), lerpf(-0.5, -3.0, sweep))
	draw_circle(hl, 2.6, Color(Pal.GOLD_LIGHT, 0.7 * a), true, -1.0, true)
	# The rim glint: once round with the accent, then gone.
	if sweep > 0.0 and sweep < 1.0:
		var g := PI * 1.1 + TAU * sweep
		var ga := sin(PI * sweep) * a
		draw_arc(Vector2.ZERO, R - 1.5, g - 0.35, g + 0.35, 12, Color(Tok.PRIMARY_HI, 0.9 * ga), 2.2, true)
	draw_set_transform(Vector2.ZERO)
