extends Node2D
class_name SpennFX

func burst(at:Vector2,color:Color=Color("#FFE49A"))->void:
 var ring:=ImpactRing.new()
 ring.position=at
 ring.tint=color
 add_child(ring)

class ImpactRing:
 extends Node2D
 var age:float=0.0
 var tint:Color=Color.WHITE
 func _process(delta:float)->void:
  age+=delta
  queue_redraw()
  if age>0.38: queue_free()
 func _draw()->void:
  var k:float=clampf(age/0.38,0.0,1.0)
  draw_arc(Vector2.ZERO,lerpf(10.0,54.0,k),0,TAU,30,Color(tint,1.0-k),lerpf(6.0,1.0,k),true)
  for i in range(8):
   var a:float=TAU*float(i)/8.0
   var p:=Vector2(cos(a),sin(a))*lerpf(14.0,48.0,k)
   draw_circle(p,lerpf(4.0,1.0,k),Color(tint,1.0-k))
