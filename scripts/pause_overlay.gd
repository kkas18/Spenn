extends CanvasLayer
class_name SpennPauseOverlay
signal restart_requested
var panel:ColorRect
func _ready()->void:
 layer=50
 process_mode=Node.PROCESS_MODE_ALWAYS
 panel=ColorRect.new()
 panel.color=Color(0.05,0.09,0.14,0.82)
 panel.position=Vector2.ZERO
 panel.size=Vector2(720,1280)
 add_child(panel)
 var title:Label=Label.new()
 title.text="PAUSE"
 title.position=Vector2(290,420)
 title.add_theme_font_size_override("font_size",38)
 panel.add_child(title)
 var resume:Button=Button.new()
 resume.text="FORTSETT"
 resume.position=Vector2(235,500)
 resume.size=Vector2(250,64)
 resume.pressed.connect(toggle)
 panel.add_child(resume)
 var restart:Button=Button.new()
 restart.text="START PÅ NYTT"
 restart.position=Vector2(235,580)
 restart.size=Vector2(250,64)
 restart.pressed.connect(func(): restart_requested.emit())
 panel.add_child(restart)
 visible=false
func toggle()->void:
 visible=not visible
 get_tree().paused=visible
