extends Area2D
class_name SpennTarget
signal destroyed(points:int)
signal struck(at:Vector2,color:Color)

enum Kind { ORB, ARMORED, HEX, DROP }
@export var target_color:Color=Color("#6557D9")
@export var points:int=100
@export var radius:float=34.0
@export var kind:Kind=Kind.ORB
var hp:int=1
var phase:float=0.0
var age:float=0.0
var hit_flash:float=0.0

func _ready()->void:
 add_to_group("targets")
 collision_layer=2
 collision_mask=1
 hp=2 if kind==Kind.ARMORED else 1
 var shape:CollisionShape2D=CollisionShape2D.new()
 var circle:CircleShape2D=CircleShape2D.new()
 circle.radius=radius
 shape.shape=circle
 add_child(shape)
 phase=position.x*0.017
 queue_redraw()

func _process(delta:float)->void:
 age+=delta
 hit_flash=maxf(0.0,hit_flash-delta*5.0)
 rotation=sin(age*1.55+phase)*(0.035 if kind!=Kind.DROP else 0.065)
 var breathe:float=1.0+sin(age*2.1+phase)*0.012
 scale=Vector2(breathe,breathe)
 queue_redraw()

func hit()->void:
 hit_flash=1.0
 struck.emit(global_position,target_color)
 hp-=1
 if hp<=0:
  destroyed.emit(points)
  queue_free()

func _draw()->void:
 var c:Color=target_color.lerp(Color.WHITE,hit_flash*0.45)
 for r in range(int(radius+12),int(radius),-2):
  draw_circle(Vector2(5,8),r,Color(0.10,0.22,0.34,0.025))
 match kind:
  Kind.HEX: _draw_hex(c)
  Kind.DROP: _draw_drop(c)
  _: _draw_orb(c)
 _draw_face()
 if kind==Kind.ARMORED:
  draw_arc(Vector2.ZERO,radius-8,0,TAU,40,Color("#FFE5A0"),5,true)

func _draw_orb(c:Color)->void:
 draw_circle(Vector2.ZERO,radius,Color("#F8F2E7"))
 draw_circle(Vector2.ZERO,radius-4,c.darkened(0.16))
 draw_circle(Vector2(-9,-10),radius*0.48,c.lightened(0.18))
 draw_circle(Vector2(-12,-14),radius*0.12,Color(1,1,1,0.52))
 draw_arc(Vector2.ZERO,radius-2,0,TAU,40,Color(1,1,1,0.30),2,true)

func _draw_hex(c:Color)->void:
 var pts:PackedVector2Array=PackedVector2Array()
 for i in range(6):
  var a:float=-PI/2.0+TAU*float(i)/6.0
  pts.append(Vector2(cos(a),sin(a))*radius)
 draw_colored_polygon(pts,c.darkened(0.12))
 var outline:PackedVector2Array=pts.duplicate()
 outline.append(pts[0])
 draw_polyline(outline,Color("#FFF0C2"),3,true)

func _draw_drop(c:Color)->void:
 var pts:=PackedVector2Array([Vector2(0,-radius),Vector2(radius*0.82,5),Vector2(radius*0.55,radius*0.72),Vector2(0,radius),Vector2(-radius*0.55,radius*0.72),Vector2(-radius*0.82,5)])
 draw_colored_polygon(pts,c)
 draw_circle(Vector2(-9,-9),6,Color(1,1,1,0.38))

func _draw_face()->void:
 draw_circle(Vector2(0,3),7,Color(0.08,0.12,0.18,0.72))
 draw_circle(Vector2(-2,1),2,Color("#FFF7D0"))
