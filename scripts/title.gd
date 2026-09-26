class_name TitleLetters
extends Node2D
## The title: T A U T hanging from the rail on strings, each letter a
## swinging body with depth. On entering the menu the letters fall in from
## above on slack strings that snap taut and catch them, one note of the
## menu's key each, the gold letter last. Hanging, they turn slowly on their
## strings (showing their edge and darker back) and a sheen passes over them
## now and then. Balls knock them about; starting a run snaps the strings
## one by one so the letters drop out of the way.

signal caught(i: int, pos: Vector2, gold: bool)

const K := 90.0                # string stiffness once settled
const K_CATCH := 700.0         # ... while a falling letter is caught
const GRAVITY := 900.0
const FS := 92
const DEPTH := 7.0             # extrusion (px) seen when fully side-on
const TWIST_K := 3.2           # torsion of the string (rad/s² per rad)
const TWIST_C := 0.9
const DROP_GAP := 0.13         # s between letters falling in
const SHEEN_EVERY := 5.5
# The note ladder is in C minor; this lifts it a major third into the
# menu music's E minor.
const MENU_PITCH := 1.2599
const STEPS := [0, 2, 1, 3, 4, 5, 6, 7]

var push := 0.0               # sideways push from the phone's lean (px/s²)
var l: Layout
var font: Font
var active := false
var _letters: Array[Dictionary] = []
var _snap_t := -1.0
var _clock := 0.0
var _current := ""
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/sheen.gdshader")
	material = _mat


func setup(layout: Layout, display_font: Font, drop := false) -> void:
	l = layout
	font = display_font
	if not Loc.language_changed.is_connected(_on_language):
		Loc.language_changed.connect(_on_language)
	reset(drop)


## The title is localized; if the word differs, re-hang the letters.
func _on_language() -> void:
	if active and _snap_t < 0.0 and _word() != _current:
		reset()


func _word() -> String:
	return Loc.t("game.title")


## Hangs the letters; with `drop` they fall in from above the screen, in a
## shuffled order with the gold letter last.
func reset(drop := false) -> void:
	_rng.randomize()
	_letters.clear()
	_current = _word()
	var lens := [0.2, 0.33, 0.25, 0.36, 0.17, 0.28, 0.22, 0.31]
	var n := _current.length()
	var gold := Loc.title_accent()
	var order: Array[int] = []
	for i in n:
		if i != gold:
			order.append(i)
	order.shuffle()
	if gold >= 0 and gold < n:
		order.append(gold)
	var calm := Prefs.reduced_motion
	for i in n:
		var ax := l.size.x * (0.14 + 0.72 * i / maxf(1.0, n - 1.0))
		var len: float = l.play_h * lens[i % lens.size()]
		var anchor := Vector2(ax, l.rail_y + 3.0)
		var d := {
			"ch": _current[i], "anchor": anchor, "len": len,
			"pos": anchor + Vector2(0, len * 0.3), "vel": Vector2(_rng.randf_range(-60, 60), 0),
			"rot": 0.0, "spin": 0.0, "attached": true, "alpha": 1.0,
			"yaw": _rng.randf_range(-0.3, 0.3), "yaw_v": 0.0, "k": K,
			"wait": 0.0, "caught": true, "phase": _rng.randf() * TAU,
		}
		if drop:
			var slot := order.find(i)
			d.wait = 0.25 + slot * DROP_GAP * (0.6 if calm else 1.0)
			d.pos = Vector2(ax + _rng.randf_range(-30, 30), -FS - 40.0 - slot * 30.0)
			d.vel = Vector2.ZERO
			d.yaw = _rng.randf_range(-1.2, 1.2)
			d.caught = false
			d.k = K_CATCH
		_letters.append(d)
	_snap_t = -1.0
	_clock = 0.0
	active = true
	visible = true


## Where each letter comes to rest (its string's length below its hook).
func rest_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for d in _letters:
		out.append(d.anchor + Vector2(0, d.len))
	return out


## Starts the exit: strings snap left to right over ~0.5 s.
func release() -> void:
	if _snap_t < 0.0:
		_snap_t = 0.0


func is_gone() -> bool:
	return not active


## A ball passing through knocks a letter; returns true on contact.
func knock(p: Vector2, v: Vector2, r: float) -> bool:
	var any := false
	for d in _letters:
		if d.wait <= 0.0 and d.pos.distance_to(p) < r + 34.0:
			d.vel += v * 0.25
			d.spin += signf(v.x + 0.01) * 4.0
			d.yaw_v += signf(v.x + 0.01) * 5.0
			any = true
	return any


func _process(delta: float) -> void:
	if not active or l == null:
		return
	var dt := minf(delta, 1.0 / 30.0)
	_clock += dt
	if _snap_t >= 0.0:
		_snap_t += dt
	var alive := false
	var calm := Prefs.reduced_motion
	for i in _letters.size():
		var d: Dictionary = _letters[i]
		if d.wait > 0.0:
			d.wait -= dt
			alive = true
			continue
		if d.attached and _snap_t >= 0.0 and _snap_t > i * 0.09:
			d.attached = false
			d.vel += Vector2(_rng.randf_range(-80, 80), -140)
			d.spin = _rng.randf_range(-5.0, 5.0)
			d.yaw_v += _rng.randf_range(-6.0, 6.0)
			Sfx.play("snap", _rng.randf_range(0.9, 1.15), -10.0)
		d.vel.y += GRAVITY * dt
		if d.attached:
			d.vel.x += push * dt
			var off: Vector2 = d.pos - d.anchor
			var dist := off.length()
			if dist > d.len:
				var dir := off / dist
				if not d.caught and d.vel.dot(dir) > 0.0:
					# The string takes most of the fall: what is left is a
					# short, lively bounce, not a trampoline.
					d.vel -= dir * d.vel.dot(dir) * 0.72
					_catch(i, d)
				if dist > d.len * 1.12:
					d.pos = d.anchor + dir * d.len * 1.12
				d.vel -= dir * d.k * (dist - d.len) * dt
				d.vel -= dir * d.vel.dot(dir) * (2.0 if d.k <= K + 1.0 else 7.0) * dt
			d.vel *= exp(-0.8 * dt)
			# The catch spring relaxes to the soft one as the bounce dies.
			if d.caught:
				d.k = lerpf(d.k, K, 1.0 - exp(-dt / 0.9))
			if dist > 1.0:
				d.rot = lerp_angle(d.rot, atan2(-off.x, off.y) * 0.8, Pal.damp(0.2, dt))
			# Torsion: the string winds back, plus a slow breath of air so
			# a letter at rest keeps turning a little.
			var air := 0.0 if calm else sin(_clock * 0.37 + d.phase) * 0.55 + sin(_clock * 0.23 + d.phase * 1.7) * 0.35
			d.yaw_v += (-TWIST_K * (d.yaw - air * 0.45) - TWIST_C * d.yaw_v) * dt
		else:
			d.rot += d.spin * dt
			d.alpha = maxf(0.0, d.alpha - dt * 1.2)
		d.yaw += d.yaw_v * dt
		d.pos += d.vel * dt
		if d.alpha > 0.0 and d.pos.y < l.size.y + 80.0:
			alive = true
	if not alive:
		active = false
		visible = false
	# A sheen sweeps across the title every few seconds.
	var sw := fmod(_clock + 2.0, SHEEN_EVERY) / 1.3
	_mat.set_shader_parameter("sweep", lerpf(-400.0, l.size.x + 400.0, sw) if sw < 1.0 else -9999.0)
	queue_redraw()


## A falling letter's string snaps taut.
func _catch(i: int, d: Dictionary) -> void:
	d.caught = true
	d.yaw_v += _rng.randf_range(-3.0, 3.0)
	var gold := i == Loc.title_accent()
	var slot := 0
	for e in _letters:
		if e.caught:
			slot += 1
	Sfx.note(STEPS[clampi(slot - 1, 0, STEPS.size() - 1)] + (2 if gold else 0), -3.0 if gold else -7.0, MENU_PITCH)
	Sfx.play("twang", _rng.randf_range(0.85, 1.1), -4.0)
	caught.emit(i, d.pos, gold)


func _draw() -> void:
	if font == null:
		return
	for i in _letters.size():
		var d: Dictionary = _letters[i]
		if d.wait > 0.0:
			continue
		var a: float = d.alpha
		var top: Vector2 = d.pos + Vector2(0, -FS * 0.62).rotated(d.rot)
		if d.attached:
			draw_set_transform(Vector2.ZERO)
			var dist: float = d.anchor.distance_to(d.pos)
			if dist < d.len * 0.97:
				# Slack: the string hangs in a curve until it pulls taut.
				var span: float = d.anchor.distance_to(top)
				var rope: float = span + (d.len - dist)
				var sag := sqrt(maxf(0.0, rope * rope - span * span)) * 0.45
				var mid: Vector2 = (d.anchor + top) * 0.5 + Vector2(sag * 0.25, sag)
				var pts := PackedVector2Array()
				for s in 13:
					var t := s / 12.0
					pts.append(d.anchor.lerp(mid, t).lerp(mid.lerp(top, t), t))
				draw_polyline(pts, Color(Pal.STRING, a), 1.6, true)
			else:
				draw_line(d.anchor, top, Color(Pal.STRING, a), 1.6, true)
		var w := font.get_string_size(d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var gold := i == Loc.title_accent()
		var face := Pal.GOLD if gold else Pal.INK
		var back := Pal.GOLD_DARK if gold else Pal.INK_DIM.darkened(0.25)
		var side := Pal.GOLD_DARK.darkened(0.3) if gold else Pal.METAL_LIGHT.darkened(0.15)
		var c := cos(d.yaw)
		var sx := signf(c) * maxf(absf(c), 0.06)
		var s := sin(d.yaw)
		var o := Vector2(-w * 0.5, FS * 0.08)
		var scl := Vector2(sx, 1.0)
		# Shadow on the wall.
		draw_set_transform(d.pos + Pal.SHADOW_OFFSET * 1.5, d.rot, scl)
		draw_string(font, o, d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(0, 0, 0, 0.35 * a))
		# The edge: the glyph stacked back into the letter's depth.
		var steps := 5
		for k in range(steps, 0, -1):
			var off := Vector2(s * DEPTH * k / steps, 0.0).rotated(d.rot)
			draw_set_transform(d.pos + off, d.rot, scl)
			draw_string(font, o, d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(side.darkened(0.07 * k), a))
		# The face, or the darker back when turned away.
		var col := face if c >= 0.0 else back
		var lit := 0.78 + 0.22 * absf(c)
		draw_set_transform(d.pos, d.rot, scl)
		draw_string(font, o, d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(col.r * lit, col.g * lit, col.b * lit, a))
	draw_set_transform(Vector2.ZERO)
