extends CanvasLayer
class_name SpennIntro

signal finished
var elapsed:float=0.0
var title:Label
var subtitle:Label
var veil:ColorRect

func _ready()->void:
 layer=40
 process_mode=Node.PROCESS_MODE_ALWAYS
 veil=ColorRect.new()
 veil.color=Color(0.06,0.12,0.20,1.0)
 veil.position=Vector2.ZERO
 veil.size=Vector2(720,1280)
 add_child(veil)
 title=Label.new()
 title.text="SPENN"
 title.position=Vector2(220,490)
 title.add_theme_font_size_override("font_size",72)
 title.add_theme_color_override("font_color",Color("#FFF0C2"))
 veil.add_child(title)
 subtitle=Label.new()
 subtitle.text="OVER SKYENE"
 subtitle.position=Vector2(270,585)
 subtitle.add_theme_font_size_override("font_size",20)
 subtitle.add_theme_color_override("font_color",Color(0.86,0.93,1.0,0.8))
 veil.add_child(subtitle)

func _process(delta:float)->void:
 elapsed+=delta
 var pulse:float=0.96+sin(elapsed*2.2)*0.025
 title.scale=Vector2.ONE*pulse
 if elapsed>1.75:
  var fade:float=clampf((elapsed-1.75)/0.55,0.0,1.0)
  veil.modulate.a=1.0-fade
 if elapsed>2.35:
  finished.emit()
  queue_free()
