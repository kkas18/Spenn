class_name Hud
extends CanvasLayer
## The presentation layer, built on design tokens (`Tok`) and the motion
## system (`Motion`): the minimal in-game bar, cards and enemy intros, the
## blurred scrim, pause / settings / game-over panels, the resume
## countdown, the main-menu chrome and the launch intro. All text comes from
## `Loc` and is refreshed live on a language change.

signal resume_pressed
signal restart_pressed
signal menu_pressed

const INTRO_TIME := 3.2

var l: Layout
var bar: TopBar
var overlay: Overlay
var intro_seq: Intro
var locked := false            # input lock while a transition runs

var _scrim: ColorRect
var _scrim_mat: ShaderMaterial
var _pause: Control
var _pause_box: Control
var _settings: Control
var _settings_box: Control
var _settings_from := ""
var _over: GameOver
var _menu_bar: HBoxContainer
var _theme: Theme
var _font_caps: FontVariation
var _font_num: FontVariation
var _font_display: FontVariation

var _font_body: FontVariation
var _font_body_b: FontVariation

var _pause_title: Label
var _pause_best: Label
var _pause_hint: Label
var _pause_vals: Array[Label] = []   # score, wave, time
var _pause_caps: Array[Label] = []
var _pause_icon_caps: Array[Label] = []
var _b_resume: UIButton
var _b_restart: IconBtn
var _b_settings: IconBtn
var _b_menu: IconBtn
var _s_title: Label
var _s_secs: Array[Label] = []
var _s_rows: Array[SetRow] = []
var _s_credits: Label
var _s_back: IconBtn
var _m_settings: Token
var _m_lang: Lever
var _m_stats: Token
var _m_skins: Token
var _m_daily: IconBtn
var run_secs := 0              # the run's time so far, for the pause summary
var daily := false             # the menu's mode: the next run is the daily challenge
var flow := 0.0                # the flow meter, 0..1 (set by the game)
var perk_order: Array[String] = []  # perks won this run, in order (the tray)
var perk_levels := {}
var flow_hot := false          # flow is on
var _stats: Control
var _stats_box: VBoxContainer
var _skins: Control
var _skins_box: VBoxContainer


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_fonts()
	bar = TopBar.new()
	bar.hud = self
	add_child(bar)
	_scrim = ColorRect.new()
	_scrim_mat = ShaderMaterial.new()
	_scrim_mat.shader = preload("res://shaders/scrim.gdshader")
	_scrim.material = _scrim_mat
	_scrim_mat.set_shader_parameter("amount", 0.0)
	_scrim_mat.set_shader_parameter("blur", 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	add_child(_scrim)
	# Overlay sits above the scrim so the countdown reads over a dimmed field.
	overlay = Overlay.new()
	overlay.hud = self
	add_child(overlay)
	_build_menu_bar()
	_build_pause()
	_build_settings()
	var sp := _panel()
	_stats = sp[0]
	_stats_box = sp[1]
	var kp := _panel()
	_skins = kp[0]
	_skins_box = kp[1]
	_over = GameOver.new()
	_over.hud = self
	_over.theme = _theme
	add_child(_over)
	intro_seq = Intro.new()
	intro_seq.hud = self
	add_child(intro_seq)
	Loc.language_changed.connect(_refresh_text)
	Prefs.changed.connect(_refresh_text)
	_refresh_text()


func setup(layout: Layout) -> void:
	l = layout
	for c: Control in [bar, overlay, _scrim, _pause, _settings, _over, intro_seq, _stats, _skins]:
		c.position = Vector2.ZERO
		c.size = l.size
	bar.size = Vector2(l.size.x, l.top_bar_h)
	var touch := maxf(88.0, Tok.TOUCH_MIN_DP * l.dp)
	_b_resume.custom_minimum_size = Vector2(minf(500.0, l.size.x - 180.0), touch + 8.0)
	for b: IconBtn in [_b_restart, _b_settings, _b_menu]:
		b.custom_minimum_size = Vector2(touch, touch)
	for b: Token in [_m_settings, _m_stats, _m_skins]:
		b.custom_minimum_size = Vector2(touch, touch)
	_s_back.custom_minimum_size = Vector2(touch * 0.85, touch * 0.85)
	var row_w := minf(640.0, l.size.x - 2.0 * Tok.SPACE_LG - 2.0 * Tok.SPACE_MD)
	for r: SetRow in _s_rows:
		r.custom_minimum_size = Vector2(row_w - 2.0 * Tok.SPACE_LG, touch)
	_s_credits.custom_minimum_size = Vector2(row_w - 40.0, 0)
	_m_lang.custom_minimum_size = Vector2(touch * 1.75, touch)
	_menu_bar.position = Vector2(l.margin, l.safe_top + Tok.SPACE_LG)
	_menu_bar.size = Vector2(l.size.x - l.margin * 2.0, touch)
	_m_daily.custom_minimum_size = Vector2(maxf(340.0, 48.0 * l.dp), maxf(72.0, 36.0 * l.dp))
	_m_daily.size = _m_daily.custom_minimum_size
	_m_daily.position = Vector2(l.size.x * 0.5 - _m_daily.size.x * 0.5, menu_record_y() - 118.0)
	_over.setup()


func _game_sensor() -> Vector3:
	var g := Input.get_gravity()
	if g.length() < 2.0:
		g = Input.get_accelerometer()
	return g if g.length() >= 2.0 else Vector3.ZERO


func caps_font() -> Font:
	return _font_caps


func num_font() -> Font:
	return _font_num


func display_font() -> Font:
	return _font_display


## Nunito in mixed case, no tracking: labels and values in panels and HUD.
func body_font() -> Font:
	return _font_body_b


static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------------------------------------------------------------- screens

## Main menu chrome: settings + language buttons and the record/prompt copy.
## Where the menu's record figure sits (the daily toggle goes above it,
## the missions below).
func menu_record_y() -> float:
	return l.rail_y + l.play_h * 0.62


func show_menu() -> void:
	bar.visible = false
	_refresh_text()
	for c: Control in [_menu_bar, _m_daily]:
		c.visible = true
		c.modulate.a = 0.0
		Motion.to(c, "modulate:a", 1.0, Motion.SLOW, Motion.Ease.ENTER, 0.15)
	# The tokens drop in on their cords, one after another.
	var i := 0
	for t: Token in [_m_settings, _m_stats, _m_skins]:
		t.enter(0.1 + 0.09 * i)
		i += 1
	_m_lang.enter(0.4)
	overlay.menu_a = 0.0
	Motion.to(overlay, "menu_a", 1.0, Motion.SLOW, Motion.Ease.ENTER, 0.25)


func hide_menu_ui() -> void:
	Motion.to(_menu_bar, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.to(_m_daily, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.to(overlay, "menu_a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.after(Motion.FAST, func() -> void:
		_menu_bar.visible = false
		_m_daily.visible = false)


## The in-game bar opens with its own choreography (TopBar.begin_intro).
func reveal_hud() -> void:
	bar.visible = true
	bar.modulate.a = 1.0
	bar.begin_intro()


func fade_hud(to: float, d: float, delay := 0.0) -> void:
	Motion.to(bar, "modulate:a", to, d, Motion.Ease.EXIT, delay)


func scrim_to(amount: float, d: float, delay := 0.0) -> void:
	_scrim.visible = true
	var blur := 0.0 if Prefs.reduced_motion else 3.0
	Motion.to(_scrim_mat, "shader_parameter/blur", blur * amount, d, Motion.Ease.STANDARD, delay)
	var tr := Motion.to(_scrim_mat, "shader_parameter/amount", amount, d, Motion.Ease.STANDARD, delay)
	if amount <= 0.0:
		tr.done = func() -> void: _scrim.visible = false


## Pause: gameplay is already frozen; scrim darkens (0–150 ms), blur follows
## (50–250 ms), the menu scales 0.97 → 1 and fades in (100–300 ms).
func open_pause(secs := 0) -> void:
	run_secs = secs
	_refresh_text()
	scrim_to(1.0, 0.25)
	_open_panel(_pause, _pause_box, 0.1)
	Sfx.play("panel")


func close_pause() -> void:
	_close_panel(_pause)


func open_settings(from: String) -> void:
	_settings_from = from
	_refresh_text()
	if from == "pause":
		_close_panel(_pause)
	else:
		hide_menu_ui()
		scrim_to(1.0, 0.25)
	_open_panel(_settings, _settings_box, 0.08)
	Sfx.play("panel")


func _close_settings() -> void:
	_close_panel(_settings)
	if _settings_from == "pause":
		_open_panel(_pause, _pause_box, 0.08)
	else:
		scrim_to(0.0, 0.25)
		show_menu()


func _open_panel(p: Control, box: Control, delay: float) -> void:
	p.visible = true
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.modulate.a = 0.0
	var body: Control = box.get_parent() if box.get_parent() is PanelContainer else box
	body.pivot_offset = body.size * 0.5
	body.scale = Vector2(0.97, 0.97)
	Motion.to(p, "modulate:a", 1.0, Motion.NORMAL, Motion.Ease.ENTER, delay)
	Motion.to(body, "scale", Vector2.ONE, Motion.NORMAL, Motion.Ease.ENTER, delay)
	# The rows arrive one after another, each fading up from a little
	# below: the panel reads top to bottom instead of popping in whole.
	if not Prefs.reduced_motion:
		var i := 0
		for c in box.get_children():
			if c is Control and c.visible:
				c.modulate.a = 0.0
				Motion.to(c, "modulate:a", 1.0, Motion.NORMAL, Motion.Ease.ENTER, delay + 0.03 * i)
				i += 1


func _close_panel(p: Control) -> void:
	if not p.visible:
		return
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := Motion.to(p, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	tr.done = func() -> void: p.visible = false


## 3 → 2 → 1 over the dimmed game, then `cb`. Scrim lifts on the last beat.
func countdown(cb: Callable) -> void:
	for i in 3:
		Motion.after(0.42 * i, func() -> void:
			overlay.count_n = 3 - i
			overlay.count_t = 0.0
			Sfx.play("countdown", 1.0 + 0.06 * i)
			Sfx.haptic_pattern("light"))
	scrim_to(0.0, 0.35, 0.9)
	Motion.after(1.26, func() -> void:
		overlay.count_n = 0
		cb.call())


func show_game_over(score: int, prev_best: int, is_record: bool, secs: int, acc: int, skills: Array = [], overloads := 0, was_daily := false, done: Array = []) -> void:
	_over.play(score, prev_best, is_record, secs, acc, skills, overloads, was_daily, done)


func hide_game_over() -> void:
	_over.close()


## Big centred card: an event name and a line under it.
## A new wave opens: its number comes in large while light sweeps the field.
func wave_intro(n: int, sub := "", col := Tok.PRIMARY) -> void:
	overlay.wave_n = n
	overlay.wave_sub = sub
	overlay.wave_col = col
	overlay.wave_t = 0.0


## A perk won: its card pops up, then flies into the tray (top left).
func perk_toast(id: String, level: int) -> void:
	if not perk_order.has(id):
		perk_order.append(id)
	perk_levels[id] = level
	overlay.toast_id = id
	overlay.toast_t = 0.0


## Drops any card showing or waiting (a run ended).
func clear_cards() -> void:
	overlay.card_queue.clear()
	overlay.card_t = 99.0


## Shows a card; if one is still up, this one waits its turn (never lost).
func card(title: String, sub: String, hold := 1.0) -> void:
	if overlay.card_busy():
		if overlay.card_queue.size() < 3:
			overlay.card_queue.append([title, sub, hold])
		return
	overlay.card_title = title
	overlay.card_sub = sub
	overlay.card_hold = hold
	overlay.card_t = 0.0


## "New enemy" card near the bottom of the field.
func intro(name: String, desc: String) -> void:
	overlay.intro_name = name
	overlay.intro_desc = desc
	overlay.intro_t = 0.0


## A panel is up: cards and enemy intros hold back so nothing overlaps it.
func modal_open() -> bool:
	return _pause.visible or _settings.visible or _over.visible or _stats.visible or _skins.visible


func intro_busy() -> bool:
	return overlay.intro_t < INTRO_TIME


## Every button routes here: ignored while locked, and it locks briefly
## itself so a burst of taps can only ever act once.
func _act(cb: Callable) -> void:
	if locked:
		return
	locked = true
	Motion.after(0.25, func() -> void: locked = false)
	cb.call()


func _refresh_text() -> void:
	_pause_title.text = Loc.t("pause.title")
	_pause_best.text = Loc.t("pause.best") % _group(maxi(Prefs.record, bar.score))
	_pause_hint.text = Loc.t("pause.hint")
	_pause_vals[0].text = _group(bar.score)
	_pause_vals[1].text = str(bar.phase)
	_pause_vals[2].text = "%d:%02d" % [run_secs / 60, run_secs % 60]
	for i in 3:
		_pause_caps[i].text = Loc.t(["pause.score", "pause.wave", "pause.time"][i])
	_b_resume.text = Loc.t("pause.resume")
	for i in 3:
		_pause_icon_caps[i].text = Loc.t(["pause.restart", "pause.settings", "pause.mainMenu"][i])
	_s_title.text = Loc.t("settings.title")
	for i in _s_secs.size():
		_s_secs[i].text = Loc.t(["settings.sec.sound", "settings.sec.game", "settings.sec.access", "settings.sec.lang", "settings.sec.data"][i])
	for r: SetRow in _s_rows:
		r.refresh()
	_s_credits.text = Loc.t("settings.credits")
	_m_settings.tooltip_text = Loc.t("menu.settings")
	_m_stats.tooltip_text = Loc.t("menu.stats")
	_m_skins.tooltip_text = Loc.t("menu.skins")
	_m_daily.caption = Loc.t("menu.daily")
	_m_daily.lit = daily
	_m_daily.queue_redraw()
	_m_lang.queue_redraw()
	_over.refresh_text()
	bar.queue_redraw()
	overlay.queue_redraw()


# ---------------------------------------------------------------- building

## The game is laid out at 720 px wide and scaled to the screen; text is
## rasterized at the real pixel size of the screen (oversampling), so on a
## 1440 px phone it is drawn from glyphs twice as detailed, not blown up.
func _crisp_fonts(list: Array) -> void:
	var k := maxf(1.0, float(DisplayServer.window_get_size().x) / 720.0)
	for f in list:
		if f is FontFile:
			(f as FontFile).oversampling = k


func _build_fonts() -> void:
	var ts := TextServerManager.get_primary_interface()
	# Gluten: round, bouncy, a little wobbly, like the jelly enemies it
	# names; for the title, the score and the big cards. Nunito: rounded
	# and quiet, for everything small (labels, buttons, missions).
	var gluten: Font = load("res://fonts/Gluten.ttf")
	var nunito: Font = load("res://fonts/Nunito.ttf")
	_crisp_fonts([gluten, nunito])
	_font_caps = FontVariation.new()
	_font_caps.base_font = nunito
	_font_caps.variation_opentype = {ts.name_to_tag("wght"): 800}
	_font_caps.spacing_glyph = Tok.TRACKING
	_font_num = FontVariation.new()
	_font_num.base_font = gluten
	_font_num.variation_opentype = {ts.name_to_tag("wght"): 650}
	_font_num.opentype_features = {ts.name_to_tag("tnum"): 1}
	_font_display = FontVariation.new()
	_font_display.base_font = gluten
	_font_display.variation_opentype = {ts.name_to_tag("wght"): 700}
	_font_body = FontVariation.new()
	_font_body.base_font = nunito
	_font_body.variation_opentype = {ts.name_to_tag("wght"): 700}
	_font_body_b = FontVariation.new()
	_font_body_b.base_font = nunito
	_font_body_b.variation_opentype = {ts.name_to_tag("wght"): 800}
	_theme = Theme.new()
	_theme.default_font = _font_body_b
	_theme.default_font_size = Tok.TYPE_BODY
	_theme.set_stylebox("normal", "Button", _box(Tok.SURFACE, Tok.BORDER))
	_theme.set_stylebox("hover", "Button", _box(Tok.SURFACE_HI, Tok.BORDER_HI))
	_theme.set_stylebox("focus", "Button", _box(Tok.SURFACE_HI, Tok.BORDER_HI))
	_theme.set_stylebox("pressed", "Button", _box(Tok.SURFACE_LO, Color(Tok.PRIMARY, 0.6)))
	_theme.set_stylebox("disabled", "Button", _box(Tok.SURFACE_LO, Tok.BORDER))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		_theme.set_color(c, "Button", Tok.TEXT_PRIMARY)
	_theme.set_color("font_pressed_color", "Button", Tok.PRIMARY_HI)
	# Primary: the one gold action on a screen.
	_theme.set_type_variation(&"PrimaryButton", &"Button")
	var prim := _box(Tok.PRIMARY, Tok.PRIMARY)
	prim.shadow_color = Tok.PRIMARY_LO
	prim.shadow_offset = Vector2(0, 5)
	prim.shadow_size = 1
	_theme.set_stylebox("normal", "PrimaryButton", prim)
	_theme.set_stylebox("hover", "PrimaryButton", _box(Tok.PRIMARY_HI, Tok.PRIMARY_HI))
	_theme.set_stylebox("focus", "PrimaryButton", _box(Tok.PRIMARY_HI, Tok.PRIMARY_HI))
	_theme.set_stylebox("pressed", "PrimaryButton", _box(Tok.PRIMARY_LO, Tok.PRIMARY_LO))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(c, "PrimaryButton", Tok.ON_PRIMARY)
	# Round glass buttons that carry a line icon (menu, pause, settings).
	_theme.set_type_variation(&"IconButton", &"Button")
	var ib := _glass(Tok.RADIUS_PILL)
	ib.set_content_margin_all(0)
	ib.shadow_size = 10
	ib.shadow_offset = Vector2(0, 4)
	var ibh := ib.duplicate() as StyleBoxFlat
	ibh.border_color = Tok.BORDER_HI
	var ibp := ib.duplicate() as StyleBoxFlat
	ibp.bg_color = Tok.SURFACE_LO
	ibp.border_color = Color(Tok.PRIMARY, 0.6)
	_theme.set_stylebox("normal", "IconButton", ib)
	_theme.set_stylebox("hover", "IconButton", ibh)
	_theme.set_stylebox("focus", "IconButton", ibh)
	_theme.set_stylebox("pressed", "IconButton", ibp)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_theme.set_color(c, "IconButton", Tok.TEXT_PRIMARY)
	# Settings rows: the row itself is the target, drawn by the row.
	_theme.set_type_variation(&"RowButton", &"Button")
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		_theme.set_stylebox(st, "RowButton", empty)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(Tok.RADIUS_PILL)
	s.content_margin_left = Tok.SPACE_LG
	s.content_margin_right = Tok.SPACE_LG
	s.shadow_color = Tok.SHADOW
	s.shadow_offset = Pal.SHADOW_OFFSET
	s.shadow_size = 2
	s.anti_aliasing = true
	return s


## The panel surface: a dark glass sheet with a fine border and a soft
## drop shadow, over the blurred scrim.
func _glass(radius := Tok.RADIUS_XL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Tok.GLASS
	s.border_color = Tok.BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 28
	s.shadow_offset = Vector2(0, 10)
	s.set_content_margin_all(Tok.SPACE_LG)
	s.anti_aliasing = true
	return s


func _card(radius := Tok.RADIUS_XL) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", _glass(radius))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func label(size: int, col: Color, font: Font) -> Label:
	var lb := Label.new()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", col)
	return lb


func button(cb: Callable, primary := false) -> UIButton:
	var b := UIButton.new()
	b.custom_minimum_size = Vector2(320, 60)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(func() -> void: _act(cb))
	return b


## A full-screen panel with a centred column, on a glass card unless
## `bare`; returns [panel, column].
func _panel(bare := false) -> Array:
	var p := Control.new()
	p.theme = _theme
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Tok.SPACE_MD)
	if bare:
		center.add_child(box)
	else:
		var card := _card()
		card.get_theme_stylebox("panel").content_margin_top = Tok.SPACE_XL
		card.get_theme_stylebox("panel").content_margin_bottom = Tok.SPACE_XL
		card.get_theme_stylebox("panel").content_margin_left = Tok.SPACE_XL
		card.get_theme_stylebox("panel").content_margin_right = Tok.SPACE_XL
		center.add_child(card)
		card.add_child(box)
	return [p, box]


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _token(glyph: String, cb: Callable) -> Token:
	var b := Token.new()
	b.glyph = glyph
	b.hud = self
	b.theme_type_variation = &"RowButton"
	b.custom_minimum_size = Vector2(96, 96)
	b.pressed.connect(func() -> void: _act(cb))
	return b


func _icon_button(glyph: String, cb: Callable) -> IconBtn:
	var b := IconBtn.new()
	b.glyph = glyph
	b.theme_type_variation = &"IconButton"
	b.custom_minimum_size = Vector2(96, 96)
	b.pressed.connect(func() -> void: _act(cb))
	return b


## Pause: a glass card with the run so far (score · wave · time), the one
## gold action to carry on, and a row of round icon actions under it.
func _build_pause() -> void:
	var pb := _panel(true)
	_pause = pb[0]
	_pause_box = pb[1]
	_pause_box.add_theme_constant_override("separation", Tok.SPACE_LG)
	var card := _card()
	var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_top = Tok.SPACE_XL
	sb.content_margin_bottom = Tok.SPACE_XL
	sb.content_margin_left = Tok.SPACE_XL
	sb.content_margin_right = Tok.SPACE_XL
	_pause_box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tok.SPACE_LG)
	card.add_child(col)
	_pause_title = label(Tok.TYPE_DISPLAY + 8, Tok.TEXT_PRIMARY, _font_display)
	_pause_best = label(20, Tok.TEXT_FAINT, _font_body)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.add_child(_pause_title)
	head.add_child(_pause_best)
	col.add_child(head)
	# Summary: three figures split by hairlines.
	var sum := HBoxContainer.new()
	sum.add_theme_constant_override("separation", 0)
	for i in 3:
		if i > 0:
			var rule := ColorRect.new()
			rule.color = Tok.BORDER
			rule.custom_minimum_size = Vector2(2, 56)
			rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sum.add_child(rule)
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(160, 0)
		c.add_theme_constant_override("separation", 0)
		var v := label(40, Tok.PRIMARY_HI if i == 0 else Tok.TEXT_PRIMARY, _font_num)
		var k := label(19, Tok.TEXT_SECONDARY, _font_body_b)
		c.add_child(v)
		c.add_child(k)
		_pause_vals.append(v)
		_pause_caps.append(k)
		sum.add_child(c)
	col.add_child(sum)
	_b_resume = button(func() -> void: resume_pressed.emit(), true)
	_b_resume.add_theme_font_size_override("font_size", 30)
	_b_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_b_resume)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", Tok.SPACE_XL)
	_b_restart = _icon_button("restart", func() -> void: restart_pressed.emit())
	_b_settings = _icon_button("gear", func() -> void: open_settings("pause"))
	_b_menu = _icon_button("home", func() -> void: menu_pressed.emit())
	for b: IconBtn in [_b_restart, _b_settings, _b_menu]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", Tok.SPACE_SM)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(b)
		var k := label(19, Tok.TEXT_SECONDARY, _font_body_b)
		k.custom_minimum_size = Vector2(150, 0)
		c.add_child(k)
		_pause_icon_caps.append(k)
		icons.add_child(c)
	col.add_child(icons)
	_pause_hint = label(19, Tok.TEXT_FAINT, _font_body)
	_pause_box.add_child(_pause_hint)


## Settings: a header with a back button, then grouped glass cards
## (sound, game, accessibility, language), each row a label on the left
## and its control on the right; credits at the foot.
func _build_settings() -> void:
	var pb := _panel(true)
	_settings = pb[0]
	_settings_box = pb[1]
	_settings_box.add_theme_constant_override("separation", Tok.SPACE_SM)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Tok.SPACE_MD)
	_s_back = _icon_button("back", _close_settings)
	head.add_child(_s_back)
	_s_title = label(Tok.TYPE_DISPLAY - 8, Tok.TEXT_PRIMARY, _font_display)
	_s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(_s_title)
	_settings_box.add_child(head)
	var groups := [
		[SetRow.Kind.STEPS, "settings.music", func() -> int: return Prefs.music_volume, func(v: int) -> void: Prefs.set_music(v)],
		[SetRow.Kind.STEPS, "settings.effects", func() -> int: return Prefs.sfx_volume, func(v: int) -> void:
			Prefs.set_sfx(v)
			Sfx.play("countdown")],
		null,
		[SetRow.Kind.SWITCH, "settings.aimGuide", func() -> int: return int(Prefs.aim_guide), func(_v: int) -> void: Prefs.toggle_aim_guide()],
		[SetRow.Kind.SWITCH, "settings.tilt", func() -> int: return int(Prefs.tilt), func(_v: int) -> void: Prefs.toggle_tilt()],
		null,
		[SetRow.Kind.SWITCH, "settings.reducedMotion", func() -> int: return int(Prefs.reduced_motion), func(_v: int) -> void: Prefs.toggle_reduced_motion()],
		[SetRow.Kind.SWITCH, "settings.haptics", func() -> int: return int(Prefs.haptics), func(_v: int) -> void:
			Prefs.toggle_haptics()
			Sfx.haptic_pattern("soft")],
		null,
		[SetRow.Kind.LANG, "settings.language", func() -> int: return 0 if Loc.lang == "no" else 1, func(v: int) -> void: Loc.set_language("no" if v == 0 else "en")],
		null,
		[SetRow.Kind.HOLD, "settings.reset", func() -> int: return 0, func(_v: int) -> void:
			Prefs.reset_progress()
			Sfx.play("clear", 0.8, -4.0)
			Sfx.haptic_pattern("record")],
	]
	var rows: VBoxContainer = null
	var first := true
	for g in [null] + groups:
		if g == null:
			var cap := label(19, Tok.TEXT_SECONDARY, _font_caps)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			var capbox := MarginContainer.new()
			capbox.add_theme_constant_override("margin_left", Tok.SPACE_MD)
			capbox.add_theme_constant_override("margin_right", Tok.SPACE_MD)
			capbox.add_theme_constant_override("margin_top", Tok.SPACE_SM)
			# The section name, and an engraved brass rule running on from it.
			var caprow := HBoxContainer.new()
			caprow.add_theme_constant_override("separation", Tok.SPACE_MD)
			cap.add_theme_color_override("font_color", Tok.PRIMARY)
			caprow.add_child(cap)
			var rule := ColorRect.new()
			rule.color = Color(Tok.PRIMARY_LO, 0.55)
			rule.custom_minimum_size = Vector2(0, 2)
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			caprow.add_child(rule)
			capbox.add_child(caprow)
			_s_secs.append(cap)
			_settings_box.add_child(capbox)
			var card := _card(32)
			var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			sb.shadow_size = 16
			_settings_box.add_child(card)
			rows = VBoxContainer.new()
			rows.add_theme_constant_override("separation", 0)
			card.add_child(rows)
			first = true
			continue
		var r := SetRow.new()
		r.hud = self
		r.kind = g[0]
		r.key = g[1]
		r.getter = g[2]
		r.glyph = {"settings.music": "note", "settings.effects": "speaker", "settings.aimGuide": "aim", "settings.tilt": "tilt",
			"settings.reducedMotion": "motion", "settings.haptics": "vibrate", "settings.language": "globe", "settings.reset": "restart"}.get(g[1], "")
		r.first = first
		r.theme_type_variation = &"RowButton"
		var setter: Callable = g[3]
		r.picked.connect(func(v: int) -> void: _act(func() -> void: setter.call(v)))
		if g[1] == "settings.reset":
			var row := r
			r.note = func() -> String:
				return Loc.t("settings.resetDone") if row.done_t < 2.2 else Loc.t("settings.resetHint")
		if g[1] == "settings.tilt":
			r.note = func() -> String:
				return Loc.t("settings.noSensor") if Prefs.tilt and _game_sensor() == Vector3.ZERO and Input.get_gyroscope() == Vector3.ZERO else ""
		rows.add_child(r)
		_s_rows.append(r)
		first = false
	# Attribution for the music (CC BY 4.0) and the CC0 packs.
	_s_credits = label(17, Tok.TEXT_FAINT, _font_body)
	_s_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s_credits.custom_minimum_size = Vector2(560, 0)
	_settings_box.add_child(_spacer(Tok.SPACE_XS))
	_settings_box.add_child(_s_credits)


## Menu chrome: round glass icon buttons (settings on the left; stats,
## balls and the language pill on the right) and the daily-challenge pill.
func _build_menu_bar() -> void:
	_menu_bar = HBoxContainer.new()
	_menu_bar.theme = _theme
	_menu_bar.visible = false
	add_child(_menu_bar)
	_m_settings = _token("gear", func() -> void: open_settings("menu"))
	_menu_bar.add_child(_m_settings)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_bar.add_child(gap)
	_m_stats = _token("chart", func() -> void: _open_meta(_stats, _stats_box, _fill_stats))
	_menu_bar.add_child(_m_stats)
	_m_skins = _token("ball", func() -> void: _open_meta(_skins, _skins_box, _fill_skins))
	_menu_bar.add_child(_m_skins)
	_m_lang = Lever.new()
	_m_lang.hud = self
	_m_lang.theme_type_variation = &"RowButton"
	_m_lang.picked.connect(func(code: String) -> void: _act(func() -> void: Loc.set_language(code)))
	_menu_bar.add_child(_m_lang)
	_menu_bar.add_theme_constant_override("separation", Tok.SPACE_MD)
	# Mode toggle: the next pull starts either a normal run or today's
	# seeded challenge (same spawns for everyone that day, its own record).
	_m_daily = _icon_button("calendar", func() -> void:
		daily = not daily
		_refresh_text())
	_m_daily.theme = _theme
	_m_daily.add_theme_font_size_override("font_size", 24)
	_m_daily.visible = false
	add_child(_m_daily)


# ---------------------------------------------------------------- meta panels

## Stats and skins: full-screen panels over the menu, rebuilt on open so
## they always show the latest numbers.
func _open_meta(p: Control, box: VBoxContainer, fill: Callable) -> void:
	for c in box.get_children():
		c.queue_free()
	fill.call(box)
	var back := button(func() -> void: _close_meta(p))
	back.text = Loc.t("settings.back")
	back.custom_minimum_size = Vector2(maxf(320.0, 48.0 * l.dp), maxf(60.0, Tok.TOUCH_MIN_DP * l.dp))
	box.add_child(_spacer(Tok.SPACE_SM))
	box.add_child(back)
	hide_menu_ui()
	scrim_to(1.0, 0.25)
	_open_panel(p, box, 0.08)
	Sfx.play("panel")


func _close_meta(p: Control) -> void:
	_close_panel(p)
	scrim_to(0.0, 0.25)
	show_menu()


## "ENEMIES BROKEN" -> "Enemies broken": the panels' quieter voice.
static func sentence(t: String) -> String:
	return t.substr(0, 1) + t.substr(1).to_lower() if t.length() > 1 else t


func _panel_title(key: String) -> Label:
	var t := label(Tok.TYPE_DISPLAY - 12, Tok.TEXT_PRIMARY, _font_display)
	t.text = sentence(Loc.t(key))
	return t


func _row(name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(500, 46)
	var a := label(23, Tok.TEXT_SECONDARY, _font_body)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.text = sentence(name)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := label(26, Tok.TEXT_PRIMARY, _font_num)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.text = value
	row.add_child(a)
	row.add_child(b)
	return row


func _fill_stats(box: VBoxContainer) -> void:
	var st := Prefs.stats
	box.add_child(_panel_title("stats.title"))
	var secs := int(st.get("secs", 0))
	var shots := int(st.get("shots", 0))
	var board := StatsBoard.new()
	board.hud = self
	board.fresh = Prefs.fresh.duplicate()
	board.hero = [
		["stats.best", Prefs.record],
		["stats.wave", int(st.get("best_wave", 0))],
		["stats.accuracy", int(round(100.0 * int(st.get("hits", 0)) / shots)) if shots > 0 else 0],
	]
	board.tiles = [
		["stats.runs", "restart", int(st.get("runs", 0))],
		["stats.total", "coins", Prefs.total_points],
		["stats.kills", "burst", int(st.get("kills", 0))],
		["gameOver.overloads", "bolt", int(st.get("overloads", 0))],
		["skill.bank", "bank", int(st.get("bank", 0))],
		["skill.chain", "chain", int(st.get("chain", 0))],
		["skill.cut", "scissors", int(st.get("cuts", 0))],
		["stats.missions", "flag", Prefs.mission_level],
		["stats.time", "clock", "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
	]
	box.add_child(board)


## Skins: each a button with a swatch; locked ones show what they cost.
func _fill_skins(box: VBoxContainer) -> void:
	box.add_child(_panel_title("skins.title"))
	var sub := label(21, Tok.TEXT_SECONDARY, _font_body)
	sub.text = sentence(Loc.t("skins.total") % _group(Prefs.skin_points))
	box.add_child(sub)
	box.add_child(_spacer(Tok.SPACE_SM))
	for i in Meta.SKINS.size():
		var sk: Array = Meta.SKINS[i]
		var open := Meta.skin_unlocked(i, Prefs.skin_points)
		var b := button(func() -> void:
			if Meta.skin_unlocked(i, Prefs.skin_points):
				Prefs.set_skin(i)
				_open_meta(_skins, _skins_box, _fill_skins)
			else:
				Sfx.play("deny")
				Sfx.haptic_pattern("error"), i == Prefs.skin)
		b.custom_minimum_size = Vector2(maxf(360.0, 52.0 * l.dp), maxf(60.0, Tok.TOUCH_MIN_DP * l.dp))
		var name := sentence(Loc.t(sk[0]))
		if i == Prefs.skin:
			b.text = "%s  ·  %s" % [name, Loc.t("skins.equipped")]
		elif open:
			b.text = name
		else:
			b.text = "%s  ·  %s" % [name, Loc.t("skins.locked") % _group(int(sk[1]))]
			b.modulate.a = 0.55
		b.icon = _swatch(Meta.skin_colors(i), open)
		b.expand_icon = false
		box.add_child(b)


## A small lit ball for a skin button (drawn into a texture once).
func _swatch(c: Array, open: bool) -> Texture2D:
	var n := 36
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := n * 0.5 - 2.0
	var ctr := Vector2(n * 0.5, n * 0.5)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(ctr)
			if d > r + 0.5:
				continue
			var a := clampf(r + 0.5 - d, 0.0, 1.0)
			var col: Color = c[0] if d > r - 1.6 else c[1]
			if p.distance_to(ctr - Vector2(r, r) * 0.34) < r * 0.32:
				col = col.lerp(c[2], 0.55)
			if not open:
				col = Color(col.get_luminance(), col.get_luminance(), col.get_luminance())
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- widgets

## A filled pill (width ≥ height) with softened edges.
static func pill(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var rad := minf(r.size.x, r.size.y) * 0.5
	var c1 := Vector2(r.position.x + rad, r.position.y + r.size.y * 0.5)
	var c2 := Vector2(r.end.x - rad, c1.y)
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI * 0.5 + PI * k / 12.0
		pts.append(c1 + Vector2(cos(a), sin(a)) * rad)
	for k in 13:
		var a := -PI * 0.5 + PI * k / 12.0
		pts.append(c2 + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, 1.0, true)


## A brass lever switch on an engraved plate: `labels` at the two ends
## (the lit one is the side the lever leans to), a steel rod from a brass
## boss and a brass ball on its end. `a` is the lever's angle: negative
## leans left, positive right.
static func lever(ci: CanvasItem, plate: Rect2, a: float, labels: Array, f: Font) -> void:
	pill(ci, Rect2(plate.position + Vector2(2, 3.5), plate.size), Color(0, 0, 0, 0.45))
	pill(ci, plate, Tok.PRIMARY_LO)
	pill(ci, plate.grow(-2.5), Tok.PRIMARY)
	pill(ci, plate.grow(-6.0), Color("0E1015"))
	var fs := 22
	var base := plate.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	for i in 2:
		var t: String = labels[i]
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := plate.position.x + (30.0 if i == 0 else plate.size.x - 30.0) - tw * 0.5
		var on := (a < 0.0) == (i == 0)
		ci.draw_string(f, Vector2(x, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.PRIMARY_HI if on else Tok.TEXT_FAINT)
	var piv := Vector2(plate.get_center().x, plate.end.y - 12.0)
	var tip := piv + Vector2(0, -plate.size.y * 0.72).rotated(a)
	ci.draw_line(piv + Vector2(1.5, 2.5), tip + Vector2(1.5, 2.5), Color(0, 0, 0, 0.4), 5.0, true)
	ci.draw_line(piv, tip, Pal.METAL_LIGHT, 4.0, true)
	ci.draw_line(piv + Vector2(-0.8, 0), tip + Vector2(-0.8, 0), Color(1, 1, 1, 0.25), 1.2, true)
	brass_disc(ci, piv, 8.0, Tok.PRIMARY_LO)
	ci.draw_circle(tip + Vector2(1.5, 2.5), 9.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	ci.draw_circle(tip, 9.0, Tok.PRIMARY, true, -1.0, true)
	ci.draw_circle(tip + Vector2(-2.5, -3.0), 3.0, Color(1, 1, 1, 0.45), true, -1.0, true)


## A brass medallion: cast shadow, milled rim lit from the top left and a
## sunken dark face (radius `r`, centred on `c`).
static func brass_disc(ci: CanvasItem, c: Vector2, r: float, face := Color("0E1015")) -> void:
	ci.draw_circle(c + Vector2(2.0, 3.5), r + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	ci.draw_circle(c, r, Tok.PRIMARY_LO, true, -1.0, true)
	ci.draw_circle(c + Vector2(-0.8, -1.0), r - 2.5, Tok.PRIMARY, true, -1.0, true)
	var ridges := int(clampf(r * 1.1, 18.0, 56.0))
	for i in ridges:
		var d := Vector2.from_angle(TAU * i / ridges)
		ci.draw_line(c + d * (r - 5.5), c + d * (r - 2.5), Color(Color("5E4620"), 0.55), 1.2, true)
	ci.draw_arc(c, r - 1.5, PI * 1.02, PI * 1.62, 16, Color(Tok.PRIMARY_HI, 0.85), 1.6, true)
	var fr := r - maxf(7.0, r * 0.2)
	ci.draw_circle(c, fr, face, true, -1.0, true)
	ci.draw_arc(c, fr, PI * 0.1, PI * 0.9, 16, Color(Tok.PRIMARY_HI, 0.25), 1.2, true)
	ci.draw_arc(c, fr, PI * 1.1, PI * 1.9, 16, Color(0, 0, 0, 0.5), 1.6, true)


## The UI's line icons, drawn on a 24-unit grid centred on `c`; `s` is the
## scale of one unit in px.
static func glyph(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var lw := 1.9 * s
	var o := c - Vector2(12, 12) * s
	var line := func(pts: Array) -> void:
		var pv := PackedVector2Array()
		for p: Vector2 in pts:
			pv.append(o + p * s)
		ci.draw_polyline(pv, col, lw, true)
	match id:
		"gear":
			ci.draw_arc(c, 6.2 * s, 0.0, TAU, 40, col, lw, true)
			ci.draw_arc(c, 2.4 * s, 0.0, TAU, 24, col, lw, true)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + d * 6.2 * s, c + d * 9.4 * s, col, lw * 1.25, true)
		"chart":
			line.call([Vector2(5, 19.5), Vector2(5, 12)])
			line.call([Vector2(12, 19.5), Vector2(12, 5)])
			line.call([Vector2(19, 19.5), Vector2(19, 14.5)])
		"ball":
			ci.draw_circle(c, 8.5 * s, Tok.PRIMARY, true, -1.0, true)
			ci.draw_circle(c + Vector2(-2.6, -2.6) * s, 2.6 * s, Tok.PRIMARY_HI, true, -1.0, true)
		"restart":
			ci.draw_arc(c, 7.5 * s, -PI * 0.25, PI * 1.35, 36, col, lw, true)
			# Arrowhead at the open end, pointing along the turn.
			var tip := c + Vector2.from_angle(-PI * 0.25) * 7.5 * s
			var fwd := Vector2.from_angle(-PI * 0.25 + PI * 0.5)
			var side := fwd.orthogonal()
			ci.draw_colored_polygon(PackedVector2Array([tip + fwd * 3.6 * s, tip - fwd * 1.6 * s + side * 3.4 * s, tip - fwd * 1.6 * s - side * 3.4 * s]), col)
		"home":
			line.call([Vector2(4, 11.5), Vector2(12, 4.5), Vector2(20, 11.5)])
			line.call([Vector2(6.5, 9.5), Vector2(6.5, 19.5), Vector2(17.5, 19.5), Vector2(17.5, 9.5)])
		"back":
			line.call([Vector2(14.5, 5), Vector2(7.5, 12), Vector2(14.5, 19)])
		"note":
			line.call([Vector2(9, 18), Vector2(9, 5), Vector2(19, 3.5), Vector2(19, 16)])
			ci.draw_circle(o + Vector2(6.5, 18) * s, 2.8 * s, col, true, -1.0, true)
			ci.draw_circle(o + Vector2(16.5, 16) * s, 2.8 * s, col, true, -1.0, true)
		"speaker":
			line.call([Vector2(4, 9.5), Vector2(8, 9.5), Vector2(13, 5), Vector2(13, 19), Vector2(8, 14.5), Vector2(4, 14.5), Vector2(4, 9.5)])
			ci.draw_arc(o + Vector2(13, 12) * s, 4.5 * s, -0.8, 0.8, 10, col, lw, true)
			ci.draw_arc(o + Vector2(13, 12) * s, 8.0 * s, -0.8, 0.8, 12, col, lw, true)
		"aim":
			for k in 5:
				var tt := k / 4.0
				ci.draw_circle(o + Vector2(4.0 + 16.0 * tt, 19.0 - 15.0 * tt + 8.0 * tt * tt) * s, (2.2 - tt * 0.9) * s, col, true, -1.0, true)
		"tilt":
			ci.draw_set_transform(c, -0.35)
			ci.draw_rect(Rect2(Vector2(-5, -9) * s, Vector2(10, 18) * s), col, false, lw)
			ci.draw_line(Vector2(-2, 6.5) * s, Vector2(2, 6.5) * s, col, lw, true)
			ci.draw_set_transform(Vector2.ZERO)
			ci.draw_arc(c, 11.0 * s, -0.5, 0.2, 8, col, lw * 0.8, true)
			ci.draw_arc(c, 11.0 * s, PI - 0.5, PI + 0.2, 8, col, lw * 0.8, true)
		"motion":
			line.call([Vector2(3, 8), Vector2(12, 8)])
			line.call([Vector2(5, 12), Vector2(12, 12)])
			line.call([Vector2(3, 16), Vector2(12, 16)])
			ci.draw_arc(o + Vector2(16, 12) * s, 4.5 * s, 0.0, TAU, 16, col, lw, true)
		"vibrate":
			ci.draw_rect(Rect2(o + Vector2(8, 4) * s, Vector2(8, 16) * s), col, false, lw)
			line.call([Vector2(4, 8), Vector2(2.5, 10), Vector2(4, 12), Vector2(2.5, 14), Vector2(4, 16)])
			line.call([Vector2(20, 8), Vector2(21.5, 10), Vector2(20, 12), Vector2(21.5, 14), Vector2(20, 16)])
		"globe":
			ci.draw_arc(c, 8.5 * s, 0.0, TAU, 32, col, lw, true)
			ci.draw_set_transform(c, 0.0, Vector2(0.45, 1.0))
			ci.draw_arc(Vector2.ZERO, 8.5 * s, 0.0, TAU, 32, col, lw, true)
			ci.draw_set_transform(Vector2.ZERO)
			line.call([Vector2(3.5, 12), Vector2(20.5, 12)])
		"coins":
			for k in 3:
				ci.draw_set_transform(o + Vector2(12, 17 - k * 4.5) * s, 0.0, Vector2(1.0, 0.4))
				ci.draw_circle(Vector2.ZERO, 7.5 * s, col, true, -1.0, true)
				ci.draw_arc(Vector2.ZERO, 7.5 * s, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 2.0, true)
			ci.draw_set_transform(Vector2.ZERO)
		"burst":
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0 + 0.2)
				ci.draw_line(c + d * 4.0 * s, c + d * (8.5 if k % 2 == 0 else 6.5) * s, col, lw, true)
			ci.draw_circle(c, 2.2 * s, col, true, -1.0, true)
		"bolt":
			var pv := PackedVector2Array()
			for q in [Vector2(13.5, 2.5), Vector2(6, 13.5), Vector2(11.5, 13.5), Vector2(10, 21.5), Vector2(18, 10), Vector2(12.5, 10)]:
				pv.append(o + q * s)
			ci.draw_colored_polygon(pv, col)
		"bank":
			line.call([Vector2(20, 3), Vector2(20, 21)])
			line.call([Vector2(4, 19), Vector2(16, 11), Vector2(6, 4)])
			ci.draw_circle(o + Vector2(6, 4) * s, 2.4 * s, col, true, -1.0, true)
		"chain":
			for k in 2:
				ci.draw_set_transform(o + Vector2(8.5 + k * 7.0, 12 + (k * 2 - 1) * 2.5) * s, -0.6)
				ci.draw_rect(Rect2(Vector2(-5.5, -3) * s, Vector2(11, 6) * s), col, false, lw)
			ci.draw_set_transform(Vector2.ZERO)
		"scissors":
			ci.draw_arc(o + Vector2(7, 17) * s, 3.2 * s, 0.0, TAU, 14, col, lw, true)
			ci.draw_arc(o + Vector2(17, 17) * s, 3.2 * s, 0.0, TAU, 14, col, lw, true)
			line.call([Vector2(9, 14.5), Vector2(17, 3.5)])
			line.call([Vector2(15, 14.5), Vector2(7, 3.5)])
		"flag":
			line.call([Vector2(6, 21), Vector2(6, 3.5)])
			var fv := PackedVector2Array()
			for q in [Vector2(6, 3.5), Vector2(19, 7.5), Vector2(6, 12)]:
				fv.append(o + q * s)
			ci.draw_colored_polygon(fv, col)
		"clock":
			ci.draw_arc(c, 8.5 * s, 0.0, TAU, 32, col, lw, true)
			line.call([Vector2(12, 12), Vector2(12, 6.5)])
			line.call([Vector2(12, 12), Vector2(16, 14)])
		"calendar":
			line.call([Vector2(4, 6), Vector2(20, 6), Vector2(20, 19.5), Vector2(4, 19.5), Vector2(4, 6)])
			line.call([Vector2(4, 10), Vector2(20, 10)])
			line.call([Vector2(8, 3.5), Vector2(8, 7.5)])
			line.call([Vector2(16, 3.5), Vector2(16, 7.5)])


## A round glass button with a line icon; with a caption it becomes a
## glass pill, icon leading the text. `lit` marks a toggle that is on.
class IconBtn extends UIButton:
	var glyph := ""
	var caption := ""
	var lit := false

	func _draw() -> void:
		var col := Tok.TEXT_PRIMARY
		if lit:
			Hud.pill(self, Rect2(Vector2.ZERO, size).grow(-2.0), Tok.PRIMARY)
			col = Tok.ON_PRIMARY
		var s := size.y / 48.0 if caption == "" else size.y / 64.0
		if caption == "":
			Hud.glyph(self, glyph, size * 0.5, s, col)
			return
		var f := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var iw := 24.0 * s
		var x0 := size.x * 0.5 - (iw + 12.0 + tw) * 0.5
		Hud.glyph(self, glyph, Vector2(x0 + iw * 0.5, size.y * 0.5), s, Tok.ON_PRIMARY if lit else Tok.PRIMARY)
		var base := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string(f, Vector2(x0 + iw + 12.0, base), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Statistics as an instrument board: three brass gauges up top (best
## score, best wave, and accuracy on a needle dial), and a grid of engraved
## tiles below. On opening, the gauges pop in, the needle swings up to its
## reading with an overshoot and every figure counts up.
class StatsBoard extends Control:
	var hud: Hud
	var hero: Array = []           # [key, value]
	var tiles: Array = []          # [key, glyph, value (int or text)]
	var fresh := {}                # bests the last run set: they get a "New!" tag
	var _t := 0.0
	var _needle := 0.0
	var _needle_v := 0.0
	var _tile_box: StyleBoxFlat

	func _ready() -> void:
		custom_minimum_size = Vector2(564, 624)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tile_box = StyleBoxFlat.new()
		_tile_box.bg_color = Color("12151B")
		_tile_box.border_color = Tok.BORDER
		_tile_box.set_border_width_all(2)
		_tile_box.set_corner_radius_all(20)
		_tile_box.anti_aliasing = true

	func _process(delta: float) -> void:
		var dt := minf(delta, 1.0 / 30.0)
		_t += dt
		var acc := float(hero[2][1]) / 100.0 if hero.size() > 2 else 0.0
		var want := acc if _t > 0.35 else 0.0
		_needle_v += (140.0 * (want - _needle) - 9.0 * _needle_v) * dt
		_needle += _needle_v * dt
		queue_redraw()

	func _count(v: int, delay: float) -> int:
		var k := clampf((_t - delay) / 0.9, 0.0, 1.0)
		return int(round(v * (1.0 - pow(1.0 - k, 3.0))))

	func _pop(delay: float) -> float:
		return Motion.ease_value(Motion.Ease.EMPHASIZED, clampf((_t - delay) / 0.35, 0.0, 1.0))

	func _draw() -> void:
		if hud == null or hero.size() < 3:
			return
		var w := size.x
		var num := hud.num_font()
		var body := hud.body_font()
		var r := 74.0
		for i in 3:
			var c := Vector2(w * (i * 2 + 1) / 6.0, r + 8.0)
			var k := _pop(0.05 + 0.08 * i)
			if k <= 0.0:
				continue
			draw_set_transform(c, 0.0, Vector2(k, k))
			Hud.brass_disc(self, Vector2.ZERO, r)
			if i == 2:
				_draw_dial(r)
			else:
				var txt := Hud._group(_count(int(hero[i][1]), 0.2 + 0.08 * i))
				var fs := 52
				while fs > 22 and num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r * 1.45:
					fs -= 2
				var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var base := (num.get_ascent(fs) - num.get_descent(fs)) * 0.5
				draw_string(num, Vector2(-tw * 0.5 + 2.0, base + 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.4))
				draw_string(num, Vector2(-tw * 0.5, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.PRIMARY_HI)
			draw_set_transform(Vector2.ZERO)
			if i < 2 and fresh.get(["best", "wave"][i], false):
				var nk := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf((_t - 0.9) / 0.35, 0.0, 1.0))
				if nk > 0.0:
					var nt := Loc.t("stats.new")
					var nw := body.get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
					draw_set_transform(c + Vector2(r * 0.62, -r * 0.8), 0.12, Vector2(nk, nk))
					var nr := Rect2(-nw * 0.5, -13.0, nw, 26.0)
					Hud.pill(self, Rect2(nr.position + Vector2(1.5, 2.5), nr.size), Color(0, 0, 0, 0.4))
					Hud.pill(self, nr, TopBar.T_HOT)
					var nb := (body.get_ascent(16) - body.get_descent(16)) * 0.5
					draw_string(body, Vector2(-nw * 0.5, nb), nt, HORIZONTAL_ALIGNMENT_CENTER, nw, 16, Color("1A1206"))
					draw_set_transform(Vector2.ZERO)
			draw_string(body, Vector2(c.x - 100.0, c.y + r + 34.0), Hud.sentence(Loc.t(hero[i][0])), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 19, Color(Tok.TEXT_SECONDARY, k))
		# The tiles: three by three, each rising in after the one before.
		var gy := 2.0 * r + 70.0
		var gap := 14.0
		var tw := (w - 2.0 * gap) / 3.0
		var th := 124.0
		for i in tiles.size():
			var d := 0.35 + 0.05 * i
			var k := clampf((_t - d) / 0.3, 0.0, 1.0)
			if k <= 0.0:
				continue
			var e := Motion.ease_value(Motion.Ease.ENTER, k)
			var tr := Rect2((i % 3) * (tw + gap), gy + (i / 3) * (th + gap) + (1.0 - e) * 14.0, tw, th)
			_tile_box.bg_color.a = e
			_tile_box.border_color.a = e
			draw_style_box(_tile_box, tr)
			var ic := tr.position + Vector2(tw * 0.5, 30.0)
			draw_circle(ic, 19.0, Color(Tok.PRIMARY_LO, e), true, -1.0, true)
			draw_circle(ic, 16.5, Color(Color("0E1015"), e), true, -1.0, true)
			Hud.glyph(self, tiles[i][1], ic, 0.9, Color(Tok.PRIMARY_HI, e))
			var v = tiles[i][2]
			var txt: String = v if v is String else Hud._group(_count(int(v), d + 0.1))
			var fs := 32
			while fs > 20 and num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw - 20.0:
				fs -= 2
			draw_string(num, Vector2(tr.position.x, tr.position.y + 84.0), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, Color(Tok.TEXT_PRIMARY, e))
			var lab := Hud.sentence(Loc.t(tiles[i][0]))
			var lfs := 16
			while lfs > 12 and body.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > tw - 14.0:
				lfs -= 1
			draw_string(body, Vector2(tr.position.x, tr.position.y + 110.0), lab, HORIZONTAL_ALIGNMENT_CENTER, tw, lfs, Color(Tok.TEXT_SECONDARY, e))

	## Accuracy on a needle dial: a 240° scale with ticks, gold up to the
	## reading, and the needle on its brass boss.
	func _draw_dial(r: float) -> void:
		var fr := r - maxf(7.0, r * 0.2)
		var a0 := PI * 0.8333
		var span := PI * 1.3333
		var v := clampf(_needle, -0.05, 1.08)
		draw_arc(Vector2.ZERO, fr - 9.0, a0, a0 + span, 48, Tok.BORDER_HI, 4.0, true)
		if v > 0.0:
			draw_arc(Vector2.ZERO, fr - 9.0, a0, a0 + span * minf(v, 1.0), 48, Tok.PRIMARY, 4.0, true)
		for k in 11:
			var d := Vector2.from_angle(a0 + span * k / 10.0)
			var long := k % 5 == 0
			draw_line(d * (fr - (18.0 if long else 15.0)), d * (fr - 13.0), Color(Tok.PRIMARY_HI, 0.8 if long else 0.45), 1.6 if long else 1.0, true)
		var num := hud.num_font()
		var txt := "%d %%" % int(round(clampf(_needle, 0.0, 1.0) * 100.0))
		var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(num, Vector2(-tw * 0.5, fr * 0.62), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Tok.PRIMARY_HI)
		var nd := Vector2.from_angle(a0 + span * v)
		draw_line(Vector2(1.5, 2.5), nd * (fr - 16.0) + Vector2(1.5, 2.5), Color(0, 0, 0, 0.45), 3.5, true)
		draw_line(-nd * 8.0, nd * (fr - 16.0), Color("F2E6CC"), 3.0, true)
		draw_circle(Vector2.ZERO, 7.5, Tok.PRIMARY_LO, true, -1.0, true)
		draw_circle(Vector2(-0.6, -0.6), 5.5, Tok.PRIMARY, true, -1.0, true)


## A menu button as a brass token hanging on a cord from the top of the
## screen: it sways on its own, swings when tapped, and drops in on its
## cord when the menu opens. Its icon is engraved in the face.
class Token extends UIButton:
	const K := 16.0                # pendulum stiffness (rad/s² per rad)
	const C := 1.3                 # damping
	var hud: Hud
	var glyph := ""
	var _ang := 0.0
	var _w := 0.0
	var _clock := 0.0
	var _phase := randf() * TAU
	var _drop := 1.0               # 0 hidden above the screen .. 1 hanging
	var _drop_t := 9.0
	var _drop_wait := 0.0

	func _ready() -> void:
		super()
		pressed.connect(func() -> void: _w += (4.5 if randf() < 0.5 else -4.5))
		_ang = randf_range(-0.08, 0.08)

	func enter(delay: float) -> void:
		_drop_wait = delay
		_drop_t = 0.0
		_drop = 0.0

	func _process(delta: float) -> void:
		var dt := minf(delta, 1.0 / 30.0)
		_clock += dt
		if _drop_t < 9.0:
			if _drop_wait > 0.0:
				_drop_wait -= dt
			else:
				_drop_t += dt
				var was := _drop
				_drop = clampf(_drop_t / 0.45, 0.0, 1.0)
				if was < 1.0 and _drop >= 1.0:
					# The cord catches it: a jolt and a swing.
					_w += randf_range(-2.2, 2.2)
					Sfx.play("tick", randf_range(1.1, 1.3), -12.0)
		var air := 0.0 if Prefs.reduced_motion else sin(_clock * 0.9 + _phase) * 0.35
		_w += (-K * sin(_ang) - C * _w + air) * dt
		_ang += _w * dt
		queue_redraw()

	func _draw() -> void:
		var r := size.y * 0.5 - 4.0
		var top_y := -get_global_rect().position.y - 4.0
		var fall := Motion.ease_value(Motion.Ease.EMPHASIZED, _drop)
		var c0 := Vector2(size.x * 0.5, size.y * 0.5 - (1.0 - fall) * (size.y + get_global_rect().position.y + 20.0))
		var pivot := Vector2(size.x * 0.5, top_y)
		var c := pivot + (c0 - pivot).rotated(_ang)
		var dir := (c - pivot).normalized()
		draw_line(pivot + Vector2(1.5, 2.0), c - dir * r + Vector2(1.5, 2.0), Color(0, 0, 0, 0.35), 2.0, true)
		draw_line(pivot, c - dir * (r + 3.0), Pal.STRING, 1.6, true)
		# The eyelet the cord ties to.
		draw_arc(c - dir * (r + 2.0), 4.0, 0.0, TAU, 14, Tok.PRIMARY_LO, 2.4, true)
		draw_set_transform(c, _ang)
		Hud.brass_disc(self, Vector2.ZERO, r)
		# Engraved: a dark cut with a lit lower lip.
		var s := r / 24.0
		Hud.glyph(self, glyph, Vector2(0.8, 1.2), s, Color(Tok.PRIMARY_HI, 0.35))
		Hud.glyph(self, glyph, Vector2.ZERO, s, Tok.PRIMARY_HI)
		draw_set_transform(Vector2.ZERO)


## The language switch as a brass lever on an engraved plate: NO on the
## left, EN on the right; tapping throws the lever across with a spring.
class Lever extends UIButton:
	signal picked(code: String)
	var hud: Hud
	var _a := 0.0                  # lever angle
	var _av := 0.0
	var _drop := 1.0
	var _drop_t := 9.0
	var _drop_wait := 0.0

	func _ready() -> void:
		super()
		_a = _want()
		pressed.connect(func() -> void: picked.emit("en" if Loc.lang == "no" else "no"))

	func enter(delay: float) -> void:
		_drop_wait = delay
		_drop_t = 0.0
		_drop = 0.0

	func _want() -> float:
		return -0.62 if Loc.lang == "no" else 0.62

	func _process(delta: float) -> void:
		var dt := minf(delta, 1.0 / 30.0)
		if _drop_t < 9.0:
			if _drop_wait > 0.0:
				_drop_wait -= dt
			else:
				_drop_t += dt
				_drop = clampf(_drop_t / 0.4, 0.0, 1.0)
		var was := signf(_a)
		_av += (260.0 * (_want() - _a) - 16.0 * _av) * dt
		_a += _av * dt
		if was != signf(_a) and was != 0.0:
			Sfx.play("tick", 0.9, -8.0)
		queue_redraw()

	func _draw() -> void:
		if hud == null:
			return
		var k := Motion.ease_value(Motion.Ease.EMPHASIZED, _drop)
		draw_set_transform(Vector2(0, (1.0 - k) * -40.0))
		var plate := Rect2(4.0, size.y * 0.22, size.x - 8.0, size.y * 0.66)
		Hud.lever(self, plate, _a, ["NO", "EN"], hud.body_font())
		draw_set_transform(Vector2.ZERO)


## NO | EN: a glass pill with a gold knob that slides to the language.
class LangPill extends UIButton:
	signal picked(code: String)
	var hud: Hud
	var _k := -1.0

	func _ready() -> void:
		super()
		pressed.connect(func() -> void:
			var code := "no" if get_local_mouse_position().x < size.x * 0.5 else "en"
			if code == Loc.lang:
				code = "en" if Loc.lang == "no" else "no"
			picked.emit(code))

	func _process(delta: float) -> void:
		var want := 0.0 if Loc.lang == "no" else 1.0
		if _k < 0.0:
			_k = want
		if absf(_k - want) > 0.0001:
			_k = move_toward(_k, want, delta / 0.2)
			queue_redraw()

	func _draw() -> void:
		if hud == null:
			return
		var pad := 6.0
		var hw := (size.x - pad * 2.0) * 0.5
		var e := Motion.ease_value(Motion.Ease.STANDARD, clampf(_k, 0.0, 1.0))
		Hud.pill(self, Rect2(pad + hw * e, pad, hw, size.y - pad * 2.0), Tok.PRIMARY)
		var f := hud.body_font()
		var fs := 22
		for i in 2:
			var t: String = ["NO", "EN"][i]
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var on := absf(e - i) < 0.5
			var base := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
			draw_string(f, Vector2(pad + hw * (i + 0.5) - tw * 0.5, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.ON_PRIMARY if on else Tok.TEXT_SECONDARY)


## One settings row: an engraved icon and the label on the left, its
## control on the right – a brass switch that snaps across on a spring, a
## three-bar level meter (rising bars that fill with gold; none lit is off)
## or the language pair. The whole row is the touch target; tapping the
## control itself picks the bar or side under the finger.
class SetRow extends UIButton:
	enum Kind {SWITCH, STEPS, LANG, HOLD}
	const HOLD_TIME := 1.5
	const BAR_W := 15.0
	const BAR_GAP := 10.0
	signal picked(v: int)
	var hud: Hud
	var kind := Kind.SWITCH
	var key := ""
	var glyph := ""
	var getter: Callable
	var note: Callable
	var first := false
	var _shown := -1.0
	var _sv := 0.0
	var _hold := 0.0               # HOLD: how far the ring has filled
	var _holding := false
	var done_t := 9.0              # HOLD: time since it went through

	func _ready() -> void:
		super()
		pressed.connect(_on_press)
		if kind == Kind.HOLD:
			button_down.connect(func() -> void:
				if done_t > 1.0:
					_holding = true)
			button_up.connect(func() -> void: _holding = false)

	func refresh() -> void:
		queue_redraw()

	func _value() -> int:
		return int(getter.call())

	func _control_rect() -> Rect2:
		var cy := size.y * 0.5
		match kind:
			Kind.SWITCH:
				return Rect2(size.x - 156.0, cy - 30.0, 156.0, 60.0)
			Kind.STEPS:
				var w := 3.0 * BAR_W + 2.0 * BAR_GAP
				return Rect2(size.x - w, cy - 20.0, w, 40.0)
		return Rect2(size.x - 156.0, cy - 30.0, 156.0, 60.0)

	func _on_press() -> void:
		var v := _value()
		var x := get_local_mouse_position().x
		var r := _control_rect()
		match kind:
			Kind.HOLD:
				pass
			Kind.SWITCH:
				picked.emit(1 - v)
			Kind.STEPS:
				var nv := (v + 1) % 4
				if x >= r.position.x - 14.0:
					var i := clampi(int((x - r.position.x + BAR_GAP * 0.5) / (BAR_W + BAR_GAP)), 0, 2)
					nv = i + 1
					if nv == v:
						nv = i
				picked.emit(nv)
			Kind.LANG:
				var nv := 1 - v
				if x >= r.position.x:
					nv = 0 if x < r.position.x + r.size.x * 0.5 else 1
				if nv != v:
					picked.emit(nv)

	func _process(delta: float) -> void:
		if getter.is_null():
			return
		var dt := minf(delta, 1.0 / 30.0)
		if kind == Kind.HOLD:
			done_t += dt
			var before := _hold
			if _holding:
				_hold = minf(1.0, _hold + dt / HOLD_TIME)
				if floorf(before * 4.0) != floorf(_hold * 4.0) and _hold < 1.0:
					Sfx.play("tick", 0.8 + _hold * 0.6, -10.0)
				if _hold >= 1.0:
					_holding = false
					done_t = 0.0
					picked.emit(1)
			else:
				_hold = move_toward(_hold, 0.0, dt * (0.8 if done_t < 1.0 else 3.0))
			queue_redraw()
			return
		var want := float(_value())
		if _shown < -0.5:
			_shown = want
		if absf(_shown - want) > 0.0005 or absf(_sv) > 0.01:
			# A spring, a little under-damped: the knob overshoots and settles.
			var was := _shown
			_sv += (420.0 * (want - _shown) - 24.0 * _sv) * dt
			_shown += _sv * dt
			if kind != Kind.STEPS and (was - 0.5) * (_shown - 0.5) < 0.0:
				Sfx.play("tick", 0.9, -8.0)
			queue_redraw()

	func _draw() -> void:
		if hud == null or getter.is_null():
			return
		if not first:
			draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(Tok.BORDER, 0.9), 2.0)
		var f := hud.body_font()
		var fs := Tok.TYPE_BODY + 1
		var cy := size.y * 0.5
		# The icon, engraved in a small brass ring (coral for the one that
		# destroys something).
		var danger := kind == Kind.HOLD
		var ic := Vector2(21.0, cy)
		draw_circle(ic, 21.0, Tok.DANGER.darkened(0.35) if danger else Tok.PRIMARY_LO, true, -1.0, true)
		draw_circle(ic + Vector2(-0.5, -0.5), 19.0, Color("0E1015"), true, -1.0, true)
		Hud.glyph(self, glyph, ic, 0.95, Tok.DANGER if danger else Tok.PRIMARY_HI)
		var tx := 58.0
		var sub: String = note.call() if note.is_valid() else ""
		var base := cy + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - (12.0 if sub != "" else 0.0)
		draw_string(f, Vector2(tx, base), Loc.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.DANGER if danger else Tok.TEXT_PRIMARY)
		if sub != "":
			draw_string(hud.body_font(), Vector2(tx, base + 27.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Tok.TEXT_FAINT)
		var r := _control_rect()
		var v := _value()
		match kind:
			Kind.HOLD:
				# A ring that fills while the finger holds; done, it flashes
				# and shows a tick.
				var c := Vector2(size.x - 28.0, cy)
				draw_circle(c + Vector2(1.5, 2.5), 24.0, Color(0, 0, 0, 0.4), true, -1.0, true)
				draw_circle(c, 24.0, Tok.DANGER.darkened(0.45), true, -1.0, true)
				draw_circle(c, 21.0, Color("0A0C10"), true, -1.0, true)
				if _hold > 0.005:
					draw_arc(c, 17.0, -PI * 0.5, -PI * 0.5 + TAU * _hold, 40, Tok.DANGER, 5.0, true)
				if done_t < 1.2:
					var fl := 1.0 - done_t / 1.2
					draw_circle(c, 24.0 + 10.0 * (1.0 - fl), Color(Tok.DANGER, 0.3 * fl), true, -1.0, true)
					draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(8, -6)]), Tok.TEXT_PRIMARY, 3.0, true)
				else:
					draw_circle(c, 4.0, Color(Tok.DANGER, 0.5 + 0.5 * _hold), true, -1.0, true)
			Kind.SWITCH:
				# The same brass lever as the language switch: Off | On.
				Hud.lever(self, r, lerpf(-0.62, 0.62, clampf(_shown, -0.15, 1.15)), [Loc.t("settings.off"), Loc.t("settings.on")], f)
			Kind.STEPS:
				var word := Loc.t("settings.level.%d" % v)
				var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
				var wb := cy + (f.get_ascent(21) - f.get_descent(21)) * 0.5
				draw_string(f, Vector2(r.position.x - 18.0 - ww, wb), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Tok.PRIMARY_HI if v > 0 else Tok.TEXT_FAINT)
				var lvl := clampf(_shown, 0.0, 3.2)
				var bottom := cy + 21.0
				for i in 3:
					var h := 20.0 + i * 11.0
					var x := r.position.x + i * (BAR_W + BAR_GAP)
					var fill := clampf(lvl - i, 0.0, 1.0)
					var br := Rect2(x, bottom - h, BAR_W, h)
					draw_rect(Rect2(br.position + Vector2(1.5, 2.5), br.size), Color(0, 0, 0, 0.4))
					draw_rect(br, Tok.PRIMARY_LO)
					draw_rect(br.grow(-2.0), Color("0A0C10"))
					if fill > 0.01:
						var fh := (h - 6.0) * fill
						if fill > 0.9:
							draw_rect(br.grow(5.0), Color(Tok.PRIMARY, 0.1))
						draw_rect(Rect2(x + 3.0, bottom - 3.0 - fh, BAR_W - 6.0, fh), Tok.PRIMARY)
						draw_rect(Rect2(x + 3.0, bottom - 3.0 - fh, 2.0, fh), Color(Tok.PRIMARY_HI, 0.8))
			Kind.LANG:
				Hud.lever(self, r, lerpf(-0.62, 0.62, clampf(_shown, -0.15, 1.15)), ["NO", "EN"], f)


# ---------------------------------------------------------------- top bar

## The in-game bar as one crafted instrument, in the slingshot's brass and
## gunmetal:
##  - a brass medallion (left) carries the wave number and spins over to
##    the next one;
##  - the score runs on a mechanical counter: drums rolling in a recessed
##    window behind a brass bezel, with the multiplier dial beside it (three
##    lamps for the streak);
##  - the lives are knots in a rope (right);
##  - the wave's progress is a tension string across the whole bar,
##    between two brass pegs: slack at the start, it pulls tighter with
##    every kill (and quivers), fills with gold toward the fret with the
##    crown (the finale), and sings when it is taut.
## A run opens with the pieces arriving in turn (`begin_intro`). There is
## no pause button: a double-tap on the field (or Back) pauses.
class TopBar extends Control:
	signal record_broken
	signal wave_record
	const DRUMS_MIN := 5
	const NEAR := 0.8              # from here on the counter says how far to the record
	# The string's colour follows the tension: cool brass while slack, gold
	# as it builds, amber toward the finale, hot gold when it sings.
	const T_COOL := Color("9C8C69")
	const T_WARM := Color("EC9A3C")
	const T_HOT := Color("FFC266")
	const CELL := 34.0             # one drum's width
	const PLATE_H := 62.0
	const ROPE := Color("C4BBA8")
	const ROPE_DARK := Color("8C8474")
	const ROPE_LIGHT := Color("E8E0CF")
	const BRASS_DEEP := Color("5E4620")
	const WINDOW := Color("0A0C10")
	const DRUM := Color("16191F")
	var hud: Hud
	var score := 0
	var shown_score := 0.0
	var mult := 1
	var streak := 0
	var lives := 3
	var phase := 1
	var progress := 0.0
	var remaining := 0             # kills still needed this wave
	var finale_at := 0.8           # where on the string the fret sits
	var shown_progress := 0.0
	var pulse := 0.0
	var badge_pop := 0.0
	var knot_shake := 0.0
	var show_fps := false
	var hot := false               # overload: the dial blazes
	var glint := 0.0               # a big gain: the bezel flashes
	var intro_t := 99.0            # time into the run's opening
	var best := 0                  # the record to beat this run (0: none yet)
	var best_wave := 0
	var daily := false
	var _broken := false
	var _record_t := -1.0          # the NEW RECORD stamp's time (<0: not yet)
	var _wave_crown := false
	var _wave_new_t := 9.0
	var _front: Control            # above the drums: stamp, crown, tag
	var _clock := 0.0
	var _taps: Array[int] = []
	var _last_score := 0
	var _gain := 0
	var _gain_t := 9.0
	var _drum: Array[float] = []   # each place's drum, units first (0..10)
	var _plate_w := 0.0
	var _shown_lives := 3
	var _knot_t := [9.0, 9.0, 9.0] # time since each knot was tied or untied
	var _pluck := 0.0              # the string's vibration
	var _pluck_t := 9.0
	var _slack := 0.0              # extra sag while a new wave lets it go
	var _last_progress := 0.0
	var _shimmer := -1.0           # the taut string sings: light runs along it
	var _twanged := true
	var _flip := 1.0               # medallion turning over, 0..1
	var _shown_phase := 1
	var _wind := 0.0               # the right peg turns as the string tightens
	var _lamps := [0.0, 0.0, 0.0]
	var _bezel: StyleBoxFlat
	var _window: StyleBoxFlat
	var _drums: Control            # the window the drums turn in (clipped)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_drums = Control.new()
		_drums.clip_contents = true
		_drums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drums.draw.connect(_draw_drums)
		add_child(_drums)
		_front = Control.new()
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.draw.connect(_draw_front)
		add_child(_front)
		_bezel = StyleBoxFlat.new()
		_bezel.set_corner_radius_all(18)
		_bezel.shadow_color = Color(0, 0, 0, 0.45)
		_bezel.shadow_size = 10
		_bezel.shadow_offset = Vector2(0, 4)
		_bezel.anti_aliasing = true
		_window = StyleBoxFlat.new()
		_window.bg_color = WINDOW
		_window.set_corner_radius_all(12)
		_window.border_color = Color(0, 0, 0, 0.8)
		_window.set_border_width_all(1)
		_window.anti_aliasing = true

	func set_mult(m: int) -> void:
		if m != mult:
			badge_pop = 1.0
		mult = m

	func lose_life(n: int) -> void:
		lives = n
		knot_shake = 1.0

	## The run opens: pegs, string, counter, medallion, dial and knots arrive
	## one after another over about a second.
	func begin_intro() -> void:
		intro_t = 0.0
		_twanged = false
		_drum.clear()
		for i in DRUMS_MIN:
			# Each drum starts a few digits short and rolls forward onto 0.
			_drum.append(fposmod(-2.2 - i * 1.6, 10.0))
		_shown_lives = lives
		for i in 3:
			_knot_t[i] = -(0.62 + 0.13 * i)
		_shown_phase = phase
		_flip = 0.0
		_last_progress = progress
		shown_progress = progress
		_pluck = 0.0
		_slack = 0.0
		_shimmer = -1.0
		_gain = 0
		_gain_t = 9.0
		_last_score = score
		_broken = false
		_record_t = -1.0
		_wave_crown = false
		_wave_new_t = 9.0

	## A kill's energy arrived (see Backdrop): the string takes it, quivers.
	func energy() -> void:
		_pluck = minf(3.0, _pluck * exp(-_pluck_t * 4.5) + 1.6)
		_pluck_t = 0.0

	## Where the string's colour sits for progress `pr`.
	func tension_col(pr: float) -> Color:
		if pr >= 1.0:
			return T_HOT
		if pr < 0.4:
			return T_COOL.lerp(Tok.PRIMARY, pr / 0.4)
		if pr < finale_at:
			return Tok.PRIMARY.lerp(T_WARM, (pr - 0.4) / maxf(0.01, finale_at - 0.4))
		return T_WARM.lerp(T_HOT, 0.4 * _beat())

	## 1 on the music's beat, falling to 0 before the next.
	func _beat() -> float:
		var b := Music.beat()
		return pow(1.0 - fposmod(b, 1.0), 3.0) if b >= 0.0 else 0.5 + 0.5 * sin(_clock * 6.0)

	## A medallion's metal by wave: bronze, silver, gold, then ember gold.
	static func tier(wave: int) -> Array:
		if wave <= 3:
			return [Color("5E3A1E"), Color("B07A45"), Color("E6B484")]
		if wave <= 6:
			return [Color("4E555F"), Color("A7AFBA"), Color("EEF2F6")]
		if wave <= 9:
			return [Tok.PRIMARY_LO, Tok.PRIMARY, Tok.PRIMARY_HI]
		return [Color("7A3A12"), Color("E08A2E"), Color("FFD08A")]

	func knots_rect() -> Rect2:
		var l := hud.l
		var h := l.top_bar_h - l.safe_top
		var x0 := l.size.x - l.margin - 160.0
		return Rect2(x0, l.safe_top, l.size.x - x0, h * 0.6)

	func _gui_input(e: InputEvent) -> void:
		var press: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)
		if not press or modulate.a < 0.5:
			return
		if knots_rect().has_point(e.position):
			accept_event()
			var now := Time.get_ticks_msec()
			_taps.append(now)
			while _taps.size() > 0 and now - _taps[0] > 900:
				_taps.pop_front()
			if _taps.size() >= 3:
				_taps.clear()
				show_fps = not show_fps

	func _has_point(p: Vector2) -> bool:
		return hud != null and hud.l != null and visible and knots_rect().has_point(p)

	## 0..1 over [t0, t0 + d] of the opening.
	func _k(t0: float, d: float) -> float:
		return clampf((intro_t - t0) / d, 0.0, 1.0)

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.001)
		intro_t += rd
		_clock += rd
		if not _twanged and intro_t >= 0.55:
			_twanged = true
			_pluck = 5.0
			_pluck_t = 0.0
			Sfx.play("twang", 1.3, -9.0)
		# Score: the last gain, and each drum rolling forward to its digit.
		if score < _last_score:
			shown_score = float(score)
			_gain = 0
			_gain_t = 9.0
		elif score > _last_score:
			_gain = (_gain if _gain_t < 0.7 else 0) + score - _last_score
			_gain_t = 0.0
		_last_score = score
		_gain_t += rd
		if best > 0 and not _broken and score > best and intro_t > 1.0:
			_broken = true
			_record_t = 0.0
			record_broken.emit()
		if _record_t >= 0.0:
			_record_t += rd
		if best_wave > 0 and not _wave_crown and phase > best_wave:
			_wave_crown = true
			_wave_new_t = 0.0
			wave_record.emit()
		_wave_new_t += rd
		var diff := float(score) - shown_score
		if absf(diff) > 0.01:
			shown_score += signf(diff) * maxf(absf(diff) * Pal.damp(0.18, rd), minf(absf(diff), 60.0 * rd))
		var places := maxi(DRUMS_MIN, str(maxi(score, 0)).length())
		while _drum.size() < places:
			_drum.append(0.0)
		if intro_t > 0.3:
			var rest := maxi(score, 0)
			for i in _drum.size():
				var target := float(rest % 10)
				rest /= 10
				var dist := fposmod(target - _drum[i], 10.0)
				if dist < 0.002 or dist > 9.998:
					_drum[i] = target
				else:
					var step := maxf(dist * Pal.damp(0.075 + 0.03 * i, rd), minf(dist, 2.0 * rd))
					_drum[i] = fposmod(_drum[i] + step, 10.0)
		var pw := _drum.size() * CELL + ((_drum.size() - 1) / 3) * 8.0 + 24.0
		_plate_w = pw if _plate_w <= 0.0 else lerpf(_plate_w, pw, Pal.damp(0.12, rd))
		# Knots tied (won back) or untied (lost) since last frame.
		if lives != _shown_lives:
			for i in range(mini(lives, _shown_lives), maxi(lives, _shown_lives)):
				if i < 3:
					_knot_t[i] = 0.0
			_shown_lives = lives
		for i in 3:
			_knot_t[i] += rd
		# The string: a kill plucks it, the last one makes it sing, a new
		# wave lets it go slack again.
		if progress > _last_progress + 0.0001:
			if progress >= 1.0 and _last_progress < 1.0:
				_pluck = 4.5
				_shimmer = 0.0
				Sfx.play("twang", 1.6, -8.0)
			_pluck_t = 0.0 if progress >= 1.0 else _pluck_t
		elif progress < _last_progress - 0.2:
			_slack = 1.0
			_pluck = 3.0
			_pluck_t = 0.0
		_last_progress = progress
		_pluck_t += rd
		_slack = move_toward(_slack, 0.0, rd / 0.9)
		if _shimmer >= 0.0:
			_shimmer += rd
			if _shimmer > 1.1:
				_shimmer = -1.0
		shown_progress = lerpf(shown_progress, progress, Pal.damp(0.15, rd))
		_wind = lerpf(_wind, shown_progress * TAU * 1.5, Pal.damp(0.1, rd))
		# The medallion turns over to a new wave's number.
		if phase != _shown_phase and _flip >= 1.0:
			_flip = 0.0
		if _flip < 1.0:
			_flip = minf(1.0, _flip + rd / 0.65)
			if _flip >= 1.0:
				_shown_phase = phase
		# Streak lamps: 0–3 lit; all three flash out when the step is taken.
		var lit := 3 if streak >= 9 else streak % 3
		for i in 3:
			var want := 1.0 if i < lit else 0.0
			_lamps[i] = move_toward(_lamps[i], want, rd / (0.08 if want > _lamps[i] else 0.35))
		pulse = maxf(0.0, pulse - rd / 0.18)
		badge_pop = maxf(0.0, badge_pop - rd / 0.3)
		knot_shake = maxf(0.0, knot_shake - rd / 0.6)
		glint = maxf(0.0, glint - rd / 0.5)
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.l == null:
			return
		var l := hud.l
		var top := l.safe_top
		var h := l.top_bar_h - top
		_draw_string_gauge(l, top, h)
		_draw_medallion(l, top)
		_draw_counter(l, top)
		_draw_knots(l, top, h)
		if show_fps:
			var sg := hud._game_sensor()
			var gy := Input.get_gyroscope()
			var fps := "%d FPS  ·  G %.1f %.1f %.1f  ·  GYRO %.2f %.2f %.2f" % [Engine.get_frames_per_second(), sg.x, sg.y, sg.z, gy.x, gy.y, gy.z]
			draw_string(hud.caps_font(), Vector2(0, top + 12.0), fps, HORIZONTAL_ALIGNMENT_RIGHT, l.size.x - l.margin, 11, Tok.TEXT_FAINT)

	# ------------------------------------------------ the tension string

	func _string_at(a: Vector2, b: Vector2, sag: float, amp: float, t: float) -> Vector2:
		var vib := amp * (sin(PI * t) * sin(_pluck_t * 46.0) + 0.3 * sin(TAU * t) * sin(_pluck_t * 92.0 + 1.0))
		return a.lerp(b, t) + Vector2(0, sag * sin(PI * t) + vib)

	func _draw_string_gauge(l: Layout, top: float, h: float) -> void:
		var w := l.size.x
		var ys := top + h * 0.86
		var a := Vector2(24.0, ys)
		var b := Vector2(w - 24.0, ys)
		var pr := clampf(shown_progress, 0.0, 1.0)
		var taut := 1.0 - pow(1.0 - pr, 2.0)
		var sag := lerpf(10.0, 0.5, taut) + 12.0 * _slack + 16.0 * (1.0 - _k(0.5, 0.08))
		var amp := _pluck * exp(-_pluck_t * 4.5)
		var drawn := Motion.ease_value(Motion.Ease.STANDARD, _k(0.15, 0.4))
		var peg := Motion.ease_value(Motion.Ease.EMPHASIZED, _k(0.0, 0.3))
		const N := 48
		if drawn > 0.0:
			var line := PackedVector2Array()
			var sh := PackedVector2Array()
			for k in N + 1:
				var p := _string_at(a, b, sag, amp, drawn * k / float(N))
				line.append(p)
				sh.append(p + Vector2(1.0, 2.5))
			draw_polyline(sh, Color(0, 0, 0, 0.35), 2.4, true)
			draw_polyline(line, Color("7F8590"), 2.0, true)
			if pr > 0.003 and drawn >= 1.0:
				var fill := PackedVector2Array()
				var m := maxi(2, int(ceil(N * pr)))
				for k in m + 1:
					fill.append(_string_at(a, b, sag, amp, pr * k / float(m)))
				var col := tension_col(pr)
				if pr >= finale_at:
					# The finale: the whole wound length glows on the beat.
					draw_polyline(fill, Color(col, 0.1 + 0.12 * _beat()), 9.0, true)
				draw_polyline(fill, col.darkened(0.45), 3.6, true)
				draw_polyline(fill, col, 2.4, true)
				for k in fill.size():
					fill[k] += Vector2(0, -0.8)
				draw_polyline(fill, Color(col.lightened(0.4), 0.8), 0.9, true)
				var tip := _string_at(a, b, sag, amp, pr)
				draw_circle(tip, 9.0, Color(col, 0.16), true, -1.0, true)
				draw_circle(tip, 3.6, col.lightened(0.3), true, -1.0, true)
			# Taut and singing: a light runs along the whole string.
			if _shimmer >= 0.0:
				var st := Motion.ease_value(Motion.Ease.STANDARD, clampf(_shimmer / 0.9, 0.0, 1.0))
				var sp := _string_at(a, b, sag, amp, st)
				var sa := sin(PI * clampf(_shimmer / 1.1, 0.0, 1.0))
				draw_circle(sp, 16.0, Color(Tok.PRIMARY_HI, 0.12 * sa), true, -1.0, true)
				draw_circle(sp, 6.0, Color(1, 1, 1, 0.5 * sa), true, -1.0, true)
			# The fret where the finale comes, with its crown.
			if drawn >= 1.0:
				var reached := pr >= finale_at - 0.001
				var fp := _string_at(a, b, sag, amp, finale_at)
				var col := Tok.PRIMARY_HI if reached else Tok.PRIMARY_LO
				draw_line(fp + Vector2(1, -6), fp + Vector2(1, 8), Color(0, 0, 0, 0.4), 3.0, true)
				draw_line(fp + Vector2(0, -7), fp + Vector2(0, 7), col, 3.0, true)
				var cp := fp + Vector2(0, -19.0)
				if reached:
					draw_circle(cp + Vector2(0, 1), 12.0, Color(Tok.PRIMARY, 0.1 + 0.08 * sin(_clock * 4.0)), true, -1.0, true)
				draw_colored_polygon(PackedVector2Array([
					cp + Vector2(-8, 5), cp + Vector2(-9, -4), cp + Vector2(-4, 0), cp + Vector2(0, -7),
					cp + Vector2(4, 0), cp + Vector2(9, -4), cp + Vector2(8, 5)]), col)
		# The pegs: a brass knob at the left end, a toothed tuning peg at the
		# right that turns as the string is wound.
		if peg > 0.0:
			_peg(a, 9.0 * peg, 0.0, false)
			_peg(b, 10.0 * peg, _wind, true)
		# How many are left, engraved beside the tuning peg.
		var la := _k(0.7, 0.3)
		if la > 0.0:
			var body := hud.body_font()
			var txt := ""
			var col := Tok.TEXT_SECONDARY
			if progress >= 1.0:
				txt = ""
			elif pr >= finale_at - 0.001:
				txt = Loc.t("hud.finale")
				col = T_WARM.lerp(T_HOT, 0.5 * _beat())
			elif remaining > 0:
				txt = Loc.t("hud.left") % remaining
			if txt != "":
				draw_string(body, Vector2(0, ys - 12.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, w - 44.0, 16, Color(col, la))

	func _peg(c: Vector2, r: float, ang: float, teeth: bool) -> void:
		if r <= 0.5:
			return
		draw_circle(c + Vector2(1.5, 2.5), r + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		if teeth:
			for k in 8:
				var d := Vector2.from_angle(ang + TAU * k / 8.0)
				draw_line(c + d * (r - 1.0), c + d * (r + 3.0), Tok.PRIMARY_LO, 3.2, true)
		draw_circle(c, r, Tok.PRIMARY_LO, true, -1.0, true)
		draw_circle(c + Vector2(-0.8, -0.8), r - 2.0, Tok.PRIMARY, true, -1.0, true)
		draw_arc(c, r - 2.5, PI * 1.05, PI * 1.6, 10, Color(Tok.PRIMARY_HI, 0.9), 1.4, true)
		draw_circle(c, r * 0.3, BRASS_DEEP, true, -1.0, true)
		if teeth:
			draw_line(c - Vector2.from_angle(ang) * r * 0.3, c + Vector2.from_angle(ang) * r * 0.3, Color(0, 0, 0, 0.5), 1.4, true)

	# ------------------------------------------------ medallion

	func _draw_medallion(l: Layout, top: float) -> void:
		var k := _k(0.3, 0.4)
		if k <= 0.0:
			return
		var c := Vector2(l.margin + 36.0, top + 48.0)
		var r := 32.0
		# Turning over: the disc narrows to its edge and opens on the new
		# number (on the opening it simply turns in).
		var sx := absf(cos(_flip * PI)) if _flip < 1.0 else 1.0
		var n := phase if _flip >= 0.5 else _shown_phase
		sx = maxf(sx, 0.04) * Motion.ease_value(Motion.Ease.EMPHASIZED, k)
		var m := tier(n)
		if n >= 10:
			# Ember: a slow warm glow round the coin.
			draw_circle(c, r + 8.0, Color(m[1], 0.08 + 0.06 * sin(_clock * 2.5)), true, -1.0, true)
		draw_set_transform(c + Vector2(2.0, 3.0), 0.0, Vector2(sx, 1.0))
		draw_circle(Vector2.ZERO, r + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_set_transform(c, 0.0, Vector2(sx, 1.0))
		draw_circle(Vector2.ZERO, r, m[0], true, -1.0, true)
		draw_circle(Vector2(-0.8, -1.0), r - 2.5, m[1], true, -1.0, true)
		# The milled rim, the lit edge, the sunken face.
		for i in 36:
			var d := Vector2.from_angle(TAU * i / 36.0)
			draw_line(d * (r - 5.5), d * (r - 2.5), Color(m[0], 0.7), 1.2, true)
		draw_arc(Vector2.ZERO, r - 1.5, PI * 1.02, PI * 1.62, 16, Color(m[2], 0.85), 1.6, true)
		draw_circle(Vector2.ZERO, r - 7.0, Color("0E1015"), true, -1.0, true)
		draw_arc(Vector2.ZERO, r - 7.0, PI * 0.1, PI * 0.9, 16, Color(m[2], 0.25), 1.2, true)
		draw_arc(Vector2.ZERO, r - 10.0, 0.0, TAU, 40, Color(m[0], 0.9), 1.0, true)
		var num := hud.num_font()
		var txt := str(n)
		var fs := 30 if txt.length() < 2 else 25
		var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := (num.get_ascent(fs) - num.get_descent(fs)) * 0.5
		draw_string(num, Vector2(-tw * 0.5, base + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, m[2])
		draw_set_transform(Vector2.ZERO)
		# Past the best wave ever: a crown on the coin, and for a moment the
		# caption says so.
		if _wave_crown:
			var ck := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf(_wave_new_t / 0.4, 0.0, 1.0))
			_crown(c + Vector2(0, -r - 6.0), 1.0 * ck, T_HOT)
		var body := hud.body_font()
		var cap := Loc.t("hud.waveWord")
		var ccol := Color(Tok.TEXT_SECONDARY, k)
		if _wave_new_t < 3.2:
			cap = Loc.t("hud.newWave")
			ccol = Color(T_HOT, minf(1.0, (3.2 - _wave_new_t) / 0.4))
		draw_string(body, Vector2(c.x - 70.0, c.y + r + 19.0), cap, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 15, ccol)

	func _crown(c: Vector2, s: float, col: Color, ci: CanvasItem = null) -> void:
		if s <= 0.01:
			return
		var t := ci if ci != null else self
		var pts := PackedVector2Array()
		for q in [Vector2(-9, 5), Vector2(-10, -5), Vector2(-4.5, -0.5), Vector2(0, -8), Vector2(4.5, -0.5), Vector2(10, -5), Vector2(9, 5)]:
			pts.append(c + q * s)
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(1.2, 2.0))
		t.draw_colored_polygon(sh, Color(0, 0, 0, 0.4))
		t.draw_colored_polygon(pts, col)
		t.draw_line(c + Vector2(-8, 3.5) * s, c + Vector2(8, 3.5) * s, col.darkened(0.35), 1.2 * s, true)

	# ------------------------------------------------ counter and dial

	func _draw_counter(l: Layout, top: float) -> void:
		var k := _k(0.1, 0.55)
		if k <= 0.0:
			return
		var w := l.size.x
		var drop := (1.0 - Motion.ease_value(Motion.Ease.EMPHASIZED, k)) * -110.0
		var nudge := 2.5 * sin(pulse * PI)
		var pw := _plate_w
		var r := Rect2(w * 0.5 - pw * 0.5, top + 16.0 + drop + nudge, pw, PLATE_H)
		# The brass bezel, the recessed window, and the drums in it.
		# Near the record the bezel breathes; once it is beaten it stays lit.
		var breath := 0.0
		if _near():
			breath = 0.5 + 0.5 * sin(_clock * 3.2)
		var lit := maxf(glint, 0.5 * breath)
		if _broken:
			lit = maxf(lit, 0.55)
		_bezel.bg_color = Tok.PRIMARY_LO.lerp(Tok.PRIMARY, 0.35 + 0.65 * lit)
		draw_style_box(_bezel, r.grow(5.0))
		draw_line(Vector2(r.position.x + 12.0, r.position.y - 3.6), Vector2(r.end.x - 12.0, r.position.y - 3.6), Color(Tok.PRIMARY_HI, 0.55), 1.2, true)
		draw_line(Vector2(r.position.x + 12.0, r.end.y + 3.8), Vector2(r.end.x - 12.0, r.end.y + 3.8), Color(BRASS_DEEP, 0.9), 1.4, true)
		draw_style_box(_window, r)
		_drums.position = r.position + Vector2(10.0, 6.0)
		_drums.size = Vector2(r.size.x - 20.0, PLATE_H - 12.0)
		_drums.queue_redraw()
		_front.position = Vector2.ZERO
		_front.size = size
		_front.set_meta("plate", r)
		_front.queue_redraw()
		_draw_dial(Vector2(r.end.x + 40.0, r.position.y + PLATE_H * 0.5), _k(0.45, 0.35))
		# The last gain, rising a little and fading under the counter.
		if _gain > 0 and _gain_t < 1.1 and not _near():
			var ga := clampf(_gain_t / 0.08, 0.0, 1.0) * (1.0 - clampf((_gain_t - 0.6) / 0.5, 0.0, 1.0))
			var gy := r.end.y + 28.0 - 6.0 * clampf(_gain_t / 1.1, 0.0, 1.0)
			draw_string(hud.body_font(), Vector2(0, gy), "+" + Hud._group(_gain), HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(Tok.PRIMARY_HI, ga))

	func _near() -> bool:
		return best > 0 and not _broken and score >= best * NEAR and intro_t > 1.0

	## Over the drums: the tag counting down to the record, the NEW RECORD
	## stamp slamming onto the plate, and then the small crown it leaves.
	func _draw_front() -> void:
		if not _front.has_meta("plate") or hud == null:
			return
		var r: Rect2 = _front.get_meta("plate")
		var f := _front
		var body := hud.body_font()
		if _near():
			var txt := Loc.t("record.near") % Hud._group(best - score + 1)
			var tw := body.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
			var tr := Rect2(r.get_center().x - tw * 0.5, r.end.y + 12.0, tw, 26.0)
			Hud.pill(f, tr.grow(1.5), Tok.PRIMARY_LO)
			Hud.pill(f, tr, Color("0E1015"))
			var fb := tr.get_center().y + (body.get_ascent(16) - body.get_descent(16)) * 0.5
			f.draw_string(body, Vector2(tr.position.x, fb), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, 16, T_HOT.lerp(Tok.PRIMARY, 0.5 - 0.5 * sin(_clock * 3.2)))
		if not _broken:
			return
		var crown_at := Vector2(r.position.x + 4.0, r.position.y - 3.0)
		var t := _record_t
		if t < 1.9:
			# The stamp: slams down from large, holds, then shrinks into the
			# crown on the bezel's corner.
			var slam := Motion.ease_value(Motion.Ease.EXIT, clampf(t / 0.16, 0.0, 1.0))
			var sc := lerpf(2.3, 1.0, slam)
			var go := clampf((t - 1.45) / 0.45, 0.0, 1.0)
			var e := Motion.ease_value(Motion.Ease.STANDARD, go)
			var c := r.get_center().lerp(crown_at, e)
			sc *= lerpf(1.0, 0.15, e)
			var a := clampf(t / 0.08, 0.0, 1.0) * (1.0 - go * 0.6)
			var caps := hud.caps_font()
			var label := Loc.t("record.daily" if daily else "record.new")
			var lw := caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 36.0
			f.draw_set_transform(c, -0.1, Vector2(sc, sc))
			var sr := Rect2(-lw * 0.5, -24.0, lw, 48.0)
			f.draw_rect(Rect2(sr.position + Vector2(3, 5), sr.size), Color(0, 0, 0, 0.45 * a))
			f.draw_rect(sr, Color(Color("1A1206"), 0.92 * a))
			f.draw_rect(sr.grow(-3.0), Color(T_HOT, a), false, 2.5)
			f.draw_rect(sr.grow(-8.0), Color(T_HOT, 0.6 * a), false, 1.0)
			var bb := (caps.get_ascent(24) - caps.get_descent(24)) * 0.5
			f.draw_string(caps, Vector2(-lw * 0.5, bb), label, HORIZONTAL_ALIGNMENT_CENTER, lw, 24, Color(T_HOT, a))
			f.draw_set_transform(Vector2.ZERO)
			# Brass dust knocked off by the slam.
			if t < 0.6 and not Prefs.reduced_motion:
				var dk := clampf((t - 0.12) / 0.48, 0.0, 1.0)
				for i in 14:
					var d := Vector2.from_angle(i * TAU / 14.0 + 0.3)
					var p := r.get_center() + d * lerpf(20.0, 120.0, dk) * Vector2(1.5, 0.6)
					f.draw_circle(p, 2.2 * (1.0 - dk), Color(T_HOT, 1.0 - dk), true, -1.0, true)
		if t > 1.75:
			var ck := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf((t - 1.75) / 0.3, 0.0, 1.0))
			_crown(crown_at, ck, T_HOT.lerp(Tok.PRIMARY_HI, 0.5 + 0.5 * sin(_clock * 2.0)), f)

	## The drums, in the window's own clipped space: each shows its digit
	## and, while it turns, the next rolling up from below; the edges fall
	## into shadow like the curve of a cylinder. Glass lies over them.
	func _draw_drums() -> void:
		var sz := _drums.size
		var num := hud.num_font()
		var fs := 40
		var n := _drum.size()
		var digits := str(maxi(score, 0)).length()
		var asc := (num.get_ascent(fs) - num.get_descent(fs)) * 0.5
		var cy := sz.y * 0.5
		var pitch := sz.y * 0.92
		var ci := _drums
		var x := 2.0
		for j in n:
			var i := n - 1 - j
			var dr := Rect2(x, 0.0, CELL - 2.0, sz.y)
			ci.draw_rect(dr, DRUM)
			var v: float = _drum[i]
			var base := floorf(v)
			var frac := v - base
			var dim := 0.3 if i >= digits and v < 0.01 else 1.0
			for kk in 2:
				var off := (kk - frac) * pitch
				if absf(off) >= pitch:
					continue
				var ch := str(int(base + kk) % 10)
				var cw := num.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var sq := 1.0 - 0.3 * absf(off) / pitch
				ci.draw_set_transform(Vector2(dr.position.x + dr.size.x * 0.5, cy + off), 0.0, Vector2(1.0, sq))
				ci.draw_string(num, Vector2(-cw * 0.5, asc), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.TEXT_PRIMARY, dim))
			ci.draw_set_transform(Vector2.ZERO)
			# The cylinder's curve: shade deepening toward top and bottom,
			# and a fine lit line just above the middle.
			for s in 7:
				var sa := 0.62 * pow(1.0 - s / 7.0, 1.4)
				ci.draw_rect(Rect2(dr.position.x, s * 2.5, dr.size.x, 2.5), Color(0, 0, 0, sa))
				ci.draw_rect(Rect2(dr.position.x, sz.y - (s + 1) * 2.5, dr.size.x, 2.5), Color(0, 0, 0, sa))
			ci.draw_rect(Rect2(dr.position.x, cy - 12.0, dr.size.x, 1.0), Color(1, 1, 1, 0.025))
			x += CELL
			if i > 0 and i % 3 == 0:
				x += 8.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(sz.x * 0.55, 0), Vector2(sz.x * 0.42, sz.y * 0.42), Vector2(0, sz.y * 0.42)]), Color(1, 1, 1, 0.04))

	## The multiplier: a small brass dial reading ×N, with three lamps on its
	## rim that light as the streak builds toward the next step.
	func _draw_dial(c: Vector2, k: float) -> void:
		if k <= 0.0:
			return
		var s := Motion.ease_value(Motion.Ease.EMPHASIZED, k) * (1.0 + 0.2 * sin(badge_pop * PI))
		draw_set_transform(c, 0.0, Vector2(s, s))
		var on := mult > 1
		if hot:
			var glow := 0.5 + 0.5 * sin(_clock * 14.0)
			for g in 3:
				draw_circle(Vector2.ZERO, 30.0 + g * 5.0, Color(Tok.PRIMARY, (0.12 - g * 0.035) * (0.6 + 0.4 * glow)), true, -1.0, true)
		draw_circle(Vector2(1.5, 2.5), 26.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(Vector2.ZERO, 26.0, Tok.PRIMARY_LO, true, -1.0, true)
		draw_circle(Vector2(-0.8, -0.8), 23.5, Tok.PRIMARY, true, -1.0, true)
		draw_arc(Vector2.ZERO, 24.5, PI * 1.05, PI * 1.6, 12, Color(Tok.PRIMARY_HI, 0.85), 1.4, true)
		draw_circle(Vector2.ZERO, 18.0, WINDOW, true, -1.0, true)
		for i in 3:
			var d := Vector2.from_angle(-PI * 0.5 + (i - 1) * 0.72) * 21.0
			var lv: float = _lamps[i]
			if lv > 0.01:
				draw_circle(d, 6.5, Color(Tok.PRIMARY_HI, 0.25 * lv), true, -1.0, true)
			draw_circle(d, 3.0, BRASS_DEEP.lerp(Color("FFF3D1"), lv), true, -1.0, true)
		var num := hud.num_font()
		var mt := "×%d" % mult
		var fs := 19
		var tw := num.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := (num.get_ascent(fs) - num.get_descent(fs)) * 0.5
		draw_string(num, Vector2(-tw * 0.5, base + 3.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.PRIMARY_HI if on else Tok.TEXT_FAINT)
		draw_set_transform(Vector2.ZERO)

	# ------------------------------------------------ knots

	## A point along a rope `len` long from `a`, sagging `sag` in the middle.
	static func _rope(a: Vector2, len: float, sag: float, t: float) -> Vector2:
		return a + Vector2(len * t, sag * sin(PI * t))

	## The lives are knots tied in a rope; a lost one comes undone (it
	## swells, lifts and fades), one won back pulls tight into place.
	func _draw_knots(l: Layout, top: float, _h: float) -> void:
		var ra := _k(0.55, 0.3)
		if ra <= 0.0:
			return
		var len := 124.0
		var a := Vector2(l.size.x - l.margin - len, top + 46.0)
		var sag := 6.0
		var pts := PackedVector2Array()
		for k in 25:
			pts.append(_rope(a, len * ra, sag * ra, k / 24.0) + Vector2(1.5, 2.5))
		draw_polyline(pts, Color(0, 0, 0, 0.35), 3.5, true)
		for k in 25:
			pts[k] -= Vector2(1.5, 2.5)
		draw_polyline(pts, ROPE_DARK, 3.5, true)
		var tx := 3.0
		while tx < len * ra:
			var p := _rope(a, len * ra, sag * ra, tx / (len * ra))
			draw_line(p + Vector2(-1.2, -1.7), p + Vector2(1.2, 1.7), Color(ROPE_LIGHT, 0.35), 1.0, true)
			tx += 6.0
		if ra < 1.0:
			return
		for i in 3:
			var t0 := 0.18 + 0.32 * i
			var c := _rope(a, len, sag, t0)
			var ang := (_rope(a, len, sag, t0 + 0.01) - c).angle()
			if i == lives and knot_shake > 0.0:
				c.x += sin(knot_shake * 40.0) * 4.0 * knot_shake
			var t: float = _knot_t[i]
			if i < lives:
				var k := clampf(t / 0.35, 0.0, 1.0)
				var sc := lerpf(1.6, 1.0, Motion.ease_value(Motion.Ease.EMPHASIZED, k))
				_knot(c, ang, sc, k)
			else:
				draw_arc(c, 9.0, 0.0, TAU, 28, Color(Tok.TEXT_FAINT, 0.5), 1.5, true)
				if t < 0.6:
					var e := t / 0.6
					_knot(c + Vector2(0, -12.0 * e), ang, 1.0 + 0.5 * e, 1.0 - e)

	## An overhand knot seen from the front: a plump body with the rope's
	## turns wrapping it, lit from the top left.
	func _knot(c: Vector2, ang: float, s: float, a: float) -> void:
		if a <= 0.0:
			return
		draw_set_transform(c, ang, Vector2(s, s))
		var body := PackedVector2Array()
		for k in 24:
			var th := TAU * k / 24.0
			body.append(Vector2(cos(th) * 11.0, sin(th) * 9.0))
		var sh := PackedVector2Array()
		for p in body:
			sh.append(p + Vector2(1.5, 2.5))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.4 * a))
		draw_colored_polygon(body, Color(ROPE, a))
		for k in 3:
			var x := -6.0 + k * 6.0
			var g := PackedVector2Array([Vector2(x - 3.5, 8.0), Vector2(x - 1.0, 0.0), Vector2(x + 3.5, -8.0)])
			draw_polyline(g, Color(ROPE_DARK, a), 2.2, true)
			var hl := PackedVector2Array()
			for q in g:
				hl.append(q + Vector2(-1.6, 0.0))
			draw_polyline(hl, Color(ROPE_LIGHT, 0.55 * a), 1.0, true)
		draw_arc(Vector2.ZERO, 10.2, PI * 1.05, PI * 1.55, 10, Color(1, 1, 1, 0.35 * a), 1.6, true)
		draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- overlay

## Non-interactive layer: main-menu copy, event cards, enemy intros and
## the resume countdown.
class Overlay extends Control:
	var hud: Hud
	var card_title := ""
	var card_sub := ""
	var card_t := 99.0
	var card_hold := 1.0
	var card_queue: Array = []

	func card_busy() -> bool:
		return card_title != "" and card_t < Motion.NORMAL + card_hold + Motion.SLOW
	var wave_t := 99.0
	var wave_n := 1
	var wave_sub := ""
	var wave_col := Tok.PRIMARY
	var toast_t := 99.0
	var toast_id := ""
	var _toast_box: StyleBoxFlat
	var menu_a := 0.0
	var intro_name := ""
	var intro_desc := ""
	var intro_t := 99.0
	var count_n := 0
	var count_t := 0.0
	var _clock := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _flow_a := 0.0

	## Wave intro: "WAVE" in small caps over a large numeral that settles
	## from 130 % with fine gold rules drawing outward, while a band of light
	## sweeps down the field from the rail to the line.
	func _draw_wave_intro(l: Layout, caps: Font, disp: Font) -> void:
		const TOTAL := 1.75
		if wave_t >= TOTAL:
			return
		var w := l.size.x
		var sweep := Motion.ease_value(Motion.Ease.STANDARD, clampf(wave_t / 0.95, 0.0, 1.0))
		if wave_t < 0.95:
			var by := lerpf(l.rail_y, l.danger_y, sweep)
			var fade := sin(PI * sweep)
			for k in 12:
				var d := (k - 5.5) * 9.0
				var g := exp(-d * d / 900.0)
				draw_rect(Rect2(0, by + d - 4.5, w, 9.0), Color(Pal.GOLD_LIGHT, 0.075 * g * fade))
		var kin := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf(wave_t / 0.4, 0.0, 1.0))
		var a := kin
		if wave_t > 1.25:
			a *= 1.0 - Motion.ease_value(Motion.Ease.EXIT, (wave_t - 1.25) / 0.5)
		if a <= 0.0:
			return
		var y := l.rail_y + l.play_h * 0.33
		var sc := lerpf(1.3, 1.0, kin)
		var num := str(wave_n)
		var fs := 124
		var tw := disp.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(w * 0.5, y), 0.0, Vector2(sc, sc))
		draw_string(disp, Vector2(-tw * 0.5 + 4.0, 4.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * a))
		draw_string(disp, Vector2(-tw * 0.5, 0.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.TEXT_PRIMARY, a))
		draw_set_transform(Vector2.ZERO)
		draw_string(caps, Vector2(0, y - 104.0), Loc.t("hud.waveLabel"), HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 2, Color(Tok.PRIMARY, a))
		var span := w * 0.3 * Motion.ease_value(Motion.Ease.ENTER, clampf((wave_t - 0.1) / 0.6, 0.0, 1.0))
		for yy in [y - 96.0 - 6.0, y + 30.0]:
			draw_line(Vector2(w * 0.5 - span, yy), Vector2(w * 0.5 + span, yy), Color(Tok.PRIMARY, 0.5 * a), 1.0, true)
		if wave_sub != "":
			# The wave's mood, in its own colour, under the rule.
			var sa := a * Motion.ease_value(Motion.Ease.ENTER, clampf((wave_t - 0.25) / 0.4, 0.0, 1.0))
			draw_string(caps, Vector2(0, y + 58.0), wave_sub, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 1, Color(wave_col, sa))

	## Where tray slot `i` sits: a row of small discs at the top left.
	func _slot(l: Layout, i: int) -> Vector2:
		return Vector2(l.margin + 98.0 + (i % 3) * 32.0, l.safe_top + 30.0 + (i / 3) * 32.0)

	func _draw_tray(l: Layout) -> void:
		if menu_a > 0.0 or hud.perk_order.is_empty() or not hud.bar.visible:
			return
		for i in hud.perk_order.size():
			var id: String = hud.perk_order[i]
			if id == toast_id and toast_t < 1.95:
				continue
			var p := _slot(l, i)
			var land := clampf(1.0 - (toast_t - 1.95) / 0.35, 0.0, 1.0) if id == toast_id else 0.0
			var r := 14.0 + 3.0 * land
			draw_circle(p, r, Tok.SURFACE_LO, true, -1.0, true)
			draw_arc(p, r, 0.0, TAU, 32, Color(Tok.PRIMARY, 0.35 + 0.6 * land), 1.0, true)
			Perks.draw_icon(self, id, p, 1.0, 0.42)
			var lv := int(hud.perk_levels.get(id, 1))
			if lv > 1:
				Pal.disc(self, p + Vector2(11, 10), 6.0, Tok.PRIMARY)
				draw_string(hud.caps_font(), Vector2(p.x + 8.0, p.y + 14.0), str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Tok.ON_PRIMARY)

	## The perk just won: a card pops up over the floor, holds, then shrinks
	## into its icon and flies to its slot in the tray.
	func _draw_toast(l: Layout, caps: Font, disp: Font) -> void:
		if toast_t >= 1.95 or toast_id == "":
			return
		if _toast_box == null:
			_toast_box = StyleBoxFlat.new()
			_toast_box.bg_color = Tok.SURFACE_HI
			_toast_box.border_color = Tok.PRIMARY_LO
			_toast_box.set_border_width_all(1)
			_toast_box.set_corner_radius_all(Tok.RADIUS_M)
			_toast_box.shadow_color = Color(0, 0, 0, 0.45)
			_toast_box.shadow_size = 12
			_toast_box.anti_aliasing = true
		var home := Vector2(l.center_x, l.danger_y - 150.0)
		var size := Vector2(minf(420.0, l.size.x - 40.0), 96)
		var pop := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf(toast_t / 0.3, 0.0, 1.0))
		var text_a := pop * (1.0 - clampf((toast_t - 1.35) / 0.15, 0.0, 1.0))
		var icon0 := home + Vector2(-size.x * 0.5 + 48.0, 0.0)
		if text_a > 0.0:
			var sc := lerpf(0.85, 1.0, pop)
			draw_set_transform(home, 0.0, Vector2(sc, sc))
			for b in [[_toast_box, text_a]]:
				(b[0] as StyleBoxFlat).bg_color.a = b[1]
				(b[0] as StyleBoxFlat).border_color.a = b[1]
				(b[0] as StyleBoxFlat).shadow_color.a = 0.45 * b[1]
			draw_style_box(_toast_box, Rect2(-size * 0.5, size))
			draw_string(caps, Vector2(-size.x * 0.5 + 92.0, -16.0), Loc.t("perk.new"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Tok.PRIMARY, text_a))
			draw_string(disp, Vector2(-size.x * 0.5 + 92.0, 12.0), Loc.t("perk." + toast_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Tok.TEXT_PRIMARY, text_a))
			var desc := Loc.t("perk." + toast_id + ".d")
			var dfs := 11
			while dfs > 8 and caps.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs).x > size.x - 108.0:
				dfs -= 1
			draw_string(caps, Vector2(-size.x * 0.5 + 92.0, 34.0), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(Tok.TEXT_SECONDARY, text_a))
			draw_set_transform(Vector2.ZERO)
		# The icon: sits in the card, then flies to the tray.
		var fly := Motion.ease_value(Motion.Ease.STANDARD, clampf((toast_t - 1.4) / 0.55, 0.0, 1.0))
		var slot := _slot(l, maxi(0, hud.perk_order.find(toast_id)))
		var mid := icon0.lerp(slot, 0.5) + Vector2(0, -120.0)
		var p := icon0.lerp(mid, fly).lerp(mid.lerp(slot, fly), fly)
		var r := lerpf(30.0, 14.0, fly) * lerpf(0.85, 1.0, pop)
		draw_circle(p, r, Color(Tok.SURFACE_LO, pop), true, -1.0, true)
		draw_arc(p, r, 0.0, TAU, 40, Color(Tok.PRIMARY, 0.8 * pop), 1.2, true)
		Perks.draw_icon(self, toast_id, p, pop, lerpf(0.85, 0.42, fly))

	## The flow meter: a fine bar on the floor just under the danger line.
	## Hot, it fills white-cyan, glows and beats with the music.
	func _draw_flow(l: Layout, caps: Font) -> void:
		var want := 1.0 if (hud.flow > 0.02 or hud.flow_hot) and menu_a <= 0.0 else 0.0
		_flow_a = move_toward(_flow_a, want, get_process_delta_time() / 0.3)
		if _flow_a <= 0.0:
			return
		var a := _flow_a
		var w := 176.0
		var y := l.danger_y + 26.0
		var x0 := l.center_x - w * 0.5
		var b := Music.beat()
		var beat := pow(1.0 - fposmod(b, 1.0), 3.0) if b >= 0.0 else 0.0
		draw_rect(Rect2(x0, y, w, 4.0), Color(Pal.INK, 0.08 * a))
		var fw := w * clampf(hud.flow, 0.0, 1.0)
		if hud.flow_hot:
			for g in 3:
				var grow := 3.0 + g * 3.0 + beat * 3.0
				draw_rect(Rect2(x0 - grow, y - grow, fw + grow * 2.0, 4.0 + grow * 2.0), Color(Pal.FLOW, (0.1 - g * 0.03) * a))
			draw_string(caps, Vector2(0, y - 10.0), Loc.t("flow.badge"), HORIZONTAL_ALIGNMENT_CENTER, l.size.x, 11, Color(Pal.FLOW, (0.7 + 0.3 * beat) * a))
		draw_rect(Rect2(x0, y, fw, 4.0), Color(Pal.FLOW, (0.55 + 0.45 * (1.0 if hud.flow_hot else hud.flow)) * a))

	var _glass_box: StyleBoxFlat
	var _menu_t := 0.0
	var _card_ang := [0.0, 0.0, 0.0]
	var _card_w := [0.0, 0.0, 0.0]
	var _card_down := [false, false, false]
	var _card_box: StyleBoxFlat

	## Missions as three tickets pegged to a line strung across the menu:
	## they drop onto it one by one, bounce, and sway in the air. Each shows
	## its goal as a big figure and what to do under it.
	func _draw_missions(l: Layout, a: float, ly: float) -> void:
		var n := mini(3, Prefs.missions.size())
		if n == 0:
			return
		var w := l.size.x
		var ch := 152.0
		if ly + 24.0 + ch > l.fork_y - 110.0:
			return
		var body := hud.body_font()
		var num := hud.num_font()
		var sag := 16.0
		var pa := Vector2(26.0, ly)
		var pb := Vector2(w - 26.0, ly)
		var line := PackedVector2Array()
		for k in 33:
			var t := k / 32.0
			line.append(pa.lerp(pb, t) + Vector2(0, sag * sin(PI * t)))
		var shl := PackedVector2Array()
		for q in line:
			shl.append(q + Vector2(1.5, 3.0))
		draw_polyline(shl, Color(0, 0, 0, 0.35 * a), 2.0, true)
		draw_polyline(line, Color(Pal.STRING, a), 1.8, true)
		for pp in [pa, pb]:
			draw_circle(pp + Vector2(1.5, 2.5), 6.0, Color(0, 0, 0, 0.4 * a), true, -1.0, true)
			draw_circle(pp, 6.0, Color(Tok.PRIMARY_LO, a), true, -1.0, true)
			draw_circle(pp + Vector2(-0.8, -0.8), 4.2, Color(Tok.PRIMARY, a), true, -1.0, true)
		draw_string(body, Vector2(pa.x - 2.0, ly - 14.0), Loc.t("menu.missions"), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Tok.TEXT_SECONDARY, a))
		if _card_box == null:
			_card_box = StyleBoxFlat.new()
			_card_box.set_corner_radius_all(16)
			_card_box.set_border_width_all(2)
			_card_box.shadow_size = 14
			_card_box.shadow_offset = Vector2(3, 8)
			_card_box.anti_aliasing = true
		var cw := minf(184.0, (w - 110.0) / 3.0)
		for i in n:
			var drop := clampf((_menu_t - 0.35 - 0.13 * i) / 0.5, 0.0, 1.0)
			if drop <= 0.0:
				continue
			var e := Motion.ease_value(Motion.Ease.EMPHASIZED, drop)
			var t := 0.5 + (i - (n - 1) * 0.5) * 0.3
			var clip := pa.lerp(pb, t) + Vector2(0, sag * sin(PI * t))
			draw_set_transform(clip + Vector2(0, -(1.0 - e) * 260.0), _card_ang[i])
			var ca := a * minf(1.0, drop * 3.0)
			_card_box.bg_color = Color(Color("171B22"), ca)
			_card_box.border_color = Color(Tok.PRIMARY_LO, ca)
			_card_box.shadow_color = Color(0, 0, 0, 0.4 * ca)
			var r := Rect2(-cw * 0.5, 8.0, cw, ch)
			draw_style_box(_card_box, r)
			draw_rect(Rect2(r.position + Vector2(10, 30), Vector2(cw - 20, 1)), Color(Tok.PRIMARY_LO, 0.35 * ca))
			# The punched hole and the brass peg holding it to the line.
			draw_circle(Vector2(0, 22.0), 5.0, Color(0, 0, 0, 0.8 * ca), true, -1.0, true)
			draw_rect(Rect2(-7.0 + 1.5, -6.0 + 2.5, 14.0, 26.0), Color(0, 0, 0, 0.35 * ca))
			draw_rect(Rect2(-7.0, -6.0, 14.0, 26.0), Color(Tok.PRIMARY_LO, ca))
			draw_rect(Rect2(-5.0, -5.0, 5.0, 24.0), Color(Tok.PRIMARY, ca))
			draw_line(Vector2(-6.0, 6.0), Vector2(6.0, 6.0), Color(Color("5E4620"), ca), 1.2)
			var m: Dictionary = Prefs.missions[i]
			var goal := Meta.goal(m.id, int(m.level))
			var key: String = Meta.MISSIONS[m.id][0]
			var txt := ""
			if goal == 1 and Loc.STRINGS["en"].has(key + ".one"):
				txt = Loc.t(key + ".one")
			else:
				txt = Loc.t(key).replace("%s", "").replace("  ", " ").strip_edges()
			var big := Hud._group(goal)
			var fs := 46
			while fs > 28 and num.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > cw - 24.0:
				fs -= 2
			draw_string(num, Vector2(-cw * 0.5 + 2.0, 77.0), big, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Color(0, 0, 0, 0.35 * ca))
			draw_string(num, Vector2(-cw * 0.5, 74.0), big, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Color(Tok.PRIMARY_HI, ca))
			draw_multiline_string(body, Vector2(-cw * 0.5 + 10.0, 102.0), txt, HORIZONTAL_ALIGNMENT_CENTER, cw - 20.0, 16, 3, Color(Tok.TEXT_PRIMARY, 0.9 * ca))
			draw_set_transform(Vector2.ZERO)

	func _step_cards(rd: float) -> void:
		if menu_a <= 0.0:
			_menu_t = 0.0
			for i in 3:
				_card_down[i] = false
			return
		_menu_t += rd
		for i in 3:
			if not _card_down[i] and _menu_t > 0.35 + 0.13 * i + 0.5:
				_card_down[i] = true
				_card_w[i] += randf_range(1.6, 2.6) * (1.0 if i % 2 == 0 else -1.0)
			var air := 0.0 if Prefs.reduced_motion else sin(_clock * 0.8 + i * 2.1) * 0.12
			_card_w[i] += (-11.0 * sin(_card_ang[i]) - 1.1 * _card_w[i] + air) * rd
			_card_ang[i] += _card_w[i] * rd


	## Menu copy: the record in gold, today's missions on a glass card with
	## ring checkboxes, and the pull-to-play prompt breathing over the fork.
	func _draw_menu(l: Layout, a: float) -> void:
		var w := l.size.x
		var body := hud.body_font()
		var num := hud.num_font()
		var y := hud.menu_record_y()
		draw_string(body, Vector2(0, y), Loc.t("menu.dailyBest" if hud.daily else "menu.best"), HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(Tok.TEXT_SECONDARY, a))
		var rec := Hud._group(Prefs.daily_record() if hud.daily else Prefs.record)
		draw_string(num, Vector2(2, y + 61.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 60, Color(Tok.SHADOW, Tok.SHADOW.a * a))
		draw_string(num, Vector2(0, y + 58.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 60, Color(Tok.PRIMARY_HI, a))
		if not hud.daily and Prefs.fresh.get("best", false):
			# Set last run: a small crown on the record.
			var rw := num.get_string_size(rec, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
			var cp := Vector2(w * 0.5 + rw * 0.5 + 16.0, y + 14.0)
			var crown := PackedVector2Array()
			for q in [Vector2(-9, 5), Vector2(-10, -5), Vector2(-4.5, -0.5), Vector2(0, -8), Vector2(4.5, -0.5), Vector2(10, -5), Vector2(9, 5)]:
				crown.append(cp + q * 1.2)
			draw_colored_polygon(crown, Color(TopBar.T_HOT, a))
		_draw_missions(l, a, y + 112.0)
		var p := (0.55 + 0.45 * sin(_clock * 2.4)) * a
		var py := l.fork_y - 84.0
		draw_string(body, Vector2(0, py), Loc.t("menu.play"), HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(Tok.PRIMARY, p))
		var cx := w * 0.5
		var cy := py + 16.0 + 3.0 * sin(_clock * 2.4)
		draw_polyline(PackedVector2Array([Vector2(cx - 9, cy), Vector2(cx, cy + 8), Vector2(cx + 9, cy)]), Color(Tok.PRIMARY, p), 2.5, true)

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.001)
		card_t += rd
		if not card_queue.is_empty() and not card_busy():
			var c: Array = card_queue.pop_front()
			card_title = c[0]
			card_sub = c[1]
			card_hold = c[2]
			card_t = 0.0
		wave_t += rd
		toast_t += rd
		intro_t += rd
		count_t += rd
		_clock += rd
		_step_cards(minf(rd, 1.0 / 30.0))
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.l == null:
			return
		var l := hud.l
		var w := l.size.x
		var caps := hud.caps_font()
		var num := hud.num_font()
		var disp := hud.display_font()
		if menu_a > 0.0:
			_draw_menu(l, menu_a)
		if hud.modal_open():
			return
		_draw_wave_intro(l, caps, disp)
		_draw_tray(l)
		_draw_toast(l, caps, disp)
		_draw_flow(l, caps)
		if intro_t < Hud.INTRO_TIME and intro_name != "":
			var k := minf(1.0, minf(intro_t / 0.25, (Hud.INTRO_TIME - intro_t) / 0.4))
			var iy := l.danger_y - 150.0 + (1.0 - k) * 10.0
			draw_string(caps, Vector2(0, iy), Loc.t("enemy.new"), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(Tok.PRIMARY, k))
			draw_string(disp, Vector2(2, iy + 42.0), intro_name, HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color(0, 0, 0, 0.35 * k))
			draw_string(disp, Vector2(0, iy + 40.0), intro_name, HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color(Tok.TEXT_PRIMARY, k))
			draw_multiline_string(caps, Vector2(48, iy + 70.0), intro_desc, HORIZONTAL_ALIGNMENT_CENTER, w - 96.0, 14, 3, Color(Tok.TEXT_SECONDARY, k))
		var total := Motion.NORMAL + card_hold + Motion.SLOW
		if card_t < total and card_title != "":
			var k := 1.0
			if card_t < Motion.NORMAL:
				k = Motion.ease_value(Motion.Ease.ENTER, card_t / Motion.NORMAL)
			elif card_t > Motion.NORMAL + card_hold:
				k = 1.0 - Motion.ease_value(Motion.Ease.EXIT, (card_t - Motion.NORMAL - card_hold) / Motion.SLOW)
			var cy := l.rail_y + l.play_h * 0.46 + (1.0 - k) * 12.0
			# A soft dark band behind the card so it reads over the field,
			# framed by two fine hairlines that draw outward from the centre.
			var mid := cy - 12.0
			for i in 12:
				var f := float(i) / 11.0
				var a := 0.62 * k * (1.0 - f * f)
				var hh := 8.0
				draw_rect(Rect2(0, mid - (i + 1) * hh, w, hh), Color(Tok.BACKGROUND, a * 0.5))
				draw_rect(Rect2(0, mid + i * hh, w, hh), Color(Tok.BACKGROUND, a * 0.5))
			var span := w * 0.32 * Motion.ease_value(Motion.Ease.ENTER, minf(1.0, card_t / Motion.SLOW))
			for yy in [mid - 66.0, mid + 62.0]:
				draw_line(Vector2(w * 0.5 - span, yy), Vector2(w * 0.5 + span, yy), Color(Tok.PRIMARY, 0.55 * k), 1.0, true)
			draw_string(disp, Vector2(3, cy + 3), card_title, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_DISPLAY, Color(0, 0, 0, 0.35 * k))
			draw_string(disp, Vector2(0, cy), card_title, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_DISPLAY, Color(Tok.TEXT_PRIMARY, k))
			draw_string(caps, Vector2(0, cy + 36.0), card_sub, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL, Color(Tok.TEXT_SECONDARY, k))
		if count_n > 0:
			# Countdown digit: pops in (emphasized) and fades as the next nears.
			var k := Motion.ease_value(Motion.Ease.EMPHASIZED, count_t / Motion.NORMAL)
			var a := clampf(1.0 - (count_t - 0.25) / 0.17, 0.0, 1.0) * minf(1.0, count_t / 0.08)
			var sc := lerpf(1.25, 1.0, k)
			var c := Vector2(w * 0.5, l.rail_y + l.play_h * 0.46)
			draw_set_transform(c, 0.0, Vector2(sc, sc))
			var txt := str(count_n)
			var tw := disp.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 140).x
			draw_string(disp, Vector2(-tw * 0.5 + 4.0, 44.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 140, Color(0, 0, 0, 0.35 * a))
			draw_string(disp, Vector2(-tw * 0.5, 40.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 140, Color(Tok.TEXT_PRIMARY, a))
			draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- game over

## Results: title, score counting up (≈0.8 s, soft ticks), best score and
## a compact stats line, a restrained new-record moment (badge pop, a ring
## of gold grains, chime, two-step haptic), then the two actions.
class GameOver extends Control:
	var hud: Hud
	var _t := -1.0
	var _score := 0
	var _prev := 0
	var _record := false
	var _secs := 0
	var _acc := 0
	var _skills: Array = []
	var _overloads := 0
	var _daily := false
	var _done: Array = []
	var _ticked := 0.0
	var _record_done := false
	var _box: VBoxContainer
	var _retry: UIButton
	var _menu: UIButton

	const COUNT_FROM := 0.15
	const COUNT_D := 0.8

	func _ready() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", Tok.SPACE_MD)
		add_child(_box)
		_retry = hud.button(func() -> void: hud.restart_pressed.emit(), true)
		_menu = hud.button(func() -> void: hud.menu_pressed.emit())
		_box.add_child(_retry)
		_box.add_child(_menu)

	func setup() -> void:
		var l := hud.l
		var min_h := maxf(60.0, Tok.TOUCH_MIN_DP * l.dp)
		for b in [_retry, _menu]:
			b.custom_minimum_size = Vector2(maxf(320.0, 48.0 * l.dp), min_h)
		var bw := maxf(320.0, 48.0 * l.dp)
		_box.position = Vector2(l.size.x * 0.5 - bw * 0.5, l.size.y * 0.66)
		_box.size = Vector2(bw, 0)

	func refresh_text() -> void:
		_retry.text = Loc.t("gameOver.restart")
		_menu.text = Loc.t("gameOver.mainMenu")

	func play(score: int, prev_best: int, is_record: bool, secs: int, acc: int, skills: Array, overloads: int, was_daily: bool, done: Array) -> void:
		refresh_text()
		_daily = was_daily
		_done = done
		_score = score
		_prev = prev_best
		_record = is_record
		_secs = secs
		_acc = acc
		_skills = skills
		_overloads = overloads
		_t = 0.0
		_ticked = 0.0
		_record_done = false
		visible = true
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		_box.modulate.a = 0.0
		_box.visible = true
		var base_y := hud.l.size.y * 0.66
		_box.position.y = base_y + 10.0
		Motion.to(_box, "modulate:a", 1.0, Motion.NORMAL, Motion.Ease.ENTER, 0.55)
		Motion.to(_box, "position:y", base_y, Motion.NORMAL, Motion.Ease.ENTER, 0.55)

	## The run's best moments in one line: overloads and the skill shots
	## made most often (`_skills` holds [string key, count] pairs).
	func _feats() -> String:
		var order := _skills.filter(func(p: Array) -> bool: return int(p[1]) > 0)
		order.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		var parts: PackedStringArray = []
		if _overloads > 0:
			parts.append("%s ×%d" % [Loc.t("gameOver.overloads"), _overloads])
		for p: Array in order.slice(0, 3 - parts.size()):
			parts.append("%s ×%d" % [Loc.t(p[0]), p[1]])
		return "   ·   ".join(parts)

	func close() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := Motion.to(self, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
		tr.done = func() -> void:
			visible = false
			_t = -1.0

	func _process(delta: float) -> void:
		if _t < 0.0:
			return
		_t += delta / maxf(Engine.time_scale, 0.001)
		var k := clampf((_t - COUNT_FROM) / Motion.dur(COUNT_D), 0.0, 1.0)
		if k > 0.0 and k < 1.0 and _t - _ticked > 0.07:
			_ticked = _t
			Sfx.play("count", lerpf(0.9, 1.25, k))
		if _record and not _record_done and k >= 1.0:
			_record_done = true
			Sfx.play("record")
			Sfx.haptic_pattern("record")
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0 or hud.l == null:
			return
		var l := hud.l
		var w := l.size.x
		var caps := hud.caps_font()
		var num := hud.num_font()
		var cy := l.size.y * 0.34
		var ka := Motion.ease_value(Motion.Ease.ENTER, _t / Motion.NORMAL)
		draw_string(caps, Vector2(0, cy - 96.0 + (1.0 - ka) * 8.0), Loc.t("menu.daily" if _daily else "gameOver.title"), HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 1, Color(Tok.PRIMARY if _daily else Tok.TEXT_SECONDARY, ka))
		var k := Motion.ease_value(Motion.Ease.ENTER, clampf((_t - COUNT_FROM) / Motion.dur(COUNT_D), 0.0, 1.0))
		var shown := Hud._group(int(round(_score * k)))
		var sa := minf(1.0, (_t - COUNT_FROM) / 0.15)
		if sa > 0.0:
			draw_string(num, Vector2(3, cy + 3.0), shown, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_HERO, Color(0, 0, 0, 0.35 * sa))
			draw_string(num, Vector2(0, cy), shown, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_HERO, Color(Tok.TEXT_PRIMARY, sa))
		# Under the score, what it means against the record:
		#  - a new record: the old one, struck through (the stamp is above);
		#  - close (85 % or more): "So close!" and a bar filling up to the
		#    record, with how many points were missing;
		#  - otherwise: how far short, in gold.
		var ky := cy + 52.0
		var land := COUNT_FROM + Motion.dur(COUNT_D)
		var kg := clampf(Motion.ease_value(Motion.Ease.EMPHASIZED, (_t - land) / Motion.NORMAL), 0.0, 1.2)
		var gap := _prev - _score
		var body := hud.body_font()
		var ga := minf(kg, 1.0)
		if _record:
			if _prev > 0 and ga > 0.0:
				var line := Loc.t("record.prev") % Hud._group(_prev)
				var lw := body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				draw_string(body, Vector2(0, ky), line, HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color(Tok.TEXT_SECONDARY, ga))
				var sx := w * 0.5 - lw * 0.5
				draw_line(Vector2(sx - 4.0, ky - 7.0), Vector2(sx + (lw + 8.0) * ga - 4.0, ky - 7.0), Color(TopBar.T_WARM, ga), 1.6, true)
			ky += 30.0
		elif _prev > 0 and gap > 0 and _score >= _prev * 0.85:
			if ga > 0.0:
				var disp := hud.display_font()
				var gs := lerpf(1.15, 1.0, ga)
				draw_set_transform(Vector2(w * 0.5, ky + 14.0), 0.0, Vector2(gs, gs))
				draw_string(disp, Vector2(-w * 0.5 + 2.0, 3.0), Loc.t("gameOver.near"), HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color(0, 0, 0, 0.35 * ga))
				draw_string(disp, Vector2(-w * 0.5, 0.0), Loc.t("gameOver.near"), HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color(TopBar.T_WARM, ga))
				draw_set_transform(Vector2.ZERO)
				# The bar: how much of the record this run reached.
				var bw := minf(440.0, w - 120.0)
				var br := Rect2(w * 0.5 - bw * 0.5, ky + 36.0, bw, 14.0)
				var fk := Motion.ease_value(Motion.Ease.STANDARD, clampf((_t - land - 0.15) / 0.8, 0.0, 1.0))
				var frac := float(_score) / float(_prev) * fk
				Hud.pill(self, br.grow(2.0), Color(Tok.PRIMARY_LO, ga))
				Hud.pill(self, br, Color(Color("0A0C10"), ga))
				if frac > 0.02:
					var fr := Rect2(br.position + Vector2(3, 3), Vector2(maxf(8.0, (br.size.x - 6.0) * frac), br.size.y - 6.0))
					Hud.pill(self, fr, Color(TopBar.T_COOL.lerp(TopBar.T_WARM, frac), ga))
				# The record at the end of the bar.
				var cp := Vector2(br.end.x + 4.0, br.get_center().y - 16.0)
				var crown := PackedVector2Array()
				for q in [Vector2(-9, 5), Vector2(-10, -5), Vector2(-4.5, -0.5), Vector2(0, -8), Vector2(4.5, -0.5), Vector2(10, -5), Vector2(9, 5)]:
					crown.append(cp + q)
				draw_colored_polygon(crown, Color(Tok.PRIMARY_HI, ga))
				draw_string(body, Vector2(0, ky + 80.0), Loc.t("gameOver.nearSub") % Hud._group(gap), HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color(Tok.TEXT_SECONDARY, ga))
			ky += 96.0
		elif _prev > 0 and gap > 0:
			if ga > 0.0:
				var line := Loc.t("gameOver.gap") % Hud._group(gap)
				var gs := lerpf(1.12, 1.0, ga)
				draw_set_transform(Vector2(w * 0.5, ky), 0.0, Vector2(gs, gs))
				draw_string(caps, Vector2(-w * 0.5 + 1.5, 1.5), line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 2, Color(0, 0, 0, 0.35 * ga))
				draw_string(caps, Vector2(-w * 0.5, 0), line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 2, Color(Tok.PRIMARY, ga))
				draw_set_transform(Vector2.ZERO)
			ky += 30.0
		var kb := Motion.ease_value(Motion.Ease.ENTER, (_t - 0.3) / Motion.NORMAL)
		if kb > 0.0 and not _record and not (gap > 0 and _score >= _prev * 0.85):
			var best_line := "%s  %s" % [Loc.t("menu.dailyBest" if _daily else "gameOver.bestScore"), Hud._group(maxi(_prev, _score))]
			draw_string(caps, Vector2(0, ky + (1.0 - kb) * 6.0), best_line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL, Color(Tok.TEXT_SECONDARY, kb))
		var ks := Motion.ease_value(Motion.Ease.ENTER, (_t - 0.4) / Motion.NORMAL)
		if ks > 0.0:
			var stats := "%s %d:%02d   ·   %s %d %%" % [Loc.t("gameOver.time"), _secs / 60, _secs % 60, Loc.t("gameOver.accuracy"), _acc]
			draw_string(caps, Vector2(0, ky + 32.0 + (1.0 - ks) * 6.0), stats, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_CAPTION, Color(Tok.TEXT_FAINT, ks))
		var kk := Motion.ease_value(Motion.Ease.ENTER, (_t - 0.5) / Motion.NORMAL)
		var feats := _feats()
		if kk > 0.0 and feats != "":
			draw_string(caps, Vector2(0, ky + 56.0 + (1.0 - kk) * 6.0), feats, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_CAPTION, Color(Tok.PRIMARY_LO.lightened(0.25), kk))
		# Missions finished in this run, each with a gold tick.
		var km := Motion.ease_value(Motion.Ease.ENTER, (_t - 0.65) / Motion.NORMAL)
		if km > 0.0:
			for i in _done.size():
				var line := Loc.t("mission.done") + "  ·  " + str(_done[i])
				draw_string(caps, Vector2(0, ky + 92.0 + i * 24.0 + (1.0 - km) * 6.0), line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_CAPTION, Color(Tok.PRIMARY, km))
		if _record and _record_done:
			# Badge pops with a small overshoot; a ring of gold grains opens.
			var rt := _t - COUNT_FROM - Motion.dur(COUNT_D)
			# The stamp slams down, tilted, over the title.
			var slam := Motion.ease_value(Motion.Ease.EXIT, clampf(rt / 0.16, 0.0, 1.0))
			var bk := lerpf(2.3, 1.0, slam)
			var st := clampf(rt / 0.06, 0.0, 1.0)
			var label := Loc.t("record.daily" if _daily else "record.new")
			var lw := caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 44.0
			var bc := Vector2(w * 0.5, cy - 150.0)
			draw_set_transform(bc, -0.09, Vector2(bk, bk))
			var rr := Rect2(-lw * 0.5, -28.0, lw, 56.0)
			draw_rect(Rect2(rr.position + Vector2(3, 5), rr.size), Color(0, 0, 0, 0.45 * st))
			draw_rect(rr, Color(Color("1A1206"), 0.94 * st))
			draw_rect(rr.grow(-3.0), Color(TopBar.T_HOT, st), false, 3.0)
			draw_rect(rr.grow(-9.0), Color(TopBar.T_HOT, 0.6 * st), false, 1.2)
			var bb := (caps.get_ascent(28) - caps.get_descent(28)) * 0.5
			draw_string(caps, Vector2(-lw * 0.5, bb), label, HORIZONTAL_ALIGNMENT_CENTER, lw, 28, Color(TopBar.T_HOT, st))
			draw_set_transform(Vector2.ZERO)
			if rt < 0.8 and not Prefs.reduced_motion:
				var e := Motion.ease_value(Motion.Ease.ENTER, rt / 0.8)
				for i in 18:
					var a := i * TAU / 18.0
					var p := bc + Vector2.from_angle(a) * lerpf(20.0, 110.0, e) * Vector2(1.6, 0.8)
					draw_circle(p, lerpf(3.0, 1.0, e), Color(Tok.PRIMARY, 1.0 - e), true, -1.0, true)
