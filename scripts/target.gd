class_name Target
extends Node2D
## A target hanging from the rail on an elastic string (pooled).
## Body: rigid disc on a one-sided spring with its own angular inertia, so
## off-centre hits make it wobble about the string. String: Verlet rope.
## Everything is drawn in world coordinates; the node itself stays at origin.

enum Kind { RING, HEAVY, SPLIT, ROD, DROP, SHIELD, BOSS, REEL, SHADE, MEDIC, MIRROR, PIPP, PAKKIS }
enum Phase { OFF, HANGING, FALLING }

const N := 10                  # rope points
const GRAVITY := 900.0
const STRING_K := 120.0        # spring stiffness per unit mass (1/s²)
const DAMPING := 1.1

const RADIUS := {Kind.RING: 30.0, Kind.HEAVY: 34.0, Kind.SPLIT: 32.0, Kind.ROD: 15.0, Kind.DROP: 20.0, Kind.SHIELD: 26.0, Kind.BOSS: 46.0, Kind.REEL: 24.0, Kind.SHADE: 26.0, Kind.MEDIC: 26.0, Kind.MIRROR: 27.0, Kind.PIPP: 19.0, Kind.PAKKIS: 26.0}
const HP := {Kind.RING: 1, Kind.HEAVY: 2, Kind.SPLIT: 1, Kind.ROD: 1, Kind.DROP: 1, Kind.SHIELD: 1, Kind.BOSS: 8, Kind.REEL: 1, Kind.SHADE: 1, Kind.MEDIC: 1, Kind.MIRROR: 1, Kind.PIPP: 1, Kind.PAKKIS: 1}
const POINTS := {Kind.RING: 10, Kind.HEAVY: 20, Kind.SPLIT: 10, Kind.ROD: 15, Kind.DROP: 5, Kind.SHIELD: 25, Kind.BOSS: 40, Kind.REEL: 20, Kind.SHADE: 25, Kind.MEDIC: 30, Kind.MIRROR: 35, Kind.PIPP: 15, Kind.PAKKIS: 35}
const ROD_HALF := 30.0
const HOOK_LEN := 11.5         # rail pivot -> bottom of the hook eyelet
const HOOK_TILT := 0.8
const MASS := {Kind.RING: 1.0, Kind.HEAVY: 1.6, Kind.SPLIT: 1.1, Kind.ROD: 1.25, Kind.DROP: 0.6, Kind.SHIELD: 1.3, Kind.BOSS: 3.5, Kind.REEL: 0.9, Kind.SHADE: 0.9, Kind.MEDIC: 0.9, Kind.MIRROR: 1.2, Kind.PIPP: 0.55, Kind.PAKKIS: 1.0}
const SHIELD_HALF := deg_to_rad(62.0)   # Vokter: half-width of the front plate
const BOSS_ARC_HALF := deg_to_rad(38.0) # Spinneren: half-width of each orbiting plate
# Spinneren fights in three stages (by health left): two plates; three
# narrower plates turning faster; one plate whipping round while it lunges
# and calls divers without pause. [plates, half-width, orbit speed factor,
# minion interval factor]
const BOSS_STAGES := [[2, 38.0, 1.0, 1.0], [3, 30.0, 1.25, 0.75], [1, 55.0, 2.0, 0.5]]
const ANG_K := 55.0            # angular spring back to the string angle (1/s²)
const ANG_C := 2.6             # angular damping (1/s)
# Evasion profile per kind: [reaction s (at aggression 0), slide px,
# slide speed px/s, hop px, aggression needed]. Reactions shorten and moves
# grow with aggression; every move is telegraphed by a narrowed, watching
# eye first, and followed by a cooldown, so it can be read and punished.
const EVADE := {
	Kind.RING: [0.7, 110.0, 330.0, 55.0, 0.0],
	Kind.HEAVY: [0.95, 60.0, 150.0, 0.0, 0.35],
	Kind.SPLIT: [0.55, 130.0, 390.0, 0.0, 0.2],
	Kind.ROD: [0.75, 90.0, 260.0, 0.0, 0.3],
	Kind.SHIELD: [0.9, 70.0, 210.0, 0.0, 0.5],
	Kind.REEL: [0.5, 85.0, 300.0, 0.0, 0.25],
	Kind.MEDIC: [0.6, 120.0, 340.0, 40.0, 0.1],
	Kind.MIRROR: [0.9, 70.0, 200.0, 0.0, 0.4],
	Kind.PIPP: [0.5, 110.0, 380.0, 50.0, 0.0],
	Kind.PAKKIS: [0.8, 90.0, 260.0, 0.0, 0.3],
}
# Material. Soft bodies are jelly: a ring of radial springs that dents
# where it is struck, bulges elsewhere (area is kept), ripples round and
# lags behind when the body is swung. Rigid bodies keep their shape; they
# ring briefly, rock and spin instead.
const SOFT_KINDS := [Kind.RING, Kind.SPLIT, Kind.DROP, Kind.SHADE, Kind.MEDIC, Kind.PIPP, Kind.PAKKIS]
const SOFT_N := 18
const SOFT_K := 340.0          # radial spring (1/s²)
const SOFT_C := 7.5            # damping (1/s)
const SOFT_COUPLE := 900.0     # neighbour coupling: dents spread as ripples
const SOFT_INERTIA := 0.0011   # how far the jelly sloshes per px/s² of swing
const POP_TIME := 0.08

# Temperament, rolled per target so no two behave quite alike.
enum Temper { CALM, TIMID, BOLD, ERRATIC }
# Personality, on top of temperament: how it looks and carries itself.
#   CURIOUS  keeps glancing at its neighbours
#   SLEEPY   heavy-lidded, slow to blink
#   JITTERY  blinks a lot, never quite still
#   PROUD    brows up, chin up
#   SHY      looks away, blushes when you aim at it
enum Trait { CURIOUS, SLEEPY, JITTERY, PROUD, SHY }

# Character. How each kind arrives: its own speed down the string (the
# Dykker drops and bounces on its bungee, heavy ones are lowered on their
# chain link by clanking link, the Snelle reels itself down, the Speilet
# spins in and flashes, the Skygge fades in on the way).
const ENTRY_SPEED := {Kind.DROP: 1700.0, Kind.HEAVY: 320.0, Kind.BOSS: 260.0, Kind.REEL: 420.0, Kind.MIRROR: 650.0}
# Voice register by size and build: small ones squeak, big ones rumble.
const VOICE_REG := {Kind.RING: 1.0, Kind.HEAVY: 0.62, Kind.SPLIT: 0.95, Kind.ROD: 0.82, Kind.DROP: 1.5, Kind.SHIELD: 0.75, Kind.BOSS: 0.5, Kind.REEL: 1.25, Kind.SHADE: 1.1, Kind.MEDIC: 1.18, Kind.MIRROR: 0.9, Kind.PIPP: 1.75, Kind.PAKKIS: 1.1}

const SPEED_MUL := {Kind.RING: 1.0, Kind.HEAVY: 0.85, Kind.SPLIT: 1.0, Kind.ROD: 1.1, Kind.DROP: 1.7, Kind.SHIELD: 0.9, Kind.BOSS: 0.45, Kind.REEL: 1.0, Kind.SHADE: 1.0, Kind.MEDIC: 0.9, Kind.MIRROR: 0.9, Kind.PIPP: 1.15, Kind.PAKKIS: 0.9}

var kind: Kind = Kind.RING
var soft := false
var temper: Temper = Temper.CALM
var trait_kind: Trait = Trait.CURIOUS
var _eye_scale := 1.0           # each face a little different
var _pupil_scale := 1.0
var _mouth_w := 1.0
var _smile := 1.0               # resting mouth: < 0 a pout, 1 a smile
var curious_in := 3.0           # the game uses it to pick a neighbour to look at
var _sd := PackedFloat32Array()  # soft: radial displacement per spoke (px)
var _sv := PackedFloat32Array()  # soft: radial velocity per spoke
var _last_vel := Vector2.ZERO
var _ring_t := 1.0             # rigid: time since the last knock (metal ring)
var _ring_dir := Vector2.RIGHT
var _wander_t := 3.0           # idle drift along the rail
var _hue_shift := 0.0          # each one a slightly different shade of its kind
var _val_shift := 0.0
var _dropping := false        # still paying out its string on the way in
var _gone := false             # burst jelly: the body is gone, the string recoils
var pop_t := 0.0               # soft: squashed for a moment before it bursts
# Teasing: close to the line they turn smug, dance and mock near misses.
var smug := 0.0                # 0..1: half-lidded eye and a raised brow
var _taunt := -1.0             # time into a taunt (<0: none)
var _taunt_in := 3.0           # until the next unprompted taunt
var _taunt_delay := -1.0       # a near miss is mocked a moment later
static var _last_tease_ms := 0
# Teamwork: a sturdy one steps into the line of fire to shield an ally.
var covered := false           # an ally is guarding this one: it holds still
var _guard_wait := -1.0        # reaction time before the guard moves
var _guard_x := 0.0
var guard_of: Target = null    # whom this one is shielding (eye follows it)
var _queued_x := NAN           # erratic: the real slide after the feint
var _queued_speed := 0.0
var phase: Phase = Phase.OFF
var hp := 1
var radius := 30.0
var anchor := Vector2.ZERO
var length := 100.0            # rest length of the string
var goal_length := 100.0       # drop-in target length
var delay := 0.0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var body_rot := 0.0
var danger := 0.0              # 0..1, how close to the danger line
var rope_alpha := 1.0
var squash_t := 1.0            # time since last hit (s)
var squash_dir := Vector2.UP
var spin := 0.0                # rad/s while falling
var tilt := 0.0                # perspective tilt phase while falling
var fall_t := 0.0
var ang_off := 0.0             # body angle relative to the string (rad)
var ang_vel := 0.0
var wind := 0.0                # horizontal breeze acceleration (px/s²)
var startle_t := 0.0           # wide eye + flinch after a near miss
var scared := false            # overload: panics, stops sinking, climbs its string
# Chain reactions: a struck body can knock into others; a falling one lands
# on whatever hangs below. `chain_depth` counts the links back to the ball.
var struck_t := 0.0
var chain_depth := 0
var crushed: Array[int] = []    # targets this falling body has already hit
# Formations march behind a leader (the crowned one); its hook sets theirs.
# Lose it and the rest panic for a moment (`stun_t`), wide open.
var leader: Target = null
var is_leader := false
var form_off := 0.0
var stun_t := 0.0
var hurry := false             # one of a wave's last few: sinks faster, shaking
var patched := false           # Legen's bubble: soaks the next blow
var wants_heal := false        # Legen asks the game for someone to mend
var _heal_t := 3.0
var boss_stage := 0            # Spinneren: 0, 1, 2
var field_w := 720.0           # play field width (set by the game)
# Depth in the room, -1 (back, near the wall) .. 1 (front). Purely visual:
# front ones draw a touch larger and brighter, back ones smaller and dimmer,
# and their shadows on the wall sit closer and sharper. The hit area never
# changes.
var depth := 0.0
# Swing toward (+) / away from (−) the camera, driven by the phone's lean:
# a damped pendulum in depth whose rate follows the string length. Visual,
# like depth; it adds to it wherever depth shows.
static var push_z := 0.0
# The team's nerve (-1 cocky .. 1 nervous), set by the game from how well
# the player is doing: nervous ones sweat, blink more and dilate; cocky
# ones turn smug even far from the line.
static var morale := 0.0
# What the team has learned (Director.Tactic), and what it knows of the
# player's rhythm: the usual hold before a release, how long the band has
# been held right now (<0: not aiming), and the column shot at least.
static var tactic := 0
static var rhythm := false
static var hold_avg := 0.0
static var aim_hold := -1.0
static var cold_x := NAN
var _rhythm_used := false       # one early dodge per aim
var _order_drop := 0.0          # a team plunge, waiting on its telegraph
# Blackout (0..1): bodies, strings and shadows sink into the dark; the
# faces (eyes) are drawn on their own layer and keep glowing.
static var dark := 0.0
const DARK_TINT := Color(0.13, 0.15, 0.2)
# Golden one: a rare gold ring worth a fortune. It never sinks and flees
# back up its string after GOLD_TIME.
const GOLD_TIME := 5.5
var golden := false
var _gold_t := 0.0
var fled := false               # it got away (the game says so)
# Evolution: a ring left hanging too long hardens into a heavy. It warns
# first (pulses and trembles) so there is a last chance.
static var evolve_on := false
const EVOLVE_AT := 18.0
const EVOLVE_WARN := 1.6
var _age := 0.0
var evolved := false            # hardened this frame (the game announces)
# Acrobatics: a swing across to a neighbour's rope. PUMP builds the swing
# (eyes locked on the rope it wants), FLY is the ballistic leap, and the
# rope is caught if the flight passes it. A body falling from a cut rope
# can also grab a friend's rope that sweeps through its path (a rescue).
enum Acro { NONE, PUMP, FLY }
const PUMP_ACC := 430.0         # px/s² added through the lower part of the swing
const PUMP_MAX_T := 6.0
const FLY_MAX_T := 1.3
const GRAB_REACH := 10.0        # px beyond the body's radius
const RESCUE_WINDOW := 0.7      # s a cut body can still grab a rope
static var acro_on := false
var acro := Acro.NONE
var _acro_t := 0.0
var swing_host: Target = null   # the rope it is heading for
var rope_host: Target = null    # whose rope (hook) it hangs on now
var rescuable := false          # falling from a cut, may still be caught
var slipped := false            # missed its grab: falls (the game scores it)
var grabbed := false            # caught a rope this frame (the game reacts)
var rescued := false            # ... and it was a rescue
# Nemesis: the one that got through comes back later in the run, scarred,
# smug and tougher (level: how many times it has got through).
var nemesis := 0
# Cunning: an armoured one hit but not beaten may play dead, hanging limp
# and still (one wary peek), then drop on you by surprise.
static var play_dead_on := false
const PLAY_DEAD_KINDS := [Kind.HEAVY, Kind.SHIELD, Kind.MIRROR]
var playdead := 0.0             # seconds of the act left
var _peek_at := 0.0
var surprised := false          # the act ended in a drop (the game says so)
# Trick charms: a skill made visible, a bead dangling under the body. It can
# be tossed, inherited, copied and handed out (the game moves them), and a
# ball through the bead breaks it.
enum Charm { NONE, BUBBLE, SPRING, GHOST, BALLOON, VINE }
const CHARM_COL := [Color.WHITE, Color("7FE0C0"), Color("8FD0FF"), Color("F29CC8"), Color("FFB27A"), Color("9BD86A")]
const BUBBLE_BACK := 8.0
var charm := Charm.NONE
var charm_flash := 0.0
var wants_vine := false
var _charm_cd := 0.0
var _ghost_t := 0.0
var _pipp_hop := 1.5
# Mood, on top of kind and temper, rolled at spawn: grumpy ones glare, steam
# and get angrier (nearby misses, fallen friends) until they fly into a
# rage and drop; cute ones blush and sparkle, hide behind others when aimed
# at and cry for help, which their friends answer. Both are cunning.
enum Mood { NEUTRAL, GRUMPY, CUTE }
const RAGE_DROP := 55.0
var mood := Mood.NEUTRAL
var anger := 0.0                # grumpy: 0..1, a rage at 1
var raged := false              # flew into a rage this frame (the game names it)
var crying := 0.0               # cute: tears (s)
var wants_help := false         # cute: asks the game for a friend's help
var _help_cd := 0.0
# Variants: members of a family that look and act a little differently.
#   Dykker (DROP):  BOB (mint) bobs on its bungee; TWIN (lilac) splits into
#                   two little drops; BIG (deep blue) is large, takes two
#                   hits and dives further.
#   Vakt (RING):    HOPPER (pink) hops sideways now and then; BIG (deep
#                   blue) is large, takes two hits and is slower.
enum Var { STD, BOB, TWIN, BIG, HOPPER }
const VARIANT_TINT := [Color.WHITE, Color("7FE3B8"), Color("C3A8FF"), Color("3C6BD6"), Color("FF9CC6")]
var variant := Var.STD
# Champion: a wave's finale, bigger, tougher, grumpy, ringed in gold.
var champion := false
var _bob_off := 0.0
var _bob_ph := 0.0
var _hopper_t := 2.5
# Stance: how it feels right now, read from what happens to it, shown in its
# colour and a small sign, and felt in how it acts.
#   CALM     at ease
#   WARY     aimed at again and again: paler, quicker to dodge, never bold
#   FURIOUS  a friend fell or it was hit: warmer, sinks faster, lunges once
#   VETERAN  has hung on a long time: deeper colour, one more life, smarter
enum Stance { CALM, WARY, FURIOUS, VETERAN }
const STANCE_TINT := [Color.WHITE, Color("DCE8F4"), Color("FF6F86"), Color("2B2F72")]
const VETERAN_AT := 24.0
var stance := Stance.CALM
var stance_changed := false     # for the game to name (once per run)
var stance_flash := 0.0
var _stance_k := 0.0
var _fury_t := 0.0
var _aimed_n := 0
var _was_aimed := false
var _alive_t := 0.0
var _veteran_paid := false
var _floor_hits := 0           # falling: bounces on the floor so far
var _settle_t := 0.0
var _watch: Target = null       # a neighbour it is looking at (fall, arrival)
var _watch_t := 0.0
var landed := false             # arrived this frame (the game tells neighbours)
var _entry_run := 0.0
var _admire_t := 0.0            # Speilet admiring its own reflection
var _vain_in := 6.0
var _jolt_cd := 0.0
var z_swing := 0.0
var _z_vel := 0.0
var stage_changed := false     # for the game to announce

# Brain: every behaviour is telegraphed before it acts, so it can be read.
var aggression := 0.0          # 0..1 from the director
var aimed := false             # the player's aim line is on this target
var dodge_dir := 0.0           # side to dodge toward (set by the game)
var threat := Vector2.ZERO     # where the shots come from (shield faces it)
var enraged := false
var tele_t := 0.0              # telegraph (tremble + squint) before a lunge
var shield_ang := PI * 0.5     # world angle of the Vokter plate
var orbit := 0.0               # Spinneren plate orbit
var wants_minion := false      # Spinneren asks the game for a Dykker
var flash_t := 0.0
var alarm := false             # a ball is closing in (Snelle reels up)
var has_cover := false         # Vakt: an x where another target shields it
var cover_x := 0.0
var hidden_amt := 0.0          # Skygge: 0 solid .. 1 faded out
var intro_t := 0.0             # marker ring when first introduced
var fray_t := 0.0              # string frayed: a second precise hit cuts it
var _fray_at := Vector2.ZERO
var _reeled := 0.0
var _calm_t := 0.0
var _shade_t := 0.0
var _shade_hidden := false
var _aim_t := 0.0
var _dodge_cd := 0.0
# Threat reading (set by the game each frame from the predicted shot).
var threat_lvl := 0.0          # 0..1, how squarely the shot path crosses it
var incoming := false          # a ball in flight will pass close, with time to react
var slide_lo := 0.0            # the anchor may slide within [lo, hi] on the rail
var slide_hi := 0.0
var _slide_to := NAN
var _slide_speed := 0.0
var _hop_left := 0.0
var _hopped := 0.0
var _brain_t := 3.0
var _minion_t := 4.0
var _lunge_left := 0.0
var _speed_bonus := 1.0
var _cut := false
var look_at := Vector2.ZERO    # world point the pupil follows
var has_look := false
var squint := false            # nearest target while the player aims
var _pupil := Vector2.ZERO
var _open := 1.0
var _closed_t := 0.0           # "–" eye after a hit
var _blink_in := 4.0
var _blink_t := 0.0
var _clock := 0.0

var _body: Node2D                  # lit layer: string, shadow, body (see rendering)
var _face: Node2D                  # face layer: eye, mouth, details
var _xf := Transform2D.IDENTITY    # this frame's body transform
var _jit := Vector2.ZERO           # this frame's tremble, shared by every layer
var _m_pts := PackedVector2Array()  # body mesh (body space)
var _m_base := PackedVector2Array() # rest positions (jelly moves from these)
var _m_uv := PackedVector2Array()   # band-coded normals
var _m_sh := PackedVector2Array()   # the same, in the shadow band
var _m_idx := PackedInt32Array()
var _m_col := PackedColorArray()
var _m_dv := PackedInt32Array()     # vertices the jelly moves
var _m_dd := PackedVector2Array()   # ... along this direction
var _m_ds := PackedFloat32Array()   # ... by the surface at this spoke
var _m_mem := 0                     # leading vertices: the membrane
var _m_dim := Vector2i(-1, -1)      # vertex range at reduced alpha (cracked ring)
var _m_key := -1
var _one_col := PackedColorArray([Color.WHITE])
var _r_mid := PackedVector2Array()
var _c_pts := PackedVector2Array()  # chain links (world space)
var _c_uv := PackedVector2Array()
var _c_sh := PackedVector2Array()
var _c_idx := PackedInt32Array()  # string strip (world space)
var _r_pts := PackedVector2Array()
var _r_uv := PackedVector2Array()
var _r_idx := PackedInt32Array()
var _p_pts := PackedVector2Array()  # armour plates (world space)
var _p_uv := PackedVector2Array()
var _p_idx := PackedInt32Array()
var _p_col := PackedColorArray()

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rope_len := 0.0
var _attached := true
var _screen_h := 1280.0
var _pluck_cd := 0.0


func _ready() -> void:
	_pts.resize(N)
	_prev.resize(N)
	_sd.resize(SOFT_N)
	_sv.resize(SOFT_N)
	_setup_canvas()
	visible = false


func spawn(k: Kind, anchor_pos: Vector2, start_len: float, target_len: float, wait: float) -> void:
	kind = k
	soft = k in SOFT_KINDS
	_m_key = -1
	_sd.fill(0.0)
	_sv.fill(0.0)
	_last_vel = Vector2.ZERO
	_ring_t = 1.0
	_wander_t = randf_range(2.0, 5.0)
	_queued_x = NAN
	pop_t = 0.0
	_gone = false
	_dropping = false
	_hue_shift = randf_range(-0.04, 0.04)
	_val_shift = randf_range(-0.05, 0.05)
	covered = false
	_guard_wait = -1.0
	guard_of = null
	smug = 0.0
	_taunt = -1.0
	_taunt_in = randf_range(2.0, 4.0)
	_taunt_delay = -1.0
	temper = _roll_temper()
	_roll_trait()
	if k == Kind.PIPP:
		# Baby proportions: big eyes.
		_eye_scale *= 1.3
		_pupil_scale *= 1.15
	hp = HP[k]
	radius = RADIUS[k]
	anchor = anchor_pos
	length = start_len
	goal_length = target_len
	delay = wait
	pos = anchor + Vector2(0, start_len)
	vel = Vector2.ZERO
	body_rot = 0.0
	ang_off = 0.0
	ang_vel = 0.0
	startle_t = 0.0
	scared = false
	struck_t = 0.0
	chain_depth = 0
	crushed.clear()
	leader = null
	is_leader = false
	form_off = 0.0
	stun_t = 0.0
	hurry = false
	patched = false
	wants_heal = false
	_heal_t = randf_range(2.0, 3.0)
	boss_stage = 0
	stage_changed = false
	z_swing = 0.0
	_z_vel = 0.0
	_jolt_cd = 0.0
	_watch = null
	_watch_t = 0.0
	landed = false
	_entry_run = 0.0
	_admire_t = 0.0
	_vain_in = randf_range(4.0, 8.0)
	# Armoured kinds keep to the middle plane: their plates are world-sized.
	depth = 0.0 if k == Kind.SHIELD or k == Kind.BOSS else randf_range(-0.85, 0.85)
	_pluck_cd = 0.0
	aimed = false
	enraged = false
	tele_t = 0.0
	flash_t = 0.0
	wants_minion = false
	orbit = randf() * TAU
	shield_ang = PI * 0.5
	_aim_t = 0.0
	_dodge_cd = 1.0
	threat_lvl = 0.0
	incoming = false
	slide_lo = anchor_pos.x
	slide_hi = anchor_pos.x
	_slide_to = NAN
	_hop_left = 0.0
	_hopped = 0.0
	_brain_t = randf_range(2.5, 5.0)
	_minion_t = 4.0
	_lunge_left = 0.0
	_order_drop = 0.0
	_rhythm_used = false
	golden = false
	_gold_t = 0.0
	fled = false
	_age = 0.0
	evolved = false
	acro = Acro.NONE
	_acro_t = 0.0
	swing_host = null
	rope_host = null
	rescuable = false
	slipped = false
	grabbed = false
	rescued = false
	nemesis = 0
	playdead = 0.0
	surprised = false
	charm = Charm.NONE
	charm_flash = 0.0
	mood = Mood.NEUTRAL
	anger = 0.0
	variant = Var.STD
	champion = false
	stance = Stance.CALM
	stance_changed = false
	stance_flash = 0.0
	_stance_k = 0.0
	_fury_t = 0.0
	_aimed_n = 0
	_was_aimed = false
	_alive_t = 0.0
	_veteran_paid = false
	_floor_hits = 0
	_settle_t = 0.0
	_bob_off = 0.0
	_bob_ph = randf() * TAU
	_hopper_t = randf_range(1.5, 3.0)
	raged = false
	crying = 0.0
	wants_help = false
	_help_cd = 0.0
	wants_vine = false
	_charm_cd = 0.0
	_ghost_t = 0.0
	_pipp_hop = randf_range(0.8, 2.0)
	_speed_bonus = 1.0
	_cut = false
	alarm = false
	has_cover = false
	hidden_amt = 0.0
	intro_t = 0.0
	fray_t = 0.0
	_reeled = 0.0
	_calm_t = 0.0
	_shade_t = randf_range(1.5, 3.0)
	_shade_hidden = false
	danger = 0.0
	rope_alpha = 1.0
	squash_t = 1.0
	spin = 0.0
	tilt = 0.0
	fall_t = 0.0
	modulate.a = 1.0
	_pupil = Vector2.ZERO
	_open = 1.0
	_closed_t = 0.0
	_blink_in = randf_range(3.0, 7.0)
	_blink_t = 0.0
	_clock = randf() * 10.0
	_attached = true
	_rope_len = start_len
	for i in N:
		_pts[i] = anchor.lerp(pos, float(i) / (N - 1))
		_prev[i] = _pts[i]
	phase = Phase.HANGING
	visible = true
	if k == Kind.ROD:
		vel.x = 70.0 if randf() < 0.5 else -70.0


## Most are calm early on; the mix grows livelier as aggression rises.
func _roll_temper() -> Temper:
	var r := randf()
	var a := aggression
	if kind == Kind.BOSS:
		return Temper.CALM
	if r < 0.22 + 0.1 * a:
		return Temper.TIMID
	if r < 0.4 + 0.15 * a:
		return Temper.BOLD
	if r < 0.52 + 0.2 * a:
		return Temper.ERRATIC
	return Temper.CALM


## Personality follows temperament (a timid one is shy or jittery, a bold
## one proud...), and the face gets its own proportions.
func _roll_trait() -> void:
	var pool: Array = [Trait.CURIOUS, Trait.SLEEPY]
	match temper:
		Temper.TIMID:
			pool = [Trait.SHY, Trait.JITTERY, Trait.SHY]
		Temper.BOLD:
			pool = [Trait.PROUD, Trait.PROUD, Trait.CURIOUS]
		Temper.ERRATIC:
			pool = [Trait.JITTERY, Trait.CURIOUS]
	trait_kind = pool[randi() % pool.size()]
	_eye_scale = randf_range(0.88, 1.12)
	_pupil_scale = randf_range(0.85, 1.15)
	_mouth_w = randf_range(0.8, 1.2)
	_smile = randf_range(-0.3, 1.0) if trait_kind != Trait.PROUD else randf_range(-0.4, 0.2)
	curious_in = randf_range(1.5, 4.0)


static func is_soft_kind(k: int) -> bool:
	return k in SOFT_KINDS


const TAUNT_TIME := 0.9


## Arrival: the string snaps taut and the body bounces on it; jelly dents
## from below, a shell rings.
func _land() -> void:
	landed = true
	vel.y += 50.0
	dent(pos + Vector2(0, radius), 320.0)
	if not soft:
		_ring_t = 0.0
		_ring_dir = Vector2.DOWN
	match kind:
		Kind.DROP:
			# Bungee: it overshoots, bounces and settles.
			vel.y += 260.0
			dent(pos + Vector2(0, radius), 520.0)
		Kind.HEAVY, Kind.BOSS:
			vel.y += 90.0
			Sfx.play("clank", 0.8, -10.0)
		Kind.MIRROR:
			tilt = 0.0
			flash_t = 0.12
			Sfx.play("metal", 1.6, -14.0)
	Sfx.play("knock", randf_range(0.9, 1.15), -12.0)
	if randf() < 0.35:
		voice("up", -9.0)


func _on_entry() -> void:
	match kind:
		Kind.REEL:
			Sfx.play("reel", 0.9, -6.0)
		Kind.SHADE:
			hidden_amt = 1.0
		Kind.DROP:
			Sfx.play("whoosh", 1.3, -10.0)


## Sings one syllable on a note of the key, in this kind's register.
func voice(shape: String, db := 0.0) -> void:
	var reg: float = VOICE_REG[kind] * (0.82 if mood == Mood.GRUMPY else (1.22 if mood == Mood.CUTE else 1.0))
	Sfx.voice(shape, reg, randi() % 4, db)


## Looks at a neighbour for a moment (it fell, or just arrived).
func watch(o: Target, t: float) -> void:
	if o == self or aimed:
		return
	_watch = o
	_watch_t = t


const GUARD_KINDS := [Kind.HEAVY, Kind.SHIELD]


## Asked to shield `ally`: after a short, readable beat (the eye turns to
## the ally) the hook slides so the body sits on the shot line at `x`.
func guard(x: float, ally: Target) -> bool:
	if not (kind in GUARD_KINDS) or aggression < 0.25 or enraged or _dodge_cd > 0.0 or _guard_wait >= 0.0:
		return false
	_guard_x = x
	guard_of = ally
	_guard_wait = lerpf(0.45, 0.2, aggression)
	return true


func _guard_step(dt: float) -> void:
	if _guard_wait < 0.0:
		return
	_guard_wait -= dt
	if _guard_wait < 0.0:
		var sc := _screen_h / 1280.0
		_slide(anchor.x + (_guard_x - pos.x), EVADE[kind][2] * 1.2 * sc)
		_dodge_cd = lerpf(2.4, 1.2, aggression)
		startle_t = 0.2



## The closer to the line, the smugger (bold ones sooner, timid ones never);
## smug ones break into a little dance now and then.
func _tease(dt: float) -> void:
	var start := 0.25 if temper == Temper.BOLD else 0.4
	var want := 0.0 if (temper == Temper.TIMID or scared) else maxf(smoothstep(start, start + 0.25, danger), -morale * 0.55)
	smug = move_toward(smug, want, dt * 1.5)
	if _taunt_delay >= 0.0:
		_taunt_delay -= dt
		if _taunt_delay < 0.0:
			taunt()
	if _taunt >= 0.0:
		_taunt += dt
		if _taunt >= TAUNT_TIME:
			_taunt = -1.0
	elif smug > 0.5 and not aimed:
		_taunt_in -= dt
		if _taunt_in <= 0.0:
			_taunt_in = randf_range(1.5, 3.0) if temper == Temper.BOLD else randf_range(2.5, 4.5)
			taunt()


## A wiggle-and-bob, a wink and (rarely, quietly) a "na-na".
func taunt() -> void:
	if _taunt >= 0.0 or phase != Phase.HANGING or temper == Temper.TIMID or _closed_t > 0.0 or scared:
		return
	_taunt = 0.0
	_blink_t = 0.12
	if soft:
		for i in SOFT_N:
			_sv[i] += cos(3.0 * i * TAU / SOFT_N) * 90.0 * (radius / 30.0)
	var now := Time.get_ticks_msec()
	if now - _last_tease_ms > 1600:
		_last_tease_ms = now
		voice("taunt", -2.0)


## The phone was jerked downward: does this one take fright and climb?
## Heavy and armoured bodies hold on (they only sway); bold ones laugh it
## off with a taunt; timid ones always flee up; the rest are likelier to
## the closer they hang to the line. A row follows its leader's choice.
func wants_climb(rng_value: float) -> bool:
	if kind in [Kind.HEAVY, Kind.SHIELD, Kind.BOSS, Kind.MIRROR] or panicked() or _jolt_cd > 0.0:
		return false
	match temper:
		Temper.BOLD:
			return false
		Temper.TIMID:
			return true
	var p := (0.45 if temper == Temper.CALM else 0.55) + danger * 0.6
	return rng_value < p


## Startled up the string: a quick climb (the Snelle winches further), paid
## back out once things are calm again, as after a dodge.
func jolt(scale: float) -> void:
	_jolt_cd = 5.0
	startle_t = 0.4
	var up := (95.0 if kind == Kind.REEL else 60.0) * scale * lerpf(1.0, 1.4, danger)
	_hop_left += up
	_dodge_cd = maxf(_dodge_cd, 1.2)


## A strike on a soft body: the spokes near the contact are driven inward
## (the dent), the rest take up the displaced area on the next step.
func dent(at: Vector2, speed: float) -> void:
	if not soft:
		_ring_t = 0.0
		_ring_dir = (pos - at).normalized()
		return
	var la := (at - pos).angle() - body_rot
	var k := clampf(speed * 0.55, 60.0, 520.0) * (radius / 30.0)
	for i in SOFT_N:
		var d := angle_difference(la, i * TAU / SOFT_N)
		_sv[i] -= k * exp(-pow(d / 0.6, 2.0))


func _soft_step(dt: float) -> void:
	if not soft or dt <= 0.0:
		return
	var acc := (vel - _last_vel) / dt
	_last_vel = vel
	acc = acc.limit_length(9000.0)
	var mean := 0.0
	var lim := radius * 0.28
	for i in SOFT_N:
		var dir := Vector2.from_angle(i * TAU / SOFT_N + body_rot)
		var lap := _sd[(i + SOFT_N - 1) % SOFT_N] + _sd[(i + 1) % SOFT_N] - 2.0 * _sd[i]
		var f := -SOFT_K * _sd[i] - SOFT_C * _sv[i] + SOFT_COUPLE * lap * 0.25
		# Inertia: speeding up to the right, the jelly lags to the left.
		f += acc.dot(dir) * SOFT_INERTIA * radius
		_sv[i] += f * dt
	for i in SOFT_N:
		_sd[i] = clampf(_sd[i] + _sv[i] * dt, -lim, lim)
		mean += _sd[i]
	mean /= SOFT_N
	for i in SOFT_N:
		_sd[i] -= mean


func is_hittable() -> bool:
	return phase == Phase.HANGING and delay <= 0.0


## Balls collide with the body only while it is there (Skygge fades out).
func is_solid() -> bool:
	return is_hittable() and hidden_amt < 0.6


func points() -> int:
	return POINTS[kind]


func speed_mul() -> float:
	return SPEED_MUL[kind]


func mass() -> float:
	return MASS[kind] * (1.5 if variant == Var.BIG else 1.0) * (1.4 if champion else 1.0)


## Circle used for target-to-target contact (the rod uses its half span).
func contact_radius() -> float:
	return ROD_HALF + radius * 0.4 if kind == Kind.ROD else radius


## A falling body meets the walls and the floor like a real object: it
## bounces off with some of its speed (jelly less, shells more), picks up
## spin from the scrape, and rolls along the floor as it settles.
func _debris_bounce(screen_h: float) -> void:
	var e := 0.3 if soft else 0.5
	var r := shape_radius()
	if pos.x < r and vel.x < 0.0:
		pos.x = r
		vel.x = -vel.x * e
		spin = -spin * 0.6 + vel.y / maxf(r, 1.0) * 0.3
	elif pos.x > field_w - r and vel.x > 0.0:
		pos.x = field_w - r
		vel.x = -vel.x * e
		spin = -spin * 0.6 - vel.y / maxf(r, 1.0) * 0.3
	var floor_y := screen_h * 0.965
	if pos.y + r > floor_y and vel.y > 0.0:
		pos.y = floor_y - r
		var speed := vel.y
		vel.y = -vel.y * (e * 0.75 if _floor_hits == 0 else e * 0.4)
		vel.x *= 0.75
		# Rolling: the spin matches the ground speed.
		spin = vel.x / maxf(r, 1.0)
		tilt = 0.0
		_floor_hits += 1
		squash_t = 0.0
		squash_dir = Vector2.UP
		if speed > 120.0 and _floor_hits <= 2:
			var loud := linear_to_db(clampf(speed / 1400.0, 0.1, 0.55))
			if soft:
				Sfx.play("squish", randf_range(0.8, 0.95), loud - 6.0)
			elif kind in [Kind.SHIELD, Kind.MIRROR, Kind.BOSS]:
				Sfx.play("metal", randf_range(0.8, 0.95), loud - 6.0)
			else:
				Sfx.play("wood", randf_range(0.8, 0.95), loud - 6.0)


## Radius of the collision shape around `closest_point` (a rod's capsule
## is its half-thickness; everything else a circle).
func shape_radius() -> float:
	return radius if kind != Kind.ROD else radius * 0.6


## A body pressed in a collision: a quick squash along the blow.
func bump(n: Vector2, speed: float) -> void:
	if speed < 60.0:
		return
	if soft:
		if squash_t > 0.1:
			squash_t = 0.0
			squash_dir = n
	elif _ring_t > 0.1:
		# A shell rings briefly where it was struck.
		_ring_t = 0.0
		_ring_dir = n


## The screen's sides are walls: a swinging body bounces off them.
func keep_in(w: float) -> void:
	var r := shape_radius() + 2.0
	if pos.x < r:
		pos.x = r
		vel.x = absf(vel.x) * 0.45
	elif pos.x > w - r:
		pos.x = w - r
		vel.x = -absf(vel.x) * 0.45


## Pushes this rope's free points out of body `o` (the rope bends round it).
func rope_avoid(o: Target) -> void:
	if not _attached or rope_alpha <= 0.0:
		return
	var r := o.shape_radius() + 1.5
	for i in range(1, N - 1):
		var p := _pts[i]
		var q := o.closest_point(p)
		var d := p - q
		var l := d.length()
		if l < r and l > 0.001:
			_pts[i] = q + d / l * r


## Closest point of the body's collision shape to `p`.
func closest_point(p: Vector2) -> Vector2:
	if kind != Kind.ROD:
		return pos
	var axis := Vector2.RIGHT.rotated(body_rot) * ROD_HALF
	var a := pos - axis
	var b := pos + axis
	return Geometry2D.get_closest_point_to_segment(p, a, b)


func bottom_y() -> float:
	return pos.y + radius


## A falling body still solid and fast enough to knock off what it meets.
func is_crushing(min_speed: float) -> bool:
	return phase == Phase.FALLING and pop_t <= 0.0 and not _gone and modulate.a > 0.35 and vel.length() > min_speed


func was_cut() -> bool:
	return _cut


## True when a contact from direction `n` (centre → ball) lands on armour
## (or on Legen's bubble, which soaks any blow once).
func blocks(n: Vector2) -> bool:
	if patched:
		return true
	match kind:
		Kind.SHIELD:
			return absf(angle_difference(n.angle(), shield_ang)) < SHIELD_HALF
		Kind.BOSS:
			var st: Array = BOSS_STAGES[boss_stage]
			for k in int(st[0]):
				if absf(angle_difference(n.angle(), orbit + TAU * k / st[0])) < deg_to_rad(st[1]):
					return true
	return false


## Frightened out of its wits: overload, or its leader just fell.
func panicked() -> bool:
	return scared or stun_t > 0.0


## Distance test against the top third of the string, just under the hook:
## cutting is a precision shot, not something a stray ball does by luck.
func rope_hit(p: Vector2, r: float) -> bool:
	if not _attached:
		return false
	for i in range(0, 3):
		if Geometry2D.get_closest_point_to_segment(p, _pts[i], _pts[i + 1]).distance_to(p) < r + 1.5:
			return true
	return false


## A precise hit on the string: the first frays it (visible for 4 s), a
## second one while frayed severs it. Returns true when it severed.
func strike_string(p: Vector2) -> bool:
	if fray_t > 0.0:
		cut()
		return true
	fray_t = 4.0
	_fray_at = p
	for i in range(1, 4):
		_prev[i] = _pts[i] - Vector2(randf_range(-2.0, 2.0), 3.0)
	return false


## The string is severed: the body falls whatever its armour or health.
func cut() -> void:
	_cut = true
	voice("down", -2.0)
	hp = 0
	_closed_t = 1.2
	flash_t = 0.07
	_snap(Vector2(0, 60))


## Returns true if the target died from this hit. `at` is the contact point:
## off-centre contacts add torque, so the body wobbles about its string.
func hit(impulse: Vector2, at: Vector2) -> bool:
	var m: float = MASS[kind]
	vel += impulse / m
	var arm := at - pos
	ang_vel += clampf(arm.cross(impulse) / (radius * radius * m) * 0.9, -14.0, 14.0)
	squash_t = 0.0
	squash_dir = impulse.normalized() if impulse.length() > 0.01 else Vector2.UP
	_closed_t = 1.2 if kind != Kind.BOSS else 0.35
	flash_t = 0.07
	struck_t = 0.45
	hp -= 1
	if hp > 0:
		enrage(3.0)
		annoy(0.5)
		if mood == Mood.CUTE:
			cry()
		if play_dead_on and kind in PLAY_DEAD_KINDS and playdead <= 0.0 and leader == null and not is_leader and randf() < 0.45:
			_play_dead()
			return false
		if kind == Kind.HEAVY and not enraged:
			# Bulwark rage: throws itself down and sinks faster from now on.
			enraged = true
			_lunge_left += 60.0
			_speed_bonus = 1.6
			Sfx.play("whoosh", 0.8, -6.0)
		elif kind == Kind.BOSS:
			var st := 0 if hp > 5 else (1 if hp > 2 else 2)
			if st != boss_stage:
				boss_stage = st
				stage_changed = true
				enraged = st == 2
				_speed_bonus = 1.0 + 0.2 * st
				_brain_t = minf(_brain_t, 1.0)
		return false
	_snap(impulse)
	voice("down")
	if soft:
		pop_t = POP_TIME
		vel = Vector2.ZERO
		spin = 0.0
	return true


## Knock from a neighbour or a near miss: no damage, only motion.
func push(impulse: Vector2, at: Vector2) -> void:
	var m: float = MASS[kind]
	vel += impulse / m
	ang_vel += clampf((at - pos).cross(impulse) / (radius * radius * m) * 0.6, -6.0, 6.0)


## A ball crossing the string plucks it. Returns true when it did.
func pluck(p: Vector2, v: Vector2, r: float) -> bool:
	if not _attached or _pluck_cd > 0.0:
		return false
	var hit_any := false
	for i in range(2, N - 2):
		if _pts[i].distance_to(p) < r + 5.0:
			hit_any = true
			break
	if not hit_any:
		return false
	_pluck_cd = 0.25
	var kick := Vector2(v.x, v.y * 0.3).limit_length(900.0) * (1.0 / 120.0) * 0.45
	for i in range(1, N - 1):
		var fall := exp(-pow(_pts[i].distance_to(p) / 60.0, 2.0))
		_prev[i] = _pts[i] - kick * fall
	vel += Vector2(v.x, 0).limit_length(600.0) * 0.04 / MASS[kind]
	return true


func startle(from: Vector2) -> void:
	if startle_t > 0.0 or _closed_t > 0.0:
		return
	startle_t = 0.45
	voice("up", -3.0)
	# Missed it: once the fright passes, it mocks you.
	if temper != Temper.TIMID and _taunt_delay < 0.0:
		_taunt_delay = 0.5
	var away := (pos - from).normalized()
	push(away * 45.0, pos - away * radius * 0.5 + Vector2(0, -radius * 0.3))


func step(dt: float, descent: float, danger_y: float, danger_band: float, screen_h: float) -> void:
	_screen_h = screen_h
	_pluck_cd = maxf(0.0, _pluck_cd - dt)
	struck_t = maxf(0.0, struck_t - dt)
	stun_t = maxf(0.0, stun_t - dt)
	_jolt_cd = maxf(0.0, _jolt_cd - dt)
	flash_t = maxf(0.0, flash_t - dt)
	fray_t = maxf(0.0, fray_t - dt)
	match phase:
		Phase.HANGING:
			if delay > 0.0:
				delay -= dt
				visible = delay <= 0.0
				return
			if acro == Acro.FLY:
				_fly_step(dt, danger_y, danger_band)
				return
			if length < goal_length:
				var sp: float = ENTRY_SPEED.get(kind, 900.0) * (_screen_h / 1280.0)
				if not _dropping:
					_on_entry()
				var step_len := minf(goal_length - length, sp * dt)
				length += step_len
				_dropping = true
				_entry_run += step_len
				if (kind == Kind.HEAVY or kind == Kind.BOSS) and _entry_run > 34.0:
					# Lowered on its chain: a quiet clank per few links.
					_entry_run = 0.0
					Sfx.play("clank", randf_range(1.3, 1.5), -20.0)
				if kind == Kind.MIRROR:
					tilt += 11.0 * dt
			else:
				if _dropping:
					_dropping = false
					_land()
				if scared:
					# Overload: it scrambles back up its string, away from you.
					length = maxf(60.0 * (_screen_h / 1280.0), length - 35.0 * dt)
				elif golden:
					_gold_step(dt)
				elif playdead > 0.0:
					_dead_step(dt)
				else:
					length += descent * SPEED_MUL[kind] * _speed_bonus * (2.0 if hurry else 1.0) * (0.55 if charm == Charm.BALLOON else 1.0) * (1.0 + 0.35 * anger) * (1.3 if stance == Stance.FURIOUS else 1.0) * dt
				goal_length = length
				_evolve_step(dt)
			if panicked():
				tele_t = 0.0
				_lunge_left = 0.0
				_order_drop = 0.0
				_dodge_cd = maxf(_dodge_cd, 0.5)
				acro = Acro.NONE
			elif playdead > 0.0:
				pass
			elif acro == Acro.PUMP:
				_pump_step(dt)
			elif rope_host != null:
				_ride_step()
			else:
				_brain(dt)
			_charm_step(dt)
			_mood_step(dt)
			_stance_step(dt)
			_move_anchor(dt)
			if _lunge_left > 0.0:
				var step_len := minf(_lunge_left, 340.0 * dt)
				length += step_len
				goal_length = length
				_lunge_left -= step_len
			_body_step(dt)
			_z_step(dt)
			_tease(dt)
			if nemesis > 0:
				smug = maxf(smug, 0.75)
			_soft_step(dt)
			danger = clampf(1.0 - (danger_y - bottom_y()) / danger_band, 0.0, 1.0)
			_rope_step(dt)
		Phase.FALLING:
			if pop_t > 0.0:
				# Jelly holds still, squashed around the blow, then bursts.
				pop_t -= dt
				_soft_step(dt)
				_rope_step(dt)
				if pop_t <= 0.0:
					_gone = true
				return
			fall_t += dt
			vel.y += GRAVITY * dt
			pos += vel * dt
			_debris_bounce(screen_h)
			if rescuable and fall_t < RESCUE_WINDOW and swing_host != null and _try_grab(swing_host):
				rescued = true
				return
			body_rot += spin * dt
			tilt += 4.5 * dt
			_soft_step(dt)
			# Burst jelly is gone; only its recoiling string remains. A body
			# that fell whole lands, bounces and rolls, then fades.
			if not _gone:
				if _floor_hits >= 2 or fall_t > 2.6:
					_settle_t += dt
				modulate.a = clampf(1.0 - _settle_t / 0.5, 0.0, 1.0)
			_rope_step(dt)
			if (pos.y - radius > screen_h + 40.0 or modulate.a <= 0.0 or _gone) and rope_alpha <= 0.0:
				phase = Phase.OFF
				visible = false


## Per-type behaviour. Aggression (0..1) shortens reactions and cooldowns.
func _brain(dt: float) -> void:
	var a := aggression
	_dodge_cd = maxf(0.0, _dodge_cd - dt)
	_order_step(dt)
	if leader != null:
		if is_instance_valid(leader) and leader.is_hittable():
			# In formation: keep station on the leader's hook, no own moves.
			var want := clampf(leader.anchor.x + form_off, radius + 12.0, field_w - radius - 12.0)
			if absf(want - anchor.x) > 3.0:
				_slide_to = want
				_slide_speed = maxf(leader._slide_speed, 160.0 * _screen_h / 1280.0) * 1.15
			return
		leader = null
	_guard_step(dt)
	_wander(dt)
	if mood == Mood.CUTE and aimed and has_cover and kind != Kind.RING and a > 0.1 and _dodge_cd <= 0.0:
		# Cute: slips behind a bigger friend when you aim at it.
		_aim_t += dt
		if _aim_t > lerpf(0.55, 0.25, a):
			var prof: Array = EVADE.get(kind, [0.0, 0.0, 300.0])
			_slide(anchor.x + (cover_x - pos.x), float(prof[2]) * 0.8)
			_dodge_cd = lerpf(2.4, 1.2, a)
			_aim_t = 0.0
			startle_t = 0.3
		return
	if kind == Kind.MEDIC:
		_heal_t -= dt
		if _heal_t <= 0.0:
			_heal_t = lerpf(4.5, 2.6, a)
			wants_heal = true
	match kind:
		Kind.MEDIC, Kind.MIRROR, Kind.PAKKIS:
			_evade(dt)
		Kind.PIPP:
			_evade(dt)
			# A chick can't keep still: little hops on its string.
			_pipp_hop -= dt
			if _pipp_hop <= 0.0:
				_pipp_hop = randf_range(1.2, 2.4)
				vel.y -= 150.0
				squash_t = 0.0
				squash_dir = Vector2.UP
		Kind.RING:
			if variant == Var.HOPPER and not aimed:
				# Hoppering: a quick sideways hop now and then.
				_hopper_t -= dt
				if _hopper_t <= 0.0:
					_hopper_t = randf_range(2.0, 3.2)
					var sc := _screen_h / 1280.0
					var dir := -1.0 if randf() < 0.5 else 1.0
					if anchor.x + dir * 70.0 * sc > slide_hi or anchor.x + dir * 70.0 * sc < slide_lo:
						dir = -dir
					_slide(anchor.x + dir * randf_range(50.0, 80.0) * sc, 420.0 * sc, true)
					vel.y -= 110.0
					squash_t = 0.0
					squash_dir = Vector2.UP
			# Vakt: with cover available it slides its hook along the rail to
			# hang behind another target; otherwise it evades like the rest.
			if aimed and has_cover and a > 0.12 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.6, 0.25, a):
					_slide(anchor.x + (cover_x - pos.x), EVADE[kind][2] * 0.8)
					_dodge_cd = lerpf(2.4, 1.2, a)
					_aim_t = 0.0
					startle_t = 0.3
			else:
				_evade(dt)
		Kind.HEAVY, Kind.SPLIT:
			if not enraged:
				_evade(dt)
		Kind.ROD:
			_evade(dt)
			# Pendel: pumps its own swing up to a cap, so it is never still.
			var swing := atan2(pos.x - anchor.x, pos.y - anchor.y)
			if absf(swing) < lerpf(0.28, 0.5, a):
				var dir := signf(vel.x) if absf(vel.x) > 4.0 else (1.0 if randf() < 0.5 else -1.0)
				vel.x += dir * lerpf(40.0, 95.0, a) * dt
		Kind.DROP:
			# Dykker: when it sees the shot coming it ducks under it early.
			if (aimed or incoming) and a > 0.3 and tele_t <= 0.0 and _lunge_left <= 0.0 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.6, 0.25, a) or incoming:
					tele_t = 0.2
					_brain_t = lerpf(4.5, 2.2, a)
					_dodge_cd = lerpf(3.0, 1.6, a)
					_aim_t = 0.0
			if variant == Var.BOB:
				# Bobs on its bungee: never where you last saw it.
				var off := sin(_clock * 4.2 + _bob_ph) * 26.0 * (_screen_h / 1280.0)
				length += off - _bob_off
				goal_length = length
				_bob_off = off
			var big := variant == Var.BIG
			_lunge_brain(dt, lerpf(4.5, 2.2, a) * (1.5 if variant == Var.BOB else (1.4 if big else 1.0)), 85.0 if big else 50.0)
		Kind.SHIELD:
			# Vokter: the plate turns toward the slingshot with some lag.
			_evade(dt)
			var want := (threat - pos).angle()
			shield_ang = rotate_toward(shield_ang, want, lerpf(1.6, 3.6, a) * dt)
		Kind.REEL:
			_evade(dt)
			# Snelle: winches up toward the rail when threatened, lets itself
			# back down once it has been calm for a moment.
			if alarm or aimed:
				_calm_t = 0.0
				var d := minf(lerpf(240.0, 380.0, a) * dt, maxf(0.0, length - 40.0))
				if d > 0.0 and _reeled == 0.0:
					Sfx.play("reel", randf_range(0.95, 1.1))
				length -= d
				_reeled += d
			else:
				_calm_t += dt
				if _calm_t > lerpf(0.5, 1.0, a) and _reeled > 0.0:
					var u := minf(_reeled, 120.0 * dt)
					length += u
					_reeled -= u
			goal_length = length
		Kind.SHADE:
			# Skygge: visible for a while, then fades out (shots pass through),
			# then back. Only its eye and its string stay readable.
			_shade_t -= dt
			# Seen in the line of fire, it fades out early (once in a while).
			if aimed and not _shade_hidden and a > 0.3 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.7, 0.3, a):
					_shade_t = 0.0
					_dodge_cd = lerpf(4.0, 2.2, a)
					_aim_t = 0.0
			if _shade_t <= 0.0:
				_shade_hidden = not _shade_hidden
				_shade_t = lerpf(1.3, 1.9, a) if _shade_hidden else lerpf(2.6, 1.7, a) * randf_range(0.85, 1.2)
				if _shade_hidden:
					Sfx.play("fade", randf_range(0.95, 1.05))
			hidden_amt = move_toward(hidden_amt, 1.0 if _shade_hidden else 0.0, dt / 0.35)
		Kind.BOSS:
			# Spinneren: aimed at, it spins its plates faster to close the gap.
			var st: Array = BOSS_STAGES[boss_stage]
			orbit += lerpf(1.0, 1.7, a) * float(st[2]) * (lerpf(1.4, 2.2, a) if aimed else 1.0) * dt
			_minion_t -= dt
			if _minion_t <= 0.0:
				_minion_t = lerpf(6.0, 3.5, a) * float(st[3])
				wants_minion = true
			_lunge_brain(dt, lerpf(10.0, 6.0, a) * (0.45 if boss_stage == 2 else 1.0), 40.0)


## Common evasion: watch the shot (narrowed eye) for a reaction time, then
## slide the hook along the rail away from the path, or retreat up the
## string if there is no room. A ball already in flight is read faster but
## answered with a shorter move. Cooldown after every move.
func _evade(dt: float) -> void:
	var a := aggression
	var prof: Array = EVADE[kind]
	var threatened := aimed or incoming
	if guard_of != null:
		# On guard duty: standing in the line of fire is the point.
		return
	if aim_hold < 0.0:
		_rhythm_used = false
	if not threatened:
		_aim_t = maxf(0.0, _aim_t - dt * 2.0)
		return
	if covered and not incoming:
		# Shielded by a teammate: trusts it and stays put.
		return
	if _dodge_cd > 0.0 or a < prof[4]:
		return
	_aim_t += dt
	var react: float = prof[0] * lerpf(1.0, 0.4, a) * [1.0, 0.7, 1.35, 0.9][temper] * (0.7 if is_leader else 1.0)
	if incoming and not aimed:
		if a < 0.4:
			return
		react *= 0.35
	if tactic == 0 and charm != Charm.SPRING:
		# Wave one: they have not learned to read you yet.
		react *= 1.6
	if charm == Charm.SPRING:
		react *= 0.45
	if stance == Stance.WARY:
		react *= 0.7
	# They know your rhythm: the moment you usually let go, they go.
	var on_beat := tactic >= 3 and rhythm and aimed and not _rhythm_used and aim_hold >= hold_avg - 0.03
	if on_beat:
		_rhythm_used = true
	elif _aim_t < react:
		return
	if temper == Temper.BOLD and not on_beat and charm != Charm.SPRING and stance != Stance.WARY and randf() < 0.35:
		# Stands its ground: a defiant flinch, no move (a chance for you).
		ang_vel -= dodge_dir * 1.5
		_dodge_cd = lerpf(2.0, 1.0, a)
		_aim_t = 0.0
		return
	var sc := _screen_h / 1280.0
	var reach: float = prof[1] * lerpf(0.75, 1.2, a) * sc * (0.6 if incoming and not aimed else 1.0) * [1.0, 1.25, 0.8, 1.0][temper] * (0.8 if tactic == 0 else 1.0)
	var speed: float = prof[2] * lerpf(1.0, 1.4, a) * sc
	if charm == Charm.SPRING:
		reach *= 1.7
		speed *= 1.3
		charm_flash = 1.0
	if on_beat:
		# Timed to your release: a sharper, longer move.
		reach *= 1.25
		speed *= 1.25
	var room_fwd := (slide_hi - anchor.x) if dodge_dir > 0.0 else (anchor.x - slide_lo)
	var room_back := (anchor.x - slide_lo) if dodge_dir > 0.0 else (slide_hi - anchor.x)
	var moved := false
	if room_fwd > 28.0 * sc:
		_slide(anchor.x + dodge_dir * minf(reach, room_fwd), speed)
		moved = true
	elif room_back > reach * 0.8 and a > 0.45:
		# Boxed in on the far side: cut back across the shot instead.
		_slide(anchor.x - dodge_dir * minf(reach * 1.3, room_back), speed * 1.15)
		moved = true
	var hop: float = prof[3]
	if (not moved or (hop > 0.0 and a > 0.35) or temper == Temper.TIMID) and length > 90.0 * sc:
		_hop_left += maxf(hop, 45.0) * sc * lerpf(0.8, 1.3, a)
		Sfx.play("creak", randf_range(0.95, 1.1))
	ang_vel += dodge_dir * 2.5
	startle_t = 0.3
	_dodge_cd = lerpf(2.6, 1.1, a) * (1.3 if kind == Kind.HEAVY else 1.0)
	_aim_t = 0.0


func _slide(x: float, speed: float, quiet := false) -> void:
	x = clampf(x, minf(slide_lo, anchor.x), maxf(slide_hi, anchor.x))
	if absf(x - anchor.x) < 4.0:
		return
	var feint := 0.0
	if tactic >= 1 and temper == Temper.ERRATIC:
		feint = 0.6
	elif tactic >= 2:
		feint = 0.2 + 0.3 * aggression
	if not quiet and randf() < feint:
		# Feint: a quick jink the wrong way, then the real move. The eye
		# gives it away: it looks where it is really going.
		var fake := clampf(anchor.x - signf(x - anchor.x) * 30.0 * (_screen_h / 1280.0), minf(slide_lo, anchor.x), maxf(slide_hi, anchor.x))
		_queued_x = x
		_queued_speed = speed
		x = fake
		speed *= 1.3
	_slide_to = x
	_slide_speed = speed
	if not quiet:
		Sfx.play("slide", randf_range(0.92, 1.08))


## Idle life: now and then a target drifts along the rail on its own. Bold
## ones patrol wider and swing, erratic ones twitch, timid ones keep still.
func _wander(dt: float) -> void:
	if aimed or incoming or not is_nan(_slide_to) or kind == Kind.BOSS or kind == Kind.ROD:
		return
	_wander_t -= dt
	if _wander_t > 0.0:
		return
	var sc := _screen_h / 1280.0
	match temper:
		Temper.TIMID:
			_wander_t = randf_range(5.0, 9.0)
			return
		Temper.BOLD:
			_wander_t = randf_range(2.5, 4.5)
			vel.x += (1.0 if randf() < 0.5 else -1.0) * 70.0
			_slide(anchor.x + randf_range(-80.0, 80.0) * sc, 70.0 * sc, true)
		Temper.ERRATIC:
			_wander_t = randf_range(0.9, 2.0)
			_slide(anchor.x + randf_range(-35.0, 35.0) * sc, 160.0 * sc, true)
		_:
			_wander_t = randf_range(3.5, 6.5)
			if tactic >= 3 and not is_nan(cold_x) and randf() < 0.6:
				# Drifts toward where you rarely shoot.
				_slide(anchor.x + clampf(cold_x - anchor.x, -90.0 * sc, 90.0 * sc), 60.0 * sc, true)
			elif aggression > 0.2:
				_slide(anchor.x + randf_range(-45.0, 45.0) * sc, 55.0 * sc, true)


## The hook glides along the rail (eased in and out); the body follows on
## its string with a natural lag. Hops pull the string up, then it pays
## back out once things are calm.
func _move_anchor(dt: float) -> void:
	if not is_nan(_slide_to):
		var d := _slide_to - anchor.x
		var sp := _slide_speed * clampf(absf(d) / 40.0, 0.35, 1.0)
		var step_x := signf(d) * minf(absf(d), sp * dt)
		anchor.x += step_x
		if absf(_slide_to - anchor.x) < 0.5:
			_slide_to = NAN
			if not is_nan(_queued_x):
				_slide_to = _queued_x
				_slide_speed = _queued_speed
				_queued_x = NAN
	if _hop_left > 0.0:
		var u := minf(_hop_left, 320.0 * dt)
		u = minf(u, maxf(0.0, length - 60.0))
		length -= u
		goal_length = length
		_hopped += u
		_hop_left = 0.0 if u <= 0.0 else _hop_left - u
	elif _hopped > 0.0 and not aimed and not incoming and _dodge_cd < 0.6:
		var back := minf(_hopped, 110.0 * dt)
		length += back
		goal_length = length
		_hopped -= back


## Golden one: glitters for GOLD_TIME, then winches itself up and away.
func _gold_step(dt: float) -> void:
	_gold_t += dt
	if _gold_t < GOLD_TIME:
		return
	if _gold_t - dt < GOLD_TIME:
		Sfx.play("reel", 1.3)
		voice("up")
	length -= 520.0 * (_screen_h / 1280.0) * dt
	if length < 14.0:
		fled = true
		phase = Phase.OFF
		visible = false


func evolve_warning() -> float:
	if kind != Kind.RING or not evolve_on or golden or leader != null or is_leader:
		return 0.0
	return clampf((_age - (EVOLVE_AT - EVOLVE_WARN)) / EVOLVE_WARN, 0.0, 1.0)


## A plain ring hanging on too long hardens into a heavy: same place,
## tougher shell, a chain for a string.
func _evolve_step(dt: float) -> void:
	if kind != Kind.RING or golden or leader != null or is_leader:
		return
	_age += dt
	if not evolve_on or _age < EVOLVE_AT:
		return
	kind = Kind.HEAVY
	soft = false
	hp = HP[Kind.HEAVY]
	radius = RADIUS[Kind.HEAVY]
	_m_key = -1
	_sd.fill(0.0)
	_sv.fill(0.0)
	flash_t = 0.07
	squash_t = 0.0
	startle_t = 0.4
	evolved = true


func _play_dead() -> void:
	playdead = randf_range(2.6, 4.0)
	_peek_at = playdead * randf_range(0.35, 0.6)
	_closed_t = 0.3
	voice("down", -4.0)
	ang_vel += (1.0 if randf() < 0.5 else -1.0) * 4.0


## Limp and still, eye shut; one quick peek; then the surprise drop.
func _dead_step(dt: float) -> void:
	var was := playdead
	playdead -= dt
	var peeking := playdead < _peek_at and playdead > _peek_at - 0.35
	if not peeking:
		_closed_t = maxf(_closed_t, 0.1)
	if was >= _peek_at and playdead < _peek_at:
		_pupil = Vector2(signf(randf() - 0.5), 0.2)
	# Hangs a little askew, like something lifeless.
	ang_vel += (0.45 - ang_off) * 3.0 * dt
	if playdead <= 0.0:
		playdead = 0.0
		_closed_t = 0.0
		startle_t = 0.4
		smug = 1.0
		_lunge_left += 75.0 * (_screen_h / 1280.0)
		surprised = true
		voice("taunt")
		Sfx.play("whoosh", 0.9, -4.0)


## Slides the hook straight to `x` (past neighbours: a deliberate move).
func slide_now(x: float, speed: float) -> void:
	_slide_to = clampf(x, radius + 12.0, field_w - radius - 12.0)
	_slide_speed = speed
	_queued_x = NAN
	startle_t = 0.25
	Sfx.play("slide", randf_range(0.95, 1.1))


## Makes this one a variant of its family (right after spawning).
func set_variant(v: int) -> void:
	variant = v as Var
	if variant == Var.BIG:
		radius *= 1.35 if kind == Kind.DROP else 1.25
		hp = maxi(hp, 2)
		_eye_scale *= 1.2
		_m_key = -1


## A wave's finale: bigger, tougher, grumpy.
func make_champion() -> void:
	champion = true
	radius *= 1.15
	hp += 2
	_eye_scale *= 1.1
	_m_key = -1
	aggression = minf(1.0, aggression + 0.2)
	set_mood(Mood.GRUMPY)


## Key for the "new enemy" card: the kind, or its variant.
func intro_id() -> int:
	return kind if variant == Var.STD else 100 + kind * 10 + variant


## A friend fell nearby, or it was hit: furious for a while.
func enrage(secs: float) -> void:
	if phase != Phase.HANGING or kind == Kind.BOSS:
		return
	_fury_t = maxf(_fury_t, secs * (1.5 if mood == Mood.GRUMPY else (0.6 if mood == Mood.CUTE else 1.0)))


func _stance_step(dt: float) -> void:
	_alive_t += dt
	_fury_t = maxf(0.0, _fury_t - dt)
	stance_flash = maxf(0.0, stance_flash - dt * 1.5)
	if aimed and not _was_aimed:
		_aimed_n += 1
	_was_aimed = aimed
	var want := Stance.CALM
	if _fury_t > 0.0:
		want = Stance.FURIOUS
	elif _alive_t > VETERAN_AT:
		want = Stance.VETERAN
	elif _aimed_n >= 2:
		want = Stance.WARY
	if want != stance:
		stance = want
		stance_changed = want != Stance.CALM
		stance_flash = 1.0 if want != Stance.CALM else 0.0
		match want:
			Stance.FURIOUS:
				# Not every furious one throws itself down: the grumpy often do.
				if kind != Kind.DROP and tele_t <= 0.0 and mood != Mood.CUTE and randf() < (0.6 if mood == Mood.GRUMPY else 0.3):
					order_plunge(30.0, 0.35)
				voice("taunt", -4.0)
			Stance.VETERAN:
				if not _veteran_paid:
					_veteran_paid = true
					hp += 1
					aggression = minf(1.0, aggression + 0.2)
					smug = 1.0
			Stance.WARY:
				startle_t = 0.3
	_stance_k = move_toward(_stance_k, 1.0 if stance != Stance.CALM else 0.0, dt / 0.6)


## A small sign over the body as the stance changes: ! (wary), a flame
## (furious), a star (veteran).
func _draw_stance(f: Node2D) -> void:
	if stance_flash <= 0.0 or phase != Phase.HANGING:
		return
	var a := minf(1.0, stance_flash * 2.0)
	var p := pos + Vector2(radius * 0.9, -radius * 0.95 - 8.0 * (1.0 - stance_flash))
	var col: Color = STANCE_TINT[stance].lightened(0.25)
	f.draw_circle(p, 8.0, Color(Pal.BG, 0.75 * a), true, -1.0, true)
	f.draw_arc(p, 8.0, 0.0, TAU, 20, Color(col, a), 1.2, true)
	match stance:
		Stance.WARY:
			f.draw_line(p + Vector2(0, -4.5), p + Vector2(0, 1.5), Color(col, a), 2.0, true)
			Pal.disc(f, p + Vector2(0, 4.2), 1.2, Color(col, a))
		Stance.FURIOUS:
			f.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(3.5, 1.5), p + Vector2(0, 5.0), p + Vector2(-3.5, 1.5)]), Color(col, a))
		Stance.VETERAN:
			var star := PackedVector2Array()
			for i in 10:
				var r := 5.0 if i % 2 == 0 else 2.2
				star.append(p + Vector2.from_angle(-PI * 0.5 + i * TAU / 10.0) * r)
			f.draw_colored_polygon(star, Color(col, a))


## Sets the mood rolled at spawn (and when a cute one gets upset).
func set_mood(m: int) -> void:
	mood = m as Mood
	match mood:
		Mood.GRUMPY:
			_smile = randf_range(-0.9, -0.5)
			_val_shift -= 0.06
		Mood.CUTE:
			_smile = randf_range(0.7, 1.0)
			_eye_scale *= 1.1
			_pupil_scale *= 1.15
			_val_shift += 0.04


## Grumpy ones take things badly: anger rises (a rage at 1).
func annoy(v: float) -> void:
	if mood != Mood.GRUMPY or phase != Phase.HANGING:
		return
	anger = minf(1.0, anger + v)


## Cute ones cry when hurt or in trouble, and ask for help.
func cry() -> void:
	if mood != Mood.CUTE or _help_cd > 0.0:
		return
	crying = 2.2
	_help_cd = 7.0
	wants_help = true
	voice("down", -4.0)


func _mood_step(dt: float) -> void:
	_help_cd = maxf(0.0, _help_cd - dt)
	crying = maxf(0.0, crying - dt)
	match mood:
		Mood.GRUMPY:
			anger = maxf(0.0, anger - 0.05 * dt)
			if anger >= 1.0 and tele_t <= 0.0 and kind != Kind.DROP and kind != Kind.BOSS:
				# The rage: steam, a tremble, then it throws itself down.
				order_plunge(RAGE_DROP, 0.55)
				anger = 0.3
				raged = true
				voice("taunt")
		Mood.CUTE:
			if danger > 0.65:
				cry()


## Takes on a trick charm (it flashes as it lands).
func set_charm(c: int) -> void:
	charm = c as Charm
	charm_flash = 1.0
	_charm_cd = 0.0
	if charm == Charm.BUBBLE:
		patched = true


## Gives up its charm (tossed on, or broken); returns it.
func take_charm() -> int:
	var c := charm
	charm = Charm.NONE
	_ghost_t = 0.0
	return c


## Where the charm bead hangs: under the body on a short thread, trailing
## the swing a little.
func charm_pos() -> Vector2:
	return pos + Vector2(0, radius + 15.0).rotated(clampf(-vel.x * 0.0015, -0.6, 0.6))


func _charm_step(dt: float) -> void:
	charm_flash = maxf(0.0, charm_flash - dt * 2.0)
	match charm:
		Charm.BUBBLE:
			if not patched:
				_charm_cd += dt
				if _charm_cd >= BUBBLE_BACK:
					_charm_cd = 0.0
					patched = true
					charm_flash = 1.0
		Charm.GHOST:
			_ghost_t -= dt
			_charm_cd -= dt
			if aimed and _charm_cd <= 0.0:
				_ghost_t = 1.2
				_charm_cd = 4.0
				charm_flash = 1.0
				Sfx.play("fade", randf_range(1.0, 1.15))
		Charm.BALLOON:
			if aimed:
				length = maxf(60.0 * (_screen_h / 1280.0), length - 110.0 * dt)
				goal_length = length
		Charm.VINE:
			_charm_cd -= dt
			if aimed and _charm_cd <= 0.0 and acro == Acro.NONE and rope_host == null:
				wants_vine = true
				_charm_cd = 6.0
				charm_flash = 1.0
	if kind != Kind.SHADE:
		hidden_amt = move_toward(hidden_amt, 1.0 if _ghost_t > 0.0 else 0.0, dt / 0.25)


## The bead: a thread from the body, a coloured bead with a tiny glyph.
func _draw_charm(f: Node2D) -> void:
	if charm == Charm.NONE or phase != Phase.HANGING:
		return
	var a := 1.0 - 0.7 * hidden_amt
	var p := charm_pos()
	var top := pos + (p - pos).normalized() * (radius - 2.0)
	var col: Color = CHARM_COL[charm]
	f.draw_line(top, p, Color(Pal.STRING, 0.9 * a), 1.2, true)
	if charm_flash > 0.0:
		f.draw_circle(p, 7.0 + 8.0 * charm_flash, Color(col, 0.25 * charm_flash * a), true, -1.0, true)
	f.draw_circle(p + Vector2(1.2, 1.2), 7.0, Color(0, 0, 0, 0.35 * a), true, -1.0, true)
	f.draw_circle(p, 7.0, Color(col, a), true, -1.0, true)
	f.draw_circle(p + Vector2(-2.2, -2.2), 2.0, Color(1, 1, 1, 0.55 * a), true, -1.0, true)
	var g := Color(Pal.BG, 0.8 * a)
	match charm:
		Charm.BUBBLE:
			f.draw_arc(p, 3.6, 0.0, TAU, 14, g, 1.2, true)
		Charm.SPRING:
			f.draw_polyline(PackedVector2Array([p + Vector2(-3, 3), p + Vector2(-1, -1), p + Vector2(1, 3), p + Vector2(3, -1)]), g, 1.3, true)
		Charm.GHOST:
			f.draw_arc(p + Vector2(0, 0.5), 3.0, PI, TAU, 8, g, 1.3, true)
			f.draw_line(p + Vector2(-3, 0.5), p + Vector2(-3, 3.5), g, 1.3, true)
			f.draw_line(p + Vector2(3, 0.5), p + Vector2(3, 3.5), g, 1.3, true)
		Charm.BALLOON:
			f.draw_circle(p + Vector2(0, -1), 2.6, g, true, -1.0, true)
			f.draw_line(p + Vector2(0, 1.5), p + Vector2(0.8, 4.0), g, 1.0, true)
		Charm.VINE:
			f.draw_arc(p + Vector2(0, -1), 3.2, PI * 0.1, PI * 0.9, 8, g, 1.3, true)


## Sneaking down while you are busy aiming at someone else: silent, a
## sideways look at the slingshot.
func sneak(drop: float) -> void:
	_lunge_left += drop * (_screen_h / 1280.0)
	squint = true
	_watch_t = 0.0


## Starts a swing across to `host`'s rope.
func start_swing(host: Target) -> void:
	acro = Acro.PUMP
	_acro_t = 0.0
	swing_host = host
	_slide_to = NAN
	_queued_x = NAN
	watch(host, PUMP_MAX_T)
	startle_t = 0.25


## Pumping: a push through the bottom of each swing, always along the way it
## is already going, so the swing grows like a child's on a swing. It lets
## go the moment its flight would cross the host's rope.
func _pump_step(dt: float) -> void:
	_acro_t += dt
	var h := swing_host
	if h == null or not is_instance_valid(h) or not h.is_hittable() or h.acro != Acro.NONE or _acro_t > PUMP_MAX_T:
		acro = Acro.NONE
		swing_host = null
		return
	_watch = h
	_watch_t = 0.3
	var side := signf(h.pos.x - pos.x)
	var swing := atan2(pos.x - anchor.x, pos.y - anchor.y)
	if absf(swing) < 0.7:
		var dir := signf(vel.x) if absf(vel.x) > 6.0 else side
		vel.x += dir * PUMP_ACC * dt
	# Let go on the way toward the host, around the top of the arc.
	# (Not before a second of visible pumping and a real swing: the tell.)
	if _acro_t > 1.0 and absf(swing) > 0.35 and signf(vel.x) == side and signf(pos.x - anchor.x) == side and vel.y < 60.0 and _flight_meets(h):
		_release()


## Whether a leap from here, with this velocity, crosses `h`'s rope within
## reach (above its body and below its hook).
func _flight_meets(h: Target) -> bool:
	var p := pos
	var y0 := pos.y
	var v := vel * 1.1 + Vector2(0, -50.0)
	var a := h.eyelet()
	var b := h.pos
	var st := 1.0 / 30.0
	for i in 30:
		v.y += GRAVITY * st
		p += v * st
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(q) < radius * 0.6 and q.y > a.y + 24.0 and q.y < b.y - h.radius - radius - 6.0 and q.y < y0 + 70.0:
			return true
	return false


func _release() -> void:
	acro = Acro.FLY
	_acro_t = 0.0
	_attached = false
	# A little spring in the leap.
	vel = vel * 1.1 + Vector2(0, -50.0)
	spin = signf(vel.x) * randf_range(2.0, 3.5)
	startle_t = 0.5
	voice("up")
	Sfx.play("whoosh", randf_range(1.0, 1.2), -4.0)


## In the air: a thrown body. It grabs the host's rope if it passes close
## enough; after FLY_MAX_T (or too low) it has missed and falls.
func _fly_step(dt: float, danger_y: float, danger_band: float) -> void:
	_acro_t += dt
	vel.y += GRAVITY * dt
	vel.x += wind * dt / MASS[kind]
	pos += vel * dt
	body_rot += spin * dt
	danger = clampf(1.0 - (danger_y - bottom_y()) / danger_band, 0.0, 1.0)
	_rope_step(dt)
	var h := swing_host
	if h != null and is_instance_valid(h) and h.is_hittable() and _try_grab(h):
		return
	if _acro_t > FLY_MAX_T or danger > 0.6:
		acro = Acro.NONE
		swing_host = null
		slipped = true
		hp = 0
		phase = Phase.FALLING
		fall_t = 0.0
		crushed.clear()
		voice("down")


## Catches `h`'s rope if the body is within reach of it: from now on it hangs
## on that rope (the host's hook), keeping its momentum.
func _try_grab(h: Target) -> bool:
	var a := h.eyelet()
	var q := Geometry2D.get_closest_point_to_segment(pos, a, h.pos)
	if pos.distance_to(q) > radius + GRAB_REACH or q.y < a.y + 20.0 or q.y > h.pos.y - h.radius - 6.0:
		return false
	var host := h.rope_host if h.rope_host != null and is_instance_valid(h.rope_host) else h
	if hp <= 0:
		# Caught while falling from a cut rope: alive again.
		hp = 1
		_cut = false
		_closed_t = 0.6
	fall_t = 0.0
	tilt = 0.0
	crushed.clear()
	phase = Phase.HANGING
	acro = Acro.NONE
	swing_host = null
	rope_host = host
	anchor = Vector2(host.anchor.x, anchor.y)
	length = maxf(40.0, pos.distance_to(anchor))
	goal_length = length
	_attached = true
	rope_alpha = 1.0
	modulate.a = 1.0
	rescuable = false
	for i in N:
		_pts[i] = eyelet().lerp(pos, float(i) / (N - 1))
		_prev[i] = _pts[i]
	_rope_len = length
	# The rope takes the pull: a little of the momentum passes to the host.
	h.vel += vel * 0.3 * MASS[kind] / MASS[h.kind]
	h.ang_vel += signf(vel.x) * 1.5
	h.startle_t = 0.35
	spin = 0.0
	ang_vel = signf(vel.x) * 3.0
	_dodge_cd = 1.5
	grabbed = true
	voice("up")
	Sfx.play("creak", randf_range(0.9, 1.05), -2.0)
	return true


## Hanging on a neighbour's rope: its hook sets ours; no moves of its own.
func _ride_step() -> void:
	if not is_instance_valid(rope_host) or rope_host.phase != Phase.HANGING:
		# The host is gone but the rope still hangs from the hook.
		rope_host = null
		return
	anchor.x = rope_host.anchor.x
	_slide_to = NAN


## A cut body that a friend is trying to catch.
func expect_rescue(rescuer: Target) -> void:
	rescuable = true
	swing_host = rescuer


## Teamwork: a neighbour was destroyed at `from`; scatter away from it.
func scatter(from: Vector2) -> void:
	if tactic < 4 or leader != null or guard_of != null or kind == Kind.BOSS or _dodge_cd > 0.6:
		return
	var sc := _screen_h / 1280.0
	var dir := signf(pos.x - from.x) if absf(pos.x - from.x) > 2.0 else (1.0 if randf() < 0.5 else -1.0)
	_slide(anchor.x + dir * randf_range(55.0, 90.0) * sc, 300.0 * sc, true)
	startle_t = 0.35
	_dodge_cd = maxf(_dodge_cd, 0.6)


## Teamwork: the team plunges together on a signal. Telegraphed (tremble
## and squint) for `wait` seconds, then drops `drop` px.
func order_plunge(drop: float, wait: float) -> void:
	if kind == Kind.DROP or kind == Kind.BOSS or tele_t > 0.0:
		return
	_order_drop = drop
	tele_t = wait


func _order_step(dt: float) -> void:
	if _order_drop <= 0.0:
		return
	tele_t -= dt
	if tele_t <= 0.0:
		tele_t = 0.0
		_lunge_left += _order_drop * (_screen_h / 1280.0)
		_order_drop = 0.0


## Tremble and squint for 0.45 s, then drop by `drop` px (scaled).
func _lunge_brain(dt: float, every: float, drop: float) -> void:
	if tele_t > 0.0:
		tele_t -= dt
		if tele_t <= 0.0:
			_lunge_left += drop * (_screen_h / 1280.0)
			Sfx.play("whoosh", randf_range(0.95, 1.15), -8.0)
		return
	_brain_t -= dt
	if _brain_t <= 0.0:
		_brain_t = every * randf_range(0.8, 1.25)
		tele_t = 0.45


func _body_step(dt: float) -> void:
	vel.y += GRAVITY * dt
	vel.x += wind * dt / MASS[kind]
	# They are alive: when the hook has moved on, the body pulls itself back
	# under it instead of trailing for seconds on a long string.
	if kind != Kind.ROD and acro != Acro.PUMP:
		var off := anchor.x - pos.x
		if absf(off) > 10.0:
			vel.x += clampf(off * 6.0, -700.0, 700.0) * dt / MASS[kind]
	var d := pos - anchor
	var dist := d.length()
	if dist > length and dist > 0.001:
		var dir := d / dist
		# Near the danger line the string pulls tighter (stiffer, less bounce).
		var k := STRING_K * (1.0 + danger * 0.9)
		vel -= dir * k * (dist - length) * dt
		# Extra damping along the string keeps the bounce elastic but calm.
		vel -= dir * vel.dot(dir) * (2.2 + danger * 2.0) * dt
	# Pumping, it works with the swing: far less loss than at rest.
	vel *= exp(-(0.12 if acro == Acro.PUMP else DAMPING) * dt)
	pos += vel * dt
	# Swinging drives the wobble a little (the string pulls the top first).
	var swing := atan2(-(pos.x - anchor.x), pos.y - anchor.y)
	ang_vel += (-ANG_K * ang_off - ANG_C * ang_vel) * dt
	ang_off = clampf(ang_off + ang_vel * dt, -1.1, 1.1)
	body_rot = swing + ang_off


func _rope_step(dt: float) -> void:
	var g := Vector2(wind * 0.6, GRAVITY) * dt * dt
	var last := N - 1
	for i in range(1, N):
		if i == last and _attached:
			continue
		var cur := _pts[i]
		var v := (cur - _prev[i]) * 0.985
		_prev[i] = cur
		_pts[i] = cur + v + g
	_pts[0] = eyelet()
	if _attached:
		_pts[last] = pos
		_rope_len = maxf(length, pos.distance_to(anchor))
	else:
		_rope_len = move_toward(_rope_len, 0.0, 900.0 * dt)
		rope_alpha = maxf(0.0, rope_alpha - dt / 0.4)
	var seg := _rope_len / (N - 1)
	for _it in 4:
		for i in last:
			var d := _pts[i + 1] - _pts[i]
			var l := d.length()
			if l <= seg or l < 0.0001:
				continue
			var wa := 0.0 if i == 0 else 1.0
			var wb := 0.0 if (i + 1 == last and _attached) else 1.0
			var sum := wa + wb
			if sum == 0.0:
				continue
			var off := d * ((l - seg) / l)
			_pts[i] += off * (wa / sum)
			_pts[i + 1] -= off * (wb / sum)
	# Bending stiffness: a real cord resists sharp kinks, so a fast slide
	# along the rail sends a smooth wave down it instead of a zigzag.
	var bend := 0.35 if soft else 0.25
	for _it in 2:
		for i in range(1, last):
			var mid := (_pts[i - 1] + _pts[i + 1]) * 0.5
			_pts[i] = _pts[i].lerp(mid, bend)
	if not _attached:
		# The recoiling stub folds against the rail instead of passing it.
		for i in range(1, N):
			_pts[i].y = maxf(_pts[i].y, anchor.y + 1.0)


func _snap(impulse: Vector2) -> void:
	phase = Phase.FALLING
	crushed.clear()
	_attached = false
	vel = impulse * 0.5 / MASS[kind] + Vector2(0, -120)
	# Keep the wobble it already had; heavier bodies tumble slower.
	spin = ang_vel * 0.5 + randf_range(3.0, 6.0) * (1.0 if impulse.x >= 0.0 else -1.0) / MASS[kind]
	# Whip recoil: the freed rope springs upward for a few frames.
	for i in range(1, N):
		var k := float(i) / (N - 1)
		_prev[i] = _pts[i] + Vector2(randf_range(-2.0, 2.0), 9.0 + 12.0 * k)


## Squash (1.25 x 0.8 along the hit) for 60 ms, then an elastic return;
## while falling, a cosine on one axis reads as a perspective tilt. The
## tremble is computed once per frame (`_jit`) so every layer moves as one.
func body_xform() -> Transform2D:
	var sx := 1.0
	var sy := 1.0
	var t := squash_t
	if t < 0.06:
		var k := t / 0.06
		sx = 1.0 + 0.25 * k
		sy = 1.0 - 0.2 * k
	elif t < 0.6:
		var e := exp(-(t - 0.06) * 12.0) * cos((t - 0.06) * 36.0)
		sx = 1.0 + 0.25 * e
		sy = 1.0 - 0.2 * e
	# Jelly deforms through its spokes; a rigid shell does not squash.
	var amt := 0.35 if soft else 0.0
	sx = 1.0 + (sx - 1.0) * amt
	sy = 1.0 + (sy - 1.0) * amt
	# Idle breathing: jelly swells and settles, shells barely move.
	if phase == Phase.HANGING:
		var br := sin(_clock * 2.1 + _hue_shift * 90.0) * (0.03 if soft else 0.01)
		sx *= 1.0 + br
		sy *= 1.0 - br * 0.6
	var a := squash_dir.angle() + PI * 0.5
	var squash := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	var tilt_x := cos(tilt) if phase == Phase.FALLING or (kind == Kind.MIRROR and _dropping) else 1.0
	var wig := 0.0
	var bob := Vector2.ZERO
	if _taunt >= 0.0:
		var env := sin(PI * _taunt / TAUNT_TIME)
		wig = sin(_taunt * TAU * 3.2) * 0.28 * env
		bob = Vector2(0, -absf(sin(_taunt * TAU * 3.2)) * 5.0 * env)
	var body := Transform2D(body_rot + wig, Vector2.ZERO) * Transform2D(0.0, Vector2(maxf(absf(tilt_x), 0.08) * signf(tilt_x + 0.0001), 1.0), 0.0, Vector2.ZERO)
	var ds := depth_scale()
	return Transform2D(0.0, pos + _jit + bob) * squash * body * Transform2D(0.0, Vector2(ds, ds), 0.0, Vector2.ZERO)


## Steel chain along the string: links every 7 px, alternately seen flat
## (an open oval) and edge-on (a short bar), hidden where the body covers
## the end. Built as one tube mesh in the lit wire material (shaded and
## antialiased by the shader) plus its soft shadow: two draw calls for the
## whole chain. World space, drawn with the string.
func _draw_chain(ci: RID) -> void:
	const STEP := 7.0
	const HW := 1.15
	var hide := radius * depth_scale() * 0.85
	_c_pts.clear()
	_c_uv.clear()
	_c_idx.clear()
	var dist := 0.0
	var next := STEP * 0.5
	var k := 0
	for i in range(1, _r_mid.size()):
		var p0 := _r_mid[i - 1]
		var p1 := _r_mid[i]
		var seg := p0.distance_to(p1)
		while seg > 0.0 and next <= dist + seg:
			var c := p0.lerp(p1, (next - dist) / seg)
			next += STEP
			k += 1
			if _attached and c.distance_to(pos) < hide:
				continue
			var d := (p1 - p0) / seg
			var n := d.orthogonal()
			var base := _c_pts.size()
			if k % 2 == 0:
				# Flat link: a tube around an oval 4.6 along, 2.7 across.
				for j in 13:
					var ang := TAU * j / 12.0
					var p := c + d * cos(ang) * 4.6 + n * sin(ang) * 2.67
					var m := (d * cos(ang) / 4.6 + n * sin(ang) / 2.67).normalized()
					_c_pts.append(p - m * HW)
					_c_pts.append(p + m * HW)
					_c_uv.append(Vector2(B_WIRE - 1.0, float(j)))
					_c_uv.append(Vector2(B_WIRE + 1.0, float(j)))
				for j in 12:
					var q := base + j * 2
					_c_idx.append_array([q, q + 1, q + 3, q, q + 3, q + 2])
			else:
				# Edge-on link: a short bar.
				var e := d * 4.6
				var w := n * HW * 1.2
				_c_pts.append_array([c - e - w, c - e + w, c + e - w, c + e + w])
				_c_uv.append_array([Vector2(B_WIRE - 1.0, 0.0), Vector2(B_WIRE + 1.0, 0.0), Vector2(B_WIRE - 1.0, 1.0), Vector2(B_WIRE + 1.0, 1.0)])
				_c_idx.append_array([base, base + 1, base + 3, base, base + 3, base + 2])
		dist += seg
	if _c_idx.is_empty():
		return
	var a := rope_alpha * modulate.a
	# Shadow: the same links, pushed down-right, in the soft shadow band.
	_c_sh.resize(_c_uv.size())
	for j in _c_uv.size():
		_c_sh[j] = Vector2(B_SHADOW + (_c_uv[j].x - B_WIRE), 0.0)
	RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse() * Transform2D(0.0, Vector2(0.9, 0.9)))
	_one_col[0] = Color(0.0, 0.0, 0.0, 0.5 * a)
	RenderingServer.canvas_item_add_triangle_array(ci, _c_idx, _c_pts, _one_col, _c_sh)
	RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse())
	_one_col[0] = Color(Pal.METAL_LIGHT.lightened(0.35).lerp(_base_color(), 0.1).lerp(Pal.INK_DIM, danger * 0.5), a)
	RenderingServer.canvas_item_add_triangle_array(ci, _c_idx, _c_pts, _one_col, _c_uv)


func rope_style() -> Rope:
	match kind:
		Kind.DROP:
			return Rope.BUNGEE
		Kind.REEL:
			return Rope.MONO
		Kind.SHIELD, Kind.MIRROR:
			return Rope.CABLE
		Kind.HEAVY, Kind.BOSS:
			return Rope.CHAIN
	return Rope.CORD if soft else Rope.WIRE


## Current distance from the hook to the body (how stretched the string is).
func _rope_len_now() -> float:
	return pos.distance_to(anchor) if _attached else length


func depth_scale() -> float:
	return 1.0 + 0.12 * seen_depth()


## Depth as drawn: where it hangs, plus how far it is swinging in or out.
func seen_depth() -> float:
	return clampf(depth + z_swing, -1.0, 1.0)


func _z_step(dt: float) -> void:
	# Pendulum rate g/L; heavier bodies are pushed less. Held to ±0.9.
	var w2 := GRAVITY / maxf(length, 60.0)
	_z_vel += (push_z * 1.4 / MASS[kind] - w2 * z_swing - 1.4 * _z_vel) * dt
	z_swing = clampf(z_swing + _z_vel * dt, -0.9, 0.9)


## Solid enough to cast a shadow on the wall (and how much).
func shadow_alpha() -> float:
	if phase == Phase.OFF or delay > 0.0 or _gone:
		return 0.0
	return modulate.a * (1.0 - 0.85 * hidden_amt)


## This frame's tremble: the lunge telegraph, a struck shell ringing and a
## timid one's nerves.
func _tremble() -> Vector2:
	var j := Vector2.ZERO
	if tele_t > 0.0:
		j = Vector2(randf_range(-1.8, 1.8), randf_range(-1.0, 1.0))
	if not soft and _ring_t < 0.16:
		j += _ring_dir * sin(_ring_t * 110.0) * 2.2 * (1.0 - _ring_t / 0.16)
	if temper == Temper.TIMID and phase == Phase.HANGING and startle_t <= 0.0:
		j += Vector2(sin(_clock * 31.0), cos(_clock * 27.0)) * 0.35
	if trait_kind == Trait.JITTERY and phase == Phase.HANGING:
		j += Vector2(sin(_clock * 23.0 + _hue_shift * 50.0), cos(_clock * 19.0)) * 0.3
	if (panicked() or hurry) and phase == Phase.HANGING:
		j += Vector2(sin(_clock * 47.0), cos(_clock * 41.0)) * (1.1 if panicked() else 0.7)
	var ew := evolve_warning()
	if ew > 0.0 and phase == Phase.HANGING:
		j += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.8 * ew
	return j


## Hook tilt, following the top rope segment's angle from vertical.
func hook_angle() -> float:
	var d := _pts[1] - _pts[0]
	return clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7)


## Where the string leaves the hook; `anchor` is the hook's pivot on the rail.
func eyelet() -> Vector2:
	var d := _pts[1] - _pts[0]
	var a := clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7) if d.length() > 0.01 else 0.0
	return anchor + Vector2(0, HOOK_LEN).rotated(a)


func _process(delta: float) -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	intro_t = maxf(0.0, intro_t - delta)
	_body.modulate = Color.WHITE.lerp(DARK_TINT, dark) if dark > 0.0 else Color.WHITE
	_ring_t += delta
	squash_t += delta
	_clock += delta
	_update_eye(delta)
	_jit = _tremble()
	_xf = body_xform()
	_body.transform = _xf
	_face.transform = _xf
	_body.queue_redraw()
	_face.queue_redraw()


func _update_eye(delta: float) -> void:
	_closed_t = maxf(0.0, _closed_t - delta)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_t = 0.26 if trait_kind == Trait.SLEEPY else 0.13
		match trait_kind:
			Trait.JITTERY:
				_blink_in = randf_range(1.0, 2.6)
			Trait.SLEEPY:
				_blink_in = randf_range(4.0, 8.0)
			_:
				_blink_in = randf_range(3.0, 7.0)
	if _blink_in > 2.0 and morale > 0.5:
		# Nervous: they blink more.
		_blink_in -= delta
	_blink_t = maxf(0.0, _blink_t - delta)
	startle_t = maxf(0.0, startle_t - delta)
	_watch_t = maxf(0.0, _watch_t - delta)
	if kind == Kind.MIRROR and phase == Phase.HANGING:
		_admire_t = maxf(0.0, _admire_t - delta)
		_vain_in -= delta
		if _vain_in <= 0.0:
			_vain_in = randf_range(6.0, 10.0)
			if not aimed and not incoming:
				_admire_t = 1.3
	var goal_open := 0.42 if (squint or tele_t > 0.0) else 1.0
	if startle_t > 0.0 or (panicked() and phase == Phase.HANGING):
		goal_open = 1.3
	elif _blink_t > 0.0:
		goal_open = 0.0
	_open = lerpf(_open, goal_open, Pal.damp(0.35, delta))
	# Pupil follows the ball: 0.15 per frame, clamped inside the eye ring.
	var goal := Vector2.ZERO
	var target := look_at
	var looking := has_look
	if _watch_t > 0.0 and is_instance_valid(_watch) and not incoming:
		target = _watch.pos
		looking = true
	if looking:
		var d := (target - pos).rotated(-body_rot)
		goal = d.normalized() * minf(1.0, d.length() / 160.0) if d.length() > 0.01 else Vector2.ZERO
	if _admire_t > 0.0:
		# Up and to the left, at the glint on its own face.
		goal = Vector2(-0.75, -0.65)
	var quick := 0.15
	if not is_nan(_queued_x):
		# Mid-feint: the eye darts to where it is really going (the tell).
		goal = Vector2(signf(_queued_x - anchor.x), -0.15).rotated(-body_rot)
		quick = 0.45
	_pupil = _pupil.lerp(goal, Pal.damp(quick, delta))


func color() -> Color:
	var base := _base_color()
	if danger > 0.0 and phase == Phase.HANGING and not scared:
		var pulse := 0.8 + 0.2 * sin(_clock * TAU * 0.8)
		base = base.lerp(Pal.CORAL, danger * pulse)
	if scared:
		# Blanched with fright.
		base = base.lerp(Pal.INK, 0.3)
	# Depth: back ones recede into the room's darkness, front ones catch
	# a little more of the lamp.
	var sd := seen_depth()
	base = base.darkened(0.28 * maxf(0.0, -sd)).lightened(0.06 * maxf(0.0, sd))
	var ew := evolve_warning()
	if ew > 0.0:
		# About to harden: a quickening pale pulse.
		base = base.lerp(Pal.EYE, 0.35 * ew * (0.5 + 0.5 * sin(_clock * lerpf(8.0, 22.0, ew))))
	if flash_t > 0.0:
		# One-frame-ish matte flash on impact (lighter, never glowing).
		base = base.lerp(Pal.EYE, 0.55 * flash_t / 0.07)
	return base


func _base_color() -> Color:
	if golden:
		return Pal.GOLD.lerp(Pal.GOLD_LIGHT, 0.5 + 0.5 * sin(_clock * 7.0))
	# The current colour theme (they change, harmoniously, wave by wave).
	var base := Pal.kind_color(kind)
	if variant != Var.STD:
		base = base.lerp(VARIANT_TINT[variant], 0.75)
	if _stance_k > 0.0 and stance != Stance.CALM:
		base = base.lerp(STANCE_TINT[stance], 0.4 * _stance_k)
	if kind != Kind.SHIELD and kind != Kind.BOSS and kind != Kind.MIRROR:
		# Each individual a shade of its own: hue, saturation and value drift
		# a little around the theme's colour, never far enough to blur kinds.
		base = Color.from_hsv(fposmod(base.h + _hue_shift, 1.0), clampf(base.s + _hue_shift, 0.3, 1.0), clampf(base.v + _val_shift, 0.2, 1.0))
	return base


# ---------------------------------------------------------------- rendering
# Each target draws through two child canvas items that follow the body's
# transform. `_body` carries the shared lit material (shaders/lit.gdshader)
# and holds the string, the contact shadow and the body as triangle meshes,
# one draw call each; the light is computed per pixel from a normal per
# vertex, so jelly and shells shade as real solids. `_face` holds the eye,
# mouth and small details, mostly circle sprites that batch into one call.
# A body's mesh is built once per kind and health (shells never rebuild it);
# jelly only moves its vertices along the surface of its spring field.

const SHADOW_OFF := Vector2(5.0, 6.0)
const B_JELLY := 0.0
const B_SHADOW := 4.0
const B_CORD := 8.0
const B_WIRE := 12.0
const B_SHELL := 16.0
const B_MEMBRANE := 20.0
const B_METAL := 24.0
const B_CABLE := 28.0
# How each kind hangs: its string, by what it has to carry.
#   cord    jelly bodies: a dyed braided cord
#   bungee  the Dykker: thick elastic, thinning as it stretches
#   mono    the Snelle: fine fishing line off its reel
#   cable   armoured Vokter and Speilet: twisted steel
#   chain   Tungvekt and Spinneren: the heaviest, on steel chain
#   wire    the rest of the shells: plain wire
enum Rope { CORD, BUNGEE, MONO, CABLE, CHAIN, WIRE }
const ROPE_SUB := 2                 # smoothing steps per rope segment

static var _lit: ShaderMaterial


## Hands the balls' light (up to three, see shaders/lit.gdshader) to every
## lit body.
static func set_lights(lights: Array[Vector4], col: Color) -> void:
	if _lit:
		_lit.set_shader_parameter("lights", lights)
		_lit.set_shader_parameter("light_col", Vector3(col.r, col.g, col.b))
static var _dir_cache := {}


## Unit directions around a circle, cached per segment count.
static func _dirs(seg: int) -> PackedVector2Array:
	if not _dir_cache.has(seg):
		var a := PackedVector2Array()
		for i in seg:
			a.append(Vector2.from_angle(i * TAU / seg))
		_dir_cache[seg] = a
	return _dir_cache[seg]


## The viewer's lean (-1..1 each way): shared by every lit body so their
## highlights slide together, and by the mirror's glints.
static var view_dir := Vector2.ZERO


static func set_view(v: Vector2) -> void:
	view_dir = v
	if _lit:
		_lit.set_shader_parameter("view", v * 0.35)


func _setup_canvas() -> void:
	if _lit == null:
		_lit = ShaderMaterial.new()
		_lit.shader = preload("res://shaders/lit.gdshader")
	_body = Node2D.new()
	_body.material = _lit
	add_child(_body)
	_body.draw.connect(_draw_body)
	_face = Node2D.new()
	add_child(_face)
	_face.draw.connect(_draw_face)


func _draw_body() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	var ci := _body.get_canvas_item()
	var inv := _xf.affine_inverse()
	if rope_alpha > 0.0:
		RenderingServer.canvas_item_add_set_transform(ci, inv)
		_draw_rope(ci)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	if _gone:
		return
	_mesh_update()
	var keep := 1.0 - 0.9 * hidden_amt
	var col := color()
	col.a *= keep
	# Contact shadow: the same mesh, pushed down and right in world space.
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, inv.basis_xform(SHADOW_OFF)))
	_one_col[0] = Color(0.0, 0.0, 0.0, Pal.SHADOW.a * keep)
	RenderingServer.canvas_item_add_triangle_array(ci, _m_idx, _m_pts, _one_col, _m_sh)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	_mesh_colors(col)
	RenderingServer.canvas_item_add_triangle_array(ci, _m_idx, _m_pts, _m_col, _m_uv)
	if kind == Kind.SHIELD or kind == Kind.BOSS:
		RenderingServer.canvas_item_add_set_transform(ci, inv)
		_draw_plates(ci, keep)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


## The string: the Verlet points smoothed (Catmull-Rom) and extruded into a
## strip whose normal runs across it, lit as a cord (jelly) or a wire
## (shells). World space.
func _draw_rope(ci: RID) -> void:
	var m := (N - 1) * ROPE_SUB + 1
	_r_mid.resize(m)
	var k := 0
	for i in N - 1:
		var p0 := _pts[maxi(i - 1, 0)]
		var p1 := _pts[i]
		var p2 := _pts[i + 1]
		var p3 := _pts[mini(i + 2, N - 1)]
		for s in ROPE_SUB:
			var t := float(s) / ROPE_SUB
			var t2 := t * t
			_r_mid[k] = 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t)
			k += 1
	_r_mid[k] = _pts[N - 1]
	var style := rope_style()
	var hw := (1.6 if soft else 1.1) + danger * 0.3
	var band := B_CORD if soft else B_WIRE
	match style:
		Rope.BUNGEE:
			# Elastic: thick, thinner the more it is stretched.
			hw = clampf(2.6 * sqrt(maxf(length, 40.0) / maxf(_rope_len_now(), 1.0)), 1.4, 2.8)
		Rope.MONO:
			hw = 0.75
			band = B_WIRE
		Rope.CABLE:
			hw = 1.7
			band = B_CABLE
		Rope.CHAIN:
			# Only a dark core here; the links are drawn on the face layer.
			hw = 0.7
			band = B_WIRE
	_r_pts.resize(m * 2)
	_r_uv.resize(m * 2)
	var run := 0.0
	for i in m:
		var t := _r_mid[mini(i + 1, m - 1)] - _r_mid[maxi(i - 1, 0)]
		var nn := t.orthogonal().normalized() if t.length_squared() > 1e-6 else Vector2.RIGHT
		if i > 0:
			run += _r_mid[i].distance_to(_r_mid[i - 1])
		_r_pts[i * 2] = _r_mid[i] - nn * hw
		_r_pts[i * 2 + 1] = _r_mid[i] + nn * hw
		_r_uv[i * 2] = Vector2(band - 1.0, run)
		_r_uv[i * 2 + 1] = Vector2(band + 1.0, run)
	if _r_idx.size() != (m - 1) * 6:
		_r_idx.resize((m - 1) * 6)
		for i in m - 1:
			var a := i * 2
			_r_idx[i * 6] = a
			_r_idx[i * 6 + 1] = a + 1
			_r_idx[i * 6 + 2] = a + 3
			_r_idx[i * 6 + 3] = a
			_r_idx[i * 6 + 4] = a + 3
			_r_idx[i * 6 + 5] = a + 2
	# Each string takes its target's colour: a dyed cord for jelly, a
	# darker tinted wire for shells; near the line it pales under strain.
	var tint := _base_color()
	var sc := (tint.darkened(0.2) if soft else tint.darkened(0.35).lerp(Pal.STRING, 0.3)).lerp(Pal.INK_DIM, danger * 0.5)
	match style:
		Rope.CHAIN:
			sc = Color(0.0, 0.0, 0.0, 0.6)
		Rope.CABLE:
			# Bare steel, only faintly tinted by what hangs from it.
			sc = Pal.METAL_LIGHT.lerp(tint, 0.12).lerp(Pal.INK_DIM, danger * 0.5)
		Rope.MONO:
			sc = Pal.INK.lerp(tint, 0.25)
		Rope.BUNGEE:
			sc = tint.darkened(0.1)
	_one_col[0] = Color(sc, rope_alpha)
	RenderingServer.canvas_item_add_triangle_array(ci, _r_idx, _r_pts, _one_col, _r_uv)
	if style == Rope.CHAIN:
		_draw_chain(ci)


## Rebuilds the mesh when the kind or health changed; jelly then moves its
## surface vertices by the spring field every frame.
func _mesh_update() -> void:
	var key := int(kind) * 16 + hp
	if key != _m_key:
		_m_key = key
		_mesh_build()
	if soft:
		for k in _m_dv.size():
			var i := _m_dv[k]
			_m_pts[i] = _m_base[i] + _m_dd[k] * _soft_lin(_m_ds[k])


func _soft_lin(s: float) -> float:
	var i := int(s)
	var w := s - float(i)
	i = i % SOFT_N
	return lerpf(_sd[i], _sd[(i + 1) % SOFT_N], w * w * (3.0 - 2.0 * w))


func _mesh_colors(col: Color) -> void:
	var n := _m_pts.size()
	if _m_col.size() != n:
		_m_col.resize(n)
	_m_col.fill(col)
	if _m_mem > 0:
		var mem := col.darkened(0.55)
		mem.a = col.a * (0.88 if soft else 1.0)
		for i in _m_mem:
			_m_col[i] = mem
	if _m_dim.x >= 0:
		var dim := Color(col, col.a * 0.55)
		for i in range(_m_dim.x, _m_dim.y):
			_m_col[i] = dim


func _mesh_build() -> void:
	_m_base.clear()
	_m_uv.clear()
	_m_sh.clear()
	_m_idx.clear()
	_m_dv.clear()
	_m_dd.clear()
	_m_ds.clear()
	_m_mem = 0
	_m_dim = Vector2i(-1, -1)
	var b := B_JELLY if soft else B_SHELL
	var r := radius
	match kind:
		Kind.RING:
			_membrane(r - 8.0, 24)
			_ring_tube(r - 5.0, 4.5, 32, b)
		Kind.HEAVY:
			_membrane(r - 14.5, 20)
			if hp > 1:
				_ring_tube(r - 3.0, 2.5, 36, b)
			else:
				# Cracked outer ring after the first hit.
				_m_dim.x = _m_base.size()
				for i in 6:
					var a := i * TAU / 6.0 + 0.2
					_arc_tube(r - 3.0, a, a + 0.62, 2.0, 5, b)
				_m_dim.y = _m_base.size()
			_ring_tube(r - 13.0, 3.0, 32, b)
		Kind.SHIELD:
			_membrane(r - 7.5, 22)
			_ring_tube(r - 5.0, 4.0, 32, b)
		Kind.REEL:
			_membrane(r - 6.0, 20)
			_ring_tube(r - 4.0, 3.5, 32, b)
			for i in 4:
				var d := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
				_bar(d * 11.0, d * (r - 7.0), 1.5, b)
		Kind.SPLIT:
			_membrane_poly(_hex(r - 7.0, 4))
			_poly_tube(_hex(r - 4.0, 4), 4.0, b)
			_bar(Vector2(0, -r + 8.0), Vector2(0, -r * 0.55), 1.0, b)
			_bar(Vector2(0, r - 8.0), Vector2(0, r * 0.55), 1.0, b)
		Kind.ROD:
			_capsule(ROD_HALF, r, b)
		Kind.DROP:
			_fan(_drop_outline(r), Vector2(0.0, -r * 0.1), b)
		Kind.PIPP:
			_fan(_round(r, 20), Vector2.ZERO, b)
		Kind.PAKKIS:
			_fan(_round(r, 24), Vector2.ZERO, b)
		Kind.SHADE:
			_fan(_crescent(r), Vector2(-r * 0.55, 0.0), b)
		Kind.BOSS:
			_fan(_hex(r, 3), Vector2.ZERO, b)
		Kind.MEDIC:
			_membrane(r - 7.5, 22)
			_ring_tube(r - 4.5, 4.0, 32, b)
		Kind.MIRROR:
			# A polished hexagon: all metal, so it throws the light back.
			_fan(_hex(r, 2), Vector2.ZERO, B_METAL)
			_poly_tube(_hex(r - 2.0, 2), 2.0, b)
	_m_pts = _m_base.duplicate()


## Adds a vertex: position, surface normal (length 1 on a silhouette, 0
## facing the viewer), material band, whether it lies on the outer
## silhouette (where the contact shadow fades out), and the direction the
## jelly surface moves it (none for shells).
func _v(p: Vector2, n: Vector2, band: float, sil: bool, dd := Vector2.ZERO) -> int:
	var i := _m_base.size()
	_m_base.append(p)
	_m_uv.append(Vector2(band + n.x, n.y))
	_m_sh.append(Vector2(B_SHADOW + n.x, n.y) if sil else Vector2(B_SHADOW, 0.0))
	if soft and dd != Vector2.ZERO:
		_m_dv.append(i)
		_m_dd.append(dd)
		_m_ds.append(fposmod(p.angle(), TAU) / TAU * SOFT_N)
	return i


## How the jelly surface moves a point of a polygonal body: outward, less
## toward the middle.
func _poly_dd(p: Vector2) -> Vector2:
	var l := p.length()
	return p / l * minf(1.0, l / radius) if l > 0.001 else Vector2.ZERO


func _quads(base: int, n: int, closed: bool) -> void:
	for i in (n if closed else n - 1):
		var a := base + i * 2
		var b := base + ((i + 1) % n) * 2
		_m_idx.append_array([a, a + 1, b + 1, a, b + 1, b])


## The recessed inside of a ring: a flat disc under the face.
func _membrane(rr: float, seg: int) -> void:
	var c := _v(Vector2.ZERO, Vector2.ZERO, B_MEMBRANE, false)
	var dirs := _dirs(seg)
	for i in seg:
		_v(dirs[i] * rr, dirs[i], B_MEMBRANE, false, dirs[i])
	for i in seg:
		_m_idx.append_array([c, c + 1 + i, c + 1 + (i + 1) % seg])
	_m_mem = _m_base.size()


func _membrane_poly(rim: PackedVector2Array) -> void:
	var c := _v(Vector2.ZERO, Vector2.ZERO, B_MEMBRANE, false)
	var n := rim.size()
	for p in rim:
		_v(p, p.normalized(), B_MEMBRANE, false, _poly_dd(p))
	for i in n:
		_m_idx.append_array([c, c + 1 + i, c + 1 + (i + 1) % n])
	_m_mem = _m_base.size()


## A round tube: the ring bodies. Inner edge normal points in, outer out.
func _ring_tube(rm: float, hw: float, seg: int, band: float) -> void:
	var dirs := _dirs(seg)
	var base := _m_base.size()
	for d in dirs:
		_v(d * (rm - hw), -d, band, false, d)
		_v(d * (rm + hw), d, band, true, d)
	_quads(base, seg, true)


func _arc_tube(rm: float, a0: float, a1: float, hw: float, steps: int, band: float) -> void:
	var base := _m_base.size()
	for k in steps + 1:
		var d := Vector2.from_angle(lerpf(a0, a1, float(k) / steps))
		_v(d * (rm - hw), -d, band, false, d)
		_v(d * (rm + hw), d, band, true, d)
	_quads(base, steps + 1, false)


## A straight rod (spokes, the splitter's marks).
func _bar(a: Vector2, b: Vector2, hw: float, band: float) -> void:
	var n := (b - a).normalized().orthogonal()
	var base := _m_base.size()
	_v(a - n * hw, -n, band, false)
	_v(a + n * hw, n, band, false)
	_v(b - n * hw, -n, band, false)
	_v(b + n * hw, n, band, false)
	_quads(base, 2, false)


## A tube along a closed polygon (the splitter's hexagon).
func _poly_tube(path: PackedVector2Array, hw: float, band: float) -> void:
	var n := path.size()
	var base := _m_base.size()
	for i in n:
		var p := path[i]
		var nn := (path[(i + 1) % n] - path[(i - 1 + n) % n]).normalized().orthogonal()
		if nn.dot(p) < 0.0:
			nn = -nn
		var dd := _poly_dd(p)
		_v(p - nn * hw, -nn, band, false, dd)
		_v(p + nn * hw, nn, band, true, dd)
	_quads(base, n, true)


## A filled body, domed: normals face the viewer at `c` and turn out to
## the silhouette at the rim.
func _fan(rim: PackedVector2Array, c: Vector2, band: float) -> void:
	var n := rim.size()
	var ci := _v(c, Vector2.ZERO, band, false, _poly_dd(c))
	for i in n:
		var p := rim[i]
		var nn := (rim[(i + 1) % n] - rim[(i - 1 + n) % n]).normalized().orthogonal()
		if nn.dot(p - c) < 0.0:
			nn = -nn
		_v(p, nn, band, true, _poly_dd(p))
	for i in n:
		_m_idx.append_array([ci, ci + 1 + i, ci + 1 + (i + 1) % n])


## The pendulum's capsule: a spine along its axis faces the viewer, the
## outline turns away, so it shades as a rounded bar.
func _capsule(h: float, r: float, band: float) -> void:
	var rim := PackedVector2Array()
	for k in 5:
		rim.append(Vector2(lerpf(-h, h, k / 4.0), -r))
	for k in range(1, 8):
		rim.append(Vector2(h, 0.0) + Vector2.from_angle(-PI * 0.5 + PI * k / 8.0) * r)
	for k in 5:
		rim.append(Vector2(lerpf(h, -h, k / 4.0), r))
	for k in range(1, 8):
		rim.append(Vector2(-h, 0.0) + Vector2.from_angle(PI * 0.5 + PI * k / 8.0) * r)
	var base := _m_base.size()
	for p in rim:
		var s := Vector2(clampf(p.x, -h, h), 0.0)
		_v(s, Vector2.ZERO, band, false)
		_v(p, (p - s).normalized(), band, true)
	_quads(base, rim.size(), true)


## A hexagon (corner up), each edge split into `sub` pieces.
func _hex(r: float, sub: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var a := Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * r
		var b := Vector2.from_angle((i + 1) * TAU / 6.0 + PI / 6.0) * r
		for k in sub:
			out.append(a.lerp(b, float(k) / sub))
	return out


## A plain disc outline (Pipp, Pakkis): round, soft bodies.
func _round(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * i / n) * r)
	return pts


func _drop_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, -r * 1.75)])
	for i in 17:
		var a := -PI * 0.5 + 0.62 + (TAU - 1.24) * i / 16.0
		pts.append(Vector2.from_angle(a) * r)
	return pts


## Crescent: outer half-circle and an inner half-ellipse sharing the tips,
## thick on the left, tapering to points top and bottom. Never self-crosses.
func _crescent(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI * 0.5 + PI * i / 16.0
		pts.append(Vector2(-cos(a) * r, sin(a) * r))
	for i in range(1, 16):
		var a := PI * 0.5 - PI * i / 16.0
		pts.append(Vector2(-cos(a) * r * 0.22, sin(a) * r * 0.96))
	return pts


## Plates that do not turn with the body (the Vokter's front plate, the
## Spinneren's two orbiting plates): polished metal arcs with their own
## shadow, in world space, one draw call.
func _draw_plates(ci: RID, keep: float) -> void:
	_p_pts.clear()
	_p_uv.clear()
	_p_idx.clear()
	_p_col.clear()
	var metal := Color(Pal.METAL_LIGHT, keep)
	var sh := Color(0.0, 0.0, 0.0, Pal.SHADOW.a * keep)
	match kind:
		Kind.SHIELD:
			_plate(radius + 5.0, shield_ang, SHIELD_HALF, 4.0, metal, sh)
		Kind.BOSS:
			var st: Array = BOSS_STAGES[boss_stage]
			for k in int(st[0]):
				_plate(radius + 11.0, orbit + TAU * k / st[0], deg_to_rad(st[1]), 3.5, metal, sh)
	RenderingServer.canvas_item_add_triangle_array(ci, _p_idx, _p_pts, _p_col, _p_uv)


func _plate(r: float, center: float, half: float, hw: float, metal: Color, sh: Color) -> void:
	for pass_i in 2:
		var shadow := pass_i == 0
		var c := pos + (SHADOW_OFF if shadow else Vector2.ZERO)
		var band := B_SHADOW if shadow else B_METAL
		var base := _p_pts.size()
		var steps := 12
		for k in steps + 1:
			var d := Vector2.from_angle(lerpf(center - half, center + half, float(k) / steps))
			_p_pts.append(c + d * (r - hw))
			_p_uv.append(Vector2(band - d.x, -d.y))
			_p_pts.append(c + d * (r + hw))
			_p_uv.append(Vector2(band + d.x, d.y))
			_p_col.append(sh if shadow else metal)
			_p_col.append(sh if shadow else metal)
		for k in steps:
			var a := base + k * 2
			_p_idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])


# ---------------------------------------------------------------- face

## Face layer, in body space: the jelly's bubbles and the shells' rivets,
## then eye and mouth. World-space extras (the frayed string, the first-
## sighting ring, the boss's health) are drawn through the inverse.
func _draw_face() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	var f := _face
	var inv := _xf.affine_inverse()
	f.draw_set_transform_matrix(inv)
	if fray_t > 0.0 and _attached and rope_alpha > 0.0:
		# Frayed: a few loose fibres at the nearest point, blinking faster
		# as the fray is about to mend.
		var q := _pts[1]
		for i in range(1, 4):
			if _pts[i].distance_to(_fray_at) < q.distance_to(_fray_at):
				q = _pts[i]
		var blink := 0.6 + 0.4 * sin(_clock * lerpf(6.0, 18.0, 1.0 - fray_t / 4.0))
		for k in 3:
			var a := -0.9 + k * 0.9
			f.draw_line(q, q + Vector2.from_angle(a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
			f.draw_line(q, q + Vector2.from_angle(PI - a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
	if _gone:
		f.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if intro_t > 0.0:
		# First sighting: a slow dashed ring marks the new enemy.
		var k := minf(1.0, intro_t / 0.5)
		for i in 12:
			var a0 := _clock * 0.8 + i * TAU / 12.0
			f.draw_arc(pos, radius + 16.0, a0, a0 + 0.3, 6, Color(Pal.INK, 0.5 * k), 1.5, true)
	if patched and phase == Phase.HANGING:
		# Legen's bubble: a thin, shimmering skin around the body.
		var wob := 1.0 + 0.03 * sin(_clock * 7.0)
		f.draw_arc(pos, (radius + 8.0) * wob, 0.0, TAU, 40, Color(Pal.MEDIC_BADGE, 0.55), 2.0, true)
		f.draw_arc(pos, (radius + 8.0) * wob, -2.4, -1.5, 10, Color(Pal.EYE, 0.6), 2.4, true)
	if champion and phase == Phase.HANGING:
		# The champion's aura: a fine gold ring close to the body, a bright
		# glint travelling round it, and a soft warm glow behind.
		var hr := radius * depth_scale() + 7.0
		f.draw_arc(pos, hr + 3.0, 0.0, TAU, 48, Color(Pal.GOLD_LIGHT, 0.12), 6.0, true)
		f.draw_arc(pos, hr, 0.0, TAU, 48, Color(Pal.GOLD, 0.55), 1.4, true)
		var g0 := _clock * 1.6
		f.draw_arc(pos, hr, g0, g0 + 0.9, 12, Color(Pal.GOLD_LIGHT, 0.95), 2.2, true)
	_draw_charm(f)
	_draw_stance(f)
	if kind == Kind.BOSS and phase == Phase.HANGING:
		var hp_max: int = HP[kind]
		for i in hp_max:
			var x := (i - (hp_max - 1) * 0.5) * 10.0
			Pal.disc(f, pos + Vector2(x, radius + 26.0), 2.6, Color(Pal.INK, 0.85) if i < hp else Color(Pal.INK_FAINT, 0.6))
	f.draw_set_transform_matrix(Transform2D.IDENTITY)
	var col := color()
	col.a *= 1.0 - 0.9 * hidden_amt
	_details(col)
	_eye()
	if (champion or is_leader) and phase == Phase.HANGING:
		_crown(col.a)
	if nemesis > 0:
		_scar(col.a)
	if crying > 0.0 and phase == Phase.HANGING:
		_tears(col.a)


## A crown set on the top of the body, in its own space, so it turns and
## squashes with it and is sized to the body (a champion's a little grander).
func _crown(a: float) -> void:
	var w := radius * (0.95 if champion else 0.75)
	var h := w * 0.55
	var base := -radius * (0.92 if kind != Kind.ROD else 0.9) + 1.0
	if kind == Kind.ROD:
		base = -radius
	var pts := PackedVector2Array([
		Vector2(-w * 0.5, base), Vector2(-w * 0.55, base - h * 0.75), Vector2(-w * 0.26, base - h * 0.38),
		Vector2(0.0, base - h), Vector2(w * 0.26, base - h * 0.38), Vector2(w * 0.55, base - h * 0.75),
		Vector2(w * 0.5, base)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(1.2, 1.4))
	_face.draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * a))
	_face.draw_colored_polygon(pts, Color(Pal.GOLD, a))
	# A band along the base and a highlight on the left points (lamp side).
	_face.draw_line(Vector2(-w * 0.5, base - 1.2), Vector2(w * 0.5, base - 1.2), Color(Pal.GOLD_DARK, a), 2.4, true)
	_face.draw_line(pts[1], pts[2], Color(Pal.GOLD_LIGHT, 0.8 * a), 1.2, true)
	_face.draw_line(pts[2], pts[3], Color(Pal.GOLD_LIGHT, 0.6 * a), 1.2, true)
	for k in [1, 3, 5]:
		Pal.disc(_face, pts[k] + Vector2(0, 1.5), 1.6, Color(Pal.GOLD_LIGHT, a))
	if champion:
		Pal.disc(_face, Vector2(0, base - h * 0.35), 2.2, Color(Pal.CORAL.lerp(Pal.SHADE, 0.5), a))


## Cute and crying: tears roll from both sides of the eye, over the face.
func _tears(a: float) -> void:
	var er := _eye_r()
	var eo := Vector2(0.0, -er * 0.35)
	for sx: float in [-1.0, 1.0]:
		var k := fposmod(_clock * 1.3 + (0.5 if sx > 0.0 else 0.0), 1.0)
		var p := eo + Vector2(sx * er * 0.95, er * 0.2 + k * radius * 0.55)
		var c := Color(Pal.DROP.lightened(0.35), 0.9 * (1.0 - k * 0.7) * a)
		Pal.disc(_face, p, 2.4, c)
		_face.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.0, -0.6), p + Vector2(0, -5.0), p + Vector2(2.0, -0.6)]), c)


## Nemesis: a stitched scar slashed across the eye (one more per level).
func _scar(a: float) -> void:
	var h := maxf(_hole(), radius * 0.45)
	for k in mini(nemesis, 2):
		var o := Vector2(k * h * 0.35, -k * h * 0.2)
		var p0 := Vector2(-h * 0.75, -h * 0.8) + o
		var p1 := Vector2(h * 0.55, h * 0.75) + o
		_face.draw_line(p0 + Vector2(1, 1), p1 + Vector2(1, 1), Color(0, 0, 0, 0.35 * a), 3.0, true)
		_face.draw_line(p0, p1, Color(Color("E9B7AE"), 0.95 * a), 2.2, true)
		var n := (p1 - p0).orthogonal().normalized() * 3.5
		for s in 3:
			var m := p0.lerp(p1, 0.25 + 0.25 * s)
			_face.draw_line(m - n, m + n, Color(Pal.PUPIL, 0.8 * a), 1.2, true)


## Radius of the open centre of ring-shaped bodies (where the face sits).
func _hole() -> float:
	match kind:
		Kind.RING: return radius - 9.5
		Kind.HEAVY: return radius - 16.0
		Kind.SHIELD: return radius - 9.0
		Kind.REEL: return radius - 7.5
		Kind.SPLIT: return radius - 9.0
		Kind.MEDIC: return radius - 9.0
	return 0.0


## Bubbles rising slowly through jelly; rivets on the heavy's ring (gone
## once it cracks), bolts on the sentry, a hub on the reel.
func _details(col: Color) -> void:
	var f := _face
	if mood == Mood.GRUMPY and anger > 0.35 and phase == Phase.HANGING:
		# Steam from the top: two wisps rising and fading, faster when angrier.
		for sx: float in [-1.0, 1.0]:
			var k := fposmod(_clock * lerpf(0.8, 1.8, anger) + (0.5 if sx > 0.0 else 0.0), 1.0)
			var p := Vector2(sx * radius * 0.55, -radius - 4.0 - k * 16.0)
			Pal.disc(f, p + Vector2(sin(k * 6.0) * 2.0 * sx, 0), 3.5 + k * 4.0, Color(Pal.INK.lightened(0.2), minf(1.0, (anger - 0.35) * 1.4) * 0.85 * (1.0 - k) * col.a))

	if kind == Kind.PIPP:
		# A tiny beak under the eye and a tuft of down on top.
		var bk := Color("F2A65A", col.a)
		f.draw_colored_polygon(PackedVector2Array([Vector2(-4.5, radius * 0.42), Vector2(4.5, radius * 0.42), Vector2(0, radius * 0.42 + 6.5)]), bk)
		for i in 3:
			var x := (i - 1) * 4.0
			f.draw_line(Vector2(x, -radius + 1.0), Vector2(x * 1.8, -radius - 7.0 - (2.0 if i == 1 else 0.0)), Color(col.lightened(0.3), col.a), 2.0, true)
	elif kind == Kind.PAKKIS:
		# Its little sack of tricks, tied at the neck, on its side.
		var sc := Vector2(radius * 0.78, radius * 0.45)
		var sack := Color("C99A6A", col.a)
		f.draw_circle(sc + Vector2(1.5, 1.5), 9.5, Color(0, 0, 0, 0.3 * col.a), true, -1.0, true)
		f.draw_circle(sc, 9.5, sack, true, -1.0, true)
		f.draw_circle(sc + Vector2(-2.5, -2.5), 3.0, Color(Color("E6C39A"), 0.8 * col.a), true, -1.0, true)
		f.draw_line(sc + Vector2(-4, -9), sc + Vector2(4, -9), Color(Color("8A6340"), col.a), 3.0, true)
		if charm_flash > 0.0:
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.6
				f.draw_line(sc + Vector2.from_angle(a) * 12.0, sc + Vector2.from_angle(a) * (16.0 + 4.0 * charm_flash), Color(Pal.GOLD_LIGHT, charm_flash * col.a), 1.5, true)
	if morale > 0.35 and phase == Phase.HANGING and not panicked():
		# Nervous sweat: a drop that runs down the side and fades.
		var k := fposmod(_clock * 0.8 + _hue_shift * 20.0, 1.0)
		var a := (morale - 0.35) / 0.65 * sin(PI * k) * col.a
		var p := Vector2(radius * 0.55, -radius * 0.55 + k * radius * 0.6)
		Pal.disc(f, p, 2.6, Color(Pal.DROP.lightened(0.4), 0.8 * a))
		f.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.2, -0.8), p + Vector2(0, -5.5), p + Vector2(2.2, -0.8)]), Color(Pal.DROP.lightened(0.4), 0.8 * a))
	if _admire_t > 0.0:
		# The Speilet catching its own reflection: a small star on the glint.
		var s := sin(PI * minf(1.0, _admire_t / 1.3)) * 4.5
		var sp := Vector2(-radius * 0.42, -radius * 0.42)
		f.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 1, 0.9 * col.a), 1.4, true)
		f.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 1, 0.9 * col.a), 1.4, true)
	if kind == Kind.MEDIC:
		# A mint badge with a white cross on the rim.
		var bp := Vector2(radius * 0.62, -radius * 0.62)
		Pal.disc(f, bp + Vector2(1.0, 1.0), 7.5, Color(0, 0, 0, 0.35 * col.a))
		Pal.disc(f, bp, 7.5, Color(Pal.MEDIC_BADGE, col.a))
		f.draw_rect(Rect2(bp - Vector2(4.5, 1.4), Vector2(9.0, 2.8)), Color(Pal.EYE, col.a))
		f.draw_rect(Rect2(bp - Vector2(1.4, 4.5), Vector2(2.8, 9.0)), Color(Pal.EYE, col.a))
	elif kind == Kind.MIRROR:
		# Two glints across the polished face.
		# They slide across the face as the viewer leans (and it turns).
		var g := Color(1, 1, 1, 0.35 * col.a)
		var sh := (view_dir.rotated(-body_rot) * radius * 0.35)
		f.draw_line(Vector2(-radius * 0.7, radius * 0.1) + sh, Vector2(-radius * 0.1, -radius * 0.7) + sh, g, 3.0, true)
		f.draw_line(Vector2(-radius * 0.35, radius * 0.45) + sh * 1.4, Vector2(radius * 0.2, -radius * 0.1) + sh * 1.4, Color(g, g.a * 0.6), 1.6, true)
	if soft:
		var h := _hole()
		if h > 0.0:
			for i in 3:
				var ph := _clock * (7.0 + i * 2.5) + i * 17.0 + _hue_shift * 300.0
				var y := h * 0.7 - fposmod(ph, h * 1.4)
				var x := sin(_clock * 0.9 + i * 2.1) * h * 0.45
				var fade := 1.0 - absf(y) / (h * 0.75)
				if fade > 0.0:
					Pal.disc(f, Vector2(x, y), 1.4 + i * 0.5, Color(col.lightened(0.35), 0.3 * fade * col.a))
		return
	var rv := Color(col.lightened(0.45), col.a)
	var sh := Color(0, 0, 0, 0.4 * col.a)
	match kind:
		Kind.HEAVY:
			if hp > 1:
				for i in 8:
					var p := Vector2.from_angle(i * TAU / 8.0 + 0.2) * (radius - 3.0)
					Pal.disc(f, p + Vector2(0.7, 0.7), 1.5, sh)
					Pal.disc(f, p, 1.3, rv)
		Kind.SHIELD:
			for i in 4:
				var p := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * (radius - 5.0)
				Pal.disc(f, p + Vector2(0.7, 0.7), 2.0, sh)
				Pal.disc(f, p, 1.8, rv)
		Kind.REEL:
			Pal.disc(f, Vector2.ZERO, 11.5, Color(col.darkened(0.35), col.a))
			Pal.disc(f, Vector2.ZERO, 9.5, Color(col.darkened(0.6), col.a))
		Kind.BOSS:
			# Cracks spread across the shell stage by stage.
			if boss_stage >= 1:
				var cc := Color(col.darkened(0.55), col.a)
				var cracks := [[Vector2(0.55, -0.7), Vector2(0.3, -0.35), Vector2(0.42, -0.1)], [Vector2(-0.8, 0.2), Vector2(-0.45, 0.28), Vector2(-0.3, 0.55)]]
				if boss_stage >= 2:
					cracks.append([Vector2(0.1, 0.85), Vector2(0.2, 0.5), Vector2(0.05, 0.3)])
					cracks.append([Vector2(-0.6, -0.6), Vector2(-0.35, -0.42), Vector2(-0.4, -0.15)])
				for c: Array in cracks:
					var pts := PackedVector2Array()
					for q: Vector2 in c:
						pts.append(q * radius)
					f.draw_polyline(pts, cc, 2.0, true)


## The mouth carries the mood: a small smile at rest, a worried line when
## you aim at it, an "o" when startled, a smirk when smug, a tongue when it
## taunts, a frown in rage and a grimace when struck. Drawn in eye space.
func _mouth(er: float) -> void:
	var f := _face
	var y := er * 1.25
	var w := er * 0.85
	var ink := Color(Pal.EYE, 0.9 * modulate.a * (1.0 - 0.8 * hidden_amt))
	var dark := Color(Pal.PUPIL, 0.95 * modulate.a)
	var pts := PackedVector2Array()
	w *= _mouth_w
	if _closed_t > 0.0 or phase == Phase.FALLING:
		# Clenched: a short tight line, pinched at the corners.
		f.draw_line(Vector2(-w * 0.42, y), Vector2(w * 0.42, y), ink, 1.6, true)
		f.draw_line(Vector2(-w * 0.42, y - 1.2), Vector2(-w * 0.42, y + 1.2), ink, 1.2, true)
		f.draw_line(Vector2(w * 0.42, y - 1.2), Vector2(w * 0.42, y + 1.2), ink, 1.2, true)
	elif startle_t > 0.0 or panicked():
		Pal.disc(f, Vector2(0, y + 1.0), er * 0.26, dark)
		f.draw_arc(Vector2(0, y + 1.0), er * 0.26, 0.0, TAU, 14, ink, 1.4, true)
	elif _taunt >= 0.0:
		# Open grin with the tongue out.
		var grin := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			grin.append(Vector2(cos(a) * w * 0.55, y - 1.0 + sin(a) * w * 0.45))
		f.draw_colored_polygon(grin, dark)
		Pal.disc(f, Vector2(w * 0.12, y + w * 0.32), w * 0.24, Color("E86A8A", modulate.a))
		f.draw_line(Vector2(-w * 0.55, y - 1.0), Vector2(w * 0.55, y - 1.0), ink, 1.5, true)
	elif enraged:
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.5, y + 2.0 - (1.0 - t * t) * 3.0))
		f.draw_polyline(pts, ink, 1.8, true)
	elif squint or aimed or tele_t > 0.0:
		# Worried: a small downturned curve.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.36, y + 1.6 - (1.0 - t * t) * 1.6))
		f.draw_polyline(pts, ink, 1.4, true)
	elif smug > 0.35:
		# Smirk: flat on one side, curled up on the other.
		for i in 7:
			var t := i / 6.0
			pts.append(Vector2(lerpf(-w * 0.45, w * 0.55, t), y + 0.5 - pow(t, 3.0) * 3.2 * smug))
		f.draw_polyline(pts, ink, 1.7, true)
	else:
		# At rest, each its own: from a pout to a broad smile.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.4, y + (1.0 - t * t) * 2.2 * _smile))
		f.draw_polyline(pts, ink, 1.5, true)


func _eye() -> void:
	var f := _face
	_eye_parts()
	if kind != Kind.ROD:
		var er := _eye_r()
		var eo := Vector2(-radius * 0.6, 0.0) if kind == Kind.SHADE else Vector2.ZERO
		eo.y -= er * (0.35 if kind != Kind.DROP else 0.1)
		f.draw_set_transform_matrix(Transform2D(0.0, eo))
		_mouth(er)
	f.draw_set_transform_matrix(Transform2D.IDENTITY)


## Eye radius for this kind, and this one's own eye size.
func _eye_r() -> float:
	var er := 9.5
	if kind == Kind.DROP:
		er = 7.0
	elif kind == Kind.BOSS:
		er = 15.0
	return er * _eye_scale


## The colour right around the eye, which the lids are made of: the dark
## recess of a ring body, or the body itself for filled ones.
func _skin() -> Color:
	var c := color()
	if _hole() > 0.0:
		return c.darkened(0.68)
	return c.darkened(0.12)


## Eye (socket, white, pupil, glint, lids and brows) and, after it, the
## mouth, in the eye's own space. The eye itself always stays round; lids
## in the colour around it close over it, edged with a fine dark line that
## curves like a real lid. Blinks, squints, smugness and sleepiness are all
## just how far the lids have come, so every expression stays clean.
func _eye_parts() -> void:
	var f := _face
	# The Skygge's eye sits in the thick part of the crescent.
	var eo := Vector2(-radius * 0.6, 0.0) if kind == Kind.SHADE else Vector2.ZERO
	var er := _eye_r()
	var mouthed := kind != Kind.ROD
	if mouthed:
		# Eye sits a little high so there is room for a mouth below.
		eo.y -= er * (0.35 if kind != Kind.DROP else 0.1)
	var bx := Transform2D(0.0, eo)
	f.draw_set_transform_matrix(bx)
	var wide := maxf(1.0, _open)
	var pr := er * 0.48 / wide * _pupil_scale
	er *= lerpf(1.0, wide, 0.5)
	if kind == Kind.ROD or kind == Kind.DROP or kind == Kind.BOSS or kind == Kind.SHADE:
		# Filled bodies: a dark socket keeps the eye readable.
		Pal.disc(f, Vector2.ZERO, er + 2.0, Color(0, 0, 0, 0.22))
	var lash := Color(Pal.PUPIL, 0.9)
	if phase == Phase.FALLING:
		# Knocked out: a small cross for an eye.
		var xr := er * 0.6
		f.draw_line(Vector2(-xr, -xr), Vector2(xr, xr), Pal.EYE, 2.2, true)
		f.draw_line(Vector2(-xr, xr), Vector2(xr, -xr), Pal.EYE, 2.2, true)
		return
	# How far the lids are closed (0 open .. 1 shut).
	var upper := 1.0 - clampf(_open, 0.0, 1.0)
	upper = maxf(upper, smug * 0.5)
	if mood == Mood.GRUMPY and startle_t <= 0.0:
		# A glare: the lids never quite lift.
		upper = maxf(upper, 0.24 + 0.1 * anger)
	if trait_kind == Trait.SLEEPY and startle_t <= 0.0 and not panicked():
		upper = maxf(upper, 0.32)
	var lower := 0.0
	if squint or tele_t > 0.0:
		lower = 0.22
	if _closed_t > 0.0:
		upper = 1.0
	if upper + lower > 0.92:
		# Shut: a single soft curve, the lashes of a closed lid.
		_lid_curve(f, er, 0.08, 1.0, Color(Pal.EYE, 0.9), 2.0)
		return
	# Fear dilates the pupil (panic, the last of a wave, a nervous team);
	# a sudden fright shrinks it to a pinpoint instead.
	if startle_t <= 0.0 and (panicked() or hurry or morale > 0.55):
		pr = minf(pr * 1.4, er * 0.72)
	Pal.disc(f, Vector2.ZERO, er, Pal.EYE)
	var look := _pupil
	if trait_kind == Trait.SHY and not aimed and not incoming:
		# Shy: never quite meets your eye.
		look = Vector2(-look.x * 0.6, look.y * 0.4 + 0.35)
	var pupil := look * (er - pr - 1.2)
	Pal.disc(f, pupil, pr, Pal.PUPIL)
	Pal.disc(f, pupil - Vector2(pr, pr) * 0.35, pr * 0.28, Color(Pal.EYE, 0.7))
	var skin := _skin()
	if upper > 0.02:
		_lid(f, er, upper, true, skin, lash)
	if lower > 0.02:
		_lid(f, er, lower, false, skin, lash)
	if mood == Mood.CUTE:
		var cheek := minf(er * 1.3, radius * 0.6)
		for sx: float in [-1.0, 1.0]:
			Pal.disc(f, Vector2(sx * cheek, er * 0.95), minf(er * 0.3, radius * 0.18), Color(Pal.SHADE, 0.35))
		Pal.disc(f, pupil + Vector2(pr * 0.4, pr * 0.35), pr * 0.16, Color(Pal.EYE, 0.8))
	if trait_kind == Trait.SHY and aimed and soft:
		# A faint blush when it is looked at down the sights.
		for sx: float in [-1.0, 1.0]:
			Pal.disc(f, Vector2(sx * er * 1.25, er * 0.95), er * 0.32, Color(Pal.SHADE, 0.28))
	if kind == Kind.ROD:
		return
	# Brows: fine arcs, set by mood (and by personality at rest).
	var bc := Color(Pal.EYE if kind != Kind.BOSS else Pal.PUPIL, 0.75)
	var worried := (aimed or panicked() or hurry or morale > 0.6) and not enraged and smug < 0.3 and _taunt < 0.0
	if enraged or mood == Mood.GRUMPY:
		# A frown: the brows dip toward the middle (lower still when angrier).
		var k := 0.85 if enraged else lerpf(1.02, 0.86, anger)
		_brow(f, er, -1.0, -k, -1.42, bc)
		_brow(f, er, 1.0, -k, -1.42, bc)
	elif worried:
		_brow(f, er, -1.0, -1.25, -1.55, bc)
		_brow(f, er, 1.0, -1.25, -1.55, bc)
	elif smug > 0.2:
		# One brow up, the other level: the look of someone unimpressed.
		_brow(f, er, -1.0, -1.35, -1.3, Color(bc, bc.a * smug))
		_brow(f, er, 1.0, -1.55 - 0.25 * smug, -1.4, Color(bc, bc.a * smug))
	elif trait_kind == Trait.PROUD:
		_brow(f, er, -1.0, -1.45, -1.5, Color(bc, 0.45))
		_brow(f, er, 1.0, -1.45, -1.5, Color(bc, 0.45))
	elif mood == Mood.CUTE:
		# Soft, raised brows: all innocence.
		_brow(f, er, -1.0, -1.6, -1.45, Color(bc, 0.4))
		_brow(f, er, 1.0, -1.6, -1.45, Color(bc, 0.4))


## A lid over the round eye: filled in the skin colour from the top (or the
## bottom) down to a gently curved edge, with a fine lash line along it.
func _lid(f: Node2D, er: float, amount: float, top: bool, skin: Color, lash: Color) -> void:
	var r := er + 0.9
	var edge := -er + 2.0 * er * amount if top else er - 2.0 * er * amount
	var hw := sqrt(maxf(0.0, r * r - edge * edge))
	if hw < 0.5:
		return
	# The edge sags toward the middle (top) or lifts (bottom): an almond.
	var sag := er * 0.22 * (1.0 - amount) * (1.0 if top else -1.0)
	var pts := PackedVector2Array()
	var a0 := atan2(edge, hw)
	var a1 := atan2(edge, -hw)
	# Around the outside of the eye, from one end of the edge to the other.
	var span := (a1 - a0) if top else (a1 - a0 - TAU)
	if top and span > 0.0:
		span -= TAU
	if not top and span < 0.0:
		span += TAU
	for i in 13:
		pts.append(Vector2.from_angle(a0 + span * i / 12.0) * r)
	var edge_pts := PackedVector2Array()
	for i in 9:
		var t := lerpf(-1.0, 1.0, i / 8.0)
		edge_pts.append(Vector2(t * hw, edge + sag * (1.0 - t * t)))
	# The edge's end points coincide with the arc's: leave them out, or the
	# polygon has duplicate corners and will not triangulate.
	pts.append_array(edge_pts.slice(1, edge_pts.size() - 1))
	f.draw_colored_polygon(pts, skin)
	f.draw_polyline(edge_pts, lash, 1.5 if top else 1.1, true)


## The line of a closed eye: a soft curve, bowed down.
func _lid_curve(f: Node2D, er: float, y: float, bow: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var t := lerpf(-1.0, 1.0, i / 8.0)
		pts.append(Vector2(t * er * 0.85, y * er + er * 0.22 * bow * (1.0 - t * t)))
	f.draw_polyline(pts, col, w, true)


## One brow, as a fine arc above the eye; `inner_y` and `outer_y` are in
## eye radii (negative is up), `sx` the side.
func _brow(f: Node2D, er: float, sx: float, inner_y: float, outer_y: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		var x := lerpf(0.28, 1.12, t) * er * sx
		var y := lerpf(inner_y, outer_y, t) * er - sin(PI * t) * er * 0.12
		pts.append(Vector2(x, y))
	f.draw_polyline(pts, col, 1.7, true)
