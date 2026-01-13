extends Node2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D
@onready var bomb_placer: Node2D = $BombPlacer 

var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 

# --- NEW: History Manager (Git-like Snapshots) ---
var state_history: Array[Dictionary] = []
const MAX_HISTORY = 50 

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _unhandled_input(event: InputEvent) -> void:
	# UTILITY INPUTS
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_level()
		elif event.keycode == KEY_BACKSPACE:
			undo_last_action()

	# MOVEMENT INPUTS
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			# Record state before moving
			record_snapshot()
			attempt_move(inputs[dir])

func reset_level() -> void:
	get_tree().reload_current_scene()

func attempt_move(direction: Vector2) -> void:
	if bomb_placer:
		bomb_placer.update_direction(direction)
		
	if is_moving:
		input_buffer = direction
		return
	
	move(direction)

func move(direction: Vector2) -> void:
	var target_pos = position + (direction * tile_size)
	
	# 1. Check WALLS (Water)
	ray.target_position = direction * tile_size
	ray.collision_mask = wall_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		return 

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
		# Note: Snapshot handled in _unhandled_input for next move
		attempt_move(next_move)

# ------------------------------------------------------------------------------
# HISTORY MANAGER IMPL
# ------------------------------------------------------------------------------

func record_snapshot() -> void:
	var snapshot = {
		"player_pos": position,
		"boxes": [],
		"bombs": []
	}
	
	# 1. Snapshot Persistent Boxes
	# We iterate the "box" group, but skip bombs (which are also in group "box")
	var boxes = get_tree().get_nodes_in_group("box")
	for box in boxes:
		# Check if this node is managed by bomb_placer (is a bomb)
		if box in bomb_placer.active_bombs:
			continue
			
		if box.has_method("get_snapshot"):
			snapshot.boxes.append(box.get_snapshot())
			
	# 2. Snapshot Transient Bombs
	# Bombs might be destroyed, so we store their DATA and respawn them on undo
	for bomb in bomb_placer.active_bombs:
		if is_instance_valid(bomb) and bomb.has_method("get_snapshot"):
			snapshot.bombs.append(bomb.get_snapshot())
			
	state_history.append(snapshot)
	if state_history.size() > MAX_HISTORY:
		state_history.pop_front()

func undo_last_action() -> void:
	if is_moving or state_history.is_empty():
		return
		
	var snapshot = state_history.pop_back()
	restore_state(snapshot)

func restore_state(snapshot: Dictionary) -> void:
	# 1. Restore Player
	position = snapshot.player_pos
	
	# 2. Restore Boxes
	# Because boxes persist (they aren't destroyed/spawned like bombs),
	# we can rely on the node reference stored in the snapshot.
	for box_data in snapshot.boxes:
		var box = box_data.node
		if is_instance_valid(box) and box.has_method("restore_snapshot"):
			box.restore_snapshot(box_data)
			# Kill any active tweens on the box to stop movement immediately
			var t = box.create_tween()
			t.kill()
			
	# 3. Restore Bombs
	# Bombs are complicated because they might have exploded (freed).
	# Strategy: Delete ALL current bombs, then respawn from snapshot.
	
	# A. Cleanup current active bombs
	# We copy the list because queue_free might not happen immediately
	var current_bombs = bomb_placer.active_bombs.duplicate()
	bomb_placer.active_bombs.clear()
	
	for bomb in current_bombs:
		if is_instance_valid(bomb):
			bomb.queue_free()
			
	# B. Respawn bombs from history
	for bomb_data in snapshot.bombs:
		# Spawn a fresh bomb at the saved position
		var new_bomb = bomb_placer.spawn_bomb_at(bomb_data.pos)
		
		# Restore its internal state (Floating, Water info, etc)
		if new_bomb.has_method("restore_snapshot"):
			new_bomb.restore_snapshot(bomb_data)

# Triggered by BombPlacer input
func trigger_explosion_sequence() -> void:
	if is_moving: return
	bomb_placer.actual_explode_logic()

# ------------------------------------------------------------------------------
# KNOCKBACK LOGIC
# ------------------------------------------------------------------------------
func apply_knockback(direction: Vector2, distance: int) -> void:
	if is_moving: return
	is_moving = true
	
	var start_pos = position
	var target_pos = position + (direction * tile_size * distance)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.4)
	
	tween.tween_callback(func():
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = wall_layer 
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		
		if results.size() > 0:
			print("Player landed on water, returning...")
			var return_tween = create_tween()
			return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			return_tween.tween_property(self, "position", start_pos, 0.3)
			return_tween.tween_callback(func(): is_moving = false)
		else:
			is_moving = false
	)
