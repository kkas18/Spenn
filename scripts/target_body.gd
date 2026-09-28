extends Node2D
## Target, part 1 of 3: its state and behaviour (see target_look.gd for how
## it looks and target.gd for its face; `Target` is the class of all three).
##
## A target hanging from the rail on an elastic string (pooled).
## Body: rigid disc on a one-sided spring with its own angular inertia, so
## off-centre hits make it wobble about the string. String: Verlet rope.
## Everything is drawn in world coordinates; the node itself stays at origin.

enum Kind { RING, HEAVY, SPLIT, ROD, DROP, SHIELD, BOSS, REEL, SHADE, MEDIC, MIRROR, PIPP, PAKKIS, CAPTAIN, SEER, SNEAK }
enum Phase { OFF, HANGING, FALLING }

const N := 10                  # rope points
const GRAVITY := 900.0
const STRING_K := 120.0        # spring stiffness per unit mass (1/s²)
const DAMPING := 1.1

const RADIUS := {Kind.RING: 30.0, Kind.HEAVY: 34.0, Kind.SPLIT: 32.0, Kind.ROD: 15.0, Kind.DROP: 22.0, Kind.SHIELD: 26.0, Kind.BOSS: 52.0, Kind.REEL: 24.0, Kind.SHADE: 26.0, Kind.MEDIC: 26.0, Kind.MIRROR: 27.0, Kind.PIPP: 22.0, Kind.PAKKIS: 26.0, Kind.CAPTAIN: 30.0, Kind.SEER: 26.0, Kind.SNEAK: 24.0}
const HP := {Kind.RING: 1, Kind.HEAVY: 2, Kind.SPLIT: 1, Kind.ROD: 1, Kind.DROP: 1, Kind.SHIELD: 1, Kind.BOSS: 8, Kind.REEL: 1, Kind.SHADE: 1, Kind.MEDIC: 1, Kind.MIRROR: 1, Kind.PIPP: 1, Kind.PAKKIS: 1, Kind.CAPTAIN: 2, Kind.SEER: 1, Kind.SNEAK: 1}
const POINTS := {Kind.RING: 10, Kind.HEAVY: 20, Kind.SPLIT: 10, Kind.ROD: 15, Kind.DROP: 5, Kind.SHIELD: 25, Kind.BOSS: 40, Kind.REEL: 20, Kind.SHADE: 25, Kind.MEDIC: 30, Kind.MIRROR: 35, Kind.PIPP: 15, Kind.PAKKIS: 35, Kind.CAPTAIN: 45, Kind.SEER: 40, Kind.SNEAK: 35}
const ROD_HALF := 30.0
# Each individual has its own size within its kind's range (a scale on the
# radius): mass goes with its area, a small one drops a little faster and
# is worth more, a big one is slower and worth less. The Spinneren is
# always itself.
const SIZE := {Kind.RING: Vector2(0.78, 1.3), Kind.HEAVY: Vector2(0.9, 1.2), Kind.SPLIT: Vector2(0.85, 1.2), Kind.ROD: Vector2(0.85, 1.2), Kind.DROP: Vector2(0.8, 1.25), Kind.SHIELD: Vector2(0.9, 1.15), Kind.BOSS: Vector2(1.0, 1.0), Kind.REEL: Vector2(0.85, 1.2), Kind.SHADE: Vector2(0.85, 1.2), Kind.MEDIC: Vector2(0.9, 1.15), Kind.MIRROR: Vector2(0.9, 1.15), Kind.PIPP: Vector2(0.82, 1.05), Kind.PAKKIS: Vector2(0.85, 1.2), Kind.CAPTAIN: Vector2(1.0, 1.2), Kind.SEER: Vector2(0.85, 1.12), Kind.SNEAK: Vector2(0.8, 1.05)}
const HOOK_LEN := 11.5         # rail pivot -> bottom of the hook eyelet
const HOOK_TILT := 0.8
const MASS := {Kind.RING: 1.0, Kind.HEAVY: 1.6, Kind.SPLIT: 1.1, Kind.ROD: 1.25, Kind.DROP: 0.6, Kind.SHIELD: 1.3, Kind.BOSS: 3.5, Kind.REEL: 0.9, Kind.SHADE: 0.9, Kind.MEDIC: 0.9, Kind.MIRROR: 1.2, Kind.PIPP: 0.55, Kind.PAKKIS: 1.0, Kind.CAPTAIN: 1.3, Kind.SEER: 0.9, Kind.SNEAK: 0.8}
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
	Kind.CAPTAIN: [0.9, 70.0, 260.0, 0.0, 0.4],
}
# Material. Soft bodies are jelly. The outline's departure from a circle is
# the sum of shape modes m = 2..5 (cos mθ and sin mθ each), every one its
# own damped spring, as a real drop of jelly wobbles:
#  - frequencies follow a drop's (Rayleigh): higher modes are faster, and
#    bigger bodies slower;
#  - damping grows with m, so small ripples die quickly while the broad
#    squash wobbles a few times;
#  - there is no mode 0 (the area is kept) and no mode 1 (moving the whole
#    outline is moving the body, which the string and contacts already do);
#  - a strike drives the modes with a smooth inward push at the contact
#    (it flattens there and bulges at the sides); a resting contact sets a
#    quiet flat patch instead of hammering; hanging, it sags a little along
#    its string and is drawn to a point where the string holds it, a little
#    more while the string pulls hard.
# Rigid bodies keep their shape; they ring briefly, rock and spin instead.
const SOFT_KINDS := [Kind.RING, Kind.SPLIT, Kind.DROP, Kind.SHADE, Kind.MEDIC, Kind.PIPP, Kind.PAKKIS, Kind.SEER, Kind.SNEAK]
const JELLY_M: Array[int] = [2, 3, 4, 5]
const JELLY_W2 := 15.0          # rad/s: the squash mode of a 30 px body (~2.4 Hz)
const JELLY_Z2 := 0.16          # its damping ratio; mode m has JELLY_Z2 · m / 2
const JELLY_SIGMA := 0.55       # rad: how wide a strike's push is
const JELLY_LIMIT := 0.3        # soft cap on the departure, as a fraction of the radius
const JELLY_SAG := 0.035        # hanging: stretched along the string by this much
const JELLY_PINCH := 0.05       # ... and drawn to a point where it holds
const JELLY_PRESS := 0.14       # the deepest flat patch a resting contact makes
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
const VOICE_REG := {Kind.RING: 1.0, Kind.HEAVY: 0.62, Kind.SPLIT: 0.95, Kind.ROD: 0.82, Kind.DROP: 1.5, Kind.SHIELD: 0.75, Kind.BOSS: 0.5, Kind.REEL: 1.25, Kind.SHADE: 1.1, Kind.MEDIC: 1.18, Kind.MIRROR: 0.9, Kind.PIPP: 1.75, Kind.PAKKIS: 1.1, Kind.CAPTAIN: 0.7, Kind.SEER: 1.05, Kind.SNEAK: 1.3}

const SPEED_MUL := {Kind.RING: 1.0, Kind.HEAVY: 0.85, Kind.SPLIT: 1.0, Kind.ROD: 1.1, Kind.DROP: 1.7, Kind.SHIELD: 0.9, Kind.BOSS: 0.45, Kind.REEL: 1.0, Kind.SHADE: 1.0, Kind.MEDIC: 0.9, Kind.MIRROR: 0.9, Kind.PIPP: 1.15, Kind.PAKKIS: 0.9, Kind.CAPTAIN: 0.85, Kind.SEER: 1.0, Kind.SNEAK: 1.0}

var kind: Kind = Kind.RING
var soft := false
var temper: Temper = Temper.CALM
var trait_kind: Trait = Trait.CURIOUS
var _eye_scale := 1.0           # each face a little different
var _pupil_scale := 1.0
var _mouth_w := 1.0
var _smile := 1.0               # resting mouth: < 0 a pout, 1 a smile
var curious_in := 3.0           # the game uses it to pick a neighbour to look at
# Jelly state: for each mode in JELLY_M its cos and sin amplitude (px), in
# pairs; their velocities; the shape it is being pulled toward (sag, pinch
# and contact patches); and this step's contact presses, gathered by the
# contacts and taken in on the next step.
var _ja := PackedFloat32Array()
var _jv := PackedFloat32Array()
var _jt := PackedFloat32Array()
var _jp := PackedFloat32Array()
var _pull := 0.0                    # the string's pull this step, in body weights
var _pull_f := 1.0                  # ... smoothed (what the jelly's sag follows)
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
var size_k := 1.0              # this one's size (see SIZE)
var rod_half := ROD_HALF       # the Pendel's half length, by its size
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
# Shoving: a jelly arm grows out, winds back (the tell, ARM_WIND), then
# shoves a neighbour sideways; the shover recoils the other way. The game
# decides who and when (see Game._shove_tick); hitting it while it winds
# up stops the shove.
enum Arm { NONE, WIND, SHOVE, BACK }
const ARM_WIND := 0.6
const ARM_REACH := 110.0          # the arm never reaches further than this past the body
var arm := Arm.NONE
var arm_t := 0.0
var arm_to := Vector2.ZERO        # world point the hand reaches for
var arm_victim: Target = null
var arm_life := -1                 # the victim's `life` when the shove began
## Counts this pooled body's lives: a new spawn is a new creature, and
## anything holding on to the old one (an arm, a grudge) must let go.
var life := 0
var shoved := false               # the shove landed this frame (the game acts)
var shove_cd := 0.0

enum Charm { NONE, BUBBLE, SPRING, GHOST, BALLOON, VINE }
const CHARM_COL := [Color.WHITE, Color("7FE0C0"), Color("8FD0FF"), Color("F29CC8"), Color("FFB27A"), Color("9BD86A")]
const BUBBLE_BACK := 8.0
var charm := Charm.NONE
var charm_flash := 0.0
var wants_vine := false
var _charm_cd := 0.0
var _ghost_t := 0.0
var _pipp_hop := 1.5
# The smart ones (see Smarts):
#  - Kommandøren gives orders: `orders_cd` till the next, `order_flash`
#    while one goes out; those it moves remember `ordered_by`.
#  - Leseren reads a shot as it leaves the pouch and steps out of its path;
#    then it is `tired_t` (eyes shut, no dodging) and `read_cd` recovers.
#  - Luringen creeps down while nobody watches (`pace` up to PACE_SNEAK)
#    and freezes, all innocence (`innocent`), the moment you look.
var orders_cd := 1.5
var order_flash := 0.0
var ordered_by: Target = null
var ordered_life := -1
var tired_t := 0.0
var read_cd := 0.0
var read_flash := 0.0
var pace := 1.0
var innocent := 0.0
const PACE_SNEAK := 2.6
# The Mind (see Mind): four leanings, 0..1, from temper, trait, mood and
# kind: bold (stands its ground, baits), wary (flees, climbs), sly (cuts
# across, waits for the release) and social (hides behind a friend).
var p_bold := 0.4
var p_wary := 0.4
var p_sly := 0.3
var p_social := 0.3
var mind_ask := false           # it has watched your aim long enough: the Mind decides
var mind_beat := false          # ... on the beat of your usual release
var wait_t := 0.0               # coiled, waiting for the ball to leave the pouch
var bait_t := 0.0               # dancing in your line of fire for the team
var rush_t := 0.0               # sinking fast while a teammate baits
var _tell_t := 0.0              # the eye shows where it is going; then it goes
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
var _fxf := Transform2D.IDENTITY   # ... and the face's (it follows the jelly's squash)
var _jit := Vector2.ZERO           # this frame's tremble, shared by every layer
var _m_base := PackedVector2Array() # rest positions (jelly moves from these)
var _m_uv0 := PackedVector2Array()  # rest normals (band-coded, as _m_uv)
var _m_dv := PackedInt32Array()     # vertices the jelly moves
var _m_dd := PackedVector2Array()   # ... along this direction
var _m_dn := PackedVector2Array()   # ... their rest normals
var _m_da := PackedInt32Array()     # ... and the angle each sits at (index into _m_cs)
var _m_cs := PackedFloat32Array()   # per angle: cos mθ, sin mθ for each jelly mode
var _m_ang := {}                    # angle key -> index, while building
var _m_amp := -1.0                  # the jelly's size when last applied (skip if unchanged)
var _m_sig := PackedFloat32Array()  # its mode amplitudes then
var _m_mem := 0                     # leading vertices: the membrane
var _m_dim := Vector2i(-1, -1)      # vertex range at reduced alpha (cracked ring)
var _m_key := -1
var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rope_len := 0.0
var _attached := true
var _screen_h := 1280.0
var _pluck_cd := 0.0


func spawn(k: Kind, anchor_pos: Vector2, start_len: float, target_len: float, wait: float) -> void:
	life += 1
	kind = k
	orders_cd = randf_range(1.2, 2.2)
	order_flash = 0.0
	ordered_by = null
	tired_t = 0.0
	read_cd = 0.0
	read_flash = 0.0
	pace = 1.0
	innocent = 0.0
	soft = k in SOFT_KINDS
	_m_key = -1
	_jelly_reset()
	_ring_t = 1.0
	_wander_t = randf_range(2.0, 5.0)
	_queued_x = NAN
	pop_t = 0.0
	_gone = false
	_dropping = false
	# The common Ring spreads a little wider (still clear of the Rod's
	# violet), so a crowd of them is a crowd of individuals.
	var spread := 1.6 if k == Kind.RING else 1.0
	_hue_shift = randf_range(-0.04, 0.04) * spread
	_val_shift = randf_range(-0.05, 0.05) * (1.8 if k == Kind.RING else 1.0)
	covered = false
	_guard_wait = -1.0
	guard_of = null
	smug = 0.0
	_taunt = -1.0
	_taunt_in = randf_range(2.0, 4.0)
	_taunt_delay = -1.0
	temper = _roll_temper()
	_roll_trait()
	mind_ask = false
	mind_beat = false
	wait_t = 0.0
	bait_t = 0.0
	rush_t = 0.0
	_tell_t = 0.0
	if k == Kind.PIPP:
		# Baby proportions: big eyes.
		_eye_scale *= 1.3
		_pupil_scale *= 1.15
	hp = HP[k]
	var sr: Vector2 = SIZE[k]
	size_k = randf_range(sr.x, sr.y)
	radius = RADIUS[k] * size_k
	rod_half = ROD_HALF * size_k
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
	_rope_side.clear()
	_depth_sort()
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
	personality()
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
		# A three-lobed wiggle.
		_jv[2] += 110.0 * (radius / 30.0)
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


## A strike on a soft body: a smooth inward push centred on the contact
## drives the shape modes, so it flattens where it was hit and bulges at the
## sides (the area is kept), then wobbles back. Soft touches below ~40 px/s
## do nothing: a resting contact presses (see press) instead of striking.
func dent(at: Vector2, speed: float) -> void:
	if not soft:
		_ring_t = 0.0
		_ring_dir = (pos - at).normalized()
		return
	var k := clampf((speed - 40.0) * 0.5, 0.0, 440.0) * (radius / 30.0)
	if k <= 0.0:
		return
	var phi := (at - pos).angle() - body_rot
	for j in JELLY_M.size():
		var m := JELLY_M[j]
		var w := k * _jelly_w(m)
		_jv[j * 2] -= w * cos(m * phi)
		_jv[j * 2 + 1] -= w * sin(m * phi)


## A body resting against this one at `at`: a quiet flat patch there,
## `deep` px deep at the contact, for as long as it lasts (gathered for the
## next step). Only the broad modes carry it, so part of it shows as a
## gentle squash along the contact, as a pressed ball flattens.
func press(at: Vector2, deep: float) -> void:
	if not soft or deep <= 0.0:
		return
	var d := minf(deep, radius * JELLY_PRESS) / _jelly_sum()
	var phi := (at - pos).angle() - body_rot
	for j in JELLY_M.size():
		var m := JELLY_M[j]
		var w := d * _jelly_w(m)
		_jp[j * 2] -= w * cos(m * phi)
		_jp[j * 2 + 1] -= w * sin(m * phi)


## How much of a smooth push of width JELLY_SIGMA goes into mode `m`
## (worked out once: [weight per mode..., their sum, the norm of a press]).
static var _jw := PackedFloat32Array()


static func _jelly_w(m: int) -> float:
	if _jw.is_empty():
		var sum := 0.0
		var sq := 0.0
		for k: int in JELLY_M:
			var w := exp(-0.5 * pow(k * JELLY_SIGMA, 2.0))
			_jw.append(w)
			sum += w
			sq += w * w
		_jw.append(sum)
		_jw.append(sqrt(sq) / sum)
	return _jw[m - JELLY_M[0]]


## The push's depth at its centre per unit (the sum of the weights).
static func _jelly_sum() -> float:
	_jelly_w(JELLY_M[0])
	return _jw[JELLY_M.size()]


## The size of the mode amplitudes of the deepest press (per px of depth).
static func _jelly_norm() -> float:
	_jelly_w(JELLY_M[0])
	return _jw[JELLY_M.size() + 1]


## The jelly's broad squash (its m = 2 mode, capped as it is drawn) as a
## stretch in body space, for the face to follow.
func jelly_stretch() -> Transform2D:
	if not soft or _ja.size() < 2:
		return Transform2D.IDENTITY
	var a := _ja[0]
	var b := _ja[1]
	var amp := sqrt(a * a + b * b)
	if amp < 0.05:
		return Transform2D.IDENTITY
	var lim := JELLY_LIMIT * radius
	var e := lim * tanh(amp / lim) / radius
	var th := atan2(b, a) * 0.5
	return Transform2D(th, Vector2.ZERO) * Transform2D(0.0, Vector2(1.0 + e, 1.0 - e), 0.0, Vector2.ZERO) * Transform2D(-th, Vector2.ZERO)


func _jelly_reset() -> void:
	# (Packed arrays are values: each member is sized and cleared itself.)
	var n := JELLY_M.size() * 2
	_ja.resize(n)
	_ja.fill(0.0)
	_jv.resize(n)
	_jv.fill(0.0)
	_jt.resize(n)
	_jt.fill(0.0)
	_jp.resize(n)
	_jp.fill(0.0)
	_pull_f = 1.0
	_m_amp = -1.0


## The outline's departure from the circle (px, before the soft cap) at
## body-space angle `th`.
func jelly_at(th: float) -> float:
	var d := 0.0
	for j in JELLY_M.size():
		var m := JELLY_M[j]
		d += _ja[j * 2] * cos(m * th) + _ja[j * 2 + 1] * sin(m * th)
	return d


func _soft_step(dt: float) -> void:
	if not soft or dt <= 0.0:
		return
	# How hard the string pulls (1 holding its weight at rest; more as it
	# bounces or swings through, none when slack), smoothed.
	_pull_f = lerpf(_pull_f, _pull, 1.0 - exp(-dt * 12.0))
	# The shape it is drawn toward: hanging, stretched along the string and
	# drawn to a point where it holds, a little more while the string pulls
	# hard (a bounce on it) and a little less while it is slack (in a crowd
	# strings go slack and taut all the time, so only gently); falling
	# free, round. Plus any resting contacts.
	_jt.fill(0.0)
	if phase == Phase.HANGING and _attached:
		var stretch := 1.0 + 0.35 * clampf(_pull_f - 1.0, -1.0, 1.0)
		var up := _pts[N - 2] - pos
		var alpha := (up.angle() if up.length_squared() > 1.0 else -PI * 0.5) - body_rot
		var e := JELLY_SAG * stretch * radius
		var p := JELLY_PINCH * stretch * radius
		for j in JELLY_M.size():
			var m := JELLY_M[j]
			var c := (e if m == 2 else 0.0) + p * _jelly_w(m)
			_jt[j * 2] = c * cos(m * alpha)
			_jt[j * 2 + 1] = c * sin(m * alpha)
	# Several neighbours pressing at once flatten it no more than the deepest
	# single patch could (their sum is scaled back).
	var pn := 0.0
	for i in _jp.size():
		pn += _jp[i] * _jp[i]
	var cap := radius * JELLY_PRESS * _jelly_norm()
	var ks := 1.0 if pn <= cap * cap else cap / sqrt(pn)
	for i in _jt.size():
		_jt[i] += _jp[i] * ks
	_jp.fill(0.0)
	var w_scale := JELLY_W2 * sqrt(30.0 / maxf(radius, 8.0)) / sqrt(8.0)
	for j in JELLY_M.size():
		var m := JELLY_M[j]
		var w := w_scale * sqrt(float(m * (m - 1) * (m + 2)))
		var c := 2.0 * JELLY_Z2 * (m * 0.5) * w
		for k in 2:
			var i := j * 2 + k
			_jv[i] += (-w * w * (_ja[i] - _jt[i]) - c * _jv[i]) * dt
			_ja[i] += _jv[i] * dt


func is_hittable() -> bool:
	return phase == Phase.HANGING and delay <= 0.0


## Balls collide with the body only while it is there (Skygge fades out).
func is_solid() -> bool:
	return is_hittable() and hidden_amt < 0.6


## Its worth: a small one is harder to hit and pays more, a big one less.
func points() -> int:
	return maxi(1, roundi(POINTS[kind] / size_k))


## How fast it drops, by kind and size (small ones a little quicker).
func speed_mul() -> float:
	return SPEED_MUL[kind] / sqrt(size_k)


## Its body's own mass: its kind's, by its size (area).
func body_mass() -> float:
	return MASS[kind] * size_k * size_k


func mass() -> float:
	return body_mass() * (1.5 if variant == Var.BIG else 1.0) * (1.4 if champion else 1.0)


## Circle used for target-to-target contact (the rod uses its half span).
func contact_radius() -> float:
	return rod_half + radius * 0.4 if kind == Kind.ROD else radius


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
		dent(pos + Vector2(0, r), speed * 0.7)
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
	if kind == Kind.ROD:
		# The Pendel reaches along its axis too: half its length, as far as
		# it points sideways.
		r += absf(cos(body_rot)) * rod_half
	if pos.x < r:
		pos.x = r
		vel.x = absf(vel.x) * 0.45
	elif pos.x > w - r:
		pos.x = w - r
		vel.x = -absf(vel.x) * 0.45


## The string's bounding box (hook to body), refreshed once per step for
## the contact broad phase; empty when it has no string.
var rope_box := Rect2()

## Render interpolation (see Game._interpolate): where the body was a step
## ago, and how far back from `pos` to draw it this frame.
var prev_pos := Vector2.ZERO
var render_off := Vector2.ZERO


func update_rope_box() -> void:
	if not _attached or rope_alpha <= 0.0:
		rope_box = Rect2(Vector2(-1e6, -1e6), Vector2.ZERO)
		return
	var lo := _pts[0]
	var hi := _pts[0]
	for i in range(1, N):
		lo = lo.min(_pts[i])
		hi = hi.max(_pts[i])
	rope_box = Rect2(lo, hi - lo)


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
	var axis := Vector2.RIGHT.rotated(body_rot) * rod_half
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
	var m := body_mass()
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
	var m := body_mass()
	vel += impulse / m
	ang_vel += clampf((at - pos).cross(impulse) / (radius * radius * m) * 0.6, -6.0, 6.0)


## A ball crossing the string plucks it. Returns true when it did.
func pluck(p: Vector2, v: Vector2, r: float) -> bool:
	return rope_contact(p, p - v / 120.0, v, r) != Vector2.ZERO and consume_pluck()


## A ball meets the string (anywhere a cut does not happen): the string
## bends round the ball and is dragged with it, its tension turning the
## ball a little toward the string's own line and taking some of its speed
## across it; the tug runs down to the body. Pulled too far, the string
## slips off the ball and whips back. Returns the ball's change in velocity.
## `p0` is where the ball was a substep ago (so a fast ball cannot skip it).
func rope_contact(p: Vector2, p0: Vector2, v: Vector2, r: float) -> Vector2:
	if not _attached or rope_alpha < 0.5 or kind == Kind.BOSS:
		return Vector2.ZERO
	var last := N - 1
	var top := _pts[0]
	var line := pos - top
	var ll := line.length()
	if ll < 1.0:
		return Vector2.ZERO
	var reach := r + 1.6
	var dv := Vector2.ZERO
	var touched := false
	for i in last:
		var a := _pts[i]
		var b := _pts[i + 1]
		var cps := Geometry2D.get_closest_points_between_segments(p0, p, a, b)
		var q: Vector2 = cps[1]
		if (cps[0] as Vector2).distance_to(q) >= reach:
			continue
		var seg := b - a
		if seg.length() < 0.001:
			continue
		# The string keeps to the side it was on before this substep: ahead
		# of a ball crossing it, beside one that only grazes it.
		var nr := seg.normalized().orthogonal()
		var side := (q - p0).dot(nr)
		if absf(side) < 0.01:
			side = v.dot(nr)
		var dir := nr * signf(side if side != 0.0 else 1.0)
		# How far the string is already pulled from its straight line: past
		# this it slides off the ball.
		var dev := absf((q - top).cross(line) / ll)
		if dev > 34.0:
			continue
		var t := clampf((q - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var off := (p + dir * reach - q).dot(dir)
		if off <= 0.0:
			continue
		var wa := 0.0 if i == 0 else 1.0 - t
		var wb := 0.0 if (i + 1 == last) else t
		_pts[i] += dir * off * wa
		_pts[i + 1] += dir * off * wb
		touched = true
		var into := v.dot(dir)
		if into > 0.0:
			# Tension grows with the weight below and with the pull.
			# Per 1/120 s substep: a full crossing (a handful of substeps)
			# takes roughly a fifth to a third of the ball's speed across it.
			var k := clampf(0.02 + 0.012 * body_mass() + dev / 1400.0, 0.02, 0.06)
			dv -= dir * into * k
			var along := float(i + t) / last
			vel += dir * into * k * along * 0.35 / body_mass()
			ang_vel += clampf((p - pos).cross(dir * into * k) * 0.0004, -3.0, 3.0)
	if touched and dv == Vector2.ZERO:
		dv = Vector2(0.0001, 0.0)
	return dv


## True once per short cooldown: the game plays the pluck sound on it.
func consume_pluck() -> bool:
	if _pluck_cd > 0.0:
		return false
	_pluck_cd = 0.25
	return true


## Strings at about the same depth hang in one plane and cannot pass
## through each other. Each pair that meets keeps the side it met on (its
## hooks' order along the rail) at every height both strings reach, the
## bodies at their ends included (see _rope_order). Strings at clearly
## different depths hang in different planes and cross freely; the nearer
## is drawn in front (see _depth_sort). When a hook slides past the other
## along the rail the strings must cross: the pair lets them, until they
## have come apart, and then keeps the new side.
const ROPE_GAP := 3.5
const ROPE_DEPTH := 0.5         # depth apart at which strings are in different planes
const ROPE_FORGET := 30         # steps after which a pair that no longer meets is forgotten
static var rope_clock := 0      # contact steps so far (see Contacts.target_contacts)
var _rope_side := {}            # other's instance id -> [side, last step met, passing]


func rope_rope(o: Target) -> void:
	if not _attached or not o._attached or rope_alpha < 0.5 or o.rope_alpha < 0.5:
		return
	var id := o.get_instance_id()
	var hook := o._pts[0].x - _pts[0].x
	var hook_side := signf(hook) if absf(hook) > 2.0 else 0.0
	var e: Array = _rope_side.get(id, [])
	if e.is_empty() or int(e[1]) < rope_clock - ROPE_FORGET:
		# Newly met: the side is their hooks' order (their bodies', when
		# the hooks are level). Met already crossed (they came together at
		# different depths), they are left to part.
		var sd := hook_side if hook_side != 0.0 else signf(o.pos.x - pos.x + 0.001)
		e = [sd, rope_clock, _ropes_cross(o)]
		_rope_side[id] = e
	e[1] = rope_clock
	if not e[2] and hook_side != 0.0 and hook_side != e[0]:
		# The hooks have passed each other along the rail.
		e[0] = hook_side
		e[2] = true
	elif not e[2] and (rope_clock + id) % 8 == 0 and _ropes_cross(o):
		# Now and then a check that the strings did not slip through.
		e[2] = true
	if e[2]:
		if _ropes_cross(o):
			_part_in_depth(o)
			return
		e[2] = false
		e[0] = hook_side if hook_side != 0.0 else signf(o.pos.x - pos.x + 0.001)
	if absf(seen_depth() - o.seen_depth()) >= ROPE_DEPTH:
		return
	var side: float = e[0]
	_rope_order(o, side)
	o._rope_order(self, -side)


## Two strings that have to cross (their hooks passed each other): the one
## drawn in front sways toward you and the other away, until they hang in
## two planes, as real strings would pass one in front of the other.
func _part_in_depth(o: Target) -> void:
	if absf(seen_depth() - o.seen_depth()) >= ROPE_DEPTH + 0.1:
		return
	var front := 1.0 if get_index() > o.get_index() else -1.0
	_z_vel += front * 0.04
	o._z_vel -= front * 0.04


## Keeps this string, and the body at its end, on side `s` of `o`'s string
## (s > 0: `o` is to the right) at every height both reach, and clear of
## `o`'s body. Where it has come within ROPE_GAP (or crossed), both give
## way: the light strings more than the bodies. The points are moved with
## their previous positions, so a push adds no speed (no jitter). Both
## strings hang from the rail and run down, so the other string's point at
## each height is found by walking down it once.
func _rope_order(o: Target, s: float) -> void:
	var top := maxf(_pts[0].y, o._pts[0].y)
	var o_rad := o.shape_radius()
	var my_rad := shape_radius()
	var j := 0
	var last := N - 1
	for i in range(1, N):
		var p := _pts[i]
		var body := i == last
		while j < last - 1 and o._pts[j + 1].y < p.y:
			j += 1
		var v := 0.0
		var by_line := false
		var a := o._pts[j]
		var b := o._pts[j + 1]
		if p.y >= a.y and p.y <= b.y:
			# Beside the other string: the full gap from a little below the
			# rail (up there the hooks set the spacing), and a body's
			# radius when it is this string's body.
			var t := (p.y - a.y) / (b.y - a.y) if b.y - a.y > 0.001 else 0.5
			var x := lerpf(a.x, b.x, t)
			var need := ROPE_GAP * clampf((p.y - top) / 40.0, 0.0, 1.0) + (my_rad if body else 0.0)
			v = need - s * (x - p.x)
			by_line = true
		if not body:
			# Beside the other body: clear of its outline at this height.
			var c := o.closest_point(p)
			var dy := p.y - c.y
			if absf(dy) < o_rad:
				var need := sqrt(o_rad * o_rad - dy * dy) + ROPE_GAP
				var vb := need - s * (c.x - p.x)
				if vb > v:
					v = vb
					by_line = false
		if v <= 0.0:
			continue
		v = minf(v, 6.0)
		var mine := 0.25 if body else 0.5
		var dx := -s * v * mine
		if body:
			pos.x += dx
			if s * vel.x > 0.0:
				vel.x *= 0.7
		else:
			_pts[i].x += dx
			_prev[i].x += dx
		var ox := s * v * (1.0 - mine)
		if by_line:
			var t := clampf((p.y - a.y) / maxf(b.y - a.y, 0.001), 0.0, 1.0)
			o._give_way(j, ox * (1.0 - t))
			o._give_way(j + 1, ox * t)
		else:
			o._give_way(last, ox)


## Moves string point `k` by `dx` sideways (the hook stays put; the last
## point is the body, which is heavier and moves less).
func _give_way(k: int, dx: float) -> void:
	if k <= 0 or dx == 0.0:
		return
	if k == N - 1 and _attached:
		pos.x += dx * 0.5
		if signf(vel.x) == -signf(dx):
			vel.x *= 0.7
		return
	_pts[k].x += dx
	_prev[k].x += dx


## Whether the two strings cross anywhere.
func _ropes_cross(o: Target) -> bool:
	for i in N - 1:
		var a := _pts[i]
		var b := _pts[i + 1]
		for k in N - 1:
			if Geometry2D.segment_intersects_segment(a, b, o._pts[k], o._pts[k + 1]) != null:
				return true
	return false


## Draws this target in depth order among the others: back ones first, so
## a nearer body or string always passes in front of one further back.
func _depth_sort() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var me := get_index()
	var dest := -1
	var last_t := -1
	for c in parent.get_children():
		if c == self or not (c is Target):
			continue
		var ci := c.get_index()
		last_t = ci
		if dest < 0 and (c as Target).depth > depth:
			dest = ci
	if dest < 0:
		if last_t < 0:
			return
		dest = last_t if me < last_t else last_t + 1
	elif me < dest:
		dest -= 1
	if dest != me:
		parent.move_child(self, dest)


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
					length += descent * speed_mul() * pace * (1.9 if rush_t > 0.0 else 1.0) * _speed_bonus * (2.0 if hurry else 1.0) * (0.55 if charm == Charm.BALLOON else 1.0) * (1.0 + 0.35 * anger) * (1.3 if stance == Stance.FURIOUS else 1.0) * dt
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
			_arm_step(dt)
			_smart_step(dt)
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
	if bait_t > 0.0:
		# Baiting for the team: it dances in your line of fire, no dodging.
		if _taunt < 0.0:
			taunt()
		return
	if kind == Kind.MEDIC:
		_heal_t -= dt
		if _heal_t <= 0.0:
			_heal_t = lerpf(4.5, 2.6, a)
			wants_heal = true
	match kind:
		Kind.MEDIC, Kind.MIRROR, Kind.PAKKIS, Kind.CAPTAIN:
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
			# (Slipping behind a friend is one of the Mind's answers now.)
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


## Common evasion: it watches the shot (narrowed eye) for a reaction time,
## then asks the Mind what to do (see Mind): flee along the rail, cut
## across, climb, bluff, hide or wait for the release. A ball already in
## flight is read faster. After every answer, a cooldown (mind_done).
func _evade(dt: float) -> void:
	var a := aggression
	var prof: Array = EVADE[kind]
	var threatened := aimed or incoming
	if guard_of != null or bait_t > 0.0 or wait_t > 0.0 or mind_ask:
		# On guard duty or baiting, standing in the line of fire is the
		# point; a coiled one waits for the release (see Mind._spring).
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
	mind_ask = true
	mind_beat = on_beat
	_aim_t = 0.0


## The Mind's moves (see Mind). A slide is shown first: the eye darts to
## where it is going and the body holds for `tell` s, then goes (and, once
## the team has learned to feint, may still jink the wrong way first).
func mind_slide(x: float, speed: float, tell: float) -> void:
	x = clampf(x, minf(slide_lo, anchor.x), maxf(slide_hi, anchor.x))
	if absf(x - anchor.x) < 4.0:
		return
	_slide_to = NAN
	_queued_x = x
	_queued_speed = speed
	_tell_t = tell


## Up the string: it tenses (a squash upward and a creak), then winches.
func mind_climb(amount: float) -> void:
	_hop_left += amount
	squash_t = 0.0
	squash_dir = Vector2.UP
	Sfx.play("creak", randf_range(0.95, 1.1))


## A bluff: it stands its ground with a defiant flinch and a smirk.
func mind_hold() -> void:
	ang_vel -= dodge_dir * 1.5
	smug = maxf(smug, 0.5)


## Coiled: it waits (trembling) for the ball to leave the pouch, then
## springs aside at the last moment (see Mind._spring).
func mind_wait(secs: float) -> void:
	wait_t = secs


## For the team: dances in your line of fire while a partner sinks.
func mind_bait(secs: float) -> void:
	bait_t = secs
	taunt()


## For the team: sinks fast while a partner baits (arrows under it say so).
func mind_rush(secs: float) -> void:
	rush_t = secs


## After an answer: a start (when it moved) and the wait before the next.
func mind_done(still: bool) -> void:
	if not still:
		ang_vel += dodge_dir * 2.5
		startle_t = 0.3
	_dodge_cd = lerpf(2.6, 1.1, aggression) * (1.3 if kind == Kind.HEAVY else 1.0) * (0.6 if still else 1.0)
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
	if _tell_t > 0.0:
		# The tell: it holds, eye on where it is going, then goes.
		_tell_t -= dt
		if _tell_t <= 0.0 and not is_nan(_queued_x):
			var x := _queued_x
			_queued_x = NAN
			_slide(x, _queued_speed)
	elif not is_nan(_slide_to):
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
	var hs: Vector2 = SIZE[Kind.HEAVY]
	size_k = clampf(size_k, hs.x, hs.y)
	radius = RADIUS[Kind.HEAVY] * size_k
	_m_key = -1
	_jelly_reset()
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
	_tell_t = 0.0
	startle_t = 0.25
	Sfx.play("slide", randf_range(0.95, 1.1))


## Makes this one a variant of its family (right after spawning).
func set_variant(v: int) -> void:
	variant = v as Var
	if variant == Var.BIG:
		# The big variant is its own size, whatever this one rolled.
		size_k = 1.0
		radius = RADIUS[kind] * (1.35 if kind == Kind.DROP else 1.25)
		hp = maxi(hp, 2)
		_eye_scale *= 1.2
		_m_key = -1


## A wave's finale: bigger, tougher, grumpy.
func make_champion() -> void:
	champion = true
	radius = minf(radius * 1.15, RADIUS[kind] * 1.4)
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
	personality()


## Its leanings for the Mind, from temper, trait, mood and kind.
func personality() -> void:
	var b := 0.35
	var w := 0.4
	var s := 0.3
	var so := 0.3
	match temper:
		Temper.TIMID:
			w += 0.35
			b -= 0.25
			so += 0.15
		Temper.BOLD:
			b += 0.4
			w -= 0.15
		Temper.ERRATIC:
			s += 0.3
	match trait_kind:
		Trait.SHY:
			so += 0.3
		Trait.PROUD:
			b += 0.2
		Trait.JITTERY:
			w += 0.15
		Trait.CURIOUS:
			s += 0.1
		Trait.SLEEPY:
			w -= 0.1
	match mood:
		Mood.GRUMPY:
			b += 0.2
		Mood.CUTE:
			so += 0.35
	match kind:
		Kind.HEAVY, Kind.SHIELD, Kind.MIRROR:
			b += 0.2
		Kind.CAPTAIN:
			so += 0.4
			s += 0.1
		Kind.PIPP, Kind.DROP:
			w += 0.15
		Kind.PAKKIS, Kind.SHADE:
			s += 0.15
	p_bold = clampf(b, 0.0, 1.0)
	p_wary = clampf(w, 0.0, 1.0)
	p_sly = clampf(s, 0.0, 1.0)
	p_social = clampf(so, 0.0, 1.0)


## Grumpy ones take things badly: anger rises (a rage at 1).
## Starts winding up a shove at `v`.
func begin_shove(v: Target) -> void:
	arm = Arm.WIND
	arm_t = 0.0
	arm_victim = v
	arm_life = v.life
	arm_to = v.pos
	voice("taunt" if mood == Mood.GRUMPY else "up", -6.0)


## Stops a shove still winding up (the arm pulls back); true if it was.
func cancel_shove() -> bool:
	if arm != Arm.WIND:
		return false
	arm = Arm.BACK
	arm_t = 0.0
	arm_victim = null
	return true


## The smart ones' own timers, and Luringen's creeping: it sinks fast while
## nothing watches it and freezes the instant you aim at it or a ball comes
## its way (the aim and flight reads are the game's, see Game._update_eyes).
func _smart_step(dt: float) -> void:
	wait_t = maxf(0.0, wait_t - dt)
	bait_t = maxf(0.0, bait_t - dt)
	rush_t = maxf(0.0, rush_t - dt)
	order_flash = maxf(0.0, order_flash - dt)
	tired_t = maxf(0.0, tired_t - dt)
	read_cd = maxf(0.0, read_cd - dt)
	read_flash = maxf(0.0, read_flash - dt)
	if ordered_by != null and not (is_instance_valid(ordered_by) and ordered_by.life == ordered_life and ordered_by.is_hittable()):
		ordered_by = null
	if kind != Kind.SNEAK:
		return
	var watched := phase == Phase.HANGING and (aimed or incoming or alarm or threat_lvl > 0.3)
	pace = move_toward(pace, 0.0 if watched else PACE_SNEAK, dt * (8.0 if watched else 1.6))
	innocent = move_toward(innocent, 1.0 if watched else 0.0, dt * (6.0 if watched else 2.0))


func _arm_step(dt: float) -> void:
	shove_cd = maxf(0.0, shove_cd - dt)
	if arm == Arm.NONE:
		return
	if phase != Phase.HANGING:
		arm = Arm.NONE
		arm_victim = null
		return
	arm_t += dt
	# The victim counts only while it is the same creature, still hanging:
	# once it dies (and its pooled body may already hang somewhere else as
	# a new enemy) the hand lets go and just finishes its motion.
	if arm_victim != null and not (is_instance_valid(arm_victim) and arm_victim.life == arm_life and arm_victim.is_hittable()):
		arm_victim = null
		if arm == Arm.WIND:
			cancel_shove()
			return
	if arm_victim != null:
		arm_to = arm_victim.pos
		if arm == Arm.WIND:
			look_at = arm_victim.pos
			has_look = true
	match arm:
		Arm.WIND:
			if arm_t >= ARM_WIND:
				arm = Arm.SHOVE
				arm_t = 0.0
				shoved = true
		Arm.SHOVE:
			if arm_t >= 0.1:
				arm = Arm.BACK
				arm_t = 0.0
		Arm.BACK:
			if arm_t >= 0.32:
				arm = Arm.NONE
				arm_victim = null


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
	vel.x += wind * dt / body_mass()
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
	h.vel += vel * 0.3 * body_mass() / h.body_mass()
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
	vel.x += wind * dt / body_mass()
	# They are alive: when the hook has moved on, the body pulls itself back
	# under it instead of trailing for seconds on a long string.
	if kind != Kind.ROD and acro != Acro.PUMP:
		var off := anchor.x - pos.x
		if absf(off) > 10.0:
			vel.x += clampf(off * 6.0, -700.0, 700.0) * dt / body_mass()
	var d := pos - anchor
	var dist := d.length()
	_pull = 0.0
	if dist > length and dist > 0.001:
		var dir := d / dist
		# Near the danger line the string pulls tighter (stiffer, less bounce).
		var k := STRING_K * (1.0 + danger * 0.9)
		vel -= dir * k * (dist - length) * dt
		_pull = k * (dist - length) / GRAVITY
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
	vel = impulse * 0.5 / body_mass() + Vector2(0, -120)
	# Keep the wobble it already had; heavier bodies tumble slower.
	spin = ang_vel * 0.5 + randf_range(3.0, 6.0) * (1.0 if impulse.x >= 0.0 else -1.0) / body_mass()
	# Whip recoil: the freed rope springs upward for a few frames.
	for i in range(1, N):
		var k := float(i) / (N - 1)
		_prev[i] = _pts[i] + Vector2(randf_range(-2.0, 2.0), 9.0 + 12.0 * k)


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
	_z_vel += (push_z * 1.4 / body_mass() - w2 * z_swing - 1.4 * _z_vel) * dt
	z_swing = clampf(z_swing + _z_vel * dt, -0.9, 0.9)


## Solid enough to cast a shadow on the wall (and how much).
func shadow_alpha() -> float:
	if phase == Phase.OFF or delay > 0.0 or _gone:
		return 0.0
	return modulate.a * (1.0 - 0.85 * hidden_amt)


## Hook tilt, following the top rope segment's angle from vertical.
func hook_angle() -> float:
	var d := _pts[1] - _pts[0]
	return clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7)


## Where the string leaves the hook; `anchor` is the hook's pivot on the rail.
func eyelet() -> Vector2:
	var d := _pts[1] - _pts[0]
	var a := clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7) if d.length() > 0.01 else 0.0
	return anchor + Vector2(0, HOOK_LEN).rotated(a)


static var _dir_cache := {}


## The viewer's lean (-1..1 each way): shared by every lit body so their
## highlights slide together, and by the mirror's glints.
static var view_dir := Vector2.ZERO


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
