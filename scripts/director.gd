extends Node
class_name SpennDirector
signal wave_changed(wave: int)
signal target_scored(points: int)
const Target=preload("res://scripts/target.gd")
const Shadow=preload("res://scripts/cloud_shadow_projector.gd")
var wave:=1
var remaining:=0
var spawn_parent:Node
var colors=[Color("#487CCB"),Color("#6756C8"),Color("#57A06E"),Color("#D89A4B")]
func setup(parent:Node)->void:
 spawn_parent=parent
 start_wave()
func start_wave()->void:
 var count:=min(3+wave,8)
 remaining=count
 for i in range(count):
  var target:=Target.new()
  target.position=Vector2(90.0+float(i)*(540.0/max(1.0,float(count-1))),245.0+float(i%3)*92.0)
  target.target_color=colors[i%colors.size()]
  target.points=100+wave*15
  target.destroyed.connect(_on_target_destroyed)
  spawn_parent.add_child(target)
  var line:=Line2D.new()
  line.width=3.0
  line.default_color=Color(0.25,0.34,0.42,0.48)
  line.points=PackedVector2Array([Vector2(0,-target.position.y+185),Vector2.ZERO])
  line.z_index=-1
  target.add_child(line)
  var shadow:=Shadow.new()
  shadow.height_hint=120.0+float(i%3)*75.0
  target.add_child(shadow)
 wave_changed.emit(wave)
func _on_target_destroyed(points:int)->void:
 remaining-=1
 target_scored.emit(points)
 if remaining<=0:
  wave+=1
  get_tree().create_timer(0.65).timeout.connect(start_wave)
