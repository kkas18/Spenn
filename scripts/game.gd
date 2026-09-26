extends Node2D
## Spenn redesign sandbox root.
## Gameplay remains intentionally untouched while the visual foundation is developed.

const CloudEnvironment = preload("res://scripts/cloud_environment.gd")
const HeavenlyAtmosphere = preload("res://scripts/heavenly_atmosphere.gd")
const CloudShadowProjector = preload("res://scripts/cloud_shadow_projector.gd")

func _ready() -> void:
	var environment := CloudEnvironment.new()
	environment.name = "CloudEnvironment2_5D"
	add_child(environment)

	var atmosphere := HeavenlyAtmosphere.new()
	atmosphere.name = "HeavenlyAtmosphere"
	add_child(atmosphere)

	# Temporary depth-reference markers. These demonstrate how future targets
	# project height-dependent shadows without changing gameplay logic.
	_add_depth_reference(Vector2(205, 465), 105.0)
	_add_depth_reference(Vector2(515, 390), 245.0)

func _add_depth_reference(at: Vector2, height: float) -> void:
	var marker := Node2D.new()
	marker.position = at
	marker.z_index = 5
	add_child(marker)

	var shadow := CloudShadowProjector.new()
	shadow.height_hint = height
	marker.add_child(shadow)
