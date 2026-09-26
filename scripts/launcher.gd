extends Node2D
class_name SpennLauncher
signal fired(projectile)
const Projectile=preload("res://scripts/projectile.gd")
var dragging:bool=false
var pull:Vector2=Vector2.ZERO
var max_pull:float=125.0
var pulse:float=0.0
func _ready()->void:z_index=20;queue_redraw()
func _process(delta:float)->void:pulse+=delta;queue_redraw()
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventScreenTouch or event is InputEventMouseButton:
  if event.pressed and global_position.distance_to(event.position)<125.0:
   dragging=true;pull=Vector2.ZERO;get_viewport().set_input_as_handled()
  elif dragging and not event.pressed:
   _fire();dragging=false;pull=Vector2.ZERO;queue_redraw()
 elif dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
  pull=(event.position-global_position).limit_length(max_pull)
  if pull.y < -15.0:pull.y=-15.0
  queue_redraw()
func _fire()->void:
 if pull.length()<18.0:return
 var ball:SpennProjectile=Projectile.new();ball.global_position=global_position+Vector2(0,-52);get_tree().current_scene.add_child(ball);ball.launch(-pull*5.6);fired.emit(ball)
func _draw()->void:
 var left:=Vector2(-54,-70);var right:=Vector2(54,-70);var pocket:=Vector2(0,-52)+(pull if dragging else Vector2.ZERO)
 # stone platform and contact shadow
 _ellipse(Vector2(0,35),Vector2(112,30),Color(0.03,0.08,0.12,0.30))
 draw_colored_polygon(PackedVector2Array([Vector2(-112,28),Vector2(112,28),Vector2(82,70),Vector2(-76,70)]),Color("#33434A"))
 draw_line(Vector2(-92,27),Vector2(92,27),Color("#79906A"),10,true)
 # layered wood arms
 draw_line(Vector2(-58,18),left,Color("#4A2E1E"),25,true);draw_line(Vector2(58,18),right,Color("#4A2E1E"),25,true)
 draw_line(Vector2(-61,15),left+Vector2(-3,0),Color("#A66C32"),14,true);draw_line(Vector2(61,15),right+Vector2(3,0),Color("#A66C32"),14,true)
 draw_line(Vector2(-64,11),left+Vector2(-6,-2),Color("#D49A4E"),4,true);draw_line(Vector2(64,11),right+Vector2(6,-2),Color("#D49A4E"),4,true)
 # leather bands
 draw_line(left,pocket,Color("#3B241B"),8,true);draw_line(right,pocket,Color("#3B241B"),8,true)
 draw_line(left,pocket,Color("#8C5636"),3,true);draw_line(right,pocket,Color("#8C5636"),3,true)
 # gold caps and projectile
 draw_circle(left,11,Color("#D7A43C"));draw_circle(right,11,Color("#D7A43C"))
 if dragging:
  var power:float=clampf(pull.length()/max_pull,0.0,1.0)
  for i in range(1,6):
   var aim:Vector2=-pull.normalized()*float(i)*44.0
   draw_circle(Vector2(0,-52)+aim,2.4+power*1.8,Color(1.0,0.78,0.28,0.18+power*0.42))
 draw_circle(pocket,17,Color("#B66C1E"));draw_circle(pocket,13,Color("#F1B93F"));draw_circle(pocket+Vector2(-4,-5),5,Color("#FFF0A4"))
func _ellipse(center:Vector2,radii:Vector2,c:Color)->void:
 var pts:=PackedVector2Array()
 for i in range(25):
  var a:float=TAU*float(i)/24.0;pts.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
 draw_colored_polygon(pts,c)
