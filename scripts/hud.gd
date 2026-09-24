class_name Hud
extends CanvasLayer
## Top bar (pause · score · record on one baseline, level + progress below),
## hint, pause menu and game-over panel.

signal pause_pressed
signal resume_pressed
signal restart_pressed

var l: Layout
var bar: TopBar
var hint: Label
var _menu: Control
var _menu_title: Label
var _menu_score: Label
var _menu_sub: Label
var _btn_primary: Button
var _btn_restart: Button
var _btn_lang: Button
var _mode := ""                # "", "pause", "over"
var _theme: Theme
var _font_caps: FontVariation
var _font_num: FontVariation


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_fonts()
	bar = TopBar.new()
	bar.hud = self
	add_child(bar)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font", _font_caps)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Pal.INK_DIM)
	add_child(hint)
	_build_menu()
	Loc.language_changed.connect(_refresh_text)
	_refresh_text()


func setup(layout: Layout) -> void:
	l = layout
	bar.position = Vector2.ZERO
	bar.size = Vector2(l.size.x, l.top_bar_h)
	hint.size = Vector2(l.size.x, 30)
	hint.position = Vector2(0, l.fork_y - 84.0)
	_menu.size = l.size
	# Every touch target is at least 48 dp.
	var min_h := maxf(60.0, 48.0 * l.dp)
	for b in [_btn_primary, _btn_restart, _btn_lang]:
		b.custom_minimum_size = Vector2(maxf(280.0, 48.0 * l.dp), min_h)


func caps_font() -> Font:
	return _font_caps


func num_font() -> Font:
	return _font_num


func show_pause(on: bool) -> void:
	_mode = "pause" if on else ""
	_refresh_text()
	_menu.visible = on
	if on:
		_btn_primary.grab_focus.call_deferred()


func show_game_over(score: int, is_record: bool) -> void:
	_mode = "over"
	_refresh_text()
	_menu_score.text = str(score)
	_menu_sub.text = Loc.t("new_record") if is_record else "%s  %d" % [Loc.t("record"), Loc.record]
	_menu_sub.add_theme_color_override("font_color", Pal.GOLD if is_record else Pal.INK_DIM)
	_menu.visible = true


func hide_menu() -> void:
	_mode = ""
	_menu.visible = false


func _refresh_text() -> void:
	hint.text = Loc.t("hint")
	_btn_restart.text = Loc.t("restart")
	_btn_lang.text = Loc.t("language")
	if _mode == "over":
		_menu_title.text = Loc.t("game_over")
		_btn_primary.text = Loc.t("play_again")
		_menu_score.visible = true
		_menu_sub.visible = true
		_btn_restart.visible = false
		_btn_lang.visible = false
	else:
		_menu_title.text = Loc.t("paused")
		_btn_primary.text = Loc.t("resume")
		_menu_score.visible = false
		_menu_sub.visible = false
		_btn_restart.visible = true
		_btn_lang.visible = true
	bar.queue_redraw()


func _on_primary() -> void:
	Sfx.play("tick")
	if _mode == "over":
		restart_pressed.emit()
	else:
		resume_pressed.emit()


func _build_fonts() -> void:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Inter", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	sys.font_weight = 600
	_font_caps = FontVariation.new()
	_font_caps.base_font = sys
	_font_caps.spacing_glyph = 2
	_font_num = FontVariation.new()
	_font_num.base_font = sys
	_font_num.opentype_features = {"tnum": 1}
	_theme = Theme.new()
	_theme.default_font = _font_caps
	_theme.default_font_size = 18
	var normal := _box(Color("161A21"), Color("2A303A"))
	var hover := _box(Color("1B2029"), Color("363D49"))
	var pressed := _box(Color("12151B"), Color("D4A94F", 0.6))
	for t in ["normal", "focus"]:
		_theme.set_stylebox(t, "Button", normal if t == "normal" else hover)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_color("font_color", "Button", Pal.INK)
	_theme.set_color("font_hover_color", "Button", Pal.INK)
	_theme.set_color("font_pressed_color", "Button", Pal.GOLD_LIGHT)
	_theme.set_color("font_focus_color", "Button", Pal.INK)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_offset = Pal.SHADOW_OFFSET
	s.shadow_size = 2
	s.anti_aliasing = true
	return s


func _build_menu() -> void:
	_menu = Control.new()
	_menu.theme = _theme
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.045, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_menu_title = _label(18, Pal.INK_DIM, _font_caps)
	_menu_score = _label(72, Pal.INK, _font_num)
	_menu_sub = _label(16, Pal.INK_DIM, _font_caps)
	box.add_child(_menu_title)
	box.add_child(_menu_score)
	box.add_child(_menu_sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	_btn_primary = _button(_on_primary)
	_btn_restart = _button(func() -> void: Sfx.play("tick"); restart_pressed.emit())
	_btn_lang = _button(func() -> void: Sfx.play("tick"); Loc.toggle_language())
	box.add_child(_btn_primary)
	box.add_child(_btn_restart)
	box.add_child(_btn_lang)


func _label(font_size: int, col: Color, font: Font) -> Label:
	var lb := Label.new()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	return lb


func _button(cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 60)
	b.pressed.connect(cb)
	return b


## Custom-drawn top bar so pause, score and record share one baseline.
class TopBar extends Control:
	var hud: Hud
	var score := 0
	var shown_score := 0.0
	var level := 1
	var progress := 0.0
	var shown_progress := 0.0
	var pulse := 0.0             # 0..1, decays; drives the 1.08 score pulse
	var show_fps := false        # toggled by triple-tapping the record
	var _taps: Array[int] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func pause_rect() -> Rect2:
		var l := hud.l
		var s := maxf(48.0 * l.dp, 64.0)
		var c := Vector2(l.margin + 10.0, l.score_baseline - 14.0)
		return Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)).abs()

	func record_rect() -> Rect2:
		var l := hud.l
		var s := maxf(48.0 * l.dp, 64.0)
		return Rect2(l.size.x - l.margin - s * 2.0, l.score_baseline - s * 0.7, s * 2.0 + l.margin, s)

	func _gui_input(e: InputEvent) -> void:
		var press: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)
		if not press:
			return
		if pause_rect().has_point(e.position):
			accept_event()
			hud.pause_pressed.emit()
		elif record_rect().has_point(e.position):
			accept_event()
			var now := Time.get_ticks_msec()
			_taps.append(now)
			while _taps.size() > 0 and now - _taps[0] > 900:
				_taps.pop_front()
			if _taps.size() >= 3:
				_taps.clear()
				show_fps = not show_fps

	func _has_point(p: Vector2) -> bool:
		return hud != null and hud.l != null and (pause_rect().has_point(p) or record_rect().has_point(p))

	func _process(delta: float) -> void:
		var diff := float(score) - shown_score
		if absf(diff) > 0.01:
			shown_score += signf(diff) * maxf(absf(diff) * Pal.damp(0.18, delta), minf(absf(diff), 60.0 * delta))
		pulse = maxf(0.0, pulse - delta / 0.18)
		shown_progress = lerpf(shown_progress, progress, Pal.damp(0.15, delta))
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.l == null:
			return
		var l := hud.l
		var base := l.score_baseline
		var w := l.size.x
		var num := hud.num_font()
		var caps := hud.caps_font()
		# Pause: two bars resting on the baseline.
		var px := l.margin + 3.0
		for i in 2:
			var r := Rect2(px + i * 11.0, base - 24.0, 6.0, 24.0)
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Pal.SHADOW)
			draw_rect(r, Pal.INK_DIM)
		# Score (centre), pulsing about its own baseline centre.
		var txt := str(int(round(shown_score)))
		var fs := 54
		var s := 1.0 + 0.08 * sin(pulse * PI)
		var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(w * 0.5, base), 0.0, Vector2(s, s))
		draw_string(num, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.INK)
		draw_set_transform(Vector2.ZERO)
		# Record (right) on the same baseline.
		var rec := str(Loc.record)
		var rw := num.get_string_size(rec, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(num, Vector2(w - l.margin - rw, base), rec, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.INK_DIM)
		var lab := Loc.t("record")
		var lw := caps.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(caps, Vector2(w - l.margin - rw - 10.0 - lw, base), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.INK_FAINT)
		# Level label 8 px under the score, progress bar 8 px under the label.
		var lv := Loc.t("level") % level
		var ly := base + 8.0 + caps.get_ascent(14)
		draw_string(caps, Vector2(0, ly), lv, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Pal.INK_DIM)
		var bw := 132.0
		var by := ly + caps.get_descent(14) + 8.0
		var track := Rect2(w * 0.5 - bw * 0.5, by, bw, 3.0)
		draw_rect(track, Color(Pal.INK_FAINT, 0.45))
		draw_rect(Rect2(track.position, Vector2(bw * clampf(shown_progress, 0.0, 1.0), 3.0)), Pal.INK_DIM)
		if show_fps:
			var fps := "%d FPS" % Engine.get_frames_per_second()
			draw_string(caps, Vector2(0, ly), fps, HORIZONTAL_ALIGNMENT_RIGHT, w - l.margin, 12, Pal.INK_FAINT)
