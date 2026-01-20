extends Area2D
class_name DoorDetector

signal state_changed(is_active: bool)

@export var activation_effect_scene: PackedScene

var is_active: bool = false

func _ready() -> void:
	# Enable monitoring
	monitoring = true
	monitorable = false
	
	# Visual feedback (Start inactive)
	# modulate = Color(0.5, 1.5, 0.5)

func _physics_process(_delta: float) -> void:
	var bodies = get_overlapping_bodies()
	var found_valid_body = false
	
	for body in bodies:
		if body.is_in_group("box") or body.is_in_group("player"):
			# Check distance to ensure they are actually "on" the button
			if global_position.distance_to(body.global_position) <= 8.0:
				found_valid_body = true
				break
	
	_update_state(found_valid_body)

func _update_state(new_state: bool) -> void:
	if is_active != new_state:
		if new_state == true:
			_spawn_effect()
			
		is_active = new_state
		state_changed.emit(is_active)

func _spawn_effect() -> void:
	if activation_effect_scene:
		var effect = activation_effect_scene.instantiate()
		effect.global_position = global_position
		# Add to parent (Level/EntityLayer) so it doesn't move if the button moves/scales
		get_tree().get_root().add_child(effect)
