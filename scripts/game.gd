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
const RESCUE := 0.85           # ... and above this, a rescue ("SAVED!")
# Hazards: from wave 3 most waves bring one event partway through.
enum Hazard { NONE, GUST, BLACKOUT, GOLD }
const HAZARD_FROM := 3
const GUST_TIME := 9.0
const GUST_ACC := 160.0         # px/s² at full strength (targets; balls feel a share)
const GUST_BALL := 0.6
const BLACKOUT_TIME := 8.0
const GOLD_BONUS := 400
# Nemesis: the target that took a knot returns 18-30 s of play later,
# scarred and tougher; destroying it pays revenge.
const NEMESIS_BACK := Vector2(18.0, 30.0)
const REVENGE := 300
# Pendulum hit: a target struck as it swings fast through the bottom of its arc.
const SWING_ANGLE := 0.14
const SWING_SPEED := 150.0
# Acrobatics: from ACRO_WAVE a low, exposed target now and then swings over
# to a neighbour's rope, and a friend may catch one whose rope was cut.
const ACRO_WAVE := 5
const ACRO_EVERY := Vector2(8.0, 13.0)
const RESCUE_CHANCE := 0.4
const ACRO_KINDS := [Target.Kind.RING, Target.Kind.SPLIT, Target.Kind.DROP, Target.Kind.SHADE, Target.Kind.MEDIC, Target.Kind.REEL]
const MAX_MINIONS := 3
const TRIPLE_SPREAD := 0.1
const Ammo := Slingshot.Ammo
# Overload: kills and skill shots build tension (the gold inlay along the
# rail); misses and breaches bleed it. Full, it discharges for
# OVERLOAD_TIME real seconds: time slows, every ball pierces, reloads are
# near instant, the targets panic and climb their strings, points double.
const OVERLOAD_TIME := 5.0
const OVERLOAD_SCALE := 0.7
const OVERLOAD_RELOAD := 0.3   # reload time factor while it lasts
const CHARGE_KILL := 0.03
# Flow: quick hits fill a meter; full, the run speeds up for a while.
const FLOW_TIME := 7.0          # real seconds
const FLOW_HIT := 0.12
const FLOW_KILL := 0.2
const FLOW_MISS := 0.3
const FLOW_DECAY := 0.1         # per second while not flowing
const FLOW_RELOAD := 1.4        # reload speed factor while it lasts
const CHARGE_MISS := 0.05
const CHARGE_BREACH := 0.35
# Skill shots: named, paid and voiced (a short phrase up the note ladder).
enum Skill { BANK, LONG, DOUBLE, CUT, CLUTCH, CHAIN, BREAK, AIR, SWING }
const SKILL_KEY := ["skill.bank", "skill.long", "skill.double", "skill.cut", "skill.clutch", "skill.chain", "skill.break", "skill.air", "skill.swing"]
const SKILL_POINTS := [40, 40, 60, 50, 50, 60, 80, 70, 50]
const SKILL_CHARGE := [0.1, 0.09, 0.1, 0.12, 0.1, 0.14, 0.12, 0.12, 0.1]
const SKILL_NOTES := [[3, 4], [0, 3, 4], [2, 3, 4, 5], [4, 7], [0, 2, 3, 4], [4, 5, 6, 7, 8], [2, 4, 5, 7], [1, 3, 5, 8], [4, 2, 4, 7]]
const LONG_FLIGHT := 0.85      # s in the air before the kill: a long shot
# Chain reactions: a falling body this fast knocks off what it lands on; a
# freshly struck target slamming a neighbour this hard hurts it.
const CRUSH_SPEED := 220.0
const KNOCK_SPEED := 240.0

var layout: Layout
var director := Director.new()
var state := State.BOOT
var score := 0
var lives := LIVES
var streak := 0
var best_streak := 0
var cuts := 0
var charge := 0.0               # 0..1 tension toward overload
var overload_t := 0.0           # real seconds of overload left
var flow := 0.0                 # 0..1: the meter, or what is left of flow
var flow_t := 0.0               # real seconds of flow left
var flows := 0                  # flow streaks this run
var perks := {}                 # upgrades picked this run: id -> level
var _perk_pending := false      # a wave was cleared; the cards are coming
var _aim_start := -1.0          # game time the current pull began
var _release_hold := -1.0       # how long the last pull was held
var _tactic_told := 0
var _rhythm_told := false
var _plunge_t := 12.0
var _close_danger := 0.0        # how close the last killed target was to the line
var _hazard := Hazard.NONE
var _last_hazard := Hazard.NONE
var _hazard_in := -1.0          # until the scheduled hazard starts
var _hazard_t := 0.0            # time into the active hazard
var _hazard_on := false
var gust := 0.0
var _gust_dir := 1.0
var _gust_whoosh := 0.0
var _dark := 0.0
var _evolve_told := false
var _acro_t := 8.0
var _acro_told := false
var _nemesis_kind := -1         # the kind that got through, waiting to return
var _nemesis_lv := 0
var _nemesis_in := -1.0
var revenges := 0
var overloads := 0
var skill_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var waves_cleared := 0
var ammo: Array[int] = []       # index 0 is loaded
var reload_t := 0.0

var world: Node2D
var rail: Rail
var title: TitleLetters
var slingshot: Slingshot
var hud: Hud
var fx: Fx
var backdrop: Backdrop
var stage: MenuStage
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
var _heat := 0.0                # overload's warm vignette, eased
var _habit_told := false
var _last_kill := Vector2.ZERO
var _cocky_t := 0.0             # after a breach the survivors get cocky
var daily := false              # this run is the daily challenge
var run_kills := 0
var _missions_done: Array = []  # lines of the missions finished this run
var _mission_slots: Array = []  # slots already paid this run
var _mission_t := 0.0
# Tilt parallax: the phone's lean (relative to how it is usually held)
# shifts the world a few px against the wall behind it.
const TILT_PX := 18.0
var _tilt := Vector2.ZERO
var _tilt_ref := Vector2.ZERO
var _tilt_seen := false
var _gyro := Vector2.ZERO       # integrated rotation (rad), easing back to 0
# The lean also pushes the hanging bodies: sideways it swings them left or
# right like gravity tipping, forward/back it swings them toward or away
# from the camera. From the lean itself (which fades as the phone settles)
# and a kick from how fast it changes, so a quick flick sets them rocking.
const PUSH_X := 220.0           # px/s² per unit of lean
const PUSH_KICK := 40.0         # ... per unit/s of change
var _push := Vector2.ZERO
var _tilt_prev := Vector2.ZERO
# A quick downward move of the phone (linear acceleration along the
# screen's vertical, gravity removed) jolts the rail: some targets take
# fright and climb. Whichever direction peaks first decides the move.
const JOLT_ACC := 3.2           # m/s²
var _jolt_t := 0.0              # window after a peak, and cooldown
var _jolt_cd := 0.0


func _ready() -> void:
	_rng.randomize()
	layout = Layout.compute(get_viewport())
	backdrop = Backdrop.new()
	add_child(backdrop)
	stage = MenuStage.new()
	add_child(stage)
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
	# Shock rings refract the world (not the HUD); hidden while none are live.
	var shock_layer := CanvasLayer.new()
	shock_layer.layer = 4
	add_child(shock_layer)
	var shock := ColorRect.new()
	shock.set_anchors_preset(Control.PRESET_FULL_RECT)
	shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://shaders/shockwave.gdshader")
	shock.material = smat
	shock.visible = false
	shock_layer.add_child(shock)
	fx.shock_rect = shock
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
	mat.set_shader_parameter("tint", Pal.GOLD)
	vignette_layer.add_child(vignette)
	hud = Hud.new()
	add_child(hud)
	fx.font = hud.caps_font()
	slingshot.launched.connect(_on_launched)
	hud.perks.chosen.connect(_on_perk)
	title.caught.connect(_on_letter_caught)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_to_menu)
	get_viewport().size_changed.connect(_on_resize)
	_apply_layout()
	_boot()


func _apply_layout() -> void:
	rail.setup(layout, targets)
	backdrop.setup(layout)
	backdrop.targets = targets
	fx.l = layout
	(fx.shock_rect.material as ShaderMaterial).set_shader_parameter("size", layout.size)
	slingshot.setup(layout)
	hud.setup(layout)
	stage.setup(layout)
	var ry := hud.menu_record_y()
	stage.avoid = Rect2(layout.size.x * 0.16, ry - 150.0, layout.size.x * 0.68, layout.fork_y - ry + 60.0)


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
	perks.clear()
	_perk_pending = false
	hud.perks.visible = false
	_apply_perks()
	ammo.clear()
	for i in _ammo_cap():
		ammo.append(Ammo.NORMAL)
	reload_t = 0.0
	slingshot.cancel()
	_touch = -1
	_tension = 0.0
	_end_overload(true)
	_end_flow(true)
	flow = 0.0
	_end_hazard()
	charge = 0.0
	rail.charge = 0.0
	_heat = 0.0
	Music.danger = 0.0
	Target.morale = 0.0
	_cocky_t = 0.0
	_vignette.set_shader_parameter("strength", 0.55)
	_vignette.set_shader_parameter("glow", 0.0)


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
	# The title falls in on its strings and the dark comes alive.
	title.setup(layout, hud.display_font(), true)
	stage.avoid_pts = title.rest_points()
	stage.show_stage(1.4 if not from_game else 0.8)
	hud.show_menu()
	Music.set_mode(Music.Mode.MENU)
	Motion.after(Motion.NORMAL, func() -> void: hud.locked = false)


## First release on the menu starts a run: the letters' strings snap, the
## HUD comes in piece by piece and the first row hangs in.
func _start_run() -> void:
	_set_state(State.STARTING)
	# The daily challenge: the same spawn sequence for everyone that day.
	daily = hud.daily
	if daily:
		_rng.seed = Meta.today()
		seed(Meta.today())
	else:
		_rng.randomize()
		randomize()
	run_kills = 0
	# Each run starts in its own theme (the daily one is the same for all).
	Pal.set_theme(_rng.randi() % Pal.THEMES.size(), true)
	_missions_done = []
	_mission_slots = []
	_mission_t = 0.0
	score = 0
	lives = LIVES
	streak = 0
	best_streak = 0
	cuts = 0
	charge = 0.0
	rail.charge = 0.0
	overloads = 0
	skill_counts = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	waves_cleared = 0
	_habit_told = false
	_tactic_told = 0
	flows = 0
	_evolve_told = false
	_acro_told = false
	_nemesis_kind = -1
	_nemesis_lv = 0
	_nemesis_in = -1.0
	revenges = 0
	_acro_t = 8.0
	_last_hazard = Hazard.NONE
	_rhythm_told = false
	_plunge_t = 12.0
	_chain = 0
	_chain_t = 0.0
	_next_life_at = EXTRA_LIFE_EVERY
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
	_menu_exit()
	# No pause button: the first few runs say how to pause instead.
	Prefs.runs += 1
	Prefs.save()
	hud.card(Loc.t("event.survive"), Loc.t("pause.hint") if Prefs.runs <= 3 else Loc.t("event.surviveSub"))
	_spawn_formation(Target.Kind.RING, 4)
	Music.set_mode(Music.Mode.PLAY)
	Motion.after(0.5, func() -> void:
		if state == State.STARTING:
			_set_state(State.PLAYING))


## A title letter's string snapped taut as it fell in: a puff of dust at
## the knot, the rail flexes; the gold one lands with a flash and a ring.
func _on_letter_caught(_i: int, pos: Vector2, gold: bool) -> void:
	var knot := pos + Vector2(0, -TitleLetters.FS * 0.62)
	fx.puff(knot, Pal.INK, 3, 16.0, 0.12)
	rail.flex(pos.x, 5.0 if gold else 3.0)
	if gold:
		fx.flash(pos, 60.0, Pal.GOLD_LIGHT)
		fx.ring(pos, Pal.GOLD, 70.0)
		Sfx.haptic(18, 0.4)


## Leaving the menu for a run: the watchers rush the camera, the light goes
## out and a spark of light runs along the rail from left to right.
func _menu_exit() -> void:
	if not stage.visible:
		return
	stage.rush()
	Sfx.play("whoosh", 0.8, -2.0)
	for i in 7:
		var x := layout.size.x * (0.06 + i * 0.147)
		fx.after(0.04 * i, func() -> void:
			fx.flash(Vector2(x, layout.rail_y), 26.0, Pal.GOLD_LIGHT)
			rail.flex(x, 2.0))


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
	# Aggression first: the temperament is rolled from it at spawn.
	t.aggression = director.aggression()
	t.spawn(kind, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * frac, 0.0)
	_maybe_intro(t)
	director.count_spawn()
	return t


## A row of identical targets in a shallow V, dropping in left to right.
## Rows of five or more march behind a crowned leader in the middle: it
## dodges for all of them. Bring it down and the rest panic.
func _spawn_formation(kind: Target.Kind, n: int) -> void:
	var usable := layout.size.x - 120.0
	var row: Array[Target] = []
	for i in n:
		var t := _free_target()
		if t == null:
			break
		var x := 60.0 + (i + 0.5) * usable / n
		var v := absf(i - (n - 1) * 0.5) / maxf(1.0, (n - 1) * 0.5)
		t.aggression = director.aggression()
		t.spawn(kind, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * (0.2 - 0.1 * v), 0.15 + i * 0.09)
		_maybe_intro(t)
		row.append(t)
	director.count_spawn(row.size())
	if row.size() >= 5:
		var lead := row[row.size() / 2]
		lead.is_leader = true
		lead.aggression = minf(1.0, lead.aggression + 0.15)
		for t in row:
			if t != lead:
				t.leader = lead
				t.form_off = t.anchor.x - lead.anchor.x


func _spawn_boss() -> void:
	var t := _free_target()
	if t == null:
		return
	t.aggression = director.aggression()
	t.spawn(Target.Kind.BOSS, Vector2(layout.center_x, layout.rail_y + 3.0), 12.0, layout.play_h * 0.22, 0.3)
	_maybe_intro(t)
	director.count_spawn(3)


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
		# They have learned your habits: the side you favour gets fewer.
		var side := (x - layout.center_x) / (usable * 0.5)
		d = minf(d, 1000.0) * (1.0 - 0.5 * clampf(director.side_bias * side, 0.0, 1.0))
		# ... and once they know your rhythm, they come where you rarely shoot.
		if director.tactic() >= Director.Tactic.RHYTHM:
			d *= 1.0 - 0.5 * director.heat_at(x / layout.size.x)
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
	Pal.theme_tick(delta / maxf(Engine.time_scale, 0.001))
	_update_tilt(delta)
	_update_ammo(delta)
	_update_eyes()
	# Menu: new players (and anyone idle for a while) see how to shoot.
	slingshot.demo = state == State.MAIN_MENU and _touch == -1 and (Prefs.runs < 3 or _state_t > 6.0) and not hud.modal_open()
	stage.look = slingshot.pouch
	stage.tense = slingshot.power if slingshot.is_aiming() else 0.0
	if state == State.PLAYING or state == State.STARTING:
		_run_intros()
		_overload_tick(delta)
		_flow_tick(delta)
		_learn_tick()
		_hazard_tick(delta)
		_acro_tick(delta)
		_nemesis_tick(delta)
		_pace(delta)
		_spawn_minions()
		_medic_work()
		_boss_stages()
		Music.intensity = clampf(director.intensity() / 5.0, 0.0, 1.0)


## Where gravity points in the phone's frame (m/s²): the smoothed gravity
## sensor where there is one, else the raw accelerometer. Zero without.
static func sensor_gravity() -> Vector3:
	var g := Input.get_gravity()
	if g.length() < 2.0:
		g = Input.get_accelerometer()
	return g if g.length() >= 2.0 else Vector3.ZERO


## Reads the gravity sensor. The reference follows the phone's resting
## angle over several seconds, so only a fresh lean moves the view; while
## aiming the view holds still. Off in settings or without a sensor.
func _update_tilt(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	var sg := sensor_gravity()
	var want := Vector2.ZERO
	# Its own switch in settings (reduced motion no longer turns it off).
	var on := Prefs.tilt
	if sg != Vector3.ZERO and on:
		var g := Vector2(sg.x, sg.y) / 9.81
		if not _tilt_seen:
			_tilt_seen = true
			_tilt_ref = g
		_tilt_ref = _tilt_ref.lerp(g, 1.0 - exp(-rd / 6.0))
		want = (g - _tilt_ref) * 5.0
	# Gyroscope (rad/s): turns about the phone's upright axis (y) and its
	# left-right axis (x), integrated and eased back to centre over ~2 s.
	# Quicker than gravity, and it also sees a turn with no lean at all.
	var gy := Input.get_gyroscope()
	if on and gy.length() > 0.0005:
		_gyro += Vector2(-gy.y, -gy.x) * rd
		_gyro *= exp(-rd / 2.0)
		want += Vector2(_gyro.x, -_gyro.y) * 2.6
	else:
		_gyro = Vector2.ZERO
	want = want.limit_length(1.0)
	if slingshot.is_aiming():
		want = _tilt
	_tilt = _tilt.lerp(want, Pal.damp(0.12, rd))
	var rate := (_tilt - _tilt_prev) / maxf(rd, 0.001)
	_tilt_prev = _tilt
	_push = (_tilt * PUSH_X + rate * PUSH_KICK).limit_length(650.0) * layout.scale
	Target.push_z = _push.y / PUSH_X
	title.push = _push.x
	_read_jolt(rd, on)
	var v := Vector2(-_tilt.x, _tilt.y) * TILT_PX * layout.scale
	fx.view = v
	backdrop.view = v
	stage.view = v
	var lean := Vector2(-_tilt.x, _tilt.y)
	Target.set_view(lean)
	slingshot.set_view(lean)


## Linear acceleration = accelerometer − gravity. A drop of the phone
## starts with the screen's "up" axis accelerating downward (negative y in
## the phone's frame). One jolt per 1.5 s at most.
func _read_jolt(rd: float, on: bool) -> void:
	_jolt_cd = maxf(0.0, _jolt_cd - rd)
	if not on or _jolt_cd > 0.0 or slingshot.is_aiming():
		return
	var grav := Input.get_gravity()
	if grav.length() < 2.0:
		return
	var lin := Input.get_accelerometer() - grav
	if lin.y < -JOLT_ACC:
		_jolt_cd = 1.5
		_jolt()
	elif lin.y > JOLT_ACC:
		# The phone went up (or stopped a drop): no jolt, and ignore the
		# rebound of this same motion.
		_jolt_cd = 0.4


func _jolt() -> void:
	if state != State.PLAYING and state != State.STARTING:
		return
	rail.flex(layout.center_x, 3.0)
	var climbed := 0
	var choice := {}
	for t in targets:
		if not t.is_hittable():
			continue
		var decide := t
		if t.leader != null and is_instance_valid(t.leader):
			decide = t.leader
		var id := decide.get_instance_id()
		if not choice.has(id):
			choice[id] = decide.wants_climb(_rng.randf())
		if choice[id]:
			t.jolt(layout.scale)
			climbed += 1
		elif t.temper == Target.Temper.BOLD:
			t.taunt()
	if climbed > 0:
		Sfx.play("reel", 1.15, -4.0)
		Sfx.haptic(12, 0.3)


## The endless pacing: regular spawns under a rising cap, events with a
## card each, rush drops, chains timing out, phase changes and the
## heartbeat when a target is close to the line.
func _pace(delta: float) -> void:
	director.tick(delta)
	_wave_tick(delta)
	_spawn_t -= delta
	if director.wave_state == Director.Wave.SPAWNING:
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
	hud.bar.phase = director.wave
	hud.bar.progress = director.wave_progress()
	_mission_t -= delta
	if _mission_t <= 0.0:
		_mission_t = 0.5
		_check_missions()
	if not _habit_told and director.shots >= 12 and absf(director.side_bias) > Director.HABIT_TELL:
		# Say it once: the smarter spawns should be felt, and understood.
		_habit_told = true
		fx.popup(Loc.t("habit.right" if director.side_bias > 0.0 else "habit.left"), Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.3), Pal.CORAL, 16)
		Sfx.play("tease", 0.9, -4.0)
	# Tension: the vignette closes in a little while a target is near the line.
	var want := clampf(backdrop.danger, 0.0, 1.0)
	_tension = lerpf(_tension, want, Pal.damp(0.05, delta))
	Music.danger = _tension
	# The team's nerve: shooting well makes them sweat; a breach (or a run
	# of misses) makes them cocky for a while.
	_cocky_t = maxf(0.0, _cocky_t - delta)
	var nerve := (director.accuracy - 0.55) * 2.2 + minf(streak, 12) * 0.06
	if _cocky_t > 0.0:
		nerve = minf(nerve, -0.7)
	Target.morale = lerpf(Target.morale, clampf(nerve, -1.0, 1.0), Pal.damp(0.02, delta))
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_heat = lerpf(_heat, 1.0 if overload_t > 0.0 else 0.0, Pal.damp(0.12, rd))
	_vignette.set_shader_parameter("strength", lerpf(0.55, 0.78, _tension))
	_vignette.set_shader_parameter("glow", _heat * (0.22 + 0.05 * sin(_time * 9.0)))
	if backdrop.danger > 0.7:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = lerpf(0.85, 0.5, backdrop.danger)
			Sfx.play("beat")
			Sfx.haptic(8, 0.15)
	else:
		_beat_t = 0.0


## This run so far, in the terms missions and lifetime stats use.
func _run_stats() -> Dictionary:
	return {
		"kills": run_kills, "score": score, "wave": director.wave, "overloads": overloads,
		"bank": skill_counts[Skill.BANK], "chain": skill_counts[Skill.CHAIN], "cuts": cuts,
		"double": skill_counts[Skill.DOUBLE], "break": skill_counts[Skill.BREAK],
		"secs": int(director.elapsed), "shots": director.shots, "hits": director.hits,
	}


## A mission reached mid-run pays at once and says so; its slot takes the
## next, harder one (shown in the menu, not chased in this run).
func _check_missions() -> void:
	var run := _run_stats()
	for i in Prefs.missions.size():
		if _mission_slots.has(i):
			continue
		var m: Dictionary = Prefs.missions[i]
		if Meta.progress(m.id, run) < Meta.goal(m.id, int(m.level)):
			continue
		var line := Meta.describe(m.id, int(m.level))
		var pay := Prefs.complete_mission(i)
		_mission_slots.append(i)
		_missions_done.append(line)
		fx.popup("%s  +%s" % [Loc.t("mission.done"), Hud._group(pay)], Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.2), Pal.GOLD_LIGHT, 20, true)
		Sfx.phrase([4, 5, 6, 7], 0.06, -3.0)
		Sfx.haptic_pattern("record")


## Wave flow: spawning until the quota is out, then clearing (the last few
## hurry down, shaking), a clear bonus, a short break and the next wave.
func _wave_tick(delta: float) -> void:
	match director.wave_state:
		Director.Wave.CLEARING:
			var alive := _alive_count()
			var last := alive <= Director.HURRY_AT
			for t in targets:
				t.hurry = last and t.is_hittable() and t.kind != Target.Kind.BOSS
			if alive == 0 and _rush_left == 0:
				_clear_wave()
		Director.Wave.BREAK:
			if _perk_pending or hud.perks.visible:
				return
			director.wave_break -= delta
			if director.wave_break <= 0.0:
				director.next_wave()
				_spawn_t = 0.3
				# A new wave, a new colour theme, eased in.
				Pal.next_theme()
				fx.popup(Loc.t("hud.wave") % director.wave, Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.28), Pal.INK, 26)
				Sfx.play("streak", 0.85)
				_schedule_hazard()
				if director.wave == ACRO_WAVE and not _acro_told:
					_acro_told = true
					fx.after(0.9, func() -> void: hud.card(Loc.t("acro.title"), Loc.t("acro.sub"), 2.2))
				var tac := director.tactic()
				if tac > _tactic_told:
					_tactic_told = tac
					fx.after(0.9, func() -> void: _announce_tactic(tac))


func _clear_wave() -> void:
	waves_cleared += 1
	var bonus := (100 + 50 * director.wave) * _mult() * _surge()
	var mid := Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.46)
	_add_score(bonus, mid)
	hud.card(Loc.t("wave.clear") % director.wave, "+" + Hud._group(bonus))
	fx.shock(mid, 8.0, 380.0, 0.6)
	# Final-kill camera: widescreen bars close in, the camera leans in on
	# the last one and time all but stops, then the next wave breaks loose.
	var calm := Prefs.reduced_motion
	hud.cinematic(0.9)
	fx.focus(_last_kill, 0.05 if calm else 0.1, 1.4)
	fx.aberrate(2.0 if calm else 4.0)
	fx.slowmo(0.4 if calm else 0.2, 0.5 if calm else 0.8)
	Music.duck(6.0, 0.9)
	Sfx.play("burst", 0.55, -2.0)
	Sfx.play("clear")
	Sfx.phrase([0, 2, 3, 4, 7], 0.09, -2.0)
	Sfx.haptic_pattern("record")
	_charge(0.12)
	director.end_wave()
	_perk_pending = true
	fx.after(1.3, _offer_perks)


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
		t.field_w = layout.size.x
		if t.trait_kind == Target.Trait.CURIOUS and t.is_hittable():
			# Curious ones keep glancing at a neighbour.
			t.curious_in -= get_process_delta_time()
			if t.curious_in <= 0.0:
				t.curious_in = _rng.randf_range(2.0, 4.5)
				var near: Target = null
				var nd := 300.0 * layout.scale
				for n in targets:
					if n != t and n.is_hittable() and n.pos.distance_to(t.pos) < nd and _rng.randf() < 0.6:
						near = n
						nd = n.pos.distance_to(t.pos)
				if near:
					t.watch(near, 0.8)
		if t.landed:
			# A new arrival: the neighbours turn to look.
			t.landed = false
			for n in targets:
				if n != t and n.is_hittable() and n.pos.distance_to(t.pos) < 240.0 * layout.scale:
					n.watch(t, 0.7)
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
		t.covered = false
		if t.guard_of != null and (not is_instance_valid(t.guard_of) or not t.guard_of.is_hittable() or not t.guard_of.aimed):
			t.guard_of = null
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
	_guard_allies(path)
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


## Teamwork: when you aim at a smaller enemy, a sturdy neighbour (Tungvekt
## or Vokter) that hangs lower, i.e. between it and you, slides into the
## shot line to take the hit; the one it shields trusts it and holds still.
## A dashed link shows the pairing for a moment so it can be read.
func _guard_allies(path: PackedVector2Array) -> void:
	if path.is_empty():
		return
	for t in targets:
		if not t.aimed or t.kind in Target.GUARD_KINDS or t.kind == Target.Kind.BOSS:
			continue
		for g in targets:
			if g == t or not (g.kind in Target.GUARD_KINDS) or not g.is_hittable():
				continue
			if g.guard_of == t:
				t.covered = true
				break
			if g.guard_of != null:
				continue
			if g.pos.y < t.pos.y + 25.0:
				continue
			var x := _path_x_at(path, g.pos.y)
			if is_nan(x):
				continue
			var off := x - g.pos.x
			if absf(off) > 190.0 * layout.scale:
				continue
			var ax := g.anchor.x + off
			if ax < g.slide_lo - 2.0 or ax > g.slide_hi + 2.0:
				continue
			if absf(off) < g.radius * 0.5 or g.guard(x, t):
				t.covered = true
				fx.link(g.pos, t.pos, g.color())
				break
	for g in targets:
		if g.guard_of != null and is_instance_valid(g.guard_of):
			g.look_at = g.guard_of.pos
			g.has_look = true


## Where the predicted shot crosses height `y` (NaN if it never does).
func _path_x_at(path: PackedVector2Array, y: float) -> float:
	var prev := layout.pouch_rest()
	for p in path:
		if (prev.y - y) * (p.y - y) <= 0.0 and prev.y != p.y:
			return lerpf(prev.x, p.x, (y - prev.y) / (p.y - prev.y))
		prev = p
	return NAN


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
			t.wind = _breeze(t.pos.x) + _push.x + gust
			t.step(dt, descent, layout.danger_y, band, layout.size.y)
			if t.phase == Target.Phase.HANGING:
				worst = maxf(worst, t.danger)
	backdrop.danger = worst
	backdrop.descent = descent
	_target_contacts()
	if state == State.PLAYING or state == State.STARTING:
		_falling_contacts()
	slingshot.step(dt)
	for b in balls:
		if not b.active:
			continue
		b.vel.x += gust * GUST_BALL * dt
		if perk("magnet") > 0:
			_magnet(b, dt)
		if not b.step(dt, layout):
			_finish_ball(b)
			continue
		if stage.visible:
			stage.flinch(b.pos)
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
			# Billiards: a target sent flying by a hit takes a neighbour with it.
			if closing > KNOCK_SPEED * layout.scale and (a.struck_t > 0.0 or c.struck_t > 0.0) and (state == State.PLAYING or state == State.STARTING):
				var striker := a if a.struck_t >= c.struck_t else c
				var victim := c if striker == a else a
				striker.struck_t = 0.0
				var dir := nrm if striker == a else -nrm
				_chain_hit(victim, dir * j_imp * 0.5, contact, closing, striker.chain_depth + 1)
				continue
			if closing > 140.0 and _knock_sfx_cd <= 0.0:
				_knock_sfx_cd = 0.08
				Sfx.play("knock", randf_range(0.9, 1.1), linear_to_db(clampf(closing / 600.0, 0.15, 0.7)))
				Sfx.haptic(6, 0.2)


## A killed shell or a cut target falls; whatever still hangs in its way is
## knocked off its string (or loses a point of health) and falls in turn.
func _falling_contacts() -> void:
	var min_speed := CRUSH_SPEED * layout.scale
	for f in targets:
		if not f.is_crushing(min_speed):
			continue
		for t in targets:
			if t == f or not t.is_solid() or f.crushed.has(t.get_instance_id()):
				continue
			var cp := t.closest_point(f.pos)
			var rr := f.contact_radius() * 0.85 + (t.radius if t.kind != Target.Kind.ROD else t.radius * 0.6)
			if f.pos.distance_squared_to(cp) >= rr * rr:
				continue
			f.crushed.append(t.get_instance_id())
			var n := (cp - f.pos).normalized()
			var closing := (f.vel - t.vel).dot(n)
			if closing < min_speed * 0.6:
				continue
			# The faller gives up much of its speed and glances off.
			f.vel -= n * closing * 0.6
			f.spin *= -0.6
			_chain_hit(t, n * closing * f.mass() * 0.9, cp - n * t.radius * 0.5, closing, f.chain_depth + 1)


## A target struck by another body, not by a ball: scored like a hit, and a
## kill is a chain reaction (deeper links pay more).
func _chain_hit(t: Target, impulse: Vector2, contact: Vector2, closing: float, depth: int) -> void:
	if t.patched:
		_pop_bubble(t, contact)
		return
	var col := t.color()
	var at := t.pos
	var was_close := t.danger > CLOSE_CALL
	_close_danger = t.danger
	t.dent(contact, closing)
	var killed := t.hit(impulse, contact)
	t.chain_depth = depth
	var gained := t.points() * _mult() * _surge()
	if killed and t.kind == Target.Kind.BOSS:
		gained *= 5
	if killed:
		gained += _kill_bonus(t, gained)
	_add_score(gained, at)
	fx.hitstop()
	fx.flash(contact, t.radius * 0.7)
	fx.sparks(contact, col, 8)
	fx.ring(contact, col.lightened(0.15), t.radius)
	fx.popup("+%d" % gained, at + Vector2(0, -t.radius - 14.0))
	_break_fx(t, killed, col, linear_to_db(clampf(closing / 900.0, 0.3, 1.0)))
	if killed:
		_charge(CHARGE_KILL)
		_skill(Skill.CHAIN, at, depth)
		if was_close:
			_skill(Skill.CLUTCH, at)


## The leader is down (or gone): the row breaks up. Shot down, the others
## panic for a moment, wide open, and the break is a skill shot.
func _break_formation(lead: Target, scored: bool) -> void:
	lead.is_leader = false
	var n := 0
	for m in targets:
		if m.leader == lead:
			m.leader = null
			n += 1
			if scored and m.is_hittable():
				m.stun_t = 2.2
				m.startle_t = 0.4
	if scored and n > 0:
		_skill(Skill.BREAK, lead.pos)


## Legen, every few seconds: mends the nearest damaged ally, or else wraps
## the nearest one in a bubble that soaks the next blow.
func _medic_work() -> void:
	for m in targets:
		if m.kind != Target.Kind.MEDIC or not m.wants_heal:
			continue
		m.wants_heal = false
		if not m.is_hittable():
			continue
		var best: Target = null
		var best_s := INF
		for t in targets:
			if t == m or not t.is_hittable() or t.kind == Target.Kind.MEDIC or t.patched:
				continue
			var d := t.pos.distance_to(m.pos)
			if d > 300.0 * layout.scale:
				continue
			var sc := d - (400.0 if t.hp < Target.HP[t.kind] else 0.0)
			if sc < best_s:
				best_s = sc
				best = t
		if best == null:
			continue
		if best.hp < Target.HP[best.kind]:
			best.hp += 1
			fx.popup("+1", best.pos + Vector2(0, -best.radius - 14.0), Pal.MEDIC_BADGE, 18)
		else:
			best.patched = true
		fx.link(m.pos, best.pos, Pal.MEDIC_BADGE)
		m.watch(best, 1.2)
		fx.ring(best.pos, Pal.MEDIC_BADGE, best.radius + 12.0)
		Sfx.play("fade", 1.35, -6.0)


## Spinneren moving to its next stage: the old plates shatter off, a
## shockwave, and the stage is named.
func _boss_stages() -> void:
	for t in targets:
		if t.kind != Target.Kind.BOSS or not t.stage_changed:
			continue
		t.stage_changed = false
		fx.shock(t.pos, 16.0, 360.0, 0.6)
		fx.shards(t.pos, Pal.METAL_LIGHT, 5, Vector2.ZERO)
		fx.punch(0.03)
		fx.shake(2.5)
		fx.popup(Loc.t("boss.stage") % (t.boss_stage + 1), t.pos + Vector2(0, -t.radius - 40.0), Pal.CORAL, 20)
		Sfx.play("metal", 0.8)
		Sfx.play("whoosh", 0.7, -4.0)
		Sfx.haptic(40, 0.7)


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
		d.aggression = t.aggression
		d.spawn(Target.Kind.DROP, Vector2(ax, layout.rail_y + 3.0), 12.0, t.length * 0.75, 0.0)
		_maybe_intro(d)
		Sfx.play("whoosh", 1.2, -8.0)


# ---------------------------------------------------------------- hits

func _collide(b: Ball) -> void:
	var cut_speed := CUT_SPEED * layout.scale * (0.8 if perk("edge") > 0 else 1.0)
	var cut_r := 9.0 if perk("edge") > 0 else 5.0
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
		if t.kind != Target.Kind.BOSS and not b.cut_any and not b.hit_rail and b.vel.y < 0.0 and b.vel.length() > cut_speed and t.rope_hit(b.pos, cut_r):
			b.cut_any = true
			if perk("edge") > 0 or t.strike_string(b.pos):
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
		if t.kind == Target.Kind.MIRROR and not b.special and b.banks == 0 and b.hits == 0:
			_on_mirror(b, t, n, cp, rr)
		elif not b.special and t.blocks(n):
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


## Speilet: a clean shot (one that has touched nothing yet) is thrown
## straight back. The ball now counts as banked, so it can take out another.
func _on_mirror(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float) -> void:
	b.touch(t.get_instance_id())
	var res := _resolve(b, t, n, cp, rr, 1.0, 0.0)
	b.banks += 1
	var contact := b.pos - n * Ball.RADIUS
	t.push(res[0] * 0.4, contact)
	t.dent(contact, res[1])
	fx.flash(contact, 14.0)
	fx.sparks(contact, Pal.EYE, 8)
	fx.ring(contact, Pal.MIRROR, 20.0)
	fx.popup(Loc.t("popup.mirror"), contact + Vector2(0, -18), Pal.INK_DIM, 16)
	Sfx.play("clank", 1.35, -5.0)
	Sfx.note(7, -9.0)
	Sfx.haptic(10, 0.3)


## Legen's bubble takes the blow and bursts; the body underneath is fine.
func _pop_bubble(t: Target, at: Vector2) -> void:
	t.patched = false
	t.push((t.pos - at).normalized() * 60.0, at)
	fx.ring(t.pos, Pal.MEDIC_BADGE, t.radius + 14.0)
	fx.sparks(at, Pal.MEDIC_BADGE, 8)
	fx.popup(Loc.t("popup.bubble"), at + Vector2(0, -18), Pal.MEDIC_BADGE, 16)
	Sfx.play("burst", 1.45, -8.0)
	Sfx.haptic(10, 0.3)


## Armour: the ball glances off, the target rocks, nothing breaks.
func _on_block(b: Ball, t: Target, n: Vector2, cp: Vector2, rr: float) -> void:
	b.touch(t.get_instance_id())
	if t.patched:
		_resolve(b, t, n, cp, rr, SOFT_E, SOFT_MU)
		_pop_bubble(t, b.pos - n * Ball.RADIUS)
		return
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
	if t.acro == Target.Acro.FLY:
		_skill(Skill.AIR, contact)
	elif t.kind != Target.Kind.BOSS and absf(atan2(t.pos.x - t.anchor.x, t.pos.y - t.anchor.y)) < SWING_ANGLE and absf(t.vel.x) > SWING_SPEED * layout.scale:
		# Caught at the bottom of a fast swing: timing, not just aim.
		_skill(Skill.SWING, contact)
	backdrop.ripple(contact, col, clampf(closing / 1100.0, 0.35, 1.0) * (1.4 if t.hp <= 1 else 1.0))
	var was_close := t.danger > CLOSE_CALL
	_close_danger = t.danger
	var hit_at := t.pos
	if perk("heavy") > 0 and t.hp >= 2 and not b.special:
		# Heavy balls: armour takes two blows' worth.
		t.hp -= 1
	var killed := t.hit(impulse, contact)
	t.chain_depth = 0
	var gained := t.points() * b.hits * _mult() * _surge()
	if killed and kind == Target.Kind.BOSS:
		gained *= 5
	if killed:
		b.kills += 1
		gained += _kill_bonus(t, gained)
	_add_score(gained, t.pos)
	# Response: hit-stop, sparks, ring, popup, sound and haptics on every hit.
	fx.hitstop()
	fx.flash(contact, t.radius * (0.9 if killed else 0.55), col.lightened(0.4))
	if killed:
		fx.shock(t.pos, 9.0 if kind != Target.Kind.BOSS else 18.0, 170.0 if kind != Target.Kind.BOSS else 320.0)
	fx.sparks(cp, col, 10 if killed else 6)
	fx.ring(contact, col.lightened(0.15), t.radius)
	var label := "+%d" % gained
	if b.special and overload_t <= 0.0:
		label += " " + Loc.t("popup.pierce")
	elif killed and kind == Target.Kind.SPLIT:
		label += " " + Loc.t("popup.split")
	elif b.hits >= 2:
		label += " " + Loc.t("popup.combo") % b.hits
	fx.popup(label, t.pos + Vector2(0, -t.radius - 14.0))
	if b.hits >= 2:
		fx.shake(2.0 + minf(b.hits - 2, 1))
	_break_fx(t, killed, col, loud, b.hits)
	if b.hits == 2:
		_grant(Ammo.PIERCE)
	if killed:
		_charge(CHARGE_KILL * (2.0 if kind == Target.Kind.BOSS else 1.0))
		_read_skills(b, hit_at, was_close)


## Which skill shots this kill was: off a wall, after a long flight, the
## second (third...) kill of one ball, just above the line.
func _read_skills(b: Ball, at: Vector2, was_close: bool) -> void:
	if b.banks > 0 and not (b.skilled & (1 << Skill.BANK)):
		b.skilled |= 1 << Skill.BANK
		_skill(Skill.BANK, at)
	elif b.age >= LONG_FLIGHT and not (b.skilled & (1 << Skill.LONG)):
		b.skilled |= 1 << Skill.LONG
		_skill(Skill.LONG, at)
	if b.kills >= 2:
		_skill(Skill.DOUBLE, at, b.kills - 1)
	if was_close:
		_skill(Skill.CLUTCH, at)


## A named skill shot: points, a gold underlined call-out, its phrase on
## the note ladder, and a good push toward overload. `n` scales the pay
## (a triple kill is a double paid twice).
func _skill(s: Skill, at: Vector2, n := 1) -> void:
	skill_counts[s] += 1
	var pts: int = SKILL_POINTS[s] * n * _mult() * _surge()
	_add_score(pts, at)
	var text := Loc.t(SKILL_KEY[s])
	var rescue := s == Skill.CLUTCH and _close_danger >= RESCUE
	if rescue:
		# Saved at the very last moment: worth double and a moment of its own.
		text = Loc.t("skill.rescue")
		_add_score(pts, at)
		pts *= 2
	if s == Skill.DOUBLE and n >= 2:
		text = Loc.t("skill.triple") if n == 2 else Loc.t("skill.multi") % (n + 1)
	elif s == Skill.CHAIN and n >= 2:
		text += " ×%d" % n
	fx.popup("%s +%d" % [text, pts], at + Vector2(0, -64.0), Pal.GOLD_LIGHT, 24, true)
	fx.ring(at, Pal.GOLD, 48.0)
	var steps: Array = SKILL_NOTES[s].duplicate()
	if overload_t > 0.0:
		for i in steps.size():
			steps[i] += 4
	Sfx.phrase(steps, 0.075, -2.0)
	Sfx.haptic(14, 0.45)
	if rescue:
		fx.slowmo(0.25, 0.55)
		fx.focus(at, 0.08, 1.0)
		fx.aberrate(5.0)
		fx.flash(at, 80.0, Pal.GOLD_LIGHT)
		backdrop.rescue()
		Music.duck(5.0, 0.6)
		Sfx.phrase([4, 5, 6, 7], 0.07, 0.0)
		Sfx.haptic_pattern("record")
	elif s == Skill.CLUTCH:
		fx.slowmo(0.45, 0.28)
		fx.focus(at, 0.035, 0.6)
	elif (s == Skill.DOUBLE and n >= 2) or (s == Skill.CHAIN and n >= 2) or s == Skill.BREAK:
		# The rare ones get the camera and a breath of slow motion.
		fx.slowmo(0.4, 0.3)
		fx.focus(at, 0.045, 0.8)
		fx.aberrate(4.0)
		Music.duck(3.0, 0.3)
	_charge(SKILL_CHARGE[s])


# ---------------------------------------------------------------- overload

## Points double while overload lasts.
func _surge() -> int:
	return 2 if overload_t > 0.0 else 1


func _charge(v: float) -> void:
	if overload_t > 0.0 or (state != State.PLAYING and state != State.STARTING):
		return
	var was := charge
	if v > 0.0:
		v *= 1.0 + 0.3 * perk("charge")
	charge = clampf(charge + v, 0.0, 1.0)
	rail.charge = charge
	if was < 0.5 and charge >= 0.5 and Prefs.runs <= 3:
		# New players: say once what the gold in the rail is building to.
		fx.popup(Loc.t("overload.hint"), Vector2(layout.center_x, layout.rail_y + 44.0), Pal.GOLD_LIGHT, 15)
	if charge >= 1.0:
		_begin_overload()


func _begin_overload() -> void:
	overload_t = OVERLOAD_TIME
	overloads += 1
	rail.hot = true
	Ball.hot = true
	backdrop.heat = 1.0
	fx.aberrate(7.0)
	fx.set_base_time(OVERLOAD_SCALE)
	while ammo.size() < _ammo_cap():
		ammo.append(Ammo.NORMAL)
	var mid := Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.45)
	fx.shock(mid, 14.0, 560.0, 0.7)
	fx.punch(0.035)
	fx.shake(2.0)
	hud.card(Loc.t("overload.title"), Loc.t("overload.sub"))
	Music.duck(6.0, 0.8)
	hud.bar.hot = true
	_show_mult()
	Music.overload = true
	Sfx.play("rise")
	Sfx.haptic_pattern("record")


## Real time, so its own slow motion doesn't stretch it.
func _overload_tick(delta: float) -> void:
	var on := overload_t > 0.0
	for t in targets:
		t.scared = on and t.phase == Target.Phase.HANGING
	if not on:
		return
	overload_t -= delta / maxf(Engine.time_scale, 0.001)
	charge = maxf(0.0, overload_t / OVERLOAD_TIME)
	rail.charge = charge
	if overload_t <= 0.0:
		_end_overload(false)


func _end_overload(quiet: bool) -> void:
	var was := overload_t > 0.0 or rail.hot
	overload_t = 0.0
	charge = 0.0
	rail.charge = 0.0
	rail.hot = false
	Ball.hot = false
	backdrop.heat = 0.0
	hud.bar.hot = false
	Music.overload = false
	fx.set_base_time(1.0)
	for t in targets:
		t.scared = false
	_show_mult()
	if was and not quiet:
		Sfx.play("fall")


## Note ladder: each kill of a run of kills sounds one step higher (an
## octave up in overload), so a streak of kills plays a rising melody.
func _kill_note() -> void:
	Sfx.note(_chain - 1 + (4 if overload_t > 0.0 else 0), -3.0)


## What a struck target does, seen and heard: a kill bursts the jelly (after
## its squash) or shatters the shell; a survivor squishes or knocks.
func _break_fx(t: Target, killed: bool, col: Color, loud: float, hits := 1) -> void:
	var kind := t.kind
	if not killed:
		if t.soft:
			Sfx.play("squish", 30.0 / t.radius * randf_range(0.95, 1.05), loud)
		else:
			_material_knock(t, hits, loud)
		Sfx.haptic(12 if t.soft else 9, 0.3 if t.soft else 0.4)
		return
	if t.soft:
		# The jelly squashes for a moment, then bursts.
		var at := t.pos
		var rot := t.body_rot
		var r := t.radius
		fx.after(Target.POP_TIME, func() -> void:
			fx.burst(kind, at, rot, r, col, Vector2.ZERO)
			fx.puff(at, col, 2, r * 1.3, 0.32))
		# Jelly bursts wetly; the smaller it is, the higher it sounds.
		Sfx.play("splat", 30.0 / t.radius * randf_range(0.95, 1.05), loud)
		Sfx.play("squish", 1.1, loud - 6.0)
	else:
		var boss := kind == Target.Kind.BOSS
		fx.burst(kind, t.pos, t.body_rot, t.radius, col, t.vel)
		fx.shards(t.pos, col, 6 if boss else 2, t.vel)
		fx.puff(t.pos, col, 6 if boss else 2, t.radius * (1.8 if boss else 1.3), 0.32)
		Sfx.play("burst", randf_range(0.92, 1.08), loud)
		_material_knock(t, hits, loud)
	Sfx.play("snap", randf_range(0.95, 1.1), -8.0)
	Sfx.haptic(18, 0.5)
	if kind == Target.Kind.BOSS:
		fx.shake(3.0)
		fx.focus(t.pos, 0.09, 1.3)
		fx.aberrate(6.0)
		fx.slowmo(0.3, 0.6)
		Music.duck(6.0, 0.7)
		Sfx.haptic(80, 0.9)
	if kind == Target.Kind.SPLIT:
		_split(t)


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
		Target.Kind.MIRROR:
			Sfx.play("metal", p * 1.3, loud)
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
	_close_danger = t.danger
	# The rope it shares with others: all of them come down together.
	var group := _rope_group(t)
	t.cut()
	var extra := 0
	for o in group:
		o.cut()
		var og := o.points() * 2 * _mult() * _surge()
		og += _kill_bonus(o, og)
		_add_score(og, o.pos)
		extra += 1
	if extra > 0:
		_skill(Skill.DOUBLE, t.pos, extra)
	else:
		_try_rescue(t)
	var gained := t.points() * 2 * _mult() * _surge()
	gained += _kill_bonus(t, gained)
	_add_score(gained, t.pos)
	fx.hitstop()
	fx.sparks(b.pos, Pal.INK_DIM, 7)
	fx.popup("+%d" % gained, b.pos + Vector2(0, -22), Pal.INK)
	fx.shards(t.pos, col, 2, t.vel)
	Sfx.play("cut", randf_range(0.95, 1.08))
	Sfx.haptic(20, 0.5)
	_charge(CHARGE_KILL)
	_skill(Skill.CUT, b.pos)
	if was_close:
		_skill(Skill.CLUTCH, t.pos)


func _split(t: Target) -> void:
	for side: float in [-1.0, 1.0]:
		var d := _free_target()
		if d == null:
			return
		var ax := clampf(t.anchor.x + side * 38.0, 40.0, layout.size.x - 40.0)
		var p := t.pos + Vector2(side * 16.0, 0)
		var anchor := Vector2(ax, layout.rail_y + 3.0)
		var len := anchor.distance_to(p)
		d.aggression = t.aggression
		d.spawn(Target.Kind.DROP, anchor, len, len, 0.0)
		d.pos = p
		d.vel = Vector2(side * 160.0, -60.0)
		_maybe_intro(d)


## Chains (kills in quick succession) pay extra, say so, and climb the
## note ladder.
func _kill_bonus(t: Target, gained: int) -> int:
	var bonus := 0
	_chain += 1
	_chain_t = CHAIN_WINDOW
	director.count_kill()
	run_kills += 1
	# The neighbours follow the fall with their eyes; the closest flinch.
	for n in targets:
		if n != t and n.is_hittable():
			var d := n.pos.distance_to(t.pos)
			if d < 260.0 * layout.scale:
				n.watch(t, 0.9)
				if d < 120.0 * layout.scale:
					n.startle(t.pos)
				if d < 220.0 * layout.scale:
					n.scatter(t.pos)
	_last_kill = t.pos
	_flow_add(FLOW_KILL)
	if t.nemesis > 0:
		var rv := REVENGE * t.nemesis * _mult() * _surge()
		bonus += rv
		revenges += 1
		fx.popup(Loc.t("nemesis.revenge") % rv, t.pos + Vector2(0, -70.0), Pal.GOLD_LIGHT, 28, true)
		fx.flash(t.pos, 100.0, Pal.GOLD_LIGHT)
		fx.ring(t.pos, Pal.GOLD, 100.0)
		fx.focus(t.pos, 0.06, 0.8)
		fx.slowmo(0.35, 0.4)
		Sfx.phrase([0, 3, 4, 7, 8], 0.07, 0.0)
		Sfx.haptic_pattern("record")
	if t.golden:
		bonus += GOLD_BONUS * _mult() * _surge()
		fx.popup(Loc.t("gold.pop") % (GOLD_BONUS * _mult() * _surge()), t.pos + Vector2(0, -60.0), Pal.GOLD_LIGHT, 26, true)
		fx.flash(t.pos, 90.0, Pal.GOLD_LIGHT)
		fx.ring(t.pos, Pal.GOLD, 90.0)
		fx.shards(t.pos, Pal.GOLD, 8, t.vel)
		Sfx.phrase([4, 5, 6, 7, 8], 0.06, -1.0)
		Sfx.haptic_pattern("record")
		_flow_add(1.0)
	if t.is_leader:
		_break_formation(t, true)
	_kill_note()
	if _chain >= 3:
		bonus += int(gained * 0.2 * mini(_chain - 2, 6))
		fx.popup(Loc.t("popup.chain") % _chain, t.pos + Vector2(0, t.radius + 26.0), Pal.GOLD, 16)
		Sfx.play("streak", minf(1.25, 0.9 + 0.05 * _chain), -4.0)
	return bonus


## A target reached the line: a knot snaps, the rail rings, the rest of
## the field is yanked up a little as relief.
func _breach(t: Target) -> void:
	lives -= 1
	hud.bar.lose_life(lives)
	var at := Vector2(t.pos.x, layout.danger_y)
	if t.is_leader:
		_break_formation(t, false)
	# It will be back, and it will remember.
	if t.kind != Target.Kind.BOSS and not t.golden:
		_nemesis_kind = t.kind
		_nemesis_lv = maxi(_nemesis_lv, t.nemesis) + 1
		_nemesis_in = _rng.randf_range(NEMESIS_BACK.x, NEMESIS_BACK.y)
	t.cut()
	rail.flex(t.anchor.x, 9.0)
	fx.shake(3.0)
	fx.punch(0.02)
	fx.sparks(at, Pal.CORAL, 10)
	fx.ring(at, Pal.CORAL, 40.0)
	fx.puff(at, Pal.CORAL, 3, 46.0, 0.3)
	fx.shock(at, 12.0, 240.0, 0.5)
	fx.aberrate(5.0)
	fx.popup(Loc.t("popup.lifeLost"), at + Vector2(0, -30), Pal.CORAL, 20)
	Sfx.play("breach")
	Sfx.haptic(70, 0.9)
	# The ones hanging nearby enjoy it.
	for o in targets:
		if o != t and o.is_hittable() and o.pos.distance_to(t.pos) < 260.0 * layout.scale:
			o.taunt()
	streak = 0
	_chain = 0
	_cocky_t = 5.0
	hud.bar.streak = 0
	_show_mult()
	if overload_t <= 0.0:
		charge = maxf(0.0, charge - CHARGE_BREACH)
		rail.charge = charge
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
	_end_overload(true)
	_heat = 0.0
	_vignette.set_shader_parameter("glow", 0.0)
	_set_state(State.DEATH)
	hud.locked = true
	slingshot.cancel()
	_touch = -1
	fx.ring(at, Pal.CORAL, 70.0)
	fx.sparks(at, Pal.CORAL, 10)
	fx.puff(at, Pal.CORAL, 6, 90.0, 0.36)
	fx.shock(at, 20.0, 460.0, 0.8)
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
	_check_missions()
	Prefs.record_run(_run_stats())
	var prev := Prefs.daily_record() if daily else Prefs.record
	var is_record := Prefs.submit_daily(score) if daily else Prefs.submit_score(score)
	var acc := int(round(100.0 * director.hits / maxf(1.0, director.shots)))
	_set_state(State.GAME_OVER)
	var feats: Array = []
	for i in skill_counts.size():
		feats.append([SKILL_KEY[i], skill_counts[i]])
	hud.show_game_over(score, prev, is_record, int(director.elapsed), acc, feats, overloads, daily, _missions_done)
	if not is_record:
		Sfx.play("lose")
	Motion.after(0.6, func() -> void: hud.locked = false)


# ---------------------------------------------------------------- learning

## Tells the team what it knows: its tactic tier, the player's rhythm and
## the column shot at least. Says it once when the rhythm is learned.
func _learn_tick() -> void:
	var tac := director.tactic()
	Target.tactic = tac
	Target.rhythm = director.rhythm_known()
	Target.hold_avg = director.hold_avg
	Target.aim_hold = (_time - _aim_start) if _aim_start >= 0.0 and slingshot.is_aiming() else -1.0
	Target.cold_x = director.cold_u() * layout.size.x if tac >= Director.Tactic.RHYTHM else NAN
	if tac >= Director.Tactic.RHYTHM and Target.rhythm and not _rhythm_told:
		_rhythm_told = true
		fx.popup(Loc.t("habit.rhythm"), Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.3), Pal.CORAL, 16)
		Sfx.play("tease", 0.9, -4.0)
	# Teamwork: now and then the whole field plunges together on a signal.
	if tac >= Director.Tactic.TEAM and director.wave_state == Director.Wave.SPAWNING and director.breather <= 0.0 and overload_t <= 0.0:
		_plunge_t -= get_process_delta_time()
		if _plunge_t <= 0.0:
			_plunge_t = _rng.randf_range(12.0, 17.0)
			_team_plunge()


## A new tactic arrives with the wave: a card names it and says how to beat it.
func _announce_tactic(tac: int) -> void:
	if state != State.PLAYING and state != State.STARTING:
		return
	hud.card(Loc.t("tactic.%d" % tac), Loc.t("tactic.%d.sub" % tac), 2.2)
	Sfx.play("tease", 0.8, -2.0)
	Sfx.voice("taunt", 0.8, 2, -4.0)


func _team_plunge() -> void:
	var n := 0
	var drop := lerpf(40.0, 60.0, director.aggression())
	for t in targets:
		if t.is_hittable() and t.phase == Target.Phase.HANGING:
			t.order_plunge(drop, 0.75)
			n += 1
	if n >= 3:
		fx.popup(Loc.t("team.plunge"), Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.36), Pal.CORAL, 18)
		Sfx.voice("taunt", 0.7, 0, -2.0)
		Sfx.haptic(14, 0.3)


## Where a shot will cross the middle of the field, 0..1 across (walls
## fold it back, as they bounce the ball).
func _cross_u(p: Vector2, v: Vector2) -> float:
	var y := layout.rail_y + layout.play_h * 0.45
	var dy := y - p.y
	var g := Ball.GRAVITY
	var disc := v.y * v.y + 2.0 * g * dy
	var t := 0.6
	if disc >= 0.0:
		t = (-v.y - sqrt(disc)) / g
		if t <= 0.0:
			t = (-v.y + sqrt(disc)) / g
	var x := p.x + v.x * maxf(t, 0.0)
	var w := layout.size.x
	x = pingpong(x, w)
	return clampf(x / w, 0.0, 0.999)


# ---------------------------------------------------------------- hazards

## Most waves from HAZARD_FROM on bring one event partway through, never
## the same twice running.
func _schedule_hazard() -> void:
	_end_hazard()
	if director.wave < HAZARD_FROM or _rng.randf() > 0.7:
		return
	var pool: Array[Hazard] = [Hazard.GUST, Hazard.BLACKOUT, Hazard.GOLD]
	pool.erase(_last_hazard)
	_hazard = pool[_rng.randi() % pool.size()]
	_last_hazard = _hazard
	_hazard_in = _rng.randf_range(6.0, 15.0)


func _hazard_tick(delta: float) -> void:
	for t in targets:
		if t.evolved:
			t.evolved = false
			_announce_evolve(t)
		if t.fled:
			t.fled = false
			fx.popup(Loc.t("gold.fled"), Vector2(t.anchor.x, layout.rail_y + 60.0), Pal.GOLD_LIGHT, 16)
	Target.evolve_on = director.wave >= HAZARD_FROM
	if _hazard == Hazard.NONE:
		return
	if not _hazard_on:
		if director.breather > 0.0 or overload_t > 0.0:
			return
		_hazard_in -= delta
		if _hazard_in <= 0.0:
			_begin_hazard()
		return
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_hazard_t += rd
	match _hazard:
		Hazard.GUST:
			var env := smoothstep(0.0, 1.2, _hazard_t) * smoothstep(0.0, 1.2, GUST_TIME - _hazard_t)
			# It turns once, halfway through.
			var dir := _gust_dir if _hazard_t < GUST_TIME * 0.5 else -_gust_dir
			gust = dir * GUST_ACC * layout.scale * env * (0.65 + 0.35 * sin(_hazard_t * 1.7))
			_gust_whoosh -= rd
			if _gust_whoosh <= 0.0 and env > 0.5:
				_gust_whoosh = _rng.randf_range(1.6, 2.6)
				Sfx.play("whoosh", _rng.randf_range(0.6, 0.8), 2.0)
			backdrop.gust = gust
			if _hazard_t >= GUST_TIME:
				_end_hazard()
		Hazard.BLACKOUT:
			var env := smoothstep(0.0, 0.6, _hazard_t) * smoothstep(0.0, 0.9, BLACKOUT_TIME - _hazard_t)
			# The lamp struggles: now and then it flickers back for a blink.
			var flick := 0.0
			if not Prefs.reduced_motion and fposmod(_hazard_t, 2.6) > 2.45:
				flick = 0.55
			_set_dark(env * (1.0 - flick))
			if _hazard_t >= BLACKOUT_TIME:
				_end_hazard()
		Hazard.GOLD:
			if _hazard_t >= Target.GOLD_TIME + 2.0:
				_end_hazard()


func _begin_hazard() -> void:
	_hazard_on = true
	_hazard_t = 0.0
	match _hazard:
		Hazard.GUST:
			_gust_dir = 1.0 if _rng.randf() < 0.5 else -1.0
			_gust_whoosh = 0.0
			hud.card(Loc.t("hazard.gust"), Loc.t("hazard.gustSub"), 1.4)
		Hazard.BLACKOUT:
			hud.card(Loc.t("hazard.dark"), Loc.t("hazard.darkSub"), 1.4)
			Sfx.play("fall", 0.7)
		Hazard.GOLD:
			if _spawn_golden() == null:
				_end_hazard()
				return
			hud.card(Loc.t("hazard.gold"), Loc.t("hazard.goldSub"), 1.4)
			Sfx.play("clear", 1.3)


func _end_hazard() -> void:
	_hazard = Hazard.NONE
	_hazard_on = false
	_hazard_in = -1.0
	gust = 0.0
	backdrop.gust = 0.0
	_set_dark(0.0)


func _set_dark(v: float) -> void:
	_dark = v
	Target.dark = v
	backdrop.dark = v
	rail.modulate = Color.WHITE.lerp(Color(0.3, 0.32, 0.4), v)


## A golden one drops in at a free spot: it never sinks, and it flees.
func _spawn_golden() -> Target:
	var t := _free_target()
	if t == null:
		return null
	var used: Array[float] = []
	for o in targets:
		if o.is_hittable():
			used.append(o.anchor.x)
	var x := _best_slot(used, 12)
	t.aggression = 0.55
	t.spawn(Target.Kind.RING, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * _rng.randf_range(0.18, 0.32), 0.0)
	t.golden = true
	return t


func _announce_evolve(t: Target) -> void:
	fx.popup(Loc.t("evolve.pop"), t.pos + Vector2(0, -t.radius - 30.0), Pal.INK, 18)
	fx.ring(t.pos, t.color(), 60.0)
	fx.puff(t.pos, Pal.INK, 4, 22.0, 0.15)
	Sfx.play("clank", 0.8)
	t.voice("taunt")
	if not _evolve_told:
		_evolve_told = true
		hud.card(Loc.t("evolve.title"), Loc.t("evolve.sub"), 1.8)


# ---------------------------------------------------------------- acrobatics

## Every few seconds the most exposed light target picks a neighbour's rope
## within swinging reach (one whose body hangs below it) and swings over.
## Reports grabs, rescues and slips.
func _acro_tick(delta: float) -> void:
	Target.acro_on = director.wave >= ACRO_WAVE
	for t in targets:
		if t.grabbed:
			t.grabbed = false
			if t.rescued:
				t.rescued = false
				director.wave_killed = maxi(0, director.wave_killed - 1)
				fx.popup(Loc.t("acro.caught"), t.pos + Vector2(0, -t.radius - 28.0), Pal.CORAL, 18)
				Sfx.voice("taunt", 1.0, 3, -4.0)
			fx.puff(t.pos + Vector2(0, -t.radius), Pal.INK, 2, 12.0, 0.1)
		if t.slipped:
			t.slipped = false
			director.count_kill()
			run_kills += 1
			var pts := t.points() * _mult() * _surge()
			_add_score(pts, t.pos)
			fx.popup(Loc.t("acro.slip") % pts, t.pos + Vector2(0, -t.radius - 24.0), Pal.INK, 18)
	if not Target.acro_on or director.breather > 0.0 or overload_t > 0.0:
		return
	_acro_t -= delta
	if _acro_t > 0.0:
		return
	_acro_t = _rng.randf_range(ACRO_EVERY.x, ACRO_EVERY.y)
	var best: Target = null
	var best_host: Target = null
	var best_score := -INF
	for t in targets:
		if not _can_swing(t):
			continue
		for h in targets:
			if h == t or not h.is_hittable() or h.acro != Target.Acro.NONE or h.kind == Target.Kind.BOSS or h.golden:
				continue
			var dx := absf(h.anchor.x - t.anchor.x)
			if dx < 70.0 * layout.scale or dx > minf(t.length * 1.1, 260.0 * layout.scale):
				continue
			# The rope must pass the height it can reach, above the host's body.
			if h.pos.y - h.radius < t.pos.y + 10.0:
				continue
			var sc := t.danger * 2.0 - dx / (300.0 * layout.scale) + _rng.randf() * 0.3
			if sc > best_score:
				best_score = sc
				best = t
				best_host = h
	if best:
		best.start_swing(best_host)


func _can_swing(t: Target) -> bool:
	return t.is_hittable() and t.kind in ACRO_KINDS and t.acro == Target.Acro.NONE and t.rope_host == null \
		and t.leader == null and not t.is_leader and t.guard_of == null and not t.golden and not t.panicked() \
		and t.length > 110.0 * layout.scale and t.delay <= 0.0 and t.tele_t <= 0.0


## Everyone hanging on the same rope as `t` (riders and their host).
func _rope_group(t: Target) -> Array[Target]:
	var root := t.rope_host if t.rope_host != null and is_instance_valid(t.rope_host) else t
	var out: Array[Target] = []
	for o in targets:
		if o == t or not o.is_hittable():
			continue
		if o == root or o.rope_host == root:
			out.append(o)
	return out


## A cut body may be saved: a friend hanging lower throws itself out so its
## rope sweeps through the fall, and the falling one grabs it.
func _try_rescue(t: Target) -> void:
	if not Target.acro_on or _rng.randf() > RESCUE_CHANCE:
		return
	var best: Target = null
	var best_d := INF
	for r in targets:
		if r == t or not r.is_hittable() or r.acro != Target.Acro.NONE or r.kind == Target.Kind.BOSS or r.leader != null or r.is_leader or r.golden:
			continue
		if r.pos.y < t.pos.y + 50.0:
			continue
		var dx := absf(r.anchor.x - t.pos.x)
		if dx < 30.0 or dx > r.length * 0.6:
			continue
		if dx < best_d:
			best_d = dx
			best = r
	if best == null:
		return
	# Where its rope must reach at the faller's height, and the swing that
	# gets it there in about a quarter of a second.
	var f := clampf((t.pos.y - best.anchor.y) / maxf(1.0, best.pos.y - best.anchor.y), 0.15, 1.0)
	var need := (t.pos.x - best.anchor.x) / f - (best.pos.x - best.anchor.x)
	best.vel.x += clampf(need / 0.25, -1100.0, 1100.0)
	best.startle_t = 0.4
	best.voice("up")
	t.expect_rescue(best)


# ---------------------------------------------------------------- perks

func perk(id: String) -> int:
	return int(perks.get(id, 0))


func _ammo_cap() -> int:
	return AMMO_CAP + perk("rack")


func _reload_time() -> float:
	return director.reload_time() * pow(0.85, perk("reload"))


func _flow_time() -> float:
	return FLOW_TIME + 2.5 * perk("flow")


## Three cards once the cleared wave's moment has played out.
func _offer_perks() -> void:
	_perk_pending = false
	if state != State.PLAYING and state != State.STARTING:
		return
	var ids := Perks.offer(perks, lives < LIVES, _rng)
	if not ids.is_empty():
		hud.perks.open(ids, perks)


func _on_perk(id: String) -> void:
	perks[id] = perk(id) + 1
	if id == "knot" and lives < LIVES:
		lives += 1
		hud.bar.lives = lives
		hud.bar.knot_shake = 1.0
	_apply_perks()


func _apply_perks() -> void:
	slingshot.rack_slots = _ammo_cap() - 1
	slingshot.long_sight = perk("sight") > 0


## Magnet: a ball bends gently toward the nearest enemy ahead of it.
func _magnet(b: Ball, dt: float) -> void:
	var best: Target = null
	var bd := 240.0 * layout.scale
	for t in targets:
		if not t.is_solid():
			continue
		var d := t.pos.distance_to(b.pos)
		if d < bd and (t.pos - b.pos).dot(b.vel) > 0.0:
			bd = d
			best = t
	if best:
		b.vel += (best.pos - b.pos).normalized() * 260.0 * perk("magnet") * dt


# ---------------------------------------------------------------- nemesis

## The one that got through returns (once the field is in full swing),
## named, scarred and tougher; the card says who is back.
func _nemesis_tick(delta: float) -> void:
	if _nemesis_kind < 0 or _nemesis_in < 0.0:
		return
	if director.wave_state != Director.Wave.SPAWNING or director.breather > 0.0 or overload_t > 0.0:
		return
	_nemesis_in -= delta
	if _nemesis_in > 0.0:
		return
	var t := _spawn_one(_nemesis_kind as Target.Kind)
	if t == null:
		_nemesis_in = 3.0
		return
	_nemesis_in = -1.0
	_nemesis_kind = -1
	t.nemesis = _nemesis_lv
	t.hp += _nemesis_lv
	t.aggression = minf(1.0, t.aggression + 0.25)
	var name := Loc.t("nemesis.%d" % t.kind)
	if _nemesis_lv > 1:
		name += " " + ["", "", "II", "III", "IV"][mini(_nemesis_lv, 4)]
	hud.card(Loc.t("nemesis.back") % name, Loc.t("nemesis.sub"), 1.6)
	Sfx.voice("taunt", 0.8, 0, -2.0)
	Sfx.play("boss", 1.2, -6.0)
	fx.after(0.6, func() -> void:
		if is_instance_valid(t) and t.is_hittable():
			t.taunt())


# ---------------------------------------------------------------- flow

func _flow_add(v: float) -> void:
	if flow_t > 0.0 or (state != State.PLAYING and state != State.STARTING):
		return
	flow = minf(1.0, flow + v * (1.0 + 0.2 * perk("flow")))
	if flow >= 1.0:
		_begin_flow()


func _begin_flow() -> void:
	flow_t = _flow_time()
	flow = 1.0
	flows += 1
	hud.flow_hot = true
	backdrop.flow = true
	Music.flow = true
	var mid := Vector2(layout.center_x, layout.danger_y - 60.0)
	hud.card(Loc.t("flow.title"), Loc.t("flow.sub"))
	fx.shock(mid, 6.0, 420.0, 0.5)
	fx.punch(0.02)
	fx.aberrate(3.0)
	Sfx.phrase([0, 2, 3, 4, 7], 0.05, -3.0)
	Sfx.play("rise", 1.3)
	Sfx.haptic_pattern("record")
	_show_mult()


## Real time, so slow motion doesn't stretch it.
func _flow_tick(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	if flow_t > 0.0:
		flow_t -= rd
		flow = maxf(0.0, flow_t / _flow_time())
		if flow_t <= 0.0:
			_end_flow(false)
	else:
		flow = maxf(0.0, flow - FLOW_DECAY * rd)
	hud.flow = flow


func _end_flow(quiet: bool) -> void:
	var was := flow_t > 0.0 or hud.flow_hot
	flow_t = 0.0
	hud.flow_hot = false
	backdrop.flow = false
	Music.flow = false
	if was:
		flow = 0.0
		_show_mult()
		if not quiet:
			Sfx.play("fall", 1.3)


# ---------------------------------------------------------------- scoring

func _mult() -> int:
	return 1 + mini(streak / 3, 3) + (1 if flow_t > 0.0 else 0)


## The pill shows what a hit is worth: the streak multiplier, doubled in
## overload.
func _show_mult() -> void:
	hud.bar.set_mult(_mult() * _surge())


## Points fly to the counter as gold grains; every EXTRA_LIFE_EVERY points
## returns a lost knot.
func _add_score(n: int, from := Vector2.INF) -> void:
	score += n
	hud.bar.score = score
	hud.bar.pulse = 1.0
	if n >= 100:
		hud.bar.glint = 1.0
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
		_flow_add(FLOW_HIT)
		streak += 1
		best_streak = maxi(best_streak, streak)
		if streak % 5 == 0:
			_grant(Ammo.TRIPLE)
			fx.popup(Loc.t("popup.streak") % streak + " · " + Loc.t("popup.triple"), Vector2(layout.center_x, layout.fork_y - 110.0), Pal.GOLD, 18)
			Sfx.play("streak")
			Sfx.haptic(16, 0.4)
	else:
		streak = 0
		if flow_t <= 0.0:
			flow = maxf(0.0, flow - FLOW_MISS)
		if overload_t <= 0.0:
			charge = maxf(0.0, charge - CHARGE_MISS)
			rail.charge = charge
	hud.bar.streak = streak
	_show_mult()


func _grant(kind: int) -> void:
	if ammo.size() >= _ammo_cap():
		ammo[mini(1, ammo.size() - 1)] = kind
	elif ammo.is_empty():
		ammo.append(kind)
	else:
		ammo.insert(1, kind)


func _update_ammo(delta: float) -> void:
	if ammo.size() < _ammo_cap() and state != State.DEATH and state != State.GAME_OVER:
		reload_t += delta / (OVERLOAD_RELOAD if overload_t > 0.0 else 1.0) * (FLOW_RELOAD if flow_t > 0.0 else 1.0)
		if reload_t >= _reload_time():
			reload_t = 0.0
			ammo.append(Ammo.NORMAL)
	else:
		reload_t = 0.0
	slingshot.set_ammo(ammo, reload_t / _reload_time())


func _on_launched(pos: Vector2, vel: Vector2, kind: int) -> void:
	if ammo.is_empty():
		return
	ammo.pop_front()
	_shot_seq += 1
	if state == State.PLAYING or state == State.STARTING:
		director.record_aim(vel.normalized().x)
		if _release_hold >= 0.0:
			director.record_hold(_release_hold)
		director.record_column(_cross_u(pos, vel))
	_aim_start = -1.0
	_release_hold = -1.0
	var dirs: Array[float] = [0.0]
	if kind == Ammo.TRIPLE:
		dirs = [-TRIPLE_SPREAD, 0.0, TRIPLE_SPREAD]
	var fired := 0
	for a in dirs:
		for b in balls:
			if not b.active:
				b.fire(pos, vel.rotated(a), kind == Ammo.PIERCE or overload_t > 0.0, _shot_seq)
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
				_aim_start = _time
			elif _deny_cd <= _time:
				# No ball loaded: a short "not yet" instead of silence.
				_deny_cd = _time + 0.5
				Sfx.play("deny")
				Sfx.haptic_pattern("error")
		elif not e.pressed and e.index == _touch:
			_touch = -1
			_release_hold = _time - _aim_start if _aim_start >= 0.0 else -1.0
			_aim_start = -1.0
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
