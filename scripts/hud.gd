extends CanvasLayer
class_name SpennHUD
signal pause_requested

var score: int = 0
var wave: int = 1
var lives: int = 3
var multiplier: int = 1
var score_label: Label
var wave_label: Label
var mult_label: Label

func _ready() -> void:
	score_label = _label(Vector2(28,26),32)
	wave_label = _label(Vector2(28,72),18)
	mult_label = _label(Vector2(590,35),22)
	var pause: Button = Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(635,82)
	pause.size = Vector2(56,48)
	pause.pressed.connect(func(): pause_requested.emit())
	add_child(pause)
	refresh()

func _label(pos: Vector2, size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("#FFF8E8"))
	l.add_theme_color_override("font_shadow_color",Color(0.1,0.2,0.3,0.45))
	l.add_theme_constant_override("shadow_offset_x",2)
	l.add_theme_constant_override("shadow_offset_y",2)
	add_child(l)
	return l

func add_score(v: int) -> void:
	score += v * multiplier
	refresh()

func set_wave(v: int) -> void:
	wave = v
	refresh()

func refresh() -> void:
	score_label.text = str(score)
	wave_label.text = "BØLGE %d" % wave
	mult_label.text = "×%d   ♥%d" % [multiplier,lives]
