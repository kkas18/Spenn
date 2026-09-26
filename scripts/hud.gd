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
var _m_settings: IconBtn
var _m_lang: LangPill
var _m_stats: IconBtn
var _m_skins: IconBtn
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
	for b: IconBtn in [_b_restart, _b_settings, _b_menu, _m_settings, _m_stats, _m_skins]:
		b.custom_minimum_size = Vector2(touch, touch)
	_s_back.custom_minimum_size = Vector2(touch * 0.85, touch * 0.85)
	var row_w := minf(640.0, l.size.x - 2.0 * Tok.SPACE_LG - 2.0 * Tok.SPACE_MD)
	for r: SetRow in _s_rows:
		r.custom_minimum_size = Vector2(row_w - 2.0 * Tok.SPACE_LG, touch)
	_s_credits.custom_minimum_size = Vector2(row_w - 40.0, 0)
	_m_lang.custom_minimum_size = Vector2(touch * 1.6, touch * 0.8)
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
	overlay.menu_a = 0.0
	Motion.to(overlay, "menu_a", 1.0, Motion.SLOW, Motion.Ease.ENTER, 0.25)


func hide_menu_ui() -> void:
	Motion.to(_menu_bar, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.to(_m_daily, "modulate:a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.to(overlay, "menu_a", 0.0, Motion.FAST, Motion.Ease.EXIT)
	Motion.after(Motion.FAST, func() -> void:
		_menu_bar.visible = false
		_m_daily.visible = false)


## In-game bar comes in piece by piece: score, then the rest (+80 ms),
## each fading and settling 6 px.
func reveal_hud() -> void:
	bar.visible = true
	bar.modulate.a = 1.0
	bar.a_score = 0.0
	bar.a_right = 0.0
	Motion.to(bar, "a_score", 1.0, Motion.NORMAL, Motion.Ease.ENTER, 0.0)
	Motion.to(bar, "a_right", 1.0, Motion.NORMAL, Motion.Ease.ENTER, Motion.STAGGER)


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
		_s_secs[i].text = Loc.t(["settings.sec.sound", "settings.sec.game", "settings.sec.access", "settings.sec.lang"][i])
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
	]
	var rows: VBoxContainer = null
	var first := true
	for g in [null] + groups:
		if g == null:
			var cap := label(19, Tok.TEXT_SECONDARY, _font_caps)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			var capbox := MarginContainer.new()
			capbox.add_theme_constant_override("margin_left", Tok.SPACE_MD)
			capbox.add_theme_constant_override("margin_top", Tok.SPACE_SM)
			capbox.add_child(cap)
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
		r.first = first
		r.theme_type_variation = &"RowButton"
		var setter: Callable = g[3]
		r.picked.connect(func(v: int) -> void: _act(func() -> void: setter.call(v)))
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
	_m_settings = _icon_button("gear", func() -> void: open_settings("menu"))
	_menu_bar.add_child(_m_settings)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_bar.add_child(gap)
	_m_stats = _icon_button("chart", func() -> void: _open_meta(_stats, _stats_box, _fill_stats))
	_menu_bar.add_child(_m_stats)
	_m_skins = _icon_button("ball", func() -> void: _open_meta(_skins, _skins_box, _fill_skins))
	_menu_bar.add_child(_m_skins)
	_m_lang = LangPill.new()
	_m_lang.hud = self
	_m_lang.theme_type_variation = &"IconButton"
	_m_lang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	box.add_child(_spacer(Tok.SPACE_SM))
	var secs := int(st.get("secs", 0))
	var shots := int(st.get("shots", 0))
	var rows := [
		["stats.runs", _group(int(st.get("runs", 0)))],
		["stats.best", _group(Prefs.record)],
		["stats.total", _group(Prefs.total_points)],
		["stats.wave", str(int(st.get("best_wave", 0)))],
		["stats.kills", _group(int(st.get("kills", 0)))],
		["stats.accuracy", "%d %%" % (int(round(100.0 * int(st.get("hits", 0)) / shots)) if shots > 0 else 0)],
		["gameOver.overloads", _group(int(st.get("overloads", 0)))],
		["skill.bank", _group(int(st.get("bank", 0)))],
		["skill.chain", _group(int(st.get("chain", 0)))],
		["skill.cut", _group(int(st.get("cuts", 0)))],
		["stats.missions", str(Prefs.mission_level)],
		["stats.time", "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
	]
	for r: Array in rows:
		box.add_child(_row(Loc.t(r[0]), r[1]))


## Skins: each a button with a swatch; locked ones show what they cost.
func _fill_skins(box: VBoxContainer) -> void:
	box.add_child(_panel_title("skins.title"))
	var sub := label(21, Tok.TEXT_SECONDARY, _font_body)
	sub.text = sentence(Loc.t("skins.total") % _group(Prefs.total_points))
	box.add_child(sub)
	box.add_child(_spacer(Tok.SPACE_SM))
	for i in Meta.SKINS.size():
		var sk: Array = Meta.SKINS[i]
		var open := Meta.skin_unlocked(i, Prefs.total_points)
		var b := button(func() -> void:
			if Meta.skin_unlocked(i, Prefs.total_points):
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


## One settings row: the label on the left, its control on the right – a
## switch, a three-step level (off when none is lit) or the language
## pair. The whole row is the touch target; tapping the control itself
## picks the step or side under the finger.
class SetRow extends UIButton:
	enum Kind {SWITCH, STEPS, LANG}
	const STEP_W := 46.0
	const STEP_H := 14.0
	const STEP_GAP := 8.0
	signal picked(v: int)
	var hud: Hud
	var kind := Kind.SWITCH
	var key := ""
	var getter: Callable
	var note: Callable
	var first := false
	var _shown := -1.0

	func _ready() -> void:
		super()
		pressed.connect(_on_press)

	func refresh() -> void:
		queue_redraw()

	func _value() -> int:
		return int(getter.call())

	func _control_rect() -> Rect2:
		var cy := size.y * 0.5
		match kind:
			Kind.SWITCH:
				return Rect2(size.x - 84.0, cy - 24.0, 84.0, 48.0)
			Kind.STEPS:
				var w := 3.0 * STEP_W + 2.0 * STEP_GAP
				return Rect2(size.x - w, cy - 22.0, w, 44.0)
		return Rect2(size.x - 176.0, cy - 27.0, 176.0, 54.0)

	func _on_press() -> void:
		var v := _value()
		var x := get_local_mouse_position().x
		var r := _control_rect()
		match kind:
			Kind.SWITCH:
				picked.emit(1 - v)
			Kind.STEPS:
				var nv := (v + 1) % 4
				if x >= r.position.x - 10.0:
					var i := clampi(int((x - r.position.x) / (STEP_W + STEP_GAP)), 0, 2)
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
		if kind == Kind.STEPS or getter.is_null():
			return
		var want := float(_value())
		if _shown < 0.0:
			_shown = want
		if absf(_shown - want) > 0.0001:
			_shown = move_toward(_shown, want, delta / 0.16)
			queue_redraw()

	func _draw() -> void:
		if hud == null or getter.is_null():
			return
		if not first:
			draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(Tok.BORDER, 0.9), 2.0)
		var f := hud.body_font()
		var fs := Tok.TYPE_BODY + 2
		var cy := size.y * 0.5
		var sub: String = note.call() if note.is_valid() else ""
		var base := cy + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - (12.0 if sub != "" else 0.0)
		draw_string(f, Vector2(0, base), Loc.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tok.TEXT_PRIMARY)
		if sub != "":
			draw_string(hud.body_font(), Vector2(0, base + 28.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Tok.TEXT_FAINT)
		var r := _control_rect()
		var v := _value()
		var e := Motion.ease_value(Motion.Ease.STANDARD, clampf(_shown, 0.0, 1.0))
		match kind:
			Kind.SWITCH:
				Hud.pill(self, r, Tok.BORDER_HI.lerp(Tok.PRIMARY, e))
				var kc := r.position + Vector2(24.0 + (r.size.x - 48.0) * e, 24.0)
				draw_circle(kc + Vector2(0, 2), 19.0, Color(0, 0, 0, 0.25), true, -1.0, true)
				draw_circle(kc, 19.0, Tok.TEXT_SECONDARY.lerp(Tok.ON_PRIMARY, e), true, -1.0, true)
			Kind.STEPS:
				var word := Loc.t("settings.level.%d" % v)
				var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
				var wb := cy + (f.get_ascent(21) - f.get_descent(21)) * 0.5
				draw_string(f, Vector2(r.position.x - 18.0 - ww, wb), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Tok.TEXT_SECONDARY)
				for i in 3:
					var sr := Rect2(r.position.x + i * (STEP_W + STEP_GAP), cy - STEP_H * 0.5, STEP_W, STEP_H)
					Hud.pill(self, sr, Tok.PRIMARY if i < v else Tok.BORDER_HI)
			Kind.LANG:
				Hud.pill(self, r, Tok.SURFACE_LO)
				var hw := (r.size.x - 10.0) * 0.5
				Hud.pill(self, Rect2(r.position.x + 5.0 + hw * e, r.position.y + 5.0, hw, r.size.y - 10.0), Tok.PRIMARY)
				for i in 2:
					var t: String = ["NO", "EN"][i]
					var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
					var tb := cy + (f.get_ascent(22) - f.get_descent(22)) * 0.5
					draw_string(f, Vector2(r.position.x + 5.0 + hw * (i + 0.5) - tw * 0.5, tb), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Tok.ON_PRIMARY if absf(e - i) < 0.5 else Tok.TEXT_SECONDARY)


# ---------------------------------------------------------------- top bar

## The in-game bar, three zones on one line of sight:
##  left   – the wave, its progress as a rope that fills with gold toward a
##           crown (where the finale comes), how many are left, and the
##           perk tray under it;
##  centre – the score on rolling digits, the multiplier chip with the
##           streak's ring round it, and the last gain;
##  right  – the lives, as knots on a rope.
## There is no pause button: a double-tap on the field (or Back) pauses.
class TopBar extends Control:
	const ROLL := 0.14             # s for one digit to roll over
	var hud: Hud
	var score := 0
	var shown_score := 0.0
	var mult := 1
	var streak := 0
	var lives := 3
	var phase := 1
	var progress := 0.0
	var remaining := 0             # kills still needed this wave
	var finale_at := 0.8           # where on the rope the crown sits
	var shown_progress := 0.0
	var pulse := 0.0
	var badge_pop := 0.0
	var knot_shake := 0.0
	var show_fps := false
	var hot := false               # overload: the multiplier chip blazes
	var glint := 0.0               # a big gain: the counter flashes gold
	var _clock := 0.0
	var a_score := 1.0             # staggered reveal alphas
	var a_right := 1.0
	var _taps: Array[int] = []
	var _last_score := 0
	var _gain := 0
	var _gain_t := 9.0
	var _ring := 0.0
	var _digits: Array = []        # per place, units first: [digit, previous, t]
	var _shown_lives := 3
	var _knot_t := [9.0, 9.0, 9.0] # time since each knot was tied or untied

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_mult(m: int) -> void:
		if m != mult:
			badge_pop = 1.0
		mult = m

	func lose_life(n: int) -> void:
		lives = n
		knot_shake = 1.0

	func knots_rect() -> Rect2:
		var l := hud.l
		var h := l.top_bar_h - l.safe_top
		var x0 := l.size.x - l.margin - 190.0
		return Rect2(x0, l.safe_top, l.size.x - x0, h * 0.75)

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

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.001)
		# A new run: the counter and the gain start clean.
		if score < _last_score:
			shown_score = float(score)
			_gain = 0
			_gain_t = 9.0
			_digits.clear()
		elif score > _last_score:
			_gain = (_gain if _gain_t < 0.7 else 0) + score - _last_score
			_gain_t = 0.0
		_last_score = score
		_gain_t += rd
		var diff := float(score) - shown_score
		if absf(diff) > 0.01:
			shown_score += signf(diff) * maxf(absf(diff) * Pal.damp(0.18, rd), minf(absf(diff), 60.0 * rd))
		for d: Array in _digits:
			d[2] = minf(1.0, d[2] + rd / ROLL)
		# Knots tied (won back) or untied (lost) since last frame.
		if lives != _shown_lives:
			var lo := mini(lives, _shown_lives)
			for i in range(lo, maxi(lives, _shown_lives)):
				if i < 3:
					_knot_t[i] = 0.0
			_shown_lives = lives
		for i in 3:
			_knot_t[i] += rd
		var want := 1.0 if streak >= 9 else (streak % 3) / 3.0
		_ring = lerpf(_ring, want, Pal.damp(0.12, rd)) if want >= _ring else move_toward(_ring, want, rd * 3.0)
		pulse = maxf(0.0, pulse - rd / 0.18)
		badge_pop = maxf(0.0, badge_pop - rd / 0.3)
		knot_shake = maxf(0.0, knot_shake - rd / 0.6)
		glint = maxf(0.0, glint - rd / 0.5)
		_clock += rd
		shown_progress = lerpf(shown_progress, progress, Pal.damp(0.15, rd))
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.l == null:
			return
		var l := hud.l
		var top := l.safe_top
		var h := l.top_bar_h - top
		var ry := (1.0 - a_right) * 6.0
		_draw_score(l, l.score_baseline)
		_draw_wave(l, l.margin + 4.0, top, h, ry)
		_draw_knots(l, top, h, ry)
		if show_fps:
			var sg := hud._game_sensor()
			var gy := Input.get_gyroscope()
			var fps := "%d FPS  ·  G %.1f %.1f %.1f  ·  GYRO %.2f %.2f %.2f" % [Engine.get_frames_per_second(), sg.x, sg.y, sg.z, gy.x, gy.y, gy.z]
			draw_string(hud.caps_font(), Vector2(0, l.top_bar_h - 4.0), fps, HORIZONTAL_ALIGNMENT_RIGHT, l.size.x - l.margin, 11, Tok.TEXT_FAINT)

	## Score on an odometer: each place rolls up to its new digit on its own,
	## and its width eases between the two glyphs so the number never jumps
	## sideways.
	func _draw_score(l: Layout, base: float) -> void:
		var num := hud.num_font()
		var fs := 54
		var asc := a_score
		var txt := str(int(round(shown_score)))
		var n := txt.length()
		while _digits.size() < n:
			_digits.append([-1, -1, 1.0])
		for i in n:
			var dg := int(txt[n - 1 - i])
			var d: Array = _digits[i]
			if d[0] != dg:
				d[1] = d[0]
				d[0] = dg
				d[2] = 0.0 if d[1] >= 0 else 1.0
		for i in range(n, _digits.size()):
			_digits[i] = [-1, -1, 1.0]
		var gap := num.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.28
		var widths: Array[float] = []
		var total := ((n - 1) / 3) * gap
		for k in n:
			var d: Array = _digits[n - 1 - k]
			var cw := num.get_string_size(str(d[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if d[1] >= 0 and d[2] < 1.0:
				var pw := num.get_string_size(str(d[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				cw = lerpf(pw, cw, Motion.ease_value(Motion.Ease.STANDARD, d[2]))
			widths.append(cw)
			total += cw
		var s := 1.0 + 0.08 * sin(pulse * PI)
		var w := l.size.x
		draw_set_transform(Vector2(w * 0.5, base + (1.0 - asc) * 6.0), 0.0, Vector2(s, s))
		var face := Tok.TEXT_PRIMARY.lerp(Tok.PRIMARY_HI, glint)
		var x := -total * 0.5
		for k in n:
			var i := n - 1 - k
			var d: Array = _digits[i]
			var e := Motion.ease_value(Motion.Ease.STANDARD, d[2])
			var roll := fs * 0.5
			for part in [[d[0], (1.0 - e) * roll, e], [d[1], -e * roll, 1.0 - e]]:
				if part[0] < 0 or part[2] <= 0.01:
					continue
				var ch := str(part[0])
				var cw := num.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var p := Vector2(x + (widths[k] - cw) * 0.5, part[1])
				draw_string(num, p + Vector2(2, 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.SHADOW, Tok.SHADOW.a * asc * part[2]))
				draw_string(num, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(face, asc * part[2]))
			x += widths[k]
			if i > 0 and i % 3 == 0:
				x += gap
		draw_set_transform(Vector2.ZERO)
		var ar := a_right
		# Multiplier chip, the streak's progress to the next step as a ring.
		var cc := Vector2(w * 0.5 + total * 0.5 * s + 42.0, base - 18.0 + (1.0 - ar) * 6.0)
		var bs := 1.0 + 0.22 * sin(badge_pop * PI)
		draw_set_transform(cc, 0.0, Vector2(bs, bs))
		var on := mult > 1
		if hot or mult >= 3:
			var glow := 0.5 + 0.5 * sin(_clock * (14.0 if hot else 3.0))
			for g in 3:
				draw_circle(Vector2.ZERO, 30.0 + g * 4.0, Color(Tok.PRIMARY, (0.12 - g * 0.035) * (0.6 + 0.4 * glow) * ar), true, -1.0, true)
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 48, Color(Tok.BORDER_HI, 0.9 * ar), 3.5, true)
		if _ring > 0.01:
			draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, -PI * 0.5 + TAU * _ring, 48, Color(Tok.PRIMARY_HI, ar), 3.5, true)
		draw_circle(Vector2(1.5, 2.5), 20.0, Color(Tok.SHADOW, Tok.SHADOW.a * ar), true, -1.0, true)
		draw_circle(Vector2.ZERO, 20.0, Color((Tok.PRIMARY_HI if hot else Tok.PRIMARY) if on else Tok.SURFACE_HI, ar), true, -1.0, true)
		if not on:
			draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 40, Color(Tok.BORDER_HI, ar), 1.5, true)
		var body := hud.body_font()
		var mt := "×%d" % mult
		var mw := body.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(body, Vector2(-mw * 0.5, 7.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Tok.ON_PRIMARY if on else Tok.TEXT_SECONDARY, ar))
		draw_set_transform(Vector2.ZERO)
		# The last gain, rising a little and fading under the score.
		if _gain > 0 and _gain_t < 1.1:
			var ga := clampf(_gain_t / 0.08, 0.0, 1.0) * (1.0 - clampf((_gain_t - 0.6) / 0.5, 0.0, 1.0)) * asc
			var gy := base + 30.0 - 6.0 * clampf(_gain_t / 1.1, 0.0, 1.0)
			draw_string(body, Vector2(0, gy), "+" + Hud._group(_gain), HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color(Tok.PRIMARY_HI, ga))

	## A point along a rope `len` long from `a`, sagging `sag` in the middle.
	static func _rope(a: Vector2, len: float, sag: float, t: float) -> Vector2:
		return a + Vector2(len * t, sag * sin(PI * t))

	## Left zone: the wave number, the rope filling toward the crown and
	## the count left (or the finale, once the crown is passed).
	func _draw_wave(l: Layout, x0: float, top: float, h: float, ry: float) -> void:
		var ar := a_right
		var body := hud.body_font()
		var num := hud.num_font()
		var y1 := top + h * 0.30 + ry
		var word := Loc.t("hud.waveWord")
		draw_string(body, Vector2(x0, y1), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Tok.TEXT_SECONDARY, ar))
		var ww := body.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(num, Vector2(x0 + ww + 8.0, y1 + 2.0), str(phase), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Tok.TEXT_PRIMARY, ar))
		var len := minf(210.0, l.size.x * 0.29)
		var a := Vector2(x0, top + h * 0.50 + ry)
		var sag := 4.0
		var seg := 24
		var track := PackedVector2Array()
		for k in seg + 1:
			track.append(_rope(a, len, sag, k / float(seg)))
		draw_polyline(track, Color(Tok.BORDER_HI, ar), 4.0, true)
		var pr := clampf(shown_progress, 0.0, 1.0)
		if pr > 0.005:
			var fill := PackedVector2Array()
			var m := maxi(2, int(ceil(seg * pr)))
			for k in m + 1:
				fill.append(_rope(a, len, sag, pr * k / float(m)))
			draw_polyline(fill, Color(Tok.PRIMARY, ar), 4.0, true)
			# The twist of the strands, as fine ticks along the gold.
			var tx := 0.0
			while tx < len * pr - 4.0:
				var p := _rope(a, len, sag, tx / len)
				draw_line(p + Vector2(-1.5, -1.6), p + Vector2(1.5, 1.6), Color(Tok.PRIMARY_LO, 0.8 * ar), 1.2, true)
				tx += 7.0
			var tip := _rope(a, len, sag, pr)
			draw_circle(tip, 6.5, Color(Tok.PRIMARY_HI, ar), true, -1.0, true)
		# The end of the rope, and the crown where the finale comes.
		draw_circle(_rope(a, len, sag, 1.0), 3.5, Color(Tok.BORDER_HI, ar), true, -1.0, true)
		var reached := pr >= finale_at - 0.001
		var cp := _rope(a, len, sag, finale_at) + Vector2(0, -15.0)
		var ccol := Tok.PRIMARY_HI if reached else Tok.PRIMARY_LO
		if reached:
			var gl := 0.5 + 0.5 * sin(_clock * 4.0)
			draw_circle(cp + Vector2(0, 2), 13.0, Color(Tok.PRIMARY, 0.12 * gl * ar), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([
			cp + Vector2(-9, 5), cp + Vector2(-10, -5), cp + Vector2(-4.5, -0.5), cp + Vector2(0, -8),
			cp + Vector2(4.5, -0.5), cp + Vector2(10, -5), cp + Vector2(9, 5)]), Color(ccol, ar))
		draw_line(cp + Vector2(0, 5), _rope(a, len, sag, finale_at) + Vector2(0, -4), Color(ccol, 0.6 * ar), 1.2, true)
		var y3 := top + h * 0.73 + ry
		if progress >= 1.0:
			pass
		elif reached:
			draw_string(body, Vector2(x0, y3), Loc.t("hud.finale"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Tok.PRIMARY_HI, ar))
		elif remaining > 0:
			draw_string(body, Vector2(x0, y3), Loc.t("hud.left") % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Tok.TEXT_SECONDARY, ar))

	## Right zone: the lives are knots tied in a rope; a lost one comes
	## undone (it swells, lifts and fades), one won back pulls tight.
	func _draw_knots(l: Layout, top: float, h: float, ry: float) -> void:
		var ar := a_right
		var len := 132.0
		var a := Vector2(l.size.x - l.margin - len, top + h * 0.34 + ry)
		var sag := 6.0
		var pts := PackedVector2Array()
		for k in 25:
			pts.append(_rope(a, len, sag, k / 24.0) + Vector2(1.5, 2.5))
		draw_polyline(pts, Color(Tok.SHADOW, Tok.SHADOW.a * 0.6 * ar), 3.5, true)
		for k in 25:
			pts[k] -= Vector2(1.5, 2.5)
		draw_polyline(pts, Color(ROPE_DARK, ar), 3.5, true)
		# The lay of the rope: fine twist marks.
		var tx := 3.0
		while tx < len:
			var p := _rope(a, len, sag, tx / len)
			draw_line(p + Vector2(-1.2, -1.7), p + Vector2(1.2, 1.7), Color(ROPE_LIGHT, 0.35 * ar), 1.0, true)
			tx += 6.0
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
				_knot(c, ang, sc, ar * k)
			else:
				# Where a knot was: a faint ring on the bare rope.
				draw_arc(c, 9.0, 0.0, TAU, 28, Color(Tok.TEXT_FAINT, 0.5 * ar), 1.5, true)
				if t < 0.6:
					var e := t / 0.6
					_knot(c + Vector2(0, -12.0 * e), ang, 1.0 + 0.5 * e, ar * (1.0 - e))

	const ROPE := Color("C4BBA8")
	const ROPE_DARK := Color("8C8474")
	const ROPE_LIGHT := Color("E8E0CF")

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
		draw_colored_polygon(sh, Color(Tok.SHADOW, Tok.SHADOW.a * a))
		draw_colored_polygon(body, Color(ROPE, a))
		# The turns: two strands crossing over the body, each a darker
		# groove with a lit edge.
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
		return Vector2(l.margin + 17.0 + i * 34.0, l.safe_top + (l.top_bar_h - l.safe_top) * 0.9)

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
		# Missions: three goals for a single run, rewarded in points.
		var n := Prefs.missions.size()
		var row := 44.0
		var cw := minf(600.0, w - 2.0 * Tok.SPACE_XL)
		var ch := 64.0 + n * row
		var top := y + 96.0
		if n > 0 and top + ch < l.fork_y - 110.0:
			if _glass_box == null:
				_glass_box = StyleBoxFlat.new()
				_glass_box.set_corner_radius_all(32)
				_glass_box.set_border_width_all(2)
				_glass_box.shadow_size = 18
				_glass_box.shadow_offset = Vector2(0, 8)
				_glass_box.anti_aliasing = true
			_glass_box.bg_color = Color(Tok.GLASS, Tok.GLASS.a * a)
			_glass_box.border_color = Color(Tok.BORDER, a)
			_glass_box.shadow_color = Color(0, 0, 0, 0.35 * a)
			var x0 := w * 0.5 - cw * 0.5
			draw_style_box(_glass_box, Rect2(x0, top, cw, ch))
			draw_string(body, Vector2(x0 + 32.0, top + 42.0), Loc.t("menu.missions"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Tok.TEXT_SECONDARY, a))
			for i in n:
				var m: Dictionary = Prefs.missions[i]
				var line := Meta.describe(m.id, int(m.level))
				var yy := top + 64.0 + i * row + row * 0.5
				draw_arc(Vector2(x0 + 44.0, yy), 11.0, 0.0, TAU, 32, Color(Tok.BORDER_HI, a), 3.0, true)
				var fs := 22
				while fs > 15 and body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > cw - 100.0:
					fs -= 1
				var base := yy + (body.get_ascent(fs) - body.get_descent(fs)) * 0.5
				draw_string(body, Vector2(x0 + 72.0, base), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.TEXT_PRIMARY, a))
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
		# The hook: how far short of the record, in gold, once the count
		# has landed. Within a tenth of it, it says so.
		var ky := cy + 52.0
		var gap := _prev - _score
		if not _record and _prev > 0 and gap > 0:
			var kg := Motion.ease_value(Motion.Ease.EMPHASIZED, (_t - COUNT_FROM - Motion.dur(COUNT_D)) / Motion.NORMAL)
			if kg > 0.0:
				var line := Loc.t("gameOver.gap") % Hud._group(gap)
				if gap <= _prev / 10:
					line = Loc.t("gameOver.close") + "  ·  " + line
				var gs := lerpf(1.12, 1.0, kg)
				draw_set_transform(Vector2(w * 0.5, ky), 0.0, Vector2(gs, gs))
				draw_string(caps, Vector2(-w * 0.5 + 1.5, 1.5), line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 2, Color(0, 0, 0, 0.35 * minf(kg, 1.0)))
				draw_string(caps, Vector2(-w * 0.5, 0), line, HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL + 2, Color(Tok.PRIMARY, minf(kg, 1.0)))
				draw_set_transform(Vector2.ZERO)
			ky += 30.0
		var kb := Motion.ease_value(Motion.Ease.ENTER, (_t - 0.3) / Motion.NORMAL)
		if kb > 0.0:
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
			var bk := Motion.ease_value(Motion.Ease.EMPHASIZED, rt / Motion.SLOW)
			var label := Loc.t("record.new")
			var lw := caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
			var bc := Vector2(w * 0.5, cy - 150.0)
			draw_set_transform(bc, 0.0, Vector2(bk, bk))
			var rr := Rect2(-lw * 0.5, -15.0, lw, 30.0)
			draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size), Tok.SHADOW)
			draw_rect(rr, Tok.PRIMARY)
			draw_string(caps, Vector2(-lw * 0.5 + 14.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tok.ON_PRIMARY)
			draw_set_transform(Vector2.ZERO)
			if rt < 0.8 and not Prefs.reduced_motion:
				var e := Motion.ease_value(Motion.Ease.ENTER, rt / 0.8)
				for i in 18:
					var a := i * TAU / 18.0
					var p := bc + Vector2.from_angle(a) * lerpf(20.0, 110.0, e) * Vector2(1.6, 0.8)
					draw_circle(p, lerpf(3.0, 1.0, e), Color(Tok.PRIMARY, 1.0 - e), true, -1.0, true)
