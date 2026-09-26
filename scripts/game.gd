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
const HAZARD_FROM := 2
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
# Cunning tricks and the wave each starts at.
const EMPTY_WAVE := 2           # an empty rack: the nearest to the line pounce
const PLAYDEAD_WAVE := 2
const SNEAK_WAVE := 3           # while you aim at one, another sneaks down
const SWAP_WAVE := 4            # two neighbours trade places under your aim
const SNEAK_EVERY := 7.0
const SWAP_EVERY := 8.0
# Trick charms (from CHARM_WAVE): spawned on some targets, shared, swapped,
# inherited, copied by Pipp and handed out by Pakkis.
const CHARM_WAVE := 2
const CHARM_SWAP := Vector2(7.0, 11.0)
const CHARM_PASS_CD := 5.0
const CHARM_GIFT := 6.0
const CHARM_COPY := 5.0
const CHARM_BREAK := 30
const DEFENSIVE := [Target.Charm.BUBBLE, Target.Charm.SPRING, Target.Charm.GHOST]
# Moods (from MOOD_WAVE): grumpy and cute enemies, the mix set by the wave.
const MOOD_WAVE := 2
const FORESHADOW := 0.7        # s a fibre shows where an enemy is about to drop in
const GOLD_DROP_WAVE := 2
const SHOVE_WAVE := 3          # from here, moody ones shove their neighbours
const SHOVE_AIM := 0.3         # s the aim must hold before one reacts
const WAVE_MOOD_KEY := ["", "wmood.calm", "wmood.chaos", "wmood.grumpy", "wmood.cute"]
const WAVE_MOOD_COL := [Color.WHITE, Color("9CC8FF"), Color("F29CC8"), Color("F0A36A"), Color("FFB8D8")]
# Acrobatics: from ACRO_WAVE a low, exposed target now and then swings over
# to a neighbour's rope, and a friend may catch one whose rope was cut.
const ACRO_WAVE := 3
const ACRO_EVERY := Vector2(8.0, 13.0)
const RESCUE_CHANCE := 0.4
const ACRO_KINDS := [Target.Kind.RING, Target.Kind.SPLIT, Target.Kind.DROP, Target.Kind.SHADE, Target.Kind.MEDIC, Target.Kind.REEL, Target.Kind.PIPP]
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
var _told := {}                 # cunning tricks already named this run
var _empty_seen := false
var _sneak_cd := 0.0
var _swap_cd := 0.0
var _swap_aim: Target = null
var _charm_swap_t := 8.0
var _charm_pass_cd := 0.0
var _charm_gift_t := 4.0
var _charm_copy_t := 3.0
var _calm_t := 0.5
var _gold_drop_t := 20.0       # s until a gold drop gathers on a fibre
var _shove_cd := 5.0           # s until the next shove may start (one at a time)
var _shover: Target = null
var _last_pulse := 0
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
	title.caught.connect(_on_letter_caught)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_to_menu)
	hud.bar.record_broken.connect(_on_record_broken)
	hud.bar.wave_record.connect(_on_wave_record)
	backdrop.energy_arrived.connect(_on_energy)
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
	hud.perk_order.clear()
	hud.perk_levels = {}
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
	hud.clear_cards()
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
	_told = {}
	_empty_seen = false
	_sneak_cd = 4.0
	_swap_cd = 4.0
	_charm_swap_t = 8.0
	_charm_pass_cd = 0.0
	_charm_gift_t = 4.0
	_charm_copy_t = 3.0
	_acro_t = 8.0
	_last_hazard = Hazard.NONE
	_rhythm_told = false
	_plunge_t = 12.0
	_chain = 0
	_chain_t = 0.0
	_next_life_at = EXTRA_LIFE_EVERY
	_shove_cd = 5.0
	_shover = null
	_gold_drop_t = 20.0
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
	# The bests this run chases (the bar says when they are near or beaten).
	hud.bar.daily = daily
	hud.bar.best = Prefs.daily_record() if daily else Prefs.record
	hud.bar.best_wave = int(Prefs.stats.get("best_wave", 0))
	Prefs.fresh = {}
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


## The record just fell, mid-run: the counter takes the stamp (drawn by the
## bar); here, the burst of brass, the chime and a breath of slow motion.
func _on_record_broken() -> void:
	var at := Vector2(layout.center_x, layout.safe_top + 47.0)
	fx.sparks(at, Pal.GOLD_LIGHT, 18)
	fx.ring(at, Pal.GOLD_LIGHT, 70.0)
	fx.flash(at, 90.0, Pal.GOLD_LIGHT)
	Sfx.play("record")
	Sfx.strum([5, 6, 7, 8, 9, 10], 0.04, -2.0)
	Sfx.haptic_pattern("record")
	if not Prefs.reduced_motion:
		fx.slowmo(0.4, 0.3)


## A kill's energy has run up its fibre and into the tension string: the
## string takes it (a pluck on the bar) and sounds, tuned to how tight the
## wave has pulled it.
func _on_energy(_col: Color) -> void:
	if state != State.PLAYING and state != State.STARTING:
		return
	hud.bar.energy()
	Sfx.taut(director.wave_progress(), -3.0)


## A gold drop shot off its fibre: a burst of tension toward overload and
## points, and a run up the harp.
func _catch_gold(at: Vector2) -> void:
	if at == Vector2.INF:
		return
	_charge(0.3)
	_add_score(120 * _mult(), at)
	fx.sparks(at, Pal.GOLD_LIGHT, 14)
	fx.ring(at, Pal.GOLD_LIGHT, 50.0)
	fx.popup(Loc.t("gold.drop") + "  +" + Hud._group(120 * _mult()), at + Vector2(0, -34.0), Pal.GOLD_LIGHT, 18, true)
	Sfx.strum([4, 6, 8, 10], 0.05)
	Sfx.haptic_pattern("light")


## Past the best wave ever reached: a smaller moment at the medallion.
func _on_wave_record() -> void:
	var at := Vector2(layout.margin + 36.0, layout.safe_top + 48.0)
	fx.sparks(at, Pal.GOLD_LIGHT, 10)
	Sfx.phrase([4, 6, 8], 0.07, -5.0)
	Sfx.haptic_pattern("light")


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
	# A fibre shows where it will hang a moment before it drops in.
	var wait := FORESHADOW if state == State.PLAYING else 0.0
	t.spawn(kind, Vector2(x, layout.rail_y + 3.0), 12.0, layout.play_h * frac, wait)
	if wait > 0.0:
		backdrop.foreshadow(Vector2(x, layout.rail_y + 3.0 + layout.play_h * frac), Pal.kind_color(kind), wait)
	_roll_variant(t)
	_maybe_intro(t)
	_roll_mood(t)
	if director.wave >= CHARM_WAVE and kind != Target.Kind.BOSS and kind != Target.Kind.PAKKIS and _rng.randf() < clampf(0.12 + 0.03 * (director.wave - CHARM_WAVE), 0.0, 0.35):
		_give_charm(t, 1 + _rng.randi() % 5)
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
		backdrop.foreshadow(Vector2(x, layout.rail_y + 3.0 + layout.play_h * (0.2 - 0.1 * v)), Pal.kind_color(kind), 0.15 + i * 0.09)
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
	if not Prefs.seen.has(t.intro_id()) and not _intro_queue.has(t):
		_intro_queue.append(t)


func _run_intros() -> void:
	if _intro_queue.is_empty() or hud.intro_busy():
		return
	var t: Target = _intro_queue[0]
	if t.phase == Target.Phase.HANGING and t.delay > 0.0:
		return
	_intro_queue.pop_front()
	if t.phase != Target.Phase.HANGING or not Prefs.first_sight(t.intro_id()):
		return
	var parts := Loc.t("enemy.%d" % t.intro_id()).split("|")
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
	_update_ball_light()
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
		_cunning_tick(delta)
		_charm_tick(delta)
		_mood_tick(delta)
		_shove_tick(delta)
		_pace(delta)
		_spawn_minions()
		_medic_work()
		_boss_stages()
		Music.intensity = clampf(director.intensity() / 5.0 + (0.3 if director.pulse == Director.Pulse.PEAK else 0.0), 0.0, 1.0)


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
	director.update_wave(_alive_count())
	_wave_tick(delta)
	if director.wants_finale():
		director.finale_done = true
		_spawn_finale()
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
	hud.bar.remaining = maxi(0, director.wave_quota() - director.wave_killed)
	hud.bar.finale_at = Director.FINALE_AT
	backdrop.progress = director.wave_progress()
	backdrop.string_y = layout.safe_top + (layout.top_bar_h - layout.safe_top) * 0.86
	backdrop.streak_lit = mini(streak, 9)
	var in_finale := director.wave_progress() >= Director.FINALE_AT and director.wave_state != Director.Wave.BREAK
	backdrop.finale = in_finale
	Music.finale = in_finale
	# Now and then a gold drop gathers on a fibre.
	if director.wave >= GOLD_DROP_WAVE and state == State.PLAYING:
		_gold_drop_t -= delta
		if _gold_drop_t <= 0.0:
			_gold_drop_t = _rng.randf_range(22.0, 36.0)
			backdrop.spawn_gold()
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
			director.wave_break -= delta
			if director.wave_break <= 0.0:
				director.next_wave()
				_spawn_t = 0.3
				# A new wave, a new colour theme, eased in.
				Pal.next_theme()
				var wm := director.roll_mood()
				hud.wave_intro(director.wave, Loc.t(WAVE_MOOD_KEY[wm]) if wm != Director.WaveMood.NORMAL else "", WAVE_MOOD_COL[wm])
				backdrop.ripple(Vector2(layout.center_x, layout.rail_y), Pal.GOLD_LIGHT, 1.2)
				Sfx.play("streak", 0.85)
				Sfx.play("whoosh", 0.6, -4.0)
				_schedule_hazard()
				if director.wave == ACRO_WAVE and not _acro_told:
					_acro_told = true
					fx.after(1.8, func() -> void: hud.card(Loc.t("acro.title"), Loc.t("acro.sub"), 2.2))
				var tac := director.tactic()
				if tac > _tactic_told:
					_tactic_told = tac
					fx.after(1.8, func() -> void: _announce_tactic(tac))


func _clear_wave() -> void:
	waves_cleared += 1
	var bonus := (100 + 50 * director.wave) * _mult() * _surge()
	var mid := Vector2(layout.center_x, layout.rail_y + layout.play_h * 0.46)
	_add_score(bonus, mid)
	hud.card(Loc.t("wave.clear") % director.wave, "+" + Hud._group(bonus))
	Sfx.strum([0, 2, 4, 5, 7], 0.05, -2.0)
	fx.shock(mid, 8.0, 380.0, 0.6)
	# Final-kill camera: the camera leans in on the last one and time all
	# but stops; a gold ring runs out through the light fibres from the kill
	# and a spark races along the rail.
	var calm := Prefs.reduced_motion
	backdrop.ripple(_last_kill, Pal.GOLD_LIGHT, 2.0)
	for i in 9:
		var x := layout.size.x * (0.04 + i * 0.115)
		fx.after(0.05 + 0.035 * i, func() -> void:
			fx.flash(Vector2(x, layout.rail_y), 30.0, Pal.GOLD_LIGHT)
			rail.flex(x, 2.5))
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
	fx.after(1.4, _grant_perk)


## The balls in flight light what they pass (warm, fading as a spent ball
## fades; brighter when burning in overload).
var _lights: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
func _update_ball_light() -> void:
	var k := 0
	for b in balls:
		if k >= 3:
			break
		if b.active:
			var gp := b.global_position
			var glow := (1.0 if Ball.hot else 0.7) * b.modulate.a
			_lights[k] = Vector4(gp.x, gp.y, 230.0 * layout.scale, glow)
			k += 1
	for i in range(k, 3):
		_lights[i] = Vector4.ZERO
	var lc: Color = Meta.skin_colors(Prefs.skin)[2]
	Target.set_lights(_lights, lc)
	slingshot.set_lights(_lights, lc)


## Balls in flight knock into each other (a triple fan, or a fresh shot
## meeting a bouncing one): equal masses, a lively bounce, friction spin.
func _ball_contacts() -> void:
	for i in balls.size():
		var a := balls[i]
		if not a.active or a.hit_rail:
			continue
		for j in range(i + 1, balls.size()):
			var c := balls[j]
			if not c.active or c.hit_rail:
				continue
			var d := c.pos - a.pos
			var dist := d.length()
			if dist >= Ball.RADIUS * 2.0 or dist < 0.001:
				continue
			var n := d / dist
			var pen := Ball.RADIUS * 2.0 - dist
			a.pos -= n * pen * 0.5
			c.pos += n * pen * 0.5
			var vn := (a.vel - c.vel).dot(n)
			if vn <= 0.0:
				continue
			var jn := (1.0 + 0.85) * vn * 0.5
			a.vel -= n * jn
			c.vel += n * jn
			a.friction(-n, c.vel, jn, 0.15, 1.0)
			c.friction(n, a.vel, jn, 0.15, 1.0)
			a.impact(-n)
			c.impact(n)
			Sfx.play("clank", randf_range(1.5, 1.7), linear_to_db(clampf(vn / 1200.0, 0.1, 0.5)) - 6.0)


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
		if t.aimed and (t.kind == Target.Kind.RING or t.mood == Target.Mood.CUTE):
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
	_ball_contacts()
	for b in balls:
		if not b.active:
			continue
		b.vel.x += gust * GUST_BALL * dt
		if perk("magnet") > 0:
			_magnet(b, dt)
		var before := b.pos
		if not b.step(dt, layout):
			_finish_ball(b)
			continue
		# Across a fibre: it is plucked, a harp string in the track's key
		# (left to right climbs the scale; high in the field, an octave up).
		var fi := backdrop.cross(before, b.pos)
		if fi >= 0:
			var hi := 2 if b.pos.y < layout.rail_y + layout.play_h * 0.3 else 0
			Sfx.harp(fi + hi, -2.0 if b.hits > 0 else 0.0)
		var gp := backdrop.gold_pos()
		if gp != Vector2.INF and b.pos.distance_to(gp) < Ball.RADIUS + 14.0:
			_catch_gold(backdrop.catch_gold())
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
	var sc := layout.scale
	for i in n:
		var a := targets[i]
		if not a.is_hittable():
			continue
		for j in range(i + 1, n):
			var c := targets[j]
			if not c.is_hittable():
				continue
			# Shapes: circles, and a capsule for the Pendel (closest points on
			# its segment), so a rod is struck along its whole length.
			var pa := a.closest_point(c.pos)
			var pc := c.closest_point(pa)
			pa = a.closest_point(pc)
			var d := pc - pa
			var rr := a.shape_radius() + c.shape_radius()
			var dist := d.length()
			if dist >= rr or dist < 0.001:
				continue
			var nrm := d / dist
			var ia := 1.0 / a.mass()
			var ic := 1.0 / c.mass()
			# Push apart past a small slop, most of the way: stacked bodies
			# settle instead of jittering.
			var pen := maxf(0.0, rr - dist - 0.5) * 0.8
			var corr := nrm * pen / (ia + ic)
			a.pos -= corr * ia
			c.pos += corr * ic
			var contact := pa + nrm * a.shape_radius()
			var rel := a.vel - c.vel
			var closing := rel.dot(nrm)
			if closing <= 0.0:
				continue
			# Restitution by material: jelly on jelly barely bounces (it
			# squashes), shell on shell clacks apart, mixed in between.
			var e := 0.15 if (a.soft and c.soft) else (0.55 if not a.soft and not c.soft else 0.32)
			var j_imp := minf(closing * (1.0 + e) / (ia + ic), 520.0)
			# Friction along the contact: a glancing blow sets them spinning.
			var tan := rel - nrm * closing
			var f_imp := Vector2.ZERO
			if tan.length() > 1.0:
				f_imp = -tan.normalized() * minf(tan.length() / (ia + ic), j_imp * 0.35)
			a.push(-nrm * j_imp + f_imp, contact)
			c.push(nrm * j_imp - f_imp, contact)
			a.dent(contact, closing * 0.8)
			c.dent(contact, closing * 0.8)
			a.bump(-nrm, closing)
			c.bump(nrm, closing)
			# Billiards: a target sent flying by a hit takes a neighbour with it.
			if closing > KNOCK_SPEED * sc and (a.struck_t > 0.0 or c.struck_t > 0.0) and (state == State.PLAYING or state == State.STARTING):
				var striker := a if a.struck_t >= c.struck_t else c
				var victim := c if striker == a else a
				striker.struck_t = 0.0
				var dir := nrm if striker == a else -nrm
				_chain_hit(victim, dir * j_imp * 0.5, contact, closing, striker.chain_depth + 1)
				continue
			if closing > 110.0 and _knock_sfx_cd <= 0.0:
				_knock_sfx_cd = 0.07
				var loud := linear_to_db(clampf(closing / 600.0, 0.15, 0.75))
				if a.soft and c.soft:
					Sfx.play("squish", randf_range(1.05, 1.25), loud - 4.0)
				elif not a.soft and not c.soft:
					Sfx.play("clank", randf_range(1.1, 1.3), loud - 3.0)
				else:
					Sfx.play("knock", randf_range(0.9, 1.1), loud)
				Sfx.haptic(6, 0.2)
	# Ropes slide around the bodies they meet instead of passing through,
	# and bodies keep inside the walls.
	for t in targets:
		if t.phase == Target.Phase.OFF:
			continue
		if t.is_hittable():
			t.keep_in(layout.size.x)
			for o in targets:
				if o == t or absf(o.pos.x - t.pos.x) >= o.radius + 160.0 * sc:
					continue
				# Hanging bodies and falling ones alike push strings aside.
				if o.is_solid() or o.is_crushing(0.0):
					t.rope_avoid(o)
				if o.is_hittable() and o.get_instance_id() > t.get_instance_id():
					t.rope_rope(o)


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
		if t.charm != Target.Charm.NONE and b.pos.distance_to(t.charm_pos()) < Ball.RADIUS + 7.0:
			_break_charm(t)
		var rdv := t.rope_contact(b.pos, b.pos - b.vel * SUBSTEP, b.vel, Ball.RADIUS)
		if rdv != Vector2.ZERO:
			b.vel += rdv
			# The string rubs the ball: a touch of spin from the drag.
			b.w += clampf(rdv.cross(b.vel.normalized()) * 0.004, -6.0, 6.0)
			if t.consume_pluck():
				var loud := clampf(linear_to_db(clampf(rdv.length() / 120.0, 0.05, 1.0)), -18.0, -6.0)
				Sfx.play("twang", clampf(1.5 - t.length / 900.0, 0.8, 1.4) * randf_range(0.95, 1.05), loud)
				Sfx.haptic(5, 0.15)
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
				t.annoy(0.25)
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
	b.vel += n * j
	# Friction at the contact, with the ball's spin in it: a glancing blow
	# spins the ball (and a spinning ball kicks off at an angle).
	var ft := b.friction(n, t.vel, j, mu, 1.0 / (t.mass() * K_MASS))
	var imp := n * j + ft
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
	if t.playdead > 0.0:
		# Caught faking: no fooling you.
		t.playdead = 0.0
		fx.popup(Loc.t("cunning.busted"), t.pos + Vector2(0, -t.radius - 30.0), Pal.GOLD_LIGHT, 18)
		_add_score(50 * _mult(), t.pos)
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
		v *= 1.0 + 0.25 * perk("charge")
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
	elif kind == Target.Kind.DROP and t.variant == Target.Var.TWIN:
		_twin(t)


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
	backdrop.send_energy(t.pos, t.color())
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
					# A fallen friend: grumpy ones seethe, cute ones cry (and
					# now and then turn sour).
					n.annoy(0.35)
					if d < 160.0 * layout.scale:
						n.enrage(4.0)
					if n.mood == Target.Mood.CUTE:
						n.cry()
						if _rng.randf() < 0.25:
							n.set_mood(Target.Mood.GRUMPY)
	_last_kill = t.pos
	_flow_add(FLOW_KILL)
	if t.charm != Target.Charm.NONE:
		_inherit_charm(t)
	if t.champion:
		var cb := 150 * director.wave * _mult() * _surge()
		bonus += cb
		fx.popup(Loc.t("finale.won") % cb, t.pos + Vector2(0, -80.0), Pal.GOLD_LIGHT, 26, true)
		fx.ring(t.pos, Pal.GOLD, 110.0)
		fx.focus(t.pos, 0.07, 0.9)
		Sfx.phrase([0, 2, 4, 7, 8], 0.07, -1.0)
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
	# A breach costs the wave: four more to take down before it is won.
	director.extra_quota += 4
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
	# Flow and any hazard end with the run, so none lingers behind the results.
	_end_flow(true)
	_end_hazard()
	_heat = 0.0
	hud.clear_cards()
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
	_gust_dir = 1.0 if _rng.randf() < 0.5 else -1.0


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
		# The fibres warn just before it comes.
		if _hazard_in < 1.4:
			backdrop.warn = clampf(1.0 - _hazard_in / 1.4, 0.0, 1.0)
			backdrop.warn_kind = [0, 1, 2, 3][_hazard]
			backdrop.warn_dir = _gust_dir
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
	backdrop.warn = 0.0
	_hazard_t = 0.0
	match _hazard:
		Hazard.GUST:
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
	backdrop.warn = 0.0
	_set_dark(0.0)


func _set_dark(v: float) -> void:
	_dark = v
	Target.dark = v
	backdrop.dark = v
	Music.dark = v
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
			backdrop.send_energy(t.pos, t.color())
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


## A cleared wave wins the run one perk at random (never past its cap);
## it pops up and flies into the tray without stopping play.
func _grant_perk() -> void:
	if state != State.PLAYING and state != State.STARTING:
		return
	var ids := Perks.offer(perks, lives < LIVES, _rng)
	if ids.is_empty():
		return
	var id := ids[0]
	perks[id] = perk(id) + 1
	if id == "knot" and lives < LIVES:
		lives += 1
		hud.bar.lives = lives
		hud.bar.knot_shake = 1.0
	_apply_perks()
	hud.perk_toast(id, perks[id])
	Sfx.play("clear", 1.25, -4.0)
	Sfx.phrase([2, 4, 7], 0.06, -5.0)
	Sfx.haptic_pattern("light")


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


# ---------------------------------------------------------------- cunning

## Four tricks, unlocked wave by wave; each is named once, the first time it
## is pulled, so the player learns to read it.
func _cunning_tick(delta: float) -> void:
	var w := director.wave
	Target.play_dead_on = w >= PLAYDEAD_WAVE
	for t in targets:
		if t.surprised:
			t.surprised = false
			_name_trick("cunning.dead", t.pos)
	# An empty rack: the ones nearest the line see their chance.
	if w >= EMPTY_WAVE and ammo.is_empty() and not _empty_seen:
		_empty_seen = true
		var list: Array[Target] = []
		for t in targets:
			if t.is_hittable() and t.kind != Target.Kind.BOSS and t.playdead <= 0.0 and not t.golden:
				list.append(t)
		list.sort_custom(func(a: Target, b: Target) -> bool: return a.danger > b.danger)
		for i in mini(2, list.size()):
			list[i].order_plunge(30.0, 0.25)
			list[i].smug = 1.0
			if i == 0:
				_name_trick("cunning.empty", list[i].pos)
	elif not ammo.is_empty():
		_empty_seen = false
	_sneak_cd -= delta
	_swap_cd -= delta
	var aimed: Target = null
	for t in targets:
		if t.aimed:
			aimed = t
			break
	if aimed == null:
		_swap_aim = null
		return
	# Sneak: you have been on one target a while; another slips down.
	if w >= SNEAK_WAVE and _sneak_cd <= 0.0 and Target.aim_hold > 0.6:
		var best: Target = null
		for t in targets:
			if t == aimed or not t.is_hittable() or t.threat_lvl > 0.0 or t.kind == Target.Kind.BOSS or t.golden or t.playdead > 0.0:
				continue
			if t.pos.distance_to(aimed.pos) < 220.0 * layout.scale:
				continue
			if best == null or t.danger + (0.35 if t.mood == Target.Mood.CUTE else 0.0) > best.danger + (0.35 if best.mood == Target.Mood.CUTE else 0.0):
				best = t
		if best:
			_sneak_cd = SNEAK_EVERY * _rng.randf_range(0.8, 1.3)
			best.sneak(45.0)
			_name_trick("cunning.sneak", best.pos)
	# Swap: a neighbour at the same height trades places with your target.
	if w >= SWAP_WAVE and _swap_cd <= 0.0 and Target.aim_hold > 0.35 and aimed != _swap_aim:
		_swap_aim = aimed
		if _rng.randf() > 0.35 or not _free_mover(aimed):
			return
		for t in targets:
			if t == aimed or not _free_mover(t):
				continue
			if absf(t.anchor.x - aimed.anchor.x) < 130.0 * layout.scale and absf(t.pos.y - aimed.pos.y) < 70.0 * layout.scale:
				_swap_cd = SWAP_EVERY * _rng.randf_range(0.8, 1.3)
				var sp := 420.0 * layout.scale
				var ax := aimed.anchor.x
				aimed.slide_now(t.anchor.x, sp)
				t.slide_now(ax, sp)
				_name_trick("cunning.swap", aimed.pos.lerp(t.pos, 0.5))
				break


func _free_mover(t: Target) -> bool:
	return t.is_hittable() and t.kind != Target.Kind.BOSS and t.leader == null and not t.is_leader \
		and t.rope_host == null and t.guard_of == null and t.acro == Target.Acro.NONE and t.playdead <= 0.0 and not t.golden


## Names a trick the first time it is pulled this run.
func _name_trick(key: String, at: Vector2, col := Pal.CORAL) -> void:
	if _told.has(key):
		return
	_told[key] = true
	fx.popup(Loc.t(key), at + Vector2(0, -60.0), col, 18)
	Sfx.play("tease", 0.95, -4.0)


# ---------------------------------------------------------------- charms

func _give_charm(t: Target, c: int) -> void:
	t.set_charm(c)
	if not _told.has("charm.title"):
		_told["charm.title"] = true
		fx.after(0.6, func() -> void: hud.card(Loc.t("charm.title"), Loc.t("charm.sub"), 2.4))
	_name_trick("charm.%d" % c, t.pos, Target.CHARM_COL[c])


## Tosses `c` from `from` to `to` (visible arc); it is theirs on arrival.
func _toss_charm(from: Vector2, to: Target, c: int) -> void:
	var col: Color = Target.CHARM_COL[c]
	Sfx.play("whoosh", 1.5, -10.0)
	fx.charm_toss(from, to, col, func() -> void:
		if is_instance_valid(to) and to.is_hittable() and to.charm == Target.Charm.NONE:
			to.set_charm(c)
			Sfx.play("click", 1.4, -8.0)
			_name_trick("charm.%d" % c, to.pos, Target.CHARM_COL[c]))


func _break_charm(t: Target) -> void:
	var col: Color = Target.CHARM_COL[t.charm]
	var at := t.charm_pos()
	t.take_charm()
	var pts := CHARM_BREAK * _mult()
	_add_score(pts, at)
	fx.popup(Loc.t("charm.broken") % pts, at + Vector2(0, -20.0), col, 16)
	fx.sparks(at, col, 8)
	fx.ring(at, col, 26.0)
	Sfx.play("burst", 1.7, -6.0)
	Sfx.haptic(10, 0.3)


## A dying holder tosses its charm on: to a Pipp if one is near (it
## catches first), else to the nearest friend.
func _inherit_charm(t: Target) -> void:
	var c := t.take_charm()
	var best: Target = null
	var bd := INF
	for o in targets:
		if o == t or not o.is_hittable() or o.charm != Target.Charm.NONE or o.kind == Target.Kind.BOSS:
			continue
		var d := o.pos.distance_to(t.pos) * (0.5 if o.kind == Target.Kind.PIPP else 1.0)
		if d < 320.0 * layout.scale and d < bd:
			bd = d
			best = o
	if best:
		_toss_charm(t.pos, best, c)


func _nearest(from: Target, pred: Callable, reach: float) -> Target:
	var best: Target = null
	var bd := reach * layout.scale
	for o in targets:
		if o == from or not o.is_hittable() or not pred.call(o):
			continue
		var d := o.pos.distance_to(from.pos)
		if d < bd:
			bd = d
			best = o
	return best


func _charm_tick(delta: float) -> void:
	for t in targets:
		if t.wants_vine:
			t.wants_vine = false
			_vine_escape(t)
	if director.wave < CHARM_WAVE and not _any_kind(Target.Kind.PAKKIS):
		return
	_charm_pass_cd -= delta
	_charm_swap_t -= delta
	_charm_gift_t -= delta
	_charm_copy_t -= delta
	# Protect: you aim at one without a trick; a neighbour throws it theirs.
	if _charm_pass_cd <= 0.0 and Target.aim_hold > 0.35:
		for t in targets:
			if not t.aimed or t.charm != Target.Charm.NONE or t.kind == Target.Kind.BOSS:
				continue
			var giver := _nearest(t, func(o: Target) -> bool: return o.charm in DEFENSIVE and not o.aimed, 240.0)
			if giver:
				_charm_pass_cd = CHARM_PASS_CD
				_toss_charm(giver.charm_pos(), t, giver.take_charm())
				_name_trick("charm.pass", t.pos)
			break
	# Swap: two holders trade, their charms crossing in the air.
	if _charm_swap_t <= 0.0:
		_charm_swap_t = _rng.randf_range(CHARM_SWAP.x, CHARM_SWAP.y)
		for a in targets:
			if not a.is_hittable() or a.charm == Target.Charm.NONE:
				continue
			var b := _nearest(a, func(o: Target) -> bool: return o.charm != Target.Charm.NONE and o.charm != a.charm, 280.0)
			if b:
				var ca := a.take_charm()
				var cb := b.take_charm()
				_toss_charm(a.charm_pos(), b, ca)
				_toss_charm(b.charm_pos(), a, cb)
				_name_trick("charm.swap", a.pos.lerp(b.pos, 0.5))
				break
	# Pakkis hands out fresh tricks from its sack.
	if _charm_gift_t <= 0.0:
		_charm_gift_t = CHARM_GIFT
		for p in targets:
			if p.kind != Target.Kind.PAKKIS or not p.is_hittable():
				continue
			var to := _nearest(p, func(o: Target) -> bool: return o.charm == Target.Charm.NONE and o.kind != Target.Kind.BOSS and o.kind != Target.Kind.PAKKIS, 320.0)
			if to:
				p.charm_flash = 1.0
				p.voice("up", -6.0)
				_toss_charm(p.pos + Vector2(p.radius * 0.8, p.radius * 0.4), to, 1 + _rng.randi() % 5)
	# Pipp copies the trick of the nearest big one (the holder keeps it).
	if _charm_copy_t <= 0.0:
		_charm_copy_t = CHARM_COPY
		for p in targets:
			if p.kind != Target.Kind.PIPP or not p.is_hittable() or p.charm != Target.Charm.NONE:
				continue
			var src := _nearest(p, func(o: Target) -> bool: return o.charm != Target.Charm.NONE and o.kind != Target.Kind.PIPP, 300.0)
			if src:
				src.charm_flash = 1.0
				p.voice("up", -6.0)
				_toss_charm(src.charm_pos(), p, src.charm)
				_name_trick("charm.copy", p.pos)


func _any_kind(k: int) -> bool:
	for t in targets:
		if t.kind == k and t.is_hittable():
			return true
	return false


## Vine charm: aimed at, it swings over to the nearest rope it can reach.
func _vine_escape(t: Target) -> void:
	if not _can_swing(t) and not (t.is_hittable() and t.acro == Target.Acro.NONE and t.rope_host == null):
		return
	var best: Target = null
	var bd := INF
	for h in targets:
		if h == t or not h.is_hittable() or h.acro != Target.Acro.NONE or h.kind == Target.Kind.BOSS or h.golden:
			continue
		var dx := absf(h.anchor.x - t.anchor.x)
		if dx < 60.0 * layout.scale or dx > minf(t.length * 1.1, 260.0 * layout.scale) or h.pos.y - h.radius < t.pos.y + 10.0:
			continue
		if dx < bd:
			bd = dx
			best = h
	if best:
		t.start_swing(best)


# ---------------------------------------------------------------- moods

func _roll_mood(t: Target) -> void:
	if director.wave < MOOD_WAVE or t.kind == Target.Kind.BOSS or t.golden:
		return
	var st: Array = director.style.get(t.kind, [])
	if not st.is_empty() and st[0] == "mood" and _rng.randf() < 0.6:
		if st[1] != Target.Mood.NEUTRAL:
			t.set_mood(st[1])
		return
	var odds := director.mood_odds()
	var r := _rng.randf()
	if r < odds.x:
		t.set_mood(Target.Mood.GRUMPY)
	elif r < odds.x + odds.y:
		t.set_mood(Target.Mood.CUTE)


## Rages are named, cries are answered (a friend throws its trick, or a
## grumpy friend moves in to shield), and cute company calms the grumpy.
func _mood_tick(delta: float) -> void:
	# The wave's pulse: its peak brings a flurry; the fibres feel it.
	if director.pulse != _last_pulse:
		_last_pulse = director.pulse
		if director.pulse == Director.Pulse.PEAK and director.wave_state == Director.Wave.SPAWNING:
			backdrop.ripple(Vector2(layout.center_x, layout.rail_y), Pal.INK, 1.0)
			Sfx.play("rise", 1.5, -12.0)
	for t in targets:
		if t.stance_changed:
			t.stance_changed = false
			_name_trick("stance.%d" % t.stance, t.pos, Target.STANCE_TINT[t.stance].lightened(0.3))
		if t.raged:
			t.raged = false
			fx.puff(t.pos + Vector2(0, -t.radius), Pal.INK, 3, 14.0, 0.2)
			_name_trick("mood.rage", t.pos)
		if t.wants_help:
			t.wants_help = false
			if t.is_hittable():
				_answer_cry(t)
	_calm_t -= delta
	if _calm_t > 0.0:
		return
	_calm_t = 0.5
	for g in targets:
		if g.mood != Target.Mood.GRUMPY or g.anger <= 0.0 or not g.is_hittable():
			continue
		for c in targets:
			if c.mood == Target.Mood.CUTE and c.is_hittable() and c.pos.distance_to(g.pos) < 150.0 * layout.scale:
				g.anger = maxf(0.0, g.anger - 0.08)
				break


## Shoving, fair by design:
##  - only moody ones do it, from wave SHOVE_WAVE, one at a time, with a
##    pause of several seconds between shoves;
##  - they react to the aim only (held SHOVE_AIM s), never to a ball
##    already flying, and the arm winds up for Target.ARM_WIND s first:
##    release in time and the shot lands;
##  - hit the shover while it winds up and the shove is stopped, for a
##    bonus;
##  - a grumpy one aimed at shoves its neighbour aside and recoils the other
##    way, out of the line; a cute one nudges an aimed-at friend out of it.
##    The one shoved swings into whoever is beside it (the real contacts),
##    which can knock them into the line instead;
##  - nobody is shoved toward the danger line, or once it is close to it.
func _shove_tick(delta: float) -> void:
	_shove_cd -= delta
	var sc := layout.scale
	if _shover != null:
		if not is_instance_valid(_shover) or _shover.arm == Target.Arm.NONE:
			_shover = null
			return
		if _shover.arm == Target.Arm.WIND and _shover.struck_t > 0.0:
			# Caught winding up: the shove is off, and that is worth a bonus.
			_shover.cancel_shove()
			_shover.annoy(0.3)
			_add_score(60, _shover.pos)
			fx.popup(Loc.t("shove.stopped") + "  +60", _shover.pos + Vector2(0, -_shover.radius - 34.0), Pal.GOLD_LIGHT, 18, true)
			Sfx.play("streak", 1.2, -6.0)
			_shover = null
			return
		if _shover.shoved:
			_shover.shoved = false
			_land_shove(_shover, _shover.arm_victim)
		return
	if director.wave < SHOVE_WAVE or _shove_cd > 0.0 or state != State.PLAYING:
		return
	if not slingshot.is_aiming() or Target.aim_hold < SHOVE_AIM:
		return
	var safe_y := layout.danger_y - 170.0 * sc
	for a in targets:
		if a.mood == Target.Mood.NEUTRAL or a.arm != Target.Arm.NONE or a.shove_cd > 0.0 or a.struck_t > 0.0 or not _free_mover(a):
			continue
		if a.pos.y > safe_y:
			continue
		var v: Target = null
		if a.mood == Target.Mood.GRUMPY and a.aimed:
			v = _nearest(a, func(o: Target) -> bool: return _free_mover(o) and absf(o.pos.y - a.pos.y) < 110.0 * sc and o.pos.y < safe_y, 190.0)
		elif a.mood == Target.Mood.CUTE and not a.aimed:
			v = _nearest(a, func(o: Target) -> bool: return o.aimed and _free_mover(o) and absf(o.pos.y - a.pos.y) < 110.0 * sc and o.pos.y < safe_y, 190.0)
		if v == null or absf(v.pos.x - a.pos.x) < 10.0:
			continue
		a.begin_shove(v)
		a.shove_cd = 10.0
		_shover = a
		_shove_cd = maxf(4.5, 7.5 - 0.3 * (director.wave - SHOVE_WAVE)) + _rng.randf_range(0.0, 1.5)
		if not _told.has("shove.card"):
			_told["shove.card"] = true
			hud.card(Loc.t("shove.title"), Loc.t("shove.sub"), 2.2)
		return


## The shove lands: the neighbour is flung sideways (a swing on its string
## and a slide along the rail), the shover recoils the other way.
func _land_shove(a: Target, v: Target) -> void:
	if not is_instance_valid(v) or not v.is_hittable() or not a.is_hittable():
		return
	var sc := layout.scale
	var dir := signf(v.pos.x - a.pos.x)
	var grumpy := a.mood == Target.Mood.GRUMPY
	var strength := 1.0 if grumpy else 0.7
	var at := v.pos - Vector2(dir * v.radius, 0)
	v.push(Vector2(dir * 240.0 * strength, -30.0), at)
	v.slide_now(v.anchor.x + dir * 70.0 * strength * sc, 520.0 * sc)
	v.annoy(0.35)
	v.cry()
	if grumpy:
		a.slide_now(a.anchor.x - dir * 60.0 * sc, 460.0 * sc)
		a.push(Vector2(-dir * 90.0, 0), a.pos + Vector2(dir * a.radius, 0))
	fx.puff(at, Pal.INK, 4, 14.0, 0.25)
	fx.sparks(at, Pal.INK_DIM, 4)
	Sfx.play("knock", 1.35 if grumpy else 1.6, -6.0)
	Sfx.play("whoosh", 1.4, -10.0)
	Sfx.haptic(8, 0.25)
	_name_trick("shove.name" if grumpy else "shove.nudge", a.pos)


func _answer_cry(t: Target) -> void:
	var giver := _nearest(t, func(o: Target) -> bool: return o.charm in DEFENSIVE and not o.aimed, 240.0) if t.charm == Target.Charm.NONE else null
	if giver:
		_toss_charm(giver.charm_pos(), t, giver.take_charm())
		_name_trick("mood.help", t.pos)
		return
	var guard := _nearest(t, func(o: Target) -> bool: return o.mood == Target.Mood.GRUMPY and _free_mover(o) and o.pos.y > t.pos.y + 30.0, 240.0)
	if guard:
		guard.annoy(0.4)
		guard.slide_now(t.anchor.x + (guard.anchor.x - t.anchor.x) * 0.15, 360.0 * layout.scale)
		guard.voice("taunt", -4.0)
		_name_trick("mood.help", t.pos)


# ---------------------------------------------------------------- variants & finale

## Families get variants as the run goes on (each introduced once).
func _roll_variant(t: Target) -> void:
	var w := director.wave
	var r := _rng.randf()
	# This wave's style for the kind leads most of the time.
	var st: Array = director.style.get(t.kind, [])
	if not st.is_empty() and st[0] == "var" and r < 0.65:
		if st[1] != Target.Var.STD:
			t.set_variant(st[1])
		return
	match t.kind:
		Target.Kind.DROP:
			if w >= 2 and r < 0.3:
				t.set_variant(Target.Var.BOB)
			elif w >= 3 and r < 0.5:
				t.set_variant(Target.Var.TWIN)
			elif w >= 4 and r < 0.65:
				t.set_variant(Target.Var.BIG)
		Target.Kind.RING:
			if w >= 2 and r < 0.2:
				t.set_variant(Target.Var.HOPPER)
			elif w >= 3 and r < 0.32:
				t.set_variant(Target.Var.BIG)


## A twin drop bursts into two little drops on short strings.
func _twin(t: Target) -> void:
	for side: float in [-1.0, 1.0]:
		var d := _free_target()
		if d == null:
			return
		var ax := clampf(t.anchor.x + side * 30.0, 40.0, layout.size.x - 40.0)
		var p := t.pos + Vector2(side * 12.0, 0)
		var anchor := Vector2(ax, layout.rail_y + 3.0)
		var len := anchor.distance_to(p)
		d.aggression = t.aggression
		d.spawn(Target.Kind.DROP, anchor, len, len, 0.0)
		d.radius = 13.0
		d.pos = p
		d.vel = Vector2(side * 140.0, -80.0)


## The wave's finale: on every third wave the boss, otherwise a champion
## (a bigger, grumpy, tougher one of the kinds met so far, with a trick).
func _spawn_finale() -> void:
	if director.boss_wave():
		if not _boss_alive():
			_spawn_boss()
		hud.card(Loc.t("finale.boss"), Loc.t("event.bossSub"), 1.6)
		Sfx.play("boss")
		return
	var pool: Array = [Target.Kind.RING, Target.Kind.HEAVY, Target.Kind.SPLIT, Target.Kind.REEL, Target.Kind.SHIELD, Target.Kind.MIRROR, Target.Kind.PAKKIS]
	var kinds: Array = []
	for k in pool:
		if Prefs.seen.has(k) or k == Target.Kind.RING:
			kinds.append(k)
	var t := _spawn_one(kinds[_rng.randi() % kinds.size()] as Target.Kind, 0.08)
	if t == null:
		return
	t.make_champion()
	if t.charm == Target.Charm.NONE and t.kind != Target.Kind.PAKKIS:
		t.set_charm(1 + _rng.randi() % 5)
	# It never comes alone: two grumpy escorts drop in beside it.
	for i in 2:
		var e := _spawn_one(director.pick_kind(_rng), 0.1)
		if e:
			e.set_mood(Target.Mood.GRUMPY)
			e.aggression = minf(1.0, e.aggression + 0.15)
	hud.card(Loc.t("finale.title"), Loc.t("finale.sub"), 1.6)
	Sfx.play("boss", 1.3, -4.0)
	Sfx.voice("taunt", 0.7, 0, -2.0)


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
	hud.open_pause(int(director.elapsed))
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
