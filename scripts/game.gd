extends Node2D
## Spenn redesign sandbox root.
## Gameplay remains intentionally untouched while the visual foundation is developed.

const CloudEnvironment = preload("res://scripts/cloud_environment.gd")

func _ready() -> void:
	var environment := CloudEnvironment.new()
	environment.name = "CloudEnvironment2_5D"
	add_child(environment)
