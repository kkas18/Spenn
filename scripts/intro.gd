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
	# Emblem: the slingshot mark with its gold ball.
	var lk := _k(_tl.logo, _tl.logo_d)
	var c := Vector2(w * 0.5, l.size.y * 0.4 + rise)
	var s := lerpf(0.96, 1.0, lk)
	var a := lk * fade
	if a > 0.0:
		_emblem(c, 1.35 * s, a)
	# Title: letters arrive one after another, tracking in and sharpening.
	var disp := hud.display_font()
	var word := Loc.t("game.title")
	var fs := 84
	var ty := c.y + 150.0
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
	var caps := hud.caps_font()
	var tg := _k(_tl.tag, 0.5) * fade
	if tg > 0.0:
		draw_string(caps, Vector2(0, ty + 46.0 + (1.0 - tg) * 6.0), Loc.t("game.tagline"), HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_CAPTION + 1, Color(Tok.TEXT_SECONDARY, tg))
	if _skippable and _t > 0.4 and _t < _tl.exit:
		var hk := minf(1.0, (_t - 0.4) / 0.4) * 0.6
		draw_string(caps, Vector2(0, l.size.y - l.safe_bottom - 60.0), Loc.t("menu.skip"), HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_CAPTION, Color(Tok.TEXT_FAINT, hk))


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


## The mark: fork, band and ball, lit from the upper left. The ball's
## highlight travels in from the right and settles as the accent lands.
func _emblem(c: Vector2, s: float, a: float) -> void:
	draw_set_transform(c, 0.0, Vector2(s, s))
	var fork := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := lerpf(-40.0, 40.0, t)
		fork.append(Vector2(x, -38.0 + 44.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	var shaft := PackedVector2Array([Vector2(0, 6), Vector2(0, 60)])
	for layer in 3:
		var off: Vector2 = [Vector2(4, 4), Vector2(1.2, 1.2), Vector2.ZERO][layer]
		var col: Color = [Color(0, 0, 0, 0.35 * a), Color(Pal.METAL_DARK, a), Color(Pal.METAL, a)][layer]
		var wd: float = [11.0, 11.0, 9.0][layer]
		var moved := PackedVector2Array()
		for p in fork:
			moved.append(p + off)
		draw_polyline(moved, col, wd, true)
		draw_line(shaft[0] + off, shaft[1] + off, col, wd + 2.0, true)
		draw_circle(shaft[1] + off, (wd + 2.0) * 0.5, col, true, -1.0, true)
	draw_polyline(fork, Color(Pal.METAL_LIGHT, 0.5 * a), 1.5, true)
	draw_line(Vector2(-40, -38), Vector2(0, -20), Color(Pal.BAND, a), 3.0, true)
	draw_line(Vector2(40, -38), Vector2(0, -20), Color(Pal.BAND, a), 3.0, true)
	var bc := Vector2(0, -20)
	draw_circle(bc + Vector2(3, 3), 12.0, Color(0, 0, 0, 0.35 * a), true, -1.0, true)
	draw_circle(bc, 12.0, Color(Pal.GOLD_DARK, a), true, -1.0, true)
	draw_circle(bc - Vector2(1.2, 1.2), 10.5, Color(Pal.GOLD, a), true, -1.0, true)
	var sweep := _k(_tl.logo + 0.2, _tl.accent - _tl.logo - 0.1, Motion.Ease.STANDARD)
	var hl := bc + Vector2(lerpf(7.0, -4.0, sweep), lerpf(-1.0, -4.0, sweep))
	draw_circle(hl, 3.6, Color(Pal.GOLD_LIGHT, 0.6 * a), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
