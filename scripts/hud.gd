class_name Hud
extends CanvasLayer
## Everything drawn over the play field: the top bar (pause · score with
## streak multiplier · knots, level/wave + progress below), the level card,
## the title overlay, the pause menu and the results screen.
## Type: Fraunces (display, numerals) over Manrope (tracked caps), both OFL.

signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed

enum Mode { NONE, TITLE, PAUSE, OVER }

const CARD_IN := 0.25
const CARD_HOLD := 1.0
const CARD_OUT := 0.35

var l: Layout
var bar: TopBar
var overlay: Overlay
var mode := Mode.NONE

var _menu: Control
var _menu_title: Label
var _menu_score: Label
var _menu_badge: PanelContainer
var _menu_badge_label: Label
var _menu_record: Label
var _stats: GridContainer
var _stat_values: Array[Label] = []
var _stat_names: Array[Label] = []
var _btn_primary: Button
var _btn_restart: Button
var _btn_menu: Button
var _btn_lang: Button
var _btn_sound: Button
var _title_bar: HBoxContainer
var _t_sound: Button
var _t_lang: Button
var _theme: Theme
var _font_caps: FontVariation
var _font_num: FontVariation
var _font_display: FontVariation


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_fonts()
	bar = TopBar.new()
	bar.hud = self
	add_child(bar)
	overlay = Overlay.new()
	overlay.hud = self
	add_child(overlay)
	_build_title_bar()
	_build_menu()
	Loc.language_changed.connect(_refresh_text)
	_refresh_text()


func setup(layout: Layout) -> void:
	l = layout
	bar.position = Vector2.ZERO
	bar.size = Vector2(l.size.x, l.top_bar_h)
	overlay.position = Vector2.ZERO
	overlay.size = l.size
	_menu.size = l.size
	# Every touch target is at least 48 dp.
	var min_h := maxf(60.0, 48.0 * l.dp)
	for b in [_btn_primary, _btn_restart, _btn_menu, _btn_lang, _btn_sound]:
		b.custom_minimum_size = Vector2(maxf(300.0, 48.0 * l.dp), min_h)
	for b in [_t_sound, _t_lang]:
		b.custom_minimum_size = Vector2(maxf(64.0, 48.0 * l.dp), maxf(64.0, 48.0 * l.dp))
	_title_bar.position = Vector2(l.margin, l.safe_top + 24.0)
	_title_bar.size = Vector2(l.size.x - l.margin * 2.0, maxf(64.0, 48.0 * l.dp))


func caps_font() -> Font:
	return _font_caps


func num_font() -> Font:
	return _font_num


func display_font() -> Font:
	return _font_display


func show_title() -> void:
	mode = Mode.TITLE
	bar.visible = false
	_title_bar.visible = true
	_menu.visible = false
	overlay.title_t = 0.0
	_refresh_text()


func show_play() -> void:
	mode = Mode.NONE
	bar.visible = true
	_title_bar.visible = false
	_menu.visible = false


func show_pause(on: bool) -> void:
	mode = Mode.PAUSE if on else Mode.NONE
	_refresh_text()
	_menu.visible = on
	if on:
		_btn_primary.grab_focus.call_deferred()


func show_results(score: int, is_record: bool, reason: String, stats: Array) -> void:
	mode = Mode.OVER
	_refresh_text()
	_menu_title.text = reason
	_menu_score.text = _group(score)
	_menu_badge.visible = is_record
	_menu_record.visible = not is_record
	_menu_record.text = "%s  %s" % [Loc.t("record"), _group(Loc.record)]
	for i in mini(stats.size(), _stat_values.size()):
		_stat_values[i].text = str(stats[i])
	_menu.visible = true


func hide_menu() -> void:
	if mode != Mode.TITLE:
		mode = Mode.NONE
	_menu.visible = false


## Big centred card: level number (or the boss name) and a line under it.
func card(title: String, sub: String) -> void:
	overlay.card_title = title
	overlay.card_sub = sub
	overlay.card_t = 0.0


static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _refresh_text() -> void:
	_btn_restart.text = Loc.t("restart")
	_btn_menu.text = Loc.t("menu")
	_btn_lang.text = Loc.t("language")
	_btn_sound.text = Loc.t("sound_on") if Loc.sound_on else Loc.t("sound_off")
	_t_lang.text = "NO" if Loc.lang == "no" else "EN"
	_t_sound.text = _btn_sound.text
	_menu_badge_label.text = Loc.t("new_record")
	var names := [Loc.t("stat_level"), Loc.t("stat_acc"), Loc.t("stat_streak"), Loc.t("stat_cuts")]
	for i in _stat_names.size():
		_stat_names[i].text = names[i]
	var over := mode == Mode.OVER
	_menu_score.visible = over
	_stats.visible = over
	_btn_restart.visible = not over
	_btn_lang.visible = not over
	_btn_sound.visible = not over
	_menu_badge.visible = _menu_badge.visible and over
	if over:
		_btn_primary.text = Loc.t("play_again")
		_btn_primary.theme_type_variation = &"PrimaryButton"
	else:
		_menu_title.text = Loc.t("paused")
		_btn_primary.text = Loc.t("resume")
		_btn_primary.theme_type_variation = &""
		_menu_record.visible = true
		_menu_record.text = "%s  %s" % [Loc.t("record"), _group(Loc.record)]
	bar.queue_redraw()
	overlay.queue_redraw()


func _on_primary() -> void:
	Sfx.play("tick")
	if mode == Mode.OVER:
		restart_pressed.emit()
	else:
		resume_pressed.emit()


func _build_fonts() -> void:
	var ts := TextServerManager.get_primary_interface()
	var fraunces: Font = load("res://fonts/Fraunces.ttf")
	var manrope: Font = load("res://fonts/Manrope.ttf")
	_font_caps = FontVariation.new()
	_font_caps.base_font = manrope
	_font_caps.variation_opentype = {ts.name_to_tag("wght"): 700}
	_font_caps.spacing_glyph = 2
	_font_num = FontVariation.new()
	_font_num.base_font = fraunces
	_font_num.variation_opentype = {ts.name_to_tag("wght"): 600, ts.name_to_tag("opsz"): 72}
	_font_num.opentype_features = {ts.name_to_tag("tnum"): 1, ts.name_to_tag("lnum"): 1}
	_font_display = FontVariation.new()
	_font_display.base_font = fraunces
	_font_display.variation_opentype = {ts.name_to_tag("wght"): 600, ts.name_to_tag("opsz"): 144}
	_theme = Theme.new()
	_theme.default_font = _font_caps
	_theme.default_font_size = 17
	var normal := _box(Color("161A21"), Color("2A303A"))
	var hover := _box(Color("1B2029"), Color("363D49"))
	var pressed := _box(Color("12151B"), Color("D4A94F", 0.6))
	_theme.set_stylebox("normal", "Button", normal)
	_theme.set_stylebox("focus", "Button", hover)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_color("font_color", "Button", Pal.INK)
	_theme.set_color("font_hover_color", "Button", Pal.INK)
	_theme.set_color("font_pressed_color", "Button", Pal.GOLD_LIGHT)
	_theme.set_color("font_focus_color", "Button", Pal.INK)
	# Primary: the one gold action on a screen.
	_theme.set_type_variation(&"PrimaryButton", &"Button")
	_theme.set_stylebox("normal", "PrimaryButton", _box(Pal.GOLD, Pal.GOLD))
	_theme.set_stylebox("hover", "PrimaryButton", _box(Pal.GOLD_LIGHT, Pal.GOLD_LIGHT))
	_theme.set_stylebox("focus", "PrimaryButton", _box(Pal.GOLD_LIGHT, Pal.GOLD_LIGHT))
	_theme.set_stylebox("pressed", "PrimaryButton", _box(Pal.GOLD_DARK, Pal.GOLD_DARK))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(c, "PrimaryButton", Pal.BG)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(14)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_offset = Pal.SHADOW_OFFSET
	s.shadow_size = 2
	s.anti_aliasing = true
	return s


func _build_title_bar() -> void:
	_title_bar = HBoxContainer.new()
	_title_bar.theme = _theme
	_title_bar.visible = false
	add_child(_title_bar)
	_t_sound = Button.new()
	_t_sound.pressed.connect(func() -> void: Loc.toggle_sound(); Sfx.play("tick"))
	_title_bar.add_child(_t_sound)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar.add_child(gap)
	_t_lang = Button.new()
	_t_lang.pressed.connect(func() -> void: Sfx.play("tick"); Loc.toggle_language())
	_title_bar.add_child(_t_lang)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.theme = _theme
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.045, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_menu_title = _label(15, Pal.INK_DIM, _font_caps)
	_menu_score = _label(96, Pal.INK, _font_num)
	box.add_child(_menu_title)
	box.add_child(_menu_score)
	_menu_badge = PanelContainer.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Pal.GOLD
	badge_box.set_corner_radius_all(12)
	badge_box.content_margin_left = 14
	badge_box.content_margin_right = 14
	badge_box.content_margin_top = 4
	badge_box.content_margin_bottom = 4
	_menu_badge.add_theme_stylebox_override("panel", badge_box)
	_menu_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_badge_label = _label(14, Pal.BG, _font_caps)
	_menu_badge.add_child(_menu_badge_label)
	box.add_child(_menu_badge)
	_menu_record = _label(15, Pal.INK_DIM, _font_caps)
	box.add_child(_menu_record)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 12)
	var tile := StyleBoxFlat.new()
	tile.bg_color = Color("141820")
	tile.border_color = Color("232933")
	tile.set_border_width_all(1)
	tile.set_corner_radius_all(14)
	tile.set_content_margin_all(16)
	for i in 4:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", tile)
		p.custom_minimum_size = Vector2(144, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var n := _label(12, Pal.INK_DIM, _font_caps)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var val := _label(34, Pal.INK, _font_num)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(n)
		v.add_child(val)
		p.add_child(v)
		_stats.add_child(p)
		_stat_names.append(n)
		_stat_values.append(val)
	box.add_child(_stats)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)
	_btn_primary = _button(_on_primary)
	_btn_restart = _button(func() -> void: Sfx.play("tick"); restart_pressed.emit())
	_btn_menu = _button(func() -> void: Sfx.play("tick"); menu_pressed.emit())
	_btn_sound = _button(func() -> void: Loc.toggle_sound(); Sfx.play("tick"))
	_btn_lang = _button(func() -> void: Sfx.play("tick"); Loc.toggle_language())
	for b in [_btn_primary, _btn_restart, _btn_menu, _btn_sound, _btn_lang]:
		box.add_child(b)


func _label(font_size: int, col: Color, font: Font) -> Label:
	var lb := Label.new()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	return lb


func _button(cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 60)
	b.pressed.connect(cb)
	return b


## Custom-drawn top bar: pause, score and knots share one baseline.
class TopBar extends Control:
	var hud: Hud
	var score := 0
	var shown_score := 0.0
	var mult := 1
	var lives := 3
	var level := 1
	var wave := 1
	var waves := 1
	var progress := 0.0
	var shown_progress := 0.0
	var pulse := 0.0             # 0..1, decays; drives the 1.08 score pulse
	var badge_pop := 0.0
	var knot_shake := 0.0
	var show_fps := false        # toggled by triple-tapping the knots
	var _taps: Array[int] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_mult(m: int) -> void:
		if m != mult:
			badge_pop = 1.0
		mult = m

	func lose_life(n: int) -> void:
		lives = n
		knot_shake = 1.0

	func pause_rect() -> Rect2:
		var l := hud.l
		var s := maxf(48.0 * l.dp, 64.0)
		var c := Vector2(l.margin + 10.0, l.score_baseline - 14.0)
		return Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)).abs()

	func knots_rect() -> Rect2:
		var l := hud.l
		var s := maxf(48.0 * l.dp, 64.0)
		return Rect2(l.size.x - l.margin - s * 1.6, l.score_baseline - s * 0.7, s * 1.6 + l.margin, s)

	func _gui_input(e: InputEvent) -> void:
		var press: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)
		if not press:
			return
		if pause_rect().has_point(e.position):
			accept_event()
			hud.pause_pressed.emit()
		elif knots_rect().has_point(e.position):
			accept_event()
			var now := Time.get_ticks_msec()
			_taps.append(now)
			while _taps.size() > 0 and now - _taps[0] > 900:
				_taps.pop_front()
			if _taps.size() >= 3:
				_taps.clear()
				show_fps = not show_fps

	func _has_point(p: Vector2) -> bool:
		return hud != null and hud.l != null and (pause_rect().has_point(p) or knots_rect().has_point(p))

	func _process(delta: float) -> void:
		var diff := float(score) - shown_score
		if absf(diff) > 0.01:
			shown_score += signf(diff) * maxf(absf(diff) * Pal.damp(0.18, delta), minf(absf(diff), 60.0 * delta))
		pulse = maxf(0.0, pulse - delta / 0.18)
		badge_pop = maxf(0.0, badge_pop - delta / 0.3)
		knot_shake = maxf(0.0, knot_shake - delta / 0.6)
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
		var txt := Hud._group(int(round(shown_score)))
		var fs := 52
		var s := 1.0 + 0.08 * sin(pulse * PI)
		var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(w * 0.5, base), 0.0, Vector2(s, s))
		draw_string(num, Vector2(-tw * 0.5 + 2.0, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.SHADOW)
		draw_string(num, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.INK)
		draw_set_transform(Vector2.ZERO)
		# Streak multiplier: a gold pill beside the score (gold = power).
		if mult > 1:
			var mt := "×%d" % mult
			var mw := caps.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
			var bs := 1.0 + 0.25 * sin(badge_pop * PI)
			var bc := Vector2(w * 0.5 + tw * 0.5 * s + 10.0 + mw * 0.5, base - 12.0)
			draw_set_transform(bc, 0.0, Vector2(bs, bs))
			var rr := Rect2(-mw * 0.5, -12.0, mw, 24.0)
			draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size), Pal.SHADOW)
			draw_rect(rr, Pal.GOLD)
			draw_string(caps, Vector2(-mw * 0.5 + 8.0, 6.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.BG)
			draw_set_transform(Vector2.ZERO)
		# Knots (lives) on the right, same baseline.
		for i in 3:
			var cx := w - l.margin - 8.0 - (2 - i) * 22.0
			var shake := 0.0
			if i == lives and knot_shake > 0.0:
				shake = sin(knot_shake * 40.0) * 4.0 * knot_shake
			var c := Vector2(cx + shake, base - 10.0)
			if i < lives:
				draw_arc(c + Vector2(1.5, 1.5), 6.0, 0.0, TAU, 20, Pal.SHADOW, 2.6, true)
				draw_arc(c, 6.0, 0.0, TAU, 20, Pal.INK, 2.6, true)
				draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), Pal.INK_DIM, 1.2, true)
			else:
				draw_line(c + Vector2(-7, 0), c + Vector2(-2, 0), Pal.INK_FAINT, 2.4, true)
				draw_line(c + Vector2(2, 0), c + Vector2(7, 0), Pal.INK_FAINT, 2.4, true)
		# Level · wave label 8 px under the score, progress bar 8 px under it.
		var lv := Loc.t("level_wave") % [level, wave, waves] if waves > 1 else Loc.t("level") % level
		var ly := base + 10.0 + caps.get_ascent(13)
		draw_string(caps, Vector2(0, ly), lv, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Pal.INK_DIM)
		var bw := 132.0
		var by := ly + caps.get_descent(13) + 8.0
		var track := Rect2(w * 0.5 - bw * 0.5, by, bw, 3.0)
		draw_rect(track, Color(Pal.INK_FAINT, 0.45))
		draw_rect(Rect2(track.position, Vector2(bw * clampf(shown_progress, 0.0, 1.0), 3.0)), Pal.INK_DIM)
		if show_fps:
			var fps := "%d FPS" % Engine.get_frames_per_second()
			draw_string(caps, Vector2(0, ly), fps, HORIZONTAL_ALIGNMENT_RIGHT, w - l.margin, 11, Pal.INK_FAINT)


## Non-interactive layer: title copy, level card and the aim hint.
class Overlay extends Control:
	var hud: Hud
	var card_title := ""
	var card_sub := ""
	var card_t := 99.0
	var title_t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		card_t += delta
		title_t += delta
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.l == null:
			return
		var l := hud.l
		var w := l.size.x
		var caps := hud.caps_font()
		var num := hud.num_font()
		if hud.mode == Hud.Mode.TITLE:
			var y := l.rail_y + l.play_h * 0.66
			draw_string(caps, Vector2(0, y), Loc.t("record"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Pal.INK_DIM)
			var rec := Hud._group(Loc.record)
			draw_string(num, Vector2(2, y + 58.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 56, Pal.SHADOW)
			draw_string(num, Vector2(0, y + 56.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 56, Pal.INK)
			var a := 0.55 + 0.45 * sin(title_t * 2.4)
			draw_string(caps, Vector2(0, l.fork_y - 70.0), Loc.t("play"), HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(Pal.GOLD, a))
		var total := Hud.CARD_IN + Hud.CARD_HOLD + Hud.CARD_OUT
		if card_t < total and card_title != "":
			var k := 1.0
			if card_t < Hud.CARD_IN:
				k = ease(card_t / Hud.CARD_IN, 0.4)
			elif card_t > Hud.CARD_IN + Hud.CARD_HOLD:
				k = 1.0 - (card_t - Hud.CARD_IN - Hud.CARD_HOLD) / Hud.CARD_OUT
			var cy := l.rail_y + l.play_h * 0.46 + (1.0 - k) * 14.0
			var disp := hud.display_font()
			draw_string(disp, Vector2(3, cy + 3), card_title, HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(0, 0, 0, 0.35 * k))
			draw_string(disp, Vector2(0, cy), card_title, HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(Pal.INK, k))
			draw_string(caps, Vector2(0, cy + 36.0), card_sub, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(Pal.INK_DIM, k))
