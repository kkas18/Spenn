extends Node2D
## Game root: an endless survival run. Targets keep hanging in from the
## rail at a pace that only rises; events (formation, rush, boss) punctuate
## it. Also lives, streaks, chains, collisions and scoring. All nodes are created once
## in _ready(); targets, balls and effects are pooled.

enum State { BOOT, INTRO, MAIN_MENU, STARTING, PLAYING, PAUSED, RESUMING, DEATH, GAME_OVER, RESTARTING }

const MAX_TARGETS := 28
const MAX_BALLS := 6
const AMMO_CAP := 5
const SUBSTEP := 1.0 / 120.0
# Ball vs body: an impulse exchange between masses. The ball is mass 1; a
# target is K_MASS × its own mass. Jelly swallows the blow (low restitution,
# high grip); rigid shells send the ball back (higher restitution, slick).
const K_MASS := 6.0
const SOFT_E := 0.12
const SOFT_MU := 0.45
const RIGID_E := 0.5
const RIGID_MU := 0.12
const PLATE_E := 0.7
const LIVES := 3
const CUT_SPEED := 1400.0      # a rising ball this fast severs a string near its hook
const EXTRA_LIFE_EVERY := 1500
const CHAIN_WINDOW := 1.2
const CLOSE_CALL := 0.55       # danger above this when killed = close call
const MAX_MINIONS := 3
const TRIPLE_SPREAD := 0.1
const Ammo := Slingshot.Ammo

var layout: Layout
var director := Director.new()
var state := State.BOOT
var score := 0
var lives := LIVES
var streak := 0
var best_streak := 0
var cuts := 0
var ammo: Array[int] = []       # index 0 is loaded
var reload_t := 0.0

var world: Node2D
var rail: Rail
var title: TitleLetters
var slingshot: Slingshot
var hud: Hud
var fx: Fx
var backdrop: Backdrop
var targets: Array[Target] = []
var balls: Array[Ball] = []

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _state_t := 0.0
var _spawn_t := 0.0
var _rush_left := 0
var _rush_t := 0.0
var _chain := 0
var _chain_t := 0.0
var _next_life_at := EXTRA_LIFE_EVERY
var _phase_shown := 1
var _beat_t := 0.0
var _vignette: ShaderMaterial
var _tension := 0.0
var _touch := -1
var _origin := Vector2.ZERO
var _time := 0.0
var _knock_sfx_cd := 0.0
var _shot_seq := 0
var _shots := {}                # shot id -> {"balls": n, "hit": bool}
var _last_tap := -10.0
var _last_tap_pos := Vector2.ZERO
var _deny_cd := 0.0
var _intro_queue: Array[Target] = []


func _ready() -> void:
	_rng.randomize()
	layout = Layout.compute(get_viewport())
	backdrop = Backdrop.new()
	add_child(backdrop)
	world = Node2D.new()
	add_child(world)
	rail = Rail.new()
	world.add_child(rail)
	title = TitleLetters.new()
	world.add_child(title)
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
	_vignette = mat
	vignette_layer.add_child(vignette)
	hud = Hud.new()
	add_child(hud)
	fx.font = hud.caps_font()
	slingshot.launched.connect(_on_launched)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_to_menu)
	get_viewport().size_changed.connect(_on_resize)
	_apply_layout()
	_boot()


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
	if state == State.MAIN_MENU:
		title.setup(layout, hud.display_font())


# ---------------------------------------------------------------- run flow

func _clear_field() -> void:
	get_tree().paused = false
	fx.reset_time()
	fx.clear()
	for t in targets:
		t.phase = Target.Phase.OFF
		t.visible = false
	for b in balls:
		b.stop()
	_shots.clear()
	_intro_queue.clear()
	ammo.clear()
	for i in AMMO_CAP:
		ammo.append(Ammo.NORMAL)
	reload_t = 0.0
	slingshot.cancel()
	_touch = -1
	_tension = 0.0
	_vignette.set_shader_parameter("strength", 0.55)


## One place where the state changes; everything that differs per state
## (input, music, what ticks) reads `state`.
func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _boot() -> void:
	_set_state(State.BOOT)
	title.visible = false
	_set_state(State.INTRO)
	hud.intro_seq.exiting.connect(_on_intro_exit, CONNECT_ONE_SHOT)
	hud.intro_seq.play(not Prefs.intro_seen)


## The intro's dark ground lifts: the letters hang in from the rail and the
## menu chrome fades up underneath, so intro and menu are one continuous shot.
func _on_intro_exit() -> void:
	_to_menu()


func _to_menu() -> void:
	var from_game := state != State.INTRO
	_set_state(State.MAIN_MENU)
	hud.locked = true
	if from_game:
		hud.hide_game_over()
		hud.close_pause()
		hud.scrim_to(0.0, Motion.NORMAL)
		hud.fade_hud(0.0, Motion.FAST)
	_clear_field()
	title.setup(layout, hud.display_font())
	hud.show_menu()
	Music.set_mode(Music.Mode.MENU)
	Motion.after(Motion.NORMAL, func() -> void: hud.locked = false)


## First release on the menu starts a run: the letters' strings snap, the
## HUD comes in piece by piece and the first row hangs in.
func _start_run() -> void:
	_set_state(State.STARTING)
	score = 0
	lives = LIVES
	streak = 0
	best_streak = 0
	cuts = 0
	_chain = 0
	_chain_t = 0.0
	_next_life_at = EXTRA_LIFE_EVERY
	_phase_shown = 1
	_rush_left = 0
	_spawn_t = 2.5
	_last_tap = -10.0
	director.reset()
	hud.bar.score = 0
	hud.bar.shown_score = 0.0
	hud.bar.lives = lives
	hud.bar.streak = 0
	hud.bar.phase = 1
	hud.bar.progress = 0.0
	hud.bar.set_mult(1)
	hud.hide_menu_ui()
	hud.reveal_hud()
	title.release()
	# No pause button: the first few runs say how to pause instead.
	Prefs.runs += 1
	Prefs.save()
	hud.card(Loc.t("event.survive"), Loc.t("pause.hint") if Prefs.runs <= 3 else Loc.t("event.surviveSub"))
	_spawn_formation(Target.Kind.RING, 4)
	Music.set_mode(Music.Mode.PLAY)
	Motion.after(0.5, func() -> void:
		if state == State.STARTING:
			_set_state(State.PLAYING))


## Restart: the button answers at once, results fade, the scrim lifts and
## the field resets in place (no scene reload): back in play in ~0.5 s.
func _restart() -> void:
	if state != State.GAME_OVER and state != State.PAUSED:
		return
	_set_state(State.RESTARTING)
	hud.locked = true
	Sfx.play("restart")
	hud.hide_game_over()
	hud.close_pause()
	hud.scrim_to(0.0, Motion.NORMAL)
	Motion.after(Motion.FAST, func() -> void:
		_clear_field()
		title.active = false
		title.visible = false
		_start_run()
		hud.locked = false)


## One target at the freest spot along the rail, high up.
func _spawn_one(kind: Target.Kind, len_frac := -1.0) -> Target:
	var t := _free_target()
	if t == null:
		return null
	var used: Array[float] = []
	for o in targets:
		if o.is_hittable() or (o.phase == Target.Phase.HANGING and o.delay > 0.0):
			used.append(o.anchor.x)
	var x := _best_slot(used, 12)
	var frac := len_frac if len_frac >= 0.0 else _rng.randf_range(0.05, 0.3)
	t.spawn(kind, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * frac, 0.0)
	t.aggression = director.aggression()
	_maybe_intro(t)
	return t


## A row of identical targets in a shallow V, dropping in left to right.
func _spawn_formation(kind: Target.Kind, n: int) -> void:
	var usable := layout.size.x - 120.0
	for i in n:
		var t := _free_target()
		if t == null:
			return
		var x := 60.0 + (i + 0.5) * usable / n
		var v := absf(i - (n - 1) * 0.5) / maxf(1.0, (n - 1) * 0.5)
		t.spawn(kind, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * (0.2 - 0.1 * v), 0.15 + i * 0.09)
		t.aggression = director.aggression()
		_maybe_intro(t)


func _spawn_boss() -> void:
	var t := _free_target()
	if t == null:
		return
	t.spawn(Target.Kind.BOSS, Vector2(layout.center_x, layout.rail_y + 3.0), 12.0, layout.play_h * 0.22, 0.3)
	t.aggression = director.aggression()
	_maybe_intro(t)


func _alive_count() -> int:
	var n := 0
	for t in targets:
		if t.is_hittable() or (t.phase == Target.Phase.HANGING and t.delay > 0.0):
			n += 1
	return n


func _boss_alive() -> bool:
	for t in targets:
		if t.kind == Target.Kind.BOSS and t.phase == Target.Phase.HANGING:
			return true
	return false


## First time a kind ever appears it gets a short card and a marker ring.
func _maybe_intro(t: Target) -> void:
	if not Prefs.seen.has(t.kind) and not _intro_queue.has(t):
		_intro_queue.append(t)


func _run_intros() -> void:
	if _intro_queue.is_empty() or hud.intro_busy():
		return
	var t: Target = _intro_queue[0]
	if t.phase == Target.Phase.HANGING and t.delay > 0.0:
		return
	_intro_queue.pop_front()
	if t.phase != Target.Phase.HANGING or not Prefs.first_sight(t.kind):
		return
	var parts := Loc.t("enemy.%d" % t.kind).split("|")
	hud.intro(parts[0], parts[1] if parts.size() > 1 else "")
	t.intro_t = 3.0
	Sfx.play("intro")


func _best_slot(used: Array[float], slots: int) -> float:
	var best_x := layout.center_x
	var best_d := -1.0
	var usable := layout.size.x - 96.0
	for s in slots:
		var x := 48.0 + (s + 0.5) * usable / slots + _rng.randf_range(-6.0, 6.0)
		var d := INF
		for u in used:
			d = minf(d, absf(u - x))
		if d > best_d:
			best_d = d
			best_x = x
	return best_x


func _free_target() -> Target:
	for t in targets:
		if t.phase == Target.Phase.OFF:
			return t
	return null


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_acc += minf(delta, 0.05)
	while _acc >= SUBSTEP:
		_acc -= SUBSTEP
		_step(SUBSTEP)
	_state_t += delta
	_update_ammo(delta)
	_update_eyes()
	if state == State.PLAYING or state == State.STARTING:
		_run_intros()
		_pace(delta)
		_spawn_minions()
		Music.intensity = clampf(director.intensity() / 5.0, 0.0, 1.0)


## The endless pacing: regular spawns under a rising cap, events with a
## card each, rush drops, chains timing out, phase changes and the
## heartbeat when a target is close to the line.
func _pace(delta: float) -> void:
	director.tick(delta)
	_spawn_t -= delta
	if _alive_count() < director.alive_floor():
		_spawn_t = minf(_spawn_t, 0.35)
	if _spawn_t <= 0.0:
		_spawn_t = director.spawn_interval(_boss_alive()) * _rng.randf_range(0.8, 1.2)
		if _alive_count() < director.alive_cap():
			_spawn_one(director.pick_kind(_rng))
	match director.poll_event():
		Director.Event.FORMATION:
			var k := director.formation_kind(_rng)
			_spawn_formation(k, 5 + mini(3, int(director.intensity())))
			hud.card(Loc.t("event.formation"), Loc.t("event.formationSub"))
			Sfx.play("intro", 0.9)
		Director.Event.RUSH:
			_rush_left = 5 + int(director.intensity())
			_rush_t = 0.6
			hud.card(Loc.t("event.rush"), Loc.t("event.rushSub"))
			Sfx.play("whoosh", 0.8)
		Director.Event.BOSS:
			_spawn_boss()
			hud.card(Loc.t("event.boss"), Loc.t("event.bossSub"))
			Sfx.play("boss")
	if _rush_left > 0:
		_rush_t -= delta
		if _rush_t <= 0.0:
			_rush_t = 0.4
			_rush_left -= 1
			_spawn_one(Target.Kind.DROP, _rng.randf_range(0.04, 0.12))
	if _chain_t > 0.0:
		_chain_t -= delta
		if _chain_t <= 0.0:
			_chain = 0
	var p := director.phase()
	hud.bar.phase = p
	hud.bar.progress = director.phase_progress()
	if p != _phase_shown:
		_phase_shown = p
		fx.popup(Loc.t("hud.phase") % p, Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.45), Pal.INK, 24)
		Sfx.play("streak", 0.85)
	# Tension: the vignette closes in a little while a target is near the line.
	var want := clampf(backdrop.danger, 0.0, 1.0)
	_tension = lerpf(_tension, want, Pal.damp(0.05, delta))
	_vignette.set_shader_parameter("strength", lerpf(0.55, 0.78, _tension))
	if backdrop.danger > 0.7:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = lerpf(0.85, 0.5, backdrop.danger)
			Sfx.play("beat")
			Sfx.haptic(8, 0.15)
	else:
		_beat_t = 0.0


## Pupils follow the nearest ball in flight (or the pouch while aiming).
## Every target reads the predicted shot: how squarely the path crosses it,
## which side of the path it is on, and whether a ball already in flight
## will pass close with time to react. It also learns how far its hook may
## slide along the rail before it would run into a neighbour.
func _update_eyes() -> void:
	var aiming := slingshot.is_aiming() and slingshot.power >= Slingshot.MIN_POWER
	var o := layout.pouch_rest()
	var path := slingshot.predict() if aiming and slingshot.power > 0.3 else PackedVector2Array()
	var flights: Array[PackedVector2Array] = []
	for b in balls:
		if b.active:
			flights.append(_flight(b))
	for t in targets:
		if t.phase == Target.Phase.OFF:
			continue
		t.threat = o
		# Targets that have hung around learn as the run heats up.
		t.aggression = maxf(t.aggression, director.aggression())
		_read_threat(t, path)
		t.aimed = t.threat_lvl > 0.45 and t.is_hittable()
		t.alarm = false
		t.incoming = false
		for f in flights:
			_read_flight(t, f)
		t.has_cover = false
		if t.aimed and t.kind == Target.Kind.RING:
			_find_cover(t, o)
		_slide_room(t)
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
	# Everything in the line of fire narrows its eye: it is watching you.
	for t in targets:
		t.squint = t.aimed or (t.threat_lvl > 0.2 and t.is_hittable())


func _read_threat(t: Target, path: PackedVector2Array) -> void:
	t.threat_lvl = 0.0
	if path.is_empty() or not t.is_hittable():
		return
	var best := INF
	var bi := 0
	for i in path.size():
		var d := path[i].distance_squared_to(t.pos)
		if d < best:
			best = d
			bi = i
	var r := t.radius + Ball.RADIUS
	t.threat_lvl = clampf(1.0 - (sqrt(best) - r) / (r * 1.5), 0.0, 1.0)
	if t.threat_lvl <= 0.0:
		return
	# Dodge away from the path; dead-centre, away from the path's lean.
	var bp := path[bi]
	var side := t.pos.x - bp.x
	if absf(side) < 3.0:
		var lean := path[mini(bi + 1, path.size() - 1)].x - path[maxi(bi - 1, 0)].x
		side = -lean if absf(lean) > 0.5 else (1.0 if t.pos.x < layout.center_x else -1.0)
	t.dodge_dir = signf(side)


## A ball's next 0.6 s (gravity only), sampled at 30 Hz.
func _flight(b: Ball) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := b.pos
	var v := b.vel
	var dt := 1.0 / 30.0
	for i in 18:
		v.y += Ball.GRAVITY * dt
		p += v * dt
		out.append(p)
	return out


func _read_flight(t: Target, f: PackedVector2Array) -> void:
	if not t.is_hittable():
		return
	var r := t.radius + Ball.RADIUS
	for i in f.size():
		var p := f[i]
		if p.distance_squared_to(t.pos) < (r * 2.2) * (r * 2.2):
			t.alarm = true
			# Only a ball that is still ~0.2 s away can be dodged.
			if i >= 6 and p.distance_squared_to(t.pos) < (r * 1.4) * (r * 1.4):
				t.incoming = true
				var side := t.pos.x - p.x
				t.dodge_dir = signf(side) if absf(side) > 2.0 else (1.0 if t.pos.x < layout.center_x else -1.0)
			return


## How far the hook may slide: up to the screen margin, and short of any
## neighbour hanging at an overlapping height.
func _slide_room(t: Target) -> void:
	var lo := layout.margin + t.radius
	var hi := layout.size.x - layout.margin - t.radius
	for o in targets:
		if o == t or o.phase != Target.Phase.HANGING or o.delay > 0.0:
			continue
		if absf(o.pos.y - t.pos.y) > o.radius + t.radius + 24.0:
			continue
		var gap := o.radius + t.radius + 10.0
		if o.anchor.x <= t.anchor.x:
			lo = maxf(lo, o.anchor.x + gap)
		else:
			hi = minf(hi, o.anchor.x - gap)
	t.slide_lo = lo
	t.slide_hi = hi


## Cover for a Vakt: the x at its height where a lower target sits on the
## line from the slingshot, i.e. hiding behind that target.
func _find_cover(t: Target, o: Vector2) -> void:
	var best := 170.0 * layout.scale
	for c in targets:
		if c == t or not c.is_solid() or c.pos.y < t.pos.y + 30.0:
			continue
		var k := (t.pos.y - o.y) / (c.pos.y - o.y)
		var x := o.x + (c.pos.x - o.x) * k
		var d := absf(x - t.pos.x)
		if d < best:
			best = d
			t.cover_x = clampf(x, 40.0, layout.size.x - 40.0)
			t.has_cover = true


func _step(dt: float) -> void:
	var descent := director.descent(layout.scale) if (state == State.PLAYING or state == State.STARTING) else 0.0
	var band := layout.play_h * 0.15
	var worst := 0.0
	_time += dt
	_knock_sfx_cd = maxf(0.0, _knock_sfx_cd - dt)
	for t in targets:
		if t.phase != Target.Phase.OFF:
			t.wind = _breeze(t.pos.x)
			t.step(dt, descent, layout.danger_y, band, layout.size.y)
			if t.phase == Target.Phase.HANGING:
				worst = maxf(worst, t.danger)
	backdrop.danger = worst
	backdrop.descent = descent
	_target_contacts()
	slingshot.step(dt)
	for b in balls:
		if not b.active:
			continue
		if not b.step(dt, layout):
			_finish_ball(b)
			continue
		if title.active and title.knock(b.pos, b.vel, Ball.RADIUS) and _knock_sfx_cd <= 0.0:
			_knock_sfx_cd = 0.1
			Sfx.play("knock", randf_range(0.8, 1.0), -6.0)
		_collide(b)
	if state == State.PLAYING or state == State.STARTING:
		for t in targets:
			if t.is_hittable() and t.bottom_y() >= layout.danger_y:
				_breach(t)
				if state != State.PLAYING and state != State.STARTING:
					break


## Slow layered breeze: a few px/s² of sideways push that drifts across
## the field, enough for hanging targets to sway at rest.
func _breeze(x: float) -> float:
	return (sin(_time * 0.37 + x * 0.004) * 0.65 + sin(_time * 0.91 + x * 0.013 + 1.7) * 0.35) * 9.0 * layout.scale


## Soft contacts between hanging targets: overlap is pushed apart by
## inverse mass and the closing speed is exchanged with low restitution,
## so a struck target can nudge its neighbours.
func _target_contacts() -> void:
	var n := targets.size()
	for i in n:
		var a := targets[i]
		if not a.is_hittable():
			continue
		for j in range(i + 1, n):
			var c := targets[j]
			if not c.is_hittable():
				continue
			var d := c.pos - a.pos
			var rr := a.contact_radius() + c.contact_radius()
			var dist := d.length()
			if dist >= rr or dist < 0.001:
				continue
			var nrm := d / dist
			var ia := 1.0 / a.mass()
			var ic := 1.0 / c.mass()
			var corr := nrm * (rr - dist) / (ia + ic)
			a.pos -= corr * ia
			c.pos += corr * ic
			var closing := (a.vel - c.vel).dot(nrm)
			if closing <= 0.0:
				continue
			var j_imp := minf(closing * 1.35 / (ia + ic), 420.0)
			var contact := a.pos + nrm * a.contact_radius()
			a.push(-nrm * j_imp, contact)
			c.push(nrm * j_imp, contact)
			a.dent(contact, closing * 0.8)
			c.dent(contact, closing * 0.8)
			if closing > 140.0 and _knock_sfx_cd <= 0.0:
				_knock_sfx_cd = 0.08
				Sfx.play("knock", randf_range(0.9, 1.1), linear_to_db(clampf(closing / 600.0, 0.15, 0.7)))
				Sfx.haptic(6, 0.2)


func _spawn_minions() -> void:
	for t in targets:
		if t.kind != Target.Kind.BOSS or not t.wants_minion:
			continue
		t.wants_minion = false
		if not t.is_hittable():
			continue
		var alive := 0
		for m in targets:
			if m.kind == Target.Kind.DROP and m.is_hittable():
				alive += 1
		if alive >= MAX_MINIONS:
			continue
		var d := _free_target()
		if d == null:
			continue
		var ax := clampf(t.anchor.x + _rng.randf_range(-1.0, 1.0) * 150.0, 48.0, layout.size.x - 48.0)
		d.spawn(Target.Kind.DROP, Vector2(ax, layout.rail_y + 3.0), 12.0, t.length * 0.75, 0.0)
		d.aggression = t.aggression
		_maybe_intro(d)
		Sfx.play("whoosh", 1.2, -8.0)


# ---------------------------------------------------------------- hits

func _collide(b: Ball) -> void:
	var cut_speed := CUT_SPEED * layout.scale
	if b.hit_rail:
		# Spent against the rail: it drops out of play instead of raining
		# back down through the field.
		return
	for t in targets:
		if not t.is_hittable():
			continue
		# A fast ball severs the string it crosses; a slower one plucks it.
		# Cut: the ball's centre (±5 px) crosses the string near its hook on
		# the way up, fast, before touching the rail. A precision shot.
		if t.kind != Target.Kind.BOSS and not b.cut_any and not b.hit_rail and b.vel.y < 0.0 and b.vel.length() > cut_speed and t.rope_hit(b.pos, 5.0):
			b.cut_any = true
			if t.strike_string(b.pos):
				_on_cut(b, t)
			else:
				fx.sparks(b.pos, Pal.INK_DIM, 6)
				Sfx.play("twang", 1.2, -6.0)
				Sfx.haptic(8, 0.2)
			continue
		if t.pluck(b.pos, b.vel, Ball.RADIUS):
			Sfx.play("twang", randf_range(0.85, 1.25), -14.0)
		if not b.can_touch(t.get_instance_id()) or not t.is_solid():
			continue
		var cp := t.closest_point(b.pos)
		var d := b.pos - cp
		var rr := Ball.RADIUS + t.radius
		if t.kind == Target.Kind.SHIELD:
			rr += 5.0
		elif t.kind == Target.Kind.BOSS:
			rr += 11.0
		var dist := d.length()
		if dist >= rr:
			# Near miss: the target flinches and its eye pops wide.
			if dist < rr + 34.0 and b.vel.length() > 500.0:
				t.startle(b.pos)
			continue
		var n := d / dist if dist > 0.001 else -b.vel.normalized()
		if not b.special and t.blocks(n):
			_on_block(b, t, n, cp, rr)
		else:
			_on_hit(b, t, n, cp, rr)
		if not b.special:
			return


## Impulse-based contact against a moving body of mass `m` (target units).
## Updates the ball; returns the impulse to hand the target (its `hit` and
## `push` divide by the target's own mass). Also reports the closing speed.
func _resolve(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float, e: float, mu: float) -> Array:
	b.pos = cp + n * (rr + 0.5)
	var rel := b.vel - t.vel
	var vn := rel.dot(n)
	if vn >= 0.0:
		return [Vector2.ZERO, 0.0]
	var inv := 1.0 + 1.0 / (t.mass() * K_MASS)
	var j := -(1.0 + e) * vn / inv
	var tang := rel - n * vn
	var tl := tang.length()
	var jt := minf(mu * j, tl / inv)
	var imp := n * j - (tang / tl * jt if tl > 0.01 else Vector2.ZERO)
	b.vel += imp
	# Never left sitting inside the body: a little separation speed.
	if b.vel.dot(n) < 40.0:
		b.vel += n * (40.0 - b.vel.dot(n))
	b.impact(n)
	return [-imp / K_MASS, -vn]


## Armour: the ball glances off, the target rocks, nothing breaks.
func _on_block(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float) -> void:
	b.touch(t.get_instance_id())
	var res := _resolve(b, t, n, cp, rr, PLATE_E, 0.08)
	var contact := b.pos - n * Ball.RADIUS
	t.push(res[0], contact)
	t.dent(contact, res[1])
	fx.sparks(contact, Pal.METAL_LIGHT, 6)
	fx.ring(contact, Pal.METAL_LIGHT, 14.0)
	fx.popup(Loc.t("popup.blocked"), contact + Vector2(0, -18), Pal.INK_DIM, 16)
	Sfx.play("clank", randf_range(0.95, 1.08), -3.0)
	Sfx.haptic(10, 0.3)


func _on_hit(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float) -> void:
	b.touch(t.get_instance_id())
	b.hits += 1
	_mark_hit(b)
	var impulse: Vector2
	var contact := b.pos - n * Ball.RADIUS
	var closing := b.vel.length()
	if b.special:
		# Pierce: punches through, losing some speed to each body.
		impulse = b.vel.normalized() * 200.0
		b.vel *= 0.85
	else:
		var res := _resolve(b, t, n, cp, rr, SOFT_E if t.soft else RIGID_E, SOFT_MU if t.soft else RIGID_MU)
		impulse = res[0]
		closing = res[1]
	t.dent(contact, closing * (1.7 if t.hp <= 1 else 1.0))
	var loud := linear_to_db(clampf(closing / 1300.0, 0.3, 1.0))
	var kind := t.kind
	var col := t.color()
	var was_close := t.danger > CLOSE_CALL
	var killed := t.hit(impulse, contact)
	var gained := t.points() * b.hits * _mult()
	if killed and kind == Target.Kind.BOSS:
		gained *= 5
	if killed:
		gained += _kill_bonus(t, was_close, gained)
	_add_score(gained, t.pos)
	# Response: hit-stop, sparks, ring, popup, sound and haptics on every hit.
	fx.hitstop()
	fx.sparks(cp, col, 10 if killed else 6)
	fx.ring(contact, col.lightened(0.15), t.radius)
	var label := "+%d" % gained
	if b.special:
		label += " " + Loc.t("popup.pierce")
	elif killed and kind == Target.Kind.SPLIT:
		label += " " + Loc.t("popup.split")
	elif b.hits >= 2:
		label += " " + Loc.t("popup.combo") % b.hits
	fx.popup(label, t.pos + Vector2(0, -t.radius - 14.0))
	if b.hits >= 2:
		fx.shake(2.0 + minf(b.hits - 2, 1))
	if killed:
		if t.soft:
			# The jelly squashes for a moment, then bursts.
			var at := t.pos
			var rot := t.body_rot
			var r := t.radius
			fx.after(Target.POP_TIME, func() -> void:
				fx.burst(kind, at, rot, r, col, Vector2.ZERO)
				fx.puff(at, col, 2, r * 1.3, 0.32))
		else:
			fx.burst(kind, t.pos, t.body_rot, t.radius, col, t.vel)
		if not t.soft:
			fx.shards(t.pos, col, 6 if kind == Target.Kind.BOSS else 2, t.vel)
		if not t.soft:
			fx.puff(t.pos, col, 6 if kind == Target.Kind.BOSS else 2, t.radius * (1.8 if kind == Target.Kind.BOSS else 1.3), 0.32)
		if t.soft:
			# Jelly bursts wetly; the smaller it is, the higher it sounds.
			Sfx.play("splat", 30.0 / t.radius * randf_range(0.95, 1.05), loud)
			Sfx.play("squish", 1.1, loud - 6.0)
		else:
			Sfx.play("burst", randf_range(0.92, 1.08), loud)
			_material_knock(t, b.hits, loud)
		Sfx.play("snap", randf_range(0.95, 1.1), -8.0)
		Sfx.haptic(18, 0.5)
		if kind == Target.Kind.BOSS:
			fx.shake(3.0)
			fx.punch(0.045)
			fx.slowmo(0.3, 0.6)
			Sfx.haptic(80, 0.9)
		if kind == Target.Kind.SPLIT:
			_split(t)
	else:
		if t.soft:
			Sfx.play("squish", 30.0 / t.radius * randf_range(0.95, 1.05), loud)
		else:
			_material_knock(t, b.hits, loud)
		Sfx.haptic(12 if t.soft else 9, 0.3 if t.soft else 0.4)
	if b.hits == 2:
		_grant(Ammo.PIERCE)


## Rigid shells each sound like what they are made of.
func _material_knock(t: Target, hits: int, loud: float) -> void:
	var p := 1.0 + 0.06 * (hits - 1)
	match t.kind:
		Target.Kind.ROD:
			Sfx.play("wood", p, loud)
		Target.Kind.SHIELD, Target.Kind.REEL:
			Sfx.play("clank", p, loud)
		Target.Kind.BOSS:
			Sfx.play("metal", p * 0.9, loud)
		_:
			Sfx.play("hit", p, loud)


## String severed: double points, and it ignores armour and health.
func _on_cut(b: Ball, t: Target) -> void:
	b.cut_any = true
	# Cutting costs the ball most of its speed: one clean cut per shot.
	b.vel *= 0.45
	_mark_hit(b)
	cuts += 1
	var col := t.color()
	var was_close := t.danger > CLOSE_CALL
	t.cut()
	var gained := t.points() * 2 * _mult()
	gained += _kill_bonus(t, was_close, gained)
	_add_score(gained, t.pos)
	fx.hitstop()
	fx.sparks(b.pos, Pal.INK_DIM, 7)
	fx.popup("+%d %s" % [gained, Loc.t("popup.cut")], b.pos + Vector2(0, -22), Pal.INK)
	fx.shards(t.pos, col, 2, t.vel)
	Sfx.play("cut", randf_range(0.95, 1.08))
	Sfx.haptic(20, 0.5)


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
		d.aggression = t.aggression
		_maybe_intro(d)


## Chains (kills in quick succession) and close calls (a kill just above
## the line) pay extra and say so.
func _kill_bonus(t: Target, was_close: bool, gained: int) -> int:
	var bonus := 0
	_chain += 1
	_chain_t = CHAIN_WINDOW
	if _chain >= 3:
		bonus += int(gained * 0.2 * mini(_chain - 2, 6))
		fx.popup(Loc.t("popup.chain") % _chain, t.pos + Vector2(0, t.radius + 26.0), Pal.GOLD, 16)
		Sfx.play("streak", minf(1.25, 0.9 + 0.05 * _chain))
	if was_close:
		bonus += 50 * _mult()
		fx.popup(Loc.t("popup.close") + " +%d" % (50 * _mult()), t.pos + Vector2(0, -t.radius - 40.0), Pal.CORAL, 18)
		fx.slowmo(0.45, 0.28)
		fx.punch(0.02)
	return bonus


## A target reached the line: a knot snaps, the rail rings, the rest of
## the field is yanked up a little as relief.
func _breach(t: Target) -> void:
	lives -= 1
	hud.bar.lose_life(lives)
	var at := Vector2(t.pos.x, layout.danger_y)
	t.cut()
	rail.flex(t.anchor.x, 9.0)
	fx.shake(3.0)
	fx.punch(0.02)
	fx.sparks(at, Pal.CORAL, 10)
	fx.ring(at, Pal.CORAL, 40.0)
	fx.puff(at, Pal.CORAL, 3, 46.0, 0.3)
	fx.popup(Loc.t("popup.lifeLost"), at + Vector2(0, -30), Pal.CORAL, 20)
	Sfx.play("breach")
	Sfx.haptic(70, 0.9)
	# The ones hanging nearby enjoy it.
	for o in targets:
		if o != t and o.is_hittable() and o.pos.distance_to(t.pos) < 260.0 * layout.scale:
			o.taunt()
	streak = 0
	_chain = 0
	hud.bar.streak = 0
	hud.bar.set_mult(1)
	for o in targets:
		if o.is_hittable():
			o.length = maxf(40.0, o.length - 50.0 * layout.scale)
			o.goal_length = o.length
	if lives <= 0:
		_begin_death(at)


## Death: impact (shake, coral flash, sparks, low hit), then slow motion
## 1.0 → 0.35 → 0.15 → near-still over ~0.6 s while the HUD fades and the
## scene darkens; the results come in at ~0.9 s.
func _begin_death(at: Vector2) -> void:
	_set_state(State.DEATH)
	hud.locked = true
	slingshot.cancel()
	_touch = -1
	fx.ring(at, Pal.CORAL, 70.0)
	fx.sparks(at, Pal.CORAL, 10)
	fx.puff(at, Pal.CORAL, 6, 90.0, 0.36)
	fx.shake(3.0)
	fx.punch(0.03)
	Sfx.play("death")
	Sfx.haptic_pattern("impact")
	Music.set_mode(Music.Mode.DEATH)
	fx.hold_time(1.0)
	var steps := [[0.15, 0.35], [0.3, 0.15], [0.6, 0.02]]
	for st in steps:
		Motion.after(st[0], func() -> void:
			if state == State.DEATH:
				fx.hold_time(st[1]))
	hud.fade_hud(0.0, Motion.SLOW, 0.3)
	hud.scrim_to(0.85, Motion.CINEMATIC, 0.3)
	Motion.after(0.9, _show_results)


func _show_results() -> void:
	if state != State.DEATH:
		return
	var prev := Prefs.record
	var is_record := Prefs.submit_score(score)
	var acc := int(round(100.0 * director.hits / maxf(1.0, director.shots)))
	_set_state(State.GAME_OVER)
	hud.show_game_over(score, prev, is_record, int(director.elapsed), acc)
	if not is_record:
		Sfx.play("lose")
	Motion.after(0.6, func() -> void: hud.locked = false)


# ---------------------------------------------------------------- scoring

func _mult() -> int:
	return 1 + mini(streak / 3, 3)


## Points fly to the counter as gold grains; every 3000 points returns a
## lost knot.
func _add_score(n: int, from := Vector2.INF) -> void:
	score += n
	hud.bar.score = score
	hud.bar.pulse = 1.0
	if from != Vector2.INF:
		fx.tokens(from, Vector2(layout.center_x, layout.score_baseline - 16.0), clampi(2 + n / 25, 2, 8))
	while score >= _next_life_at:
		_next_life_at += EXTRA_LIFE_EVERY
		if lives < LIVES:
			lives += 1
			hud.bar.lives = lives
			hud.bar.knot_shake = 1.0
			fx.popup(Loc.t("popup.extraKnot"), Vector2(layout.size.x - 90.0, layout.top_bar_h + 40.0), Pal.INK, 18)
			Sfx.play("clear", 1.1)
			Sfx.haptic(25, 0.5)


func _mark_hit(b: Ball) -> void:
	if _shots.has(b.shot_id):
		_shots[b.shot_id].hit = true


## A ball left play; once every ball of its release is gone the shot is
## scored as a hit (streak grows) or a miss (streak resets).
func _finish_ball(b: Ball) -> void:
	b.stop()
	if not _shots.has(b.shot_id):
		return
	var s: Dictionary = _shots[b.shot_id]
	s.balls -= 1
	if s.balls > 0:
		return
	_shots.erase(b.shot_id)
	if state != State.PLAYING and state != State.STARTING:
		return
	director.record_shot(s.hit)
	if s.hit:
		streak += 1
		best_streak = maxi(best_streak, streak)
		if streak % 5 == 0:
			_grant(Ammo.TRIPLE)
			fx.popup(Loc.t("popup.streak") % streak + " · " + Loc.t("popup.triple"), Vector2(layout.center_x, layout.fork_y - 110.0), Pal.GOLD, 18)
			Sfx.play("streak")
			Sfx.haptic(16, 0.4)
	else:
		streak = 0
	hud.bar.streak = streak
	hud.bar.set_mult(_mult())


func _grant(kind: int) -> void:
	if ammo.size() >= AMMO_CAP:
		ammo[mini(1, ammo.size() - 1)] = kind
	elif ammo.is_empty():
		ammo.append(kind)
	else:
		ammo.insert(1, kind)


func _update_ammo(delta: float) -> void:
	if ammo.size() < AMMO_CAP and state != State.DEATH and state != State.GAME_OVER:
		reload_t += delta
		if reload_t >= director.reload_time():
			reload_t = 0.0
			ammo.append(Ammo.NORMAL)
	else:
		reload_t = 0.0
	slingshot.set_ammo(ammo, reload_t / director.reload_time())


func _on_launched(pos: Vector2, vel: Vector2, kind: int) -> void:
	if ammo.is_empty():
		return
	ammo.pop_front()
	_shot_seq += 1
	var dirs: Array[float] = [0.0]
	if kind == Ammo.TRIPLE:
		dirs = [-TRIPLE_SPREAD, 0.0, TRIPLE_SPREAD]
	var fired := 0
	for a in dirs:
		for b in balls:
			if not b.active:
				b.fire(pos, vel.rotated(a), kind == Ammo.PIERCE, _shot_seq)
				fired += 1
				break
	_shots[_shot_seq] = {"balls": fired, "hit": false}
	if state == State.MAIN_MENU:
		_start_run()


# ---------------------------------------------------------------- system

## Pause: gameplay stops at once (tree paused), the presentation follows.
func _pause() -> void:
	if state != State.PLAYING and state != State.STARTING:
		return
	_set_state(State.PAUSED)
	get_tree().paused = true
	fx.hold_time(1.0)
	slingshot.cancel()
	_touch = -1
	hud.open_pause()
	Music.set_mode(Music.Mode.PAUSE)
	Sfx.play("pause")
	Sfx.haptic_pattern("soft")


## Resume: menu out, a 3-2-1 over the dimmed field, then play.
func _resume() -> void:
	if state != State.PAUSED:
		return
	_set_state(State.RESUMING)
	hud.locked = true
	hud.close_pause()
	Sfx.play("resume")
	Sfx.haptic_pattern("soft")
	hud.countdown(func() -> void:
		if state != State.RESUMING:
			return
		get_tree().paused = false
		fx.release_time()
		_set_state(State.PLAYING)
		Music.set_mode(Music.Mode.PLAY)
		hud.locked = false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if not is_inside_tree():
				return
			if state == State.PLAYING or state == State.STARTING:
				_pause()
			elif state == State.RESUMING:
				# Backgrounded mid-countdown: fall back to the pause menu.
				_set_state(State.PLAYING)
				_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			match state:
				State.INTRO:
					hud.intro_seq.skip()
				State.MAIN_MENU:
					get_tree().quit()
				State.GAME_OVER:
					if not hud.locked:
						_to_menu()
				State.PAUSED:
					if not hud.locked:
						_resume()
				State.PLAYING, State.STARTING:
					_pause()


const DOUBLE_TAP := 0.3        # s between taps
const DOUBLE_TAP_SLOP := 90.0  # px between taps

func _unhandled_input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	var aim_ok := state == State.MAIN_MENU or state == State.STARTING or state == State.PLAYING
	if not aim_ok:
		return
	if e is InputEventScreenTouch:
		var in_aim_zone: bool = e.position.y > layout.danger_y - 40.0
		if e.pressed and _touch == -1 and in_aim_zone:
			if slingshot.begin_aim():
				_touch = e.index
				_origin = e.position
			elif _deny_cd <= _time:
				# No ball loaded: a short "not yet" instead of silence.
				_deny_cd = _time + 0.5
				Sfx.play("deny")
				Sfx.haptic_pattern("error")
		elif not e.pressed and e.index == _touch:
			_touch = -1
			slingshot.release()
		elif e.pressed and not in_aim_zone and e.position.y > layout.top_bar_h and state != State.MAIN_MENU:
			# Double-tap on the open field pauses. Taps there never aim, so
			# this can't collide with shooting.
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_tap < DOUBLE_TAP and e.position.distance_to(_last_tap_pos) < DOUBLE_TAP_SLOP and _touch == -1:
				_last_tap = -10.0
				_pause()
			else:
				_last_tap = now
				_last_tap_pos = e.position
	elif e is InputEventScreenDrag and e.index == _touch:
		slingshot.drag(e.position - _origin)
