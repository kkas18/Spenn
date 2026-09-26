extends Node2D
## Spenn 2.5D redesign prototype.

const CloudEnvironment=preload("res://scripts/cloud_environment.gd")
const HeavenlyAtmosphere=preload("res://scripts/heavenly_atmosphere.gd")
const Launcher=preload("res://scripts/launcher.gd")
const Rail=preload("res://scripts/rail.gd")
const HUD=preload("res://scripts/hud.gd")
const Director=preload("res://scripts/director.gd")
const PauseOverlay=preload("res://scripts/pause_overlay.gd")
const FX=preload("res://scripts/fx.gd")
const Intro=preload("res://scripts/intro.gd")

var hud
var pause_overlay
var fx

func _ready()->void:
 var environment=CloudEnvironment.new()
 environment.name="CloudEnvironment2_5D"
 add_child(environment)
 var rail=Rail.new()
 rail.position=Vector2(0,185)
 add_child(rail)
 var launcher=Launcher.new()
 launcher.position=Vector2(360,1110)
 add_child(launcher)
 hud=HUD.new()
 add_child(hud)
 var atmosphere=HeavenlyAtmosphere.new()
 atmosphere.name="HeavenlyAtmosphere"
 add_child(atmosphere)
 fx=FX.new()
 add_child(fx)
 var director=Director.new()
 add_child(director)
 director.wave_changed.connect(hud.set_wave)
 director.target_scored.connect(hud.add_score)
 director.target_struck.connect(func(at:Vector2,color:Color): fx.burst(at,color))
 director.setup(self)
 pause_overlay=PauseOverlay.new()
 add_child(pause_overlay)
 hud.pause_requested.connect(pause_overlay.toggle)
 pause_overlay.restart_requested.connect(_restart)
 var intro=Intro.new()
 add_child(intro)

func _unhandled_input(event:InputEvent)->void:
 if event is InputEventScreenTouch and event.pressed and event.double_tap:
  pause_overlay.toggle()

func _restart()->void:
 get_tree().paused=false
 get_tree().reload_current_scene()
