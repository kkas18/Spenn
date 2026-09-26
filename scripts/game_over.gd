extends CanvasLayer
class_name SpennGameOver
signal restart_requested
func _ready()->void:
 layer=60
 process_mode=Node.PROCESS_MODE_ALWAYS
 var veil:=ColorRect.new()
 veil.color=Color(0.04,0.08,0.14,0.90)
 veil.position=Vector2.ZERO
 veil.size=Vector2(720,1280)
 add_child(veil)
 var title:=Label.new()
 title.text="RUNDE SLUTT"
 title.position=Vector2(225,450)
 title.add_theme_font_size_override("font_size",42)
 title.add_theme_color_override("font_color",Color("#FFF0C2"))
 veil.add_child(title)
 var sub:=Label.new()
 sub.text="Skyene venter på et nytt forsøk"
 sub.position=Vector2(205,520)
 sub.add_theme_font_size_override("font_size",18)
 veil.add_child(sub)
 var restart:=Button.new()
 restart.text="SPILL IGJEN"
 restart.position=Vector2(235,610)
 restart.size=Vector2(250,68)
 restart.pressed.connect(func():restart_requested.emit())
 veil.add_child(restart)
