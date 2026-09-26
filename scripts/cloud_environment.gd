extends Node2D
## Cinematic 2.5D sky foundation. Procedural fallback until final painted assets are imported.
@export var drift_speed:float=3.2
var t:float=0.0
const TOP:=Color("#153B68")
const MID:=Color("#477FA8")
const HORIZON:=Color("#F1B779")
const GOLD:=Color("#FFD47B")
var far:Array=[[Vector2(80,330),0.55],[Vector2(390,275),0.48],[Vector2(660,360),0.62]]
var mid:Array=[[Vector2(30,640),0.9],[Vector2(430,590),0.85],[Vector2(700,720),1.0]]
var front:Array=[[Vector2(-40,1030),1.5],[Vector2(330,1140),1.7],[Vector2(740,1050),1.45]]
func _ready()->void:
 z_index=-100
 queue_redraw()
func _process(delta:float)->void:
 t+=delta
 queue_redraw()
func _draw()->void:
 _sky()
 _sun()
 _distant_islands()
 _cloud_layer(far,0.12,Color(0.78,0.87,0.94,0.36))
 _island(Vector2(165,720),0.78)
 _island(Vector2(585,610),0.58)
 _cloud_layer(mid,0.32,Color(0.92,0.95,0.98,0.66))
 _cloud_layer(front,0.68,Color(0.985,0.97,0.93,0.94))
 draw_rect(Rect2(0,1120,720,160),Color(0.97,0.73,0.50,0.08))
func _sky()->void:
 for i in range(32):
  var k:float=float(i)/31.0
  var c:Color=TOP.lerp(MID,minf(k*1.55,1.0))
  if k>0.54:c=MID.lerp(HORIZON,(k-0.54)/0.46)
  draw_rect(Rect2(0,float(i)*40.0,720,42),c)
 # cinematic edge depth
 for i in range(8):
  draw_rect(Rect2(float(i)*8,0,8,1280),Color(0.02,0.08,0.16,0.025*(8-i)))
  draw_rect(Rect2(712-float(i)*8,0,8,1280),Color(0.02,0.08,0.16,0.025*(8-i)))
func _sun()->void:
 var p:=Vector2(585,405)
 for r in range(180,35,-18):
  draw_circle(p,r,Color(GOLD,0.006+float(180-r)*0.00008))
 draw_circle(p,35,Color("#FFE8A6"))
func _cloud(center:Vector2,s:float,c:Color)->void:
 _ellipse(center+Vector2(4,22)*s,Vector2(105,34)*s,Color(0.08,0.22,0.36,c.a*0.16))
 var lobes:Array=[[Vector2(-72,9),42.0],[Vector2(-38,-17),56.0],[Vector2(8,-30),70.0],[Vector2(58,-13),57.0],[Vector2(86,12),38.0]]
 for l in lobes:
  draw_circle(center+l[0]*s,l[1]*s,c)
 draw_arc(center+Vector2(-3,-9)*s,69*s,3.55,5.72,18,Color(1,0.95,0.82,c.a*0.30),4*s,true)
func _cloud_layer(items:Array,parallax:float,c:Color)->void:
 for item in items:
  var p:Vector2=item[0]
  var s:float=item[1]
  var x:float=fmod(p.x+t*drift_speed*parallax+130.0,980.0)-130.0
  _cloud(Vector2(x,p.y+sin(t*0.17+p.x)*3.0),s,c)
func _distant_islands()->void:
 _island(Vector2(95,470),0.25)
 _island(Vector2(650,475),0.30)
 _island(Vector2(365,510),0.20)
func _island(p:Vector2,s:float)->void:
 var rock:=PackedVector2Array([p+Vector2(-88,0)*s,p+Vector2(92,0)*s,p+Vector2(62,48)*s,p+Vector2(18,132)*s,p+Vector2(-25,102)*s,p+Vector2(-66,45)*s])
 draw_colored_polygon(rock,Color("#344C59"))
 draw_colored_polygon(PackedVector2Array([p+Vector2(-80,0)*s,p+Vector2(82,0)*s,p+Vector2(50,24)*s,p+Vector2(-52,25)*s]),Color("#6E8B55"))
 draw_arc(p,82*s,PI,TAU,28,Color("#D6B66A"),5*s,true)
 # small castle silhouette
 draw_rect(Rect2(p+Vector2(-15,-38)*s,Vector2(30,38)*s),Color("#233846"))
 draw_rect(Rect2(p+Vector2(-30,-22)*s,Vector2(15,22)*s),Color("#233846"))
 draw_rect(Rect2(p+Vector2(15,-26)*s,Vector2(15,26)*s),Color("#233846"))
func _ellipse(center:Vector2,radii:Vector2,c:Color)->void:
 var pts:=PackedVector2Array()
 for i in range(33):
  var a:float=TAU*float(i)/32.0
  pts.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
 draw_colored_polygon(pts,c)
