class_name UIButton
extends Button
## The one button used across every screen: presses in to 97% on touch-down
## and springs back on release (Motion.FAST / Motion.NORMAL), with a soft
## click and a very light haptic tick on activation.

const PRESSED_SCALE := Vector2(0.97, 0.97)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)


func _on_down() -> void:
	Motion.to(self, "scale", PRESSED_SCALE, Motion.FAST, Motion.Ease.ENTER)


func _on_up() -> void:
	Motion.to(self, "scale", Vector2.ONE, Motion.NORMAL, Motion.Ease.EMPHASIZED)


func _on_pressed() -> void:
	Sfx.play("click")
	Sfx.haptic_pattern("light")
