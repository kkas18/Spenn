extends Node
## Device awareness (autoload `Device`). Reads what phone the game runs on
## (cores, memory, screen size, density, refresh rate, cut-outs) and picks
## an effects tier, so a Galaxy S-class phone gets the full show and an
## older or budget phone stays smooth. The tier also adapts live: if the
## frame rate sags during play it steps down, and never back up within a
## session (no flicker between tiers).
##
## Screen use is handled by the project and the layout: immersive full
## screen, stretch "expand" so every aspect ratio (16:9 up to 21:9 and
## foldables) fills the display, and the safe area keeps the HUD clear of
## the camera cut-out and the gesture bar.

signal tier_changed

enum Tier { LOW, MID, HIGH }

var tier: Tier = Tier.HIGH
var refresh_hz := 60.0
var model := ""

var _slow_t := 0.0
var _cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	model = OS.get_model_name()
	var hz := DisplayServer.screen_get_refresh_rate()
	refresh_hz = hz if hz >= 50.0 else 60.0
	tier = _detect()
	# Never let the phone dim or lock mid-run.
	DisplayServer.screen_set_keep_on(true)
	# Frames are paced by v-sync at the panel's own rate (60/90/120 Hz). No
	# max_fps cap: a timer cap equal to the refresh rate fights v-sync and
	# drops frames now and then.
	Engine.max_fps = 0
	print("Device: %s, %d cores, %.0f Hz, tier %s" % [model, OS.get_processor_count(), refresh_hz, Tier.keys()[tier]])


func _detect() -> Tier:
	if not OS.has_feature("mobile"):
		return Tier.HIGH
	var cores := OS.get_processor_count()
	var mem := float(OS.get_memory_info().get("physical", -1))
	var gb := mem / 1073741824.0 if mem > 0.0 else -1.0
	if cores >= 8 and (gb < 0.0 or gb >= 5.5):
		return Tier.HIGH
	if cores >= 6 or gb >= 3.5:
		return Tier.MID
	return Tier.LOW


## Multiplier for particle counts and other optional detail.
func fx() -> float:
	return [0.5, 0.8, 1.0][tier]


func count(n: int) -> int:
	return maxi(1, int(round(n * fx())))


## Live adaptation: sustained frame drops (below ~80 % of the panel rate
## for 4 s, while the game is running) step the tier down once.
func _process(delta: float) -> void:
	if not OS.has_feature("mobile") or tier == Tier.LOW or get_tree().paused or Engine.time_scale < 0.9:
		_slow_t = 0.0
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var fps := Engine.get_frames_per_second()
	var target := minf(refresh_hz, 60.0) * 0.8
	if fps > 0.0 and fps < target:
		_slow_t += delta
	else:
		_slow_t = maxf(0.0, _slow_t - delta * 2.0)
	if _slow_t > 4.0 and _cooldown <= 0.0:
		tier = (tier - 1) as Tier
		_slow_t = 0.0
		_cooldown = 10.0
		print("Device: frame rate low, effects tier -> %s" % Tier.keys()[tier])
		tier_changed.emit()
