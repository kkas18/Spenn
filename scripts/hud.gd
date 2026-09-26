extends CanvasLayer
class_name SpennHUD
signal pause_requested
var score:int=0
var wave:int=1
var lives:int=3
var multiplier:int=1
var score_label:Label
var wave_label:Label
var mult_label:Label
var toast:Label
var toast_time:float=0.0
func _ready()->void:
 score_label=_label(Vector2(28,26),32)
 wave_label=_label(Vector2(28,72),18)
 mult_label=_label(Vector2(540,35),22)
 toast=_label(Vector2(240,150),26)
 toast.modulate.a=0.0
 var pause:Button=Button.new()
 pause.text="Ⅱ"
 pause.position=Vector2(635,82)
 pause.size=Vector2(56,48)
 pause.pressed.connect(func():pause_requested.emit())
 add_child(pause)
 refresh()
func _process(delta:float)->void:
 if toast_time>0.0:
  toast_time-=delta
  toast.modulate.a=clampf(toast_time*2.0,0.0,1.0)
func _label(pos:Vector2,size:int)->Label:
 var l:Label=Label.new()
 l.position=pos
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",Color("#FFF8E8"))
 l.add_theme_color_override("font_shadow_color",Color(0.1,0.2,0.3,0.45))
 l.add_theme_constant_override("shadow_offset_x",2)
 l.add_theme_constant_override("shadow_offset_y",2)
 add_child(l)
 return l
func register_hit(v:int)->void:
 multiplier=mini(multiplier+1,5)
 score+=v*multiplier
 _toast("+%d   ×%d"%[v*multiplier,multiplier])
 refresh()
func register_miss()->void:
 multiplier=1
 lives=maxi(0,lives-1)
 _toast("BOM   ♥%d"%lives)
 refresh()
func set_wave(v:int)->void:
 wave=v
 _toast("BØLGE %d"%wave)
 refresh()
func _toast(t:String)->void:
 toast.text=t
 toast_time=1.1
 toast.modulate.a=1.0
func refresh()->void:
 score_label.text=str(score)
 wave_label.text="BØLGE %d"%wave
 mult_label.text="×%d   ♥%d"%[multiplier,lives]
