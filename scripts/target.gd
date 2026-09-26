extends Area2D
class_name SpennTarget
signal destroyed(points:int)
signal struck(at:Vector2,color:Color)
enum Kind{ORB,ARMORED,HEX,DROP}
@export var target_color:Color=Color("#6557D9")
@export var points:int=100
@export var radius:float=34.0
@export var kind:Kind=Kind.ORB
var hp:int=1
var phase:float=0.0
var age:float=0.0
var hit_flash:float=0.0
func _ready()->void:
 add_to_group("targets");collision_layer=2;collision_mask=1;hp=3 if kind==Kind.ARMORED else 1
 var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=radius;shape.shape=circle;add_child(shape);phase=position.x*0.017;queue_redraw()
func _process(delta:float)->void:
 age+=delta;hit_flash=maxf(0.0,hit_flash-delta*5.0);rotation=sin(age*1.4+phase)*(0.028 if kind!=Kind.DROP else 0.05);var breathe:float=1.0+sin(age*2.0+phase)*0.009;scale=Vector2(breathe,breathe);queue_redraw()
func hit()->void:
 hit_flash=1.0;struck.emit(global_position,target_color);hp-=1
 if hp<=0:destroyed.emit(points);queue_free()
func _draw()->void:
 var c:Color=target_color.lerp(Color.WHITE,hit_flash*0.5)
 _ellipse(Vector2(8,12),Vector2(radius+10,(radius+10)*0.34),Color(0.02,0.08,0.13,0.28))
 match kind:
  Kind.HEX:_hex(c)
  Kind.DROP:_drop(c)
  _:_orb(c)
 _core()
 if kind==Kind.ARMORED:_armor()
func _orb(c:Color)->void:
 draw_circle(Vector2.ZERO,radius+5,Color("#C99637"));draw_circle(Vector2.ZERO,radius+2,Color("#FFE09A"));draw_circle(Vector2.ZERO,radius-3,c.darkened(0.28));draw_circle(Vector2(-8,-9),radius*0.52,c.lightened(0.12));draw_arc(Vector2.ZERO,radius-5,0,TAU,44,Color(0.04,0.09,0.14,0.58),3,true)
func _hex(c:Color)->void:
 var outer:=_poly(6,radius+6);var inner:=_poly(6,radius)
 draw_colored_polygon(outer,Color("#E0B14D"));draw_colored_polygon(inner,c.darkened(0.22))
 var outline:=outer.duplicate();outline.append(outer[0]);draw_polyline(outline,Color("#FFE5A0"),2.5,true)
func _drop(c:Color)->void:
 var pts:=PackedVector2Array([Vector2(0,-radius-7),Vector2(radius*0.88,3),Vector2(radius*0.55,radius*0.78),Vector2(0,radius+3),Vector2(-radius*0.55,radius*0.78),Vector2(-radius*0.88,3)])
 draw_colored_polygon(pts,Color("#D59A3B"));var inner:=pts.duplicate()
 for i in range(inner.size()):inner[i]*=0.82
 draw_colored_polygon(inner,c.darkened(0.14));draw_circle(Vector2(-8,-10),5,Color(1,0.92,0.72,0.5))
func _armor()->void:
 for i in range(8):
  var a:float=TAU*float(i)/8.0;var p:=Vector2(cos(a),sin(a))*(radius+8);var q:=Vector2(cos(a),sin(a))*(radius+17);draw_line(p,q,Color("#D6A13D"),6,true)
 draw_arc(Vector2.ZERO,radius-9,0,TAU,40,Color("#FFE5A0"),5,true)
func _core()->void:
 draw_circle(Vector2(2,3),9,Color("#101A20"));draw_circle(Vector2(-1,0),3,Color("#FFF1B4"));draw_circle(Vector2(4,6),2,Color(0.2,0.45,0.6,0.7))
func _poly(n:int,r:float)->PackedVector2Array:
 var pts:=PackedVector2Array()
 for i in range(n):
  var a:float=-PI/2.0+TAU*float(i)/float(n);pts.append(Vector2(cos(a),sin(a))*r)
 return pts
func _ellipse(center:Vector2,radii:Vector2,c:Color)->void:
 var pts:=PackedVector2Array()
 for i in range(25):
  var a:float=TAU*float(i)/24.0;pts.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
 draw_colored_polygon(pts,c)
