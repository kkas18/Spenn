extends Node2D
## Game root: state, levels, input, collisions and scoring.
## All nodes are created once in _ready(); targets and balls are pooled.

enum State { PLAY, CLEARING, OVER }

const MAX_TARGETS := 16
const MAX_BALLS := 4
const AMMO_CAP := 5
const RELOAD_TIME := 1.1
const SUBSTEP := 1.0 / 120.0
const BALL_BOUNCE := 0.7

var layout: Layout
var state := State.PLAY
var level := 1
var score := 0
var level_total := 0
var level_cleared := 0
var ammo: Array[bool] = []      # index 0 is loaded; true = pierce ball
var reload_t := 0.0

var world: Node2D
var rail: Rail
var slingshot: Slingshot
var hud: Hud
var fx: Fx
var backdrop: Backdrop
var targets: Array[Target] = []
var balls: Array[Ball] = []

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _clear_t := 0.0
var _touch := -1
var _origin := Vector2.ZERO
var _first_shot := true


func _ready() -> void:
	_rng.randomize()
	layout = Layout.compute(get_viewport())
	backdrop = Backdrop.new()
	add_child(backdrop)
	world = Node2D.new()
	add_child(world)
	rail = Rail.new()
	world.add_child(rail)
	for i in MAX_TARGETS:
		var t := Target.new()
		world.add_child(t)
		targets.append(t)
	slingshot = Slingshot.new()
	world.add_child(slingshot)
	for i in MAX_BALLS:
		var b := Ball.new()
		b.z_index = 1
		world.add_child(b)
		balls.append(b)
	fx = Fx.new()
	fx.z_index = 2
	fx.shake_target = world
	world.add_child(fx)
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 5
	add_child(vignette_layer)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/vignette.gdshader")
	vignette.material = mat
	vignette_layer.add_child(vignette)
	hud = Hud.new()
	add_child(hud)
	fx.font = hud.caps_font()
	slingshot.launched.connect(_on_launched)
	hud.pause_pressed.connect(_set_paused.bind(true))
	hud.resume_pressed.connect(_set_paused.bind(false))
	hud.restart_pressed.connect(_new_game)
	get_viewport().size_changed.connect(_on_resize)
	_apply_layout()
	_new_game()


func _apply_layout() -> void:
	rail.setup(layout, targets)
	backdrop.setup(layout)
	fx.l = layout
	slingshot.setup(layout)
	hud.setup(layout)


func _on_resize() -> void:
	layout = Layout.compute(get_viewport())
	for t in targets:
		t.anchor.y = layout.rail_y + 3.0
	_apply_layout()


func _new_game() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	hud.hide_menu()
	fx.clear()
	for t in targets:
		t.phase = Target.Phase.OFF
		t.visible = false
	for b in balls:
		b.stop()
	score = 0
	hud.bar.score = 0
	hud.bar.shown_score = 0.0
	ammo.clear()
	for i in AMMO_CAP:
		ammo.append(false)
	reload_t = 0.0
	slingshot.cancel()
	_touch = -1
	_first_shot = true
	hud.hint.modulate.a = 1.0
	_start_level(1)


func _start_level(n: int) -> void:
	level = n
	state = State.PLAY
	var count := mini(4 + n, 12)
	level_total = count
	level_cleared = 0
	# Staggered rows spread over the upper half of the field, so strings of
	# lower rows pass between the targets above them.
	var rows := 2 if count <= 6 else 3
	var cols := ceili(float(count) / rows)
	var usable := layout.size.x - 112.0
	var col_w := usable / cols
	for i in count:
		var t := _free_target()
		if t == null:
			break
		var row := i % rows
		var col := i / rows
		var stagger := (row - (rows - 1) * 0.5) / rows
		var x := 56.0 + (col + 0.5 + stagger) * col_w + _rng.randf_range(-8.0, 8.0)
		x = clampf(x, 48.0, layout.size.x - 48.0)
		var len := layout.play_h * (0.13 + 0.22 * row) * _rng.randf_range(0.92, 1.08)
		t.spawn(_pick_kind(n), Vector2(x, layout.rail_y + 3.0), 12.0, len, 0.25 + i * 0.06)
	hud.bar.level = n
	hud.bar.progress = 0.0
	if n > 1:
		fx.popup(Loc.t("level") % n, Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.42), Pal.INK, 26)


func _pick_kind(n: int) -> Target.Kind:
	var pool: Array[Target.Kind] = [Target.Kind.RING, Target.Kind.RING]
	if n >= 2:
		pool.append(Target.Kind.HEAVY)
	if n >= 3:
		pool.append(Target.Kind.SPLIT)
	if n >= 4:
		pool.append(Target.Kind.ROD)
	if n >= 5:
		pool.append(Target.Kind.DROP)
	return pool[_rng.randi() % pool.size()]


func _free_target() -> Target:
	for t in targets:
		if t.phase == Target.Phase.OFF:
			return t
	return null


func _descent() -> float:
	return minf(6.0 + 1.5 * (level - 1), 26.0) * layout.scale


func _process(delta: float) -> void:
	_acc += minf(delta, 0.05)
	while _acc >= SUBSTEP:
		_acc -= SUBSTEP
		_step(SUBSTEP)
	_update_ammo(delta)
	_update_eyes()
	if state == State.CLEARING:
		_clear_t -= delta
		if _clear_t <= 0.0:
			_start_level(level + 1)


## Pupils follow the nearest ball in flight (or the pouch while aiming);
## the target nearest the aim line squints.
func _update_eyes() -> void:
	var aiming := slingshot.is_aiming() and slingshot.power >= Slingshot.MIN_POWER
	var squinter: Target = null
	if aiming:
		var best := INF
		var o := layout.pouch_rest()
		for t in targets:
			if not t.is_hittable():
				continue
			var rel := t.pos - o
			var along := rel.dot(slingshot.aim_dir)
			if along <= 0.0:
				continue
			var off := absf(rel.cross(slingshot.aim_dir))
			if off < best:
				best = off
				squinter = t
	for t in targets:
		if t.phase == Target.Phase.OFF:
			continue
		t.squint = t == squinter
		var nearest := INF
		t.has_look = false
		for b in balls:
			if b.active:
				var d := b.pos.distance_squared_to(t.pos)
				if d < nearest:
					nearest = d
					t.look_at = b.pos
					t.has_look = true
		if not t.has_look:
			t.look_at = slingshot.pouch
			t.has_look = true


func _step(dt: float) -> void:
	var descent := _descent() if state == State.PLAY else 0.0
	var band := layout.play_h * 0.15
	var worst := 0.0
	for t in targets:
		if t.phase != Target.Phase.OFF:
			t.step(dt, descent, layout.danger_y, band, layout.size.y)
			if t.phase == Target.Phase.HANGING:
				worst = maxf(worst, t.danger)
	backdrop.danger = worst
	backdrop.descent = descent
	slingshot.step(dt)
	for b in balls:
		if not b.active:
			continue
		if not b.step(dt, layout):
			b.stop()
			continue
		_collide(b)
	if state == State.PLAY:
		for t in targets:
			if t.is_hittable() and t.bottom_y() >= layout.danger_y:
				_lose()
				break


func _collide(b: Ball) -> void:
	for t in targets:
		if not t.is_hittable():
			continue
		if not b.can_touch(t.get_instance_id()):
			continue
		var cp := t.closest_point(b.pos)
		var d := b.pos - cp
		var rr := Ball.RADIUS + t.radius
		var dist := d.length()
		if dist >= rr:
			continue
		var n := d / dist if dist > 0.001 else -b.vel.normalized()
		_on_hit(b, t, n, cp, rr)
		if not b.special:
			return


func _on_hit(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float) -> void:
	b.touch(t.get_instance_id())
	b.hits += 1
	var impulse: Vector2
	if b.special:
		impulse = b.vel.normalized() * 200.0
	else:
		var vn := b.vel.dot(n)
		if vn < 0.0:
			b.vel -= (1.0 + BALL_BOUNCE) * vn * n
		b.pos = cp + n * (rr + 0.5)
		impulse = -n * 260.0
	var kind := t.kind
	var col := t.color()
	var killed := t.hit(impulse)
	var gained := t.points() * b.hits
	score += gained
	hud.bar.score = score
	hud.bar.pulse = 1.0
	# Response: hit-stop, sparks, popup, sound and haptics on every hit.
	fx.hitstop()
	fx.sparks(cp, col, 10 if killed else 6)
	var label := "+%d" % gained
	if b.special:
		label += " " + Loc.t("pierce")
	elif killed and kind == Target.Kind.SPLIT:
		label += " " + Loc.t("split")
	elif b.hits >= 2:
		label += " " + Loc.t("combo") % b.hits
	fx.popup(label, t.pos + Vector2(0, -t.radius - 14.0))
	if b.hits >= 2:
		fx.shake(2.0 + minf(b.hits - 2, 1))
	if killed:
		Sfx.play("hit", 1.0 + 0.08 * (b.hits - 1))
		Sfx.play("snap", randf_range(0.95, 1.1), -6.0)
		Sfx.haptic(18, 0.5)
		level_cleared += 1
		if kind == Target.Kind.SPLIT:
			_split(t)
	else:
		Sfx.play("thud", 1.0 + 0.05 * (b.hits - 1))
		Sfx.haptic(12, 0.35)
	if b.hits == 2:
		_grant_pierce()
	hud.bar.progress = float(level_cleared) / float(maxi(level_total, 1))
	if level_cleared >= level_total and state == State.PLAY:
		state = State.CLEARING
		_clear_t = 1.4
		Sfx.play("clear")
		fx.popup(Loc.t("level_clear") % level, Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.42), Pal.INK, 26)


func _split(t: Target) -> void:
	for side: float in [-1.0, 1.0]:
		var d := _free_target()
		if d == null:
			return
		var ax := clampf(t.anchor.x + side * 38.0, 40.0, layout.size.x - 40.0)
		var p := t.pos + Vector2(side * 16.0, 0)
		var anchor := Vector2(ax, layout.rail_y + 3.0)
		var len := anchor.distance_to(p)
		d.spawn(Target.Kind.DROP, anchor, len, len, 0.0)
		d.pos = p
		d.vel = Vector2(side * 160.0, -60.0)
		level_total += 1


func _grant_pierce() -> void:
	if ammo.size() >= AMMO_CAP:
		ammo[mini(1, ammo.size() - 1)] = true
	elif ammo.is_empty():
		ammo.append(true)
	else:
		ammo.insert(1, true)


func _update_ammo(delta: float) -> void:
	if ammo.size() < AMMO_CAP and state != State.OVER:
		reload_t += delta
		if reload_t >= RELOAD_TIME:
			reload_t = 0.0
			ammo.append(false)
	else:
		reload_t = 0.0
	slingshot.set_ammo(ammo, reload_t / RELOAD_TIME)


func _on_launched(pos: Vector2, vel: Vector2, special: bool) -> void:
	if ammo.is_empty():
		return
	for b in balls:
		if not b.active:
			b.fire(pos, vel, special)
			ammo.pop_front()
			break
	if _first_shot:
		_first_shot = false
		create_tween().tween_property(hud.hint, "modulate:a", 0.0, 0.4)


func _lose() -> void:
	state = State.OVER
	slingshot.cancel()
	_touch = -1
	var is_record := Loc.submit_score(score)
	fx.shake()
	Sfx.play("lose")
	Sfx.haptic(60, 0.8)
	hud.show_game_over(score, is_record)


func _set_paused(on: bool) -> void:
	if state == State.OVER:
		return
	get_tree().paused = on
	Engine.time_scale = 1.0
	hud.show_pause(on)
	if on:
		slingshot.cancel()
		_touch = -1


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if is_inside_tree() and state != State.OVER:
				_set_paused(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if state == State.OVER:
				get_tree().quit()
			else:
				_set_paused(not get_tree().paused)


func _unhandled_input(e: InputEvent) -> void:
	if state != State.PLAY or get_tree().paused:
		return
	if e is InputEventScreenTouch:
		if e.pressed and _touch == -1 and e.position.y > layout.danger_y - 40.0:
			if slingshot.begin_aim():
				_touch = e.index
				_origin = e.position
		elif not e.pressed and e.index == _touch:
			_touch = -1
			slingshot.release()
	elif e is InputEventScreenDrag and e.index == _touch:
		slingshot.drag(e.position - _origin)
