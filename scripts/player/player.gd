extends Node2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D

var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _unhandled_input(event: InputEvent) -> void:
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			attempt_move(inputs[dir])

func attempt_move(direction: Vector2) -> void:
	if is_moving:
		input_buffer = direction
		return
	move(direction)

func move(direction: Vector2) -> void:
	var target_pos = position + (direction * tile_size)
	
	# 1. Check WALLS (Water)
	# The player cannot walk on water directly
	ray.target_position = direction * tile_size
	ray.collision_mask = wall_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		return # Blocked by water

	# 2. Check BOXES
	ray.collision_mask = box_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		var box = ray.get_collider()
		if box.is_in_group("box"):
			if can_push_box(box, direction):
				push_box(box, direction)
				move_player(target_pos)
		else:
			return 
	else:
		move_player(target_pos)

func can_push_box(box: Node2D, direction: Vector2) -> bool:
	var original_global_pos = ray.global_position
	
	ray.global_position = box.global_position
	
	# CHANGE: We ONLY check for other boxes. 
	# We REMOVED 'wall_layer' from the mask because walls are water,
	# and we want to allow pushing into water.
	ray.collision_mask = box_layer 
	ray.force_raycast_update()
	
	var is_blocked = ray.is_colliding()
	
	ray.global_position = original_global_pos
	return not is_blocked

func push_box(box: Node2D, direction: Vector2) -> void:
	var box_target = box.position + (direction * tile_size)
	var tween = create_tween()
	
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position", box_target, move_speed)
	
	# CHANGE: After moving, tell the box to check if it landed on water
	tween.tween_callback(Callable(box, "check_on_water"))

func move_player(target_pos: Vector2) -> void:
	is_moving = true
	var tween = create_tween()
	
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, move_speed)
	tween.tween_callback(_on_move_finished)

func _on_move_finished() -> void:
	is_moving = false
	if input_buffer != Vector2.ZERO:
		var next_move = input_buffer
		input_buffer = Vector2.ZERO
		attempt_move(next_move)
