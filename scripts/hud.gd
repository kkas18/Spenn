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
var combo_bar:ColorRect
func _ready()->void:
 var score_plate:=Panel.new()
 score_plate.position=Vector2(22,22);score_plate.size=Vector2(205,92)
 var sb:=StyleBoxFlat.new();sb.bg_color=Color(0.025,0.08,0.13,0.86);sb.border_color=Color("#D9AD55");sb.set_border_width_all(2);sb.corner_radius_top_left=12;sb.corner_radius_top_right=12;sb.corner_radius_bottom_left=12;sb.corner_radius_bottom_right=12
 score_plate.add_theme_stylebox_override("panel",sb);add_child(score_plate)
 score_label=_label(Vector2(40,30),34)
 score_label.add_theme_color_override("font_color",Color("#FFE6A2"))
 wave_label=_label(Vector2(42,76),16)
 mult_label=_label(Vector2(500,36),23)
 toast=_label(Vector2(220,150),27);toast.modulate.a=0.0
 combo_bar=ColorRect.new();combo_bar.position=Vector2(500,72);combo_bar.size=Vector2(92,4);combo_bar.color=Color("#FFD56B");add_child(combo_bar)
 var pause:=Button.new();pause.text="Ⅱ";pause.position=Vector2(635,27);pause.size=Vector2(58,58)
 var ps:=StyleBoxFlat.new();ps.bg_color=Color(0.025,0.08,0.13,0.84);ps.border_color=Color("#D9AD55");ps.set_border_width_all(2);ps.corner_radius_top_left=29;ps.corner_radius_top_right=29;ps.corner_radius_bottom_left=29;ps.corner_radius_bottom_right=29
 pause.add_theme_stylebox_override("normal",ps);pause.pressed.connect(func():pause_requested.emit());add_child(pause)
 refresh()
func _process(delta:float)->void:
 if toast_time>0.0:toast_time-=delta;toast.modulate.a=clampf(toast_time*2.2,0.0,1.0)
func _label(pos:Vector2,size:int)->Label:
 var l:=Label.new();l.position=pos;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",Color("#FFF8E8"));l.add_theme_color_override("font_shadow_color",Color(0.02,0.05,0.08,0.8));l.add_theme_constant_override("shadow_offset_x",2);l.add_theme_constant_override("shadow_offset_y",2);add_child(l);return l
func register_hit(v:int)->void:
 multiplier=mini(multiplier+1,5);var gain:int=v*multiplier;score+=gain;_toast("+%d   ×%d"%[gain,multiplier]);refresh()
func register_miss()->void:
 multiplier=1;lives=maxi(0,lives-1);_toast("BOM   ♥%d"%lives);refresh()
func add_wave_bonus(v:int)->void:score+=v;_toast("KLART!  +%d"%v);refresh()
func set_wave(v:int)->void:wave=v;_toast("BØLGE %d"%wave);refresh()
func _toast(t:String)->void:toast.text=t;toast_time=1.15;toast.modulate.a=1.0
func refresh()->void:
 score_label.text=str(score).pad_zeros(6);wave_label.text="BØLGE %02d"%wave;mult_label.text="×%d   ♥%d"%[multiplier,lives];combo_bar.size.x=18.0+float(multiplier-1)*18.5;combo_bar.modulate.a=0.35+float(multiplier)*0.13
