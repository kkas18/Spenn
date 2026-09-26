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

var _pause_title: Label
var _pause_best: Label
var _pause_hint: Label
var _b_resume: UIButton
var _b_restart: UIButton
var _b_settings: UIButton
var _b_menu: UIButton
var _s_title: Label
var _s_music: UIButton
var _s_sfx: UIButton
var _s_haptics: UIButton
var _s_motion: UIButton
var _s_guide: UIButton
var _s_tilt: UIButton
var _s_lang: UIButton
var _s_credits: Label
var _s_back: UIButton
var _m_settings: UIButton
var _m_lang: UIButton
var _m_stats: UIButton
var _m_skins: UIButton
var _m_daily: UIButton
var daily := false             # the menu's mode: the next run is the daily challenge
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
	var min_h := maxf(60.0, Tok.TOUCH_MIN_DP * l.dp)
	for b: UIButton in [_b_resume, _b_restart, _b_settings, _b_menu, _s_music, _s_sfx, _s_haptics, _s_motion, _s_guide, _s_tilt, _s_lang, _s_back]:
		b.custom_minimum_size = Vector2(maxf(320.0, 48.0 * l.dp), min_h)
	for b: UIButton in [_m_settings, _m_lang, _m_stats, _m_skins]:
		b.custom_minimum_size = Vector2(maxf(64.0, 48.0 * l.dp), maxf(64.0, 48.0 * l.dp))
	_menu_bar.position = Vector2(l.margin, l.safe_top + Tok.SPACE_LG)
	_menu_bar.size = Vector2(l.size.x - l.margin * 2.0, maxf(64.0, 48.0 * l.dp))
	_m_daily.custom_minimum_size = Vector2(maxf(300.0, 44.0 * l.dp), maxf(56.0, 44.0 * l.dp))
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
func open_pause() -> void:
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
	box.scale = Vector2(0.97, 0.97)
	Motion.to(p, "modulate:a", 1.0, Motion.NORMAL, Motion.Ease.ENTER, delay)
	Motion.to(box, "scale", Vector2.ONE, Motion.NORMAL, Motion.Ease.ENTER, delay)
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
func card(title: String, sub: String) -> void:
	overlay.card_title = title
	overlay.card_sub = sub
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
	_pause_best.text = Loc.t("pause.best") % _group(Prefs.record)
	_pause_hint.text = Loc.t("pause.hint")
	_b_resume.text = Loc.t("pause.resume")
	_b_restart.text = Loc.t("pause.restart")
	_b_settings.text = Loc.t("pause.settings")
	_b_menu.text = Loc.t("pause.mainMenu")
	_s_title.text = Loc.t("settings.title")
	_s_music.text = Loc.setting("settings.music", "settings.level.%d" % Prefs.music_volume)
	_s_sfx.text = Loc.setting("settings.effects", "settings.level.%d" % Prefs.sfx_volume)
	_s_haptics.text = Loc.setting("settings.haptics", Loc.on_off(Prefs.haptics))
	_s_motion.text = Loc.setting("settings.reducedMotion", Loc.on_off(Prefs.reduced_motion))
	_s_guide.text = Loc.setting("settings.aimGuide", Loc.on_off(Prefs.aim_guide))
	# Says whether the phone actually reports a sensor, so a missing effect
	# can be told apart from a switched-off one.
	var tilt_txt := Loc.setting("settings.tilt", Loc.on_off(Prefs.tilt))
	if Prefs.tilt and _game_sensor() == Vector3.ZERO and Input.get_gyroscope() == Vector3.ZERO:
		tilt_txt += " · " + Loc.t("settings.noSensor")
	_s_tilt.text = tilt_txt
	_s_lang.text = Loc.setting("settings.language", "settings.languageName")
	_s_back.text = Loc.t("settings.back")
	_s_credits.text = Loc.t("settings.credits")
	_m_settings.text = Loc.t("menu.settings")
	_m_lang.text = "NO" if Loc.lang == "no" else "EN"
	_m_stats.text = Loc.t("menu.stats")
	_m_skins.text = Loc.t("menu.skins")
	_m_daily.text = Loc.t("menu.daily")
	_m_daily.theme_type_variation = &"PrimaryButton" if daily else &""
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
	_theme = Theme.new()
	_theme.default_font = _font_caps
	_theme.default_font_size = Tok.TYPE_BUTTON
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
	_theme.set_stylebox("normal", "PrimaryButton", _box(Tok.PRIMARY, Tok.PRIMARY))
	_theme.set_stylebox("hover", "PrimaryButton", _box(Tok.PRIMARY_HI, Tok.PRIMARY_HI))
	_theme.set_stylebox("focus", "PrimaryButton", _box(Tok.PRIMARY_HI, Tok.PRIMARY_HI))
	_theme.set_stylebox("pressed", "PrimaryButton", _box(Tok.PRIMARY_LO, Tok.PRIMARY_LO))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(c, "PrimaryButton", Tok.ON_PRIMARY)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(Tok.RADIUS_M)
	s.content_margin_left = Tok.SPACE_LG
	s.content_margin_right = Tok.SPACE_LG
	s.shadow_color = Tok.SHADOW
	s.shadow_offset = Pal.SHADOW_OFFSET
	s.shadow_size = 2
	s.anti_aliasing = true
	return s


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


## A full-screen panel with a centred column; returns [panel, column].
func _panel() -> Array:
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
	box.resized.connect(func() -> void: box.pivot_offset = box.size * 0.5)
	center.add_child(box)
	return [p, box]


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_pause() -> void:
	var pb := _panel()
	_pause = pb[0]
	_pause_box = pb[1]
	_pause_title = label(Tok.TYPE_LABEL + 1, Tok.TEXT_SECONDARY, _font_caps)
	_pause_best = label(Tok.TYPE_CAPTION + 1, Tok.TEXT_FAINT, _font_caps)
	_pause_hint = label(Tok.TYPE_CAPTION, Tok.TEXT_FAINT, _font_caps)
	_b_resume = button(func() -> void: resume_pressed.emit(), true)
	_b_restart = button(func() -> void: restart_pressed.emit())
	_b_settings = button(func() -> void: open_settings("pause"))
	_b_menu = button(func() -> void: menu_pressed.emit())
	for c: Control in [_pause_title, _pause_best, _spacer(Tok.SPACE_SM), _b_resume, _b_restart, _b_settings, _b_menu, _spacer(Tok.SPACE_SM), _pause_hint]:
		_pause_box.add_child(c)


func _build_settings() -> void:
	var pb := _panel()
	_settings = pb[0]
	_settings_box = pb[1]
	_s_title = label(Tok.TYPE_LABEL + 1, Tok.TEXT_SECONDARY, _font_caps)
	_s_music = button(func() -> void: Prefs.cycle_music())
	_s_sfx = button(func() -> void: Prefs.cycle_sfx(); Sfx.play("countdown"))
	_s_haptics = button(func() -> void: Prefs.toggle_haptics(); Sfx.haptic_pattern("soft"))
	_s_motion = button(func() -> void: Prefs.toggle_reduced_motion())
	_s_guide = button(func() -> void: Prefs.toggle_aim_guide())
	_s_tilt = button(func() -> void: Prefs.toggle_tilt())
	_s_lang = button(func() -> void: Loc.next_language())
	_s_back = button(_close_settings)
	# Attribution for the music (CC BY 4.0) and the CC0 packs.
	_s_credits = label(Tok.TYPE_CAPTION, Tok.TEXT_FAINT, _font_caps)
	_s_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s_credits.custom_minimum_size = Vector2(440, 0)
	for c: Control in [_s_title, _spacer(Tok.SPACE_SM), _s_music, _s_sfx, _s_haptics, _s_motion, _s_guide, _s_tilt, _s_lang, _spacer(Tok.SPACE_SM), _s_back, _spacer(Tok.SPACE_SM), _s_credits]:
		_settings_box.add_child(c)


func _build_menu_bar() -> void:
	_menu_bar = HBoxContainer.new()
	_menu_bar.theme = _theme
	_menu_bar.visible = false
	add_child(_menu_bar)
	_m_settings = button(func() -> void: open_settings("menu"))
	_m_settings.custom_minimum_size = Vector2(64, 64)
	_menu_bar.add_child(_m_settings)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_bar.add_child(gap)
	_m_stats = button(func() -> void: _open_meta(_stats, _stats_box, _fill_stats))
	_menu_bar.add_child(_m_stats)
	_m_skins = button(func() -> void: _open_meta(_skins, _skins_box, _fill_skins))
	_menu_bar.add_child(_m_skins)
	_m_lang = button(func() -> void: Loc.next_language())
	_m_lang.custom_minimum_size = Vector2(64, 64)
	_menu_bar.add_child(_m_lang)
	for b: UIButton in [_m_settings, _m_stats, _m_skins, _m_lang]:
		b.add_theme_font_size_override("font_size", Tok.TYPE_CAPTION + 1)
	_menu_bar.add_theme_constant_override("separation", Tok.SPACE_SM)
	# Mode toggle: the next pull starts either a normal run or today's
	# seeded challenge (same spawns for everyone that day, its own record).
	_m_daily = button(func() -> void:
		daily = not daily
		_refresh_text())
	_m_daily.theme = _theme
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


func _row(name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(440, 30)
	var a := label(Tok.TYPE_LABEL, Tok.TEXT_SECONDARY, _font_caps)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.text = name
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := label(Tok.TYPE_LABEL + 2, Tok.TEXT_PRIMARY, _font_caps)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.text = value
	row.add_child(a)
	row.add_child(b)
	return row


func _fill_stats(box: VBoxContainer) -> void:
	var st := Prefs.stats
	var t := label(Tok.TYPE_LABEL + 1, Tok.TEXT_SECONDARY, _font_caps)
	t.text = Loc.t("stats.title")
	box.add_child(t)
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
	var t := label(Tok.TYPE_LABEL + 1, Tok.TEXT_SECONDARY, _font_caps)
	t.text = Loc.t("skins.title")
	box.add_child(t)
	var sub := label(Tok.TYPE_CAPTION + 1, Tok.TEXT_FAINT, _font_caps)
	sub.text = Loc.t("skins.total") % _group(Prefs.total_points)
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
		var name := Loc.t(sk[0])
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


# ---------------------------------------------------------------- top bar

## Minimal in-game bar: score with streak multiplier, knots and phase.
## There is no pause button: a double-tap on the field (or Back) pauses.
class TopBar extends Control:
	var hud: Hud
	var score := 0
	var shown_score := 0.0
	var mult := 1
	var streak := 0
	var lives := 3
	var phase := 1
	var progress := 0.0
	var shown_progress := 0.0
	var pulse := 0.0
	var badge_pop := 0.0
	var knot_shake := 0.0
	var show_fps := false
	var hot := false               # overload: the multiplier pill blazes
	var glint := 0.0               # a big gain: the counter flashes gold
	var _clock := 0.0
	var a_score := 1.0             # staggered reveal alphas
	var a_right := 1.0
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

	func knots_rect() -> Rect2:
		var l := hud.l
		var s := maxf(48.0 * l.dp, 64.0)
		return Rect2(l.size.x - l.margin - s * 1.6, l.score_baseline - s * 0.7, s * 1.6 + l.margin, s)

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
		var diff := float(score) - shown_score
		if absf(diff) > 0.01:
			shown_score += signf(diff) * maxf(absf(diff) * Pal.damp(0.18, rd), minf(absf(diff), 60.0 * rd))
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
		var base := l.score_baseline
		var w := l.size.x
		var num := hud.num_font()
		var caps := hud.caps_font()
		# Score (centre), pulsing about its own baseline centre.
		var asc := a_score
		var txt := Hud._group(int(round(shown_score)))
		var fs := 52
		var s := 1.0 + 0.08 * sin(pulse * PI)
		var tw := num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(w * 0.5, base + (1.0 - asc) * 6.0), 0.0, Vector2(s, s))
		draw_string(num, Vector2(-tw * 0.5 + 2.0, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.SHADOW, Tok.SHADOW.a * asc))
		draw_string(num, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tok.TEXT_PRIMARY.lerp(Tok.PRIMARY_HI, glint), asc))
		draw_set_transform(Vector2.ZERO)
		var ar := a_right
		var ry := (1.0 - ar) * 6.0
		# Streak multiplier pill + streak meter beside the score.
		var sx := w * 0.5 + tw * 0.5 * s + 10.0
		if mult > 1:
			var mt := "×%d" % mult
			var mw := caps.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
			var bs := 1.0 + 0.25 * sin(badge_pop * PI)
			var bc := Vector2(sx + mw * 0.5, base - 12.0 + ry)
			draw_set_transform(bc, 0.0, Vector2(bs, bs))
			var rr := Rect2(-mw * 0.5, -12.0, mw, 24.0)
			if hot or mult >= 3:
				# Overload blazes; a high streak multiplier glows steadily.
				var glow := 0.5 + 0.5 * sin(_clock * (14.0 if hot else 3.0))
				for g in 3:
					draw_rect(rr.grow(3.0 + g * 3.0), Color(Tok.PRIMARY, (0.14 - g * 0.04) * (0.6 + 0.4 * glow) * ar))
			draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size), Color(Tok.SHADOW, Tok.SHADOW.a * ar))
			draw_rect(rr, Color(Tok.PRIMARY_HI if hot else Tok.PRIMARY, ar))
			draw_string(caps, Vector2(-mw * 0.5 + 8.0, 6.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Tok.ON_PRIMARY)
			draw_set_transform(Vector2.ZERO)
			sx += mw + 8.0
		if mult < 4:
			var filled := streak % 3
			for i in 3:
				var c := Tok.PRIMARY if i < filled else Color(Tok.TEXT_FAINT, 0.7)
				draw_circle(Vector2(sx + 2.0 + i * 9.0, base - 4.0 + ry), 2.4, Color(c, c.a * ar), true, -1.0, true)
		# Knots (lives) on the right, same baseline.
		for i in 3:
			var cx := w - l.margin - 8.0 - (2 - i) * 22.0
			var shake := 0.0
			if i == lives and knot_shake > 0.0:
				shake = sin(knot_shake * 40.0) * 4.0 * knot_shake
			var c := Vector2(cx + shake, base - 10.0 + ry)
			if i < lives:
				draw_arc(c + Vector2(1.5, 1.5), 6.0, 0.0, TAU, 20, Color(Tok.SHADOW, Tok.SHADOW.a * ar), 2.6, true)
				draw_arc(c, 6.0, 0.0, TAU, 20, Color(Tok.TEXT_PRIMARY, ar), 2.6, true)
				draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), Color(Tok.TEXT_SECONDARY, ar), 1.2, true)
			else:
				draw_line(c + Vector2(-7, 0), c + Vector2(-2, 0), Color(Tok.TEXT_FAINT, ar), 2.4, true)
				draw_line(c + Vector2(2, 0), c + Vector2(7, 0), Color(Tok.TEXT_FAINT, ar), 2.4, true)
		# Phase label 10 px under the score, progress bar 8 px under it.
		var lv := Loc.t("hud.wave") % phase
		var ly := base + 10.0 + caps.get_ascent(13) + ry
		draw_string(caps, Vector2(0, ly), lv, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(Tok.TEXT_SECONDARY, ar))
		var bw := 132.0
		var by := ly + caps.get_descent(13) + 8.0
		var track := Rect2(w * 0.5 - bw * 0.5, by, bw, 3.0)
		draw_rect(track, Color(Tok.TEXT_FAINT, 0.45 * ar))
		draw_rect(Rect2(track.position, Vector2(bw * clampf(shown_progress, 0.0, 1.0), 3.0)), Color(Tok.TEXT_SECONDARY, ar))
		if show_fps:
			var sg := hud._game_sensor()
			var gy := Input.get_gyroscope()
			var fps := "%d FPS  ·  G %.1f %.1f %.1f  ·  GYRO %.2f %.2f %.2f" % [Engine.get_frames_per_second(), sg.x, sg.y, sg.z, gy.x, gy.y, gy.z]
			draw_string(caps, Vector2(0, ly), fps, HORIZONTAL_ALIGNMENT_RIGHT, w - l.margin, 11, Tok.TEXT_FAINT)


# ---------------------------------------------------------------- overlay

## Non-interactive layer: main-menu copy, event cards, enemy intros and
## the resume countdown.
class Overlay extends Control:
	var hud: Hud
	var card_title := ""
	var card_sub := ""
	var card_t := 99.0
	var menu_a := 0.0
	var intro_name := ""
	var intro_desc := ""
	var intro_t := 99.0
	var count_n := 0
	var count_t := 0.0
	var _clock := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.001)
		card_t += rd
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
			var a := menu_a
			var y := hud.menu_record_y()
			draw_string(caps, Vector2(0, y), Loc.t("menu.dailyBest" if hud.daily else "menu.best"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(Tok.TEXT_SECONDARY, a))
			var rec := Hud._group(Prefs.daily_record() if hud.daily else Prefs.record)
			draw_string(num, Vector2(2, y + 58.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 56, Color(Tok.SHADOW, Tok.SHADOW.a * a))
			draw_string(num, Vector2(0, y + 56.0), rec, HORIZONTAL_ALIGNMENT_CENTER, w, 56, Color(Tok.TEXT_PRIMARY, a))
			# Missions: three goals for a single run, rewarded in points.
			var my := y + 100.0
			if my + 3 * 26.0 < l.fork_y - 100.0:
				draw_string(caps, Vector2(0, my), Loc.t("menu.missions"), HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(Tok.PRIMARY, a * 0.9))
				for i in Prefs.missions.size():
					var m: Dictionary = Prefs.missions[i]
					var line := Meta.describe(m.id, int(m.level))
					var yy := my + 28.0 + i * 26.0
					var tw := caps.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
					var x0 := w * 0.5 - tw * 0.5
					draw_arc(Vector2(x0 - 14.0, yy - 5.0), 4.5, 0.0, TAU, 16, Color(Tok.TEXT_FAINT, a), 1.5, true)
					draw_string(caps, Vector2(x0, yy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Tok.TEXT_SECONDARY, a))
			var p := (0.55 + 0.45 * sin(_clock * 2.4)) * a
			draw_string(caps, Vector2(0, l.fork_y - 70.0), Loc.t("menu.play"), HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(Tok.PRIMARY, p))
		if hud.modal_open():
			return
		if intro_t < Hud.INTRO_TIME and intro_name != "":
			var k := minf(1.0, minf(intro_t / 0.25, (Hud.INTRO_TIME - intro_t) / 0.4))
			var iy := l.danger_y - 150.0 + (1.0 - k) * 10.0
			draw_string(caps, Vector2(0, iy), Loc.t("enemy.new"), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(Tok.PRIMARY, k))
			draw_string(disp, Vector2(2, iy + 42.0), intro_name, HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color(0, 0, 0, 0.35 * k))
			draw_string(disp, Vector2(0, iy + 40.0), intro_name, HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color(Tok.TEXT_PRIMARY, k))
			draw_multiline_string(caps, Vector2(48, iy + 70.0), intro_desc, HORIZONTAL_ALIGNMENT_CENTER, w - 96.0, 14, 3, Color(Tok.TEXT_SECONDARY, k))
		var total := Motion.NORMAL + 1.0 + Motion.SLOW
		if card_t < total and card_title != "":
			var k := 1.0
			if card_t < Motion.NORMAL:
				k = Motion.ease_value(Motion.Ease.ENTER, card_t / Motion.NORMAL)
			elif card_t > Motion.NORMAL + 1.0:
				k = 1.0 - Motion.ease_value(Motion.Ease.EXIT, (card_t - Motion.NORMAL - 1.0) / Motion.SLOW)
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
