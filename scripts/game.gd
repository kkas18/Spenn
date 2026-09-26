extends Node2D
## Spenn 2.5D premium prototype.
const CloudEnvironment=preload("res://scripts/cloud_environment.gd")
const HeavenlyAtmosphere=preload("res://scripts/heavenly_atmosphere.gd")
const Launcher=preload("res://scripts/launcher.gd")
const Rail=preload("res://scripts/rail.gd")
const HUD=preload("res://scripts/hud.gd")
const Director=preload("res://scripts/director.gd")
const PauseOverlay=preload("res://scripts/pause_overlay.gd")
const FX=preload("res://scripts/fx.gd")
const Intro=preload("res://scripts/intro.gd")
const GameOver=preload("res://scripts/game_over.gd")
var hud:SpennHUD
var pause_overlay:SpennPauseOverlay
var fx:SpennFX
var launcher:SpennLauncher
var game_ended:bool=false
func _ready()->void:
 var environment:Node2D=CloudEnvironment.new()
 environment.name="CloudEnvironment2_5D"
 add_child(environment)
 var rail:SpennRail=Rail.new()
 rail.position=Vector2(0,185)
 add_child(rail)
 launcher=Launcher.new()
 launcher.position=Vector2(360,1110)
 launcher.fired.connect(_on_fired)
 add_child(launcher)
 hud=HUD.new()
 add_child(hud)
 var atmosphere:HeavenlyAtmosphere=HeavenlyAtmosphere.new()
 atmosphere.name="HeavenlyAtmosphere"
 add_child(atmosphere)
 fx=FX.new()
 add_child(fx)
 var director:SpennDirector=Director.new()
 add_child(director)
 director.wave_changed.connect(hud.set_wave)
 director.target_struck.connect(func(at:Vector2,color:Color):fx.burst(at,color))
 director.setup(self)
 pause_overlay=PauseOverlay.new()
 add_child(pause_overlay)
 hud.pause_requested.connect(pause_overlay.toggle)
 pause_overlay.restart_requested.connect(_restart)
 var intro:SpennIntro=Intro.new()
 add_child(intro)
func _on_fired(projectile:SpennProjectile)->void:
 projectile.resolved.connect(_on_shot_resolved)
func _on_shot_resolved(hit:bool)->void:
 if game_ended:return
 if hit:
  hud.register_hit(100)
 else:
  hud.register_miss()
  if hud.lives<=0:_show_game_over()
func _show_game_over()->void:
 game_ended=true
 launcher.process_mode=Node.PROCESS_MODE_DISABLED
 var overlay:SpennGameOver=GameOver.new()
 overlay.restart_requested.connect(_restart)
 add_child(overlay)
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventScreenTouch and event.pressed and event.double_tap and not game_ended:
  pause_overlay.toggle()
func _restart()->void:
 get_tree().paused=false
 get_tree().reload_current_scene()
