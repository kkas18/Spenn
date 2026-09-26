extends Node
class_name SpennDirector
signal wave_changed(wave:int)
signal wave_cleared(wave:int,bonus:int)
signal target_struck(at:Vector2,color:Color)
const Target=preload("res://scripts/target.gd")
const Shadow=preload("res://scripts/cloud_shadow_projector.gd")
var wave:int=1
var remaining:int=0
var spawn_parent:Node
var colors:Array[Color]=[Color("#487CCB"),Color("#6756C8"),Color("#57A06E"),Color("#D89A4B")]
func setup(parent:Node)->void:
 spawn_parent=parent
 start_wave()
func start_wave()->void:
 var count:int=mini(3+wave,9)
 remaining=count
 var spread:float=540.0/maxf(1.0,float(count-1))
 for i in range(count):
  var target:SpennTarget=Target.new()
  target.position=Vector2(90.0+float(i)*spread,240.0+float((i+wave)%3)*92.0)
  target.target_color=colors[(i+wave)%colors.size()]
  target.kind=(i+wave)%4
  target.radius=maxf(25.0,34.0-float(wave-1)*0.45+float(i%2)*3.0)
  target.points=100+wave*20+(60 if target.kind==SpennTarget.Kind.ARMORED else 0)
  target.destroyed.connect(_on_target_destroyed)
  target.struck.connect(func(at:Vector2,color:Color):target_struck.emit(at,color))
  spawn_parent.add_child(target)
  var line:Line2D=Line2D.new()
  line.width=maxf(1.6,3.0-float(wave)*0.08)
  line.default_color=Color(0.25,0.34,0.42,0.48)
  line.points=PackedVector2Array([Vector2(0,-target.position.y+185),Vector2.ZERO])
  line.z_index=-1
  target.add_child(line)
  var shadow:CloudShadowProjector=Shadow.new()
  shadow.height_hint=120.0+float((i+wave)%3)*75.0
  target.add_child(shadow)
 wave_changed.emit(wave)
func _on_target_destroyed(_points:int)->void:
 remaining-=1
 if remaining<=0:
  var completed:int=wave
  var bonus:int=250*wave
  wave_cleared.emit(completed,bonus)
  wave+=1
  get_tree().create_timer(1.15).timeout.connect(start_wave)
