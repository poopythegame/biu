extends Node2D

@export var bomb_scene: PackedScene
@export var tile_size: int = 16
@export var max_bombs: int = 1 

var ray: RayCast2D
var facing_direction: Vector2 = Vector2.DOWN
var active_bombs: Array[Node] = [] 

# [NEW] Visual state for animation
var indicator_pos: Vector2
var tween: Tween

func _ready() -> void:
	ray = RayCast2D.new()
	ray.enabled = false 
	add_child(ray)
	add_to_group("revertable")
	
	# [NEW] Initialize visual position
	indicator_pos = facing_direction * tile_size

func _unhandled_input(event: InputEvent) -> void:
	var player = get_parent()
	if not player: return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			# Record state before placing
			if active_bombs.size() < max_bombs:
				if player.has_node("HistoryManager"):
					player.get_node("HistoryManager").record_snapshot()
				try_place_bomb()
			else:
				print("Bomb limit reached!")
		
		elif event.keycode == KEY_X:
			# Record state before exploding
			if player.has_node("HistoryManager"):
				player.get_node("HistoryManager").record_snapshot()
				
			if player.has_method("trigger_explosion_sequence"):
				player.trigger_explosion_sequence()

func update_direction(new_dir: Vector2) -> void:
	# Filter redundant updates to allow the tween to complete smoothly
	if facing_direction == new_dir and indicator_pos.distance_to(new_dir * tile_size) < 0.1:
		return

	facing_direction = new_dir
	
	# [NEW] Animate the indicator separately from logic
	if tween: tween.kill()
	tween = create_tween()
	
	var target_pos = facing_direction * tile_size
	
	# Elastic/Bouncy animation
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_update_draw_pos, indicator_pos, target_pos, 0.5)

# [NEW] Helper to update position and redraw
func _update_draw_pos(pos: Vector2) -> void:
	indicator_pos = pos
	queue_redraw()

func try_place_bomb() -> void:
	var player = get_parent()
	
	if not bomb_scene or (player.get("is_moving") and player.is_moving):
		return

	ray.position = Vector2.ZERO
	# Logic uses the snapped facing_direction (instant), not the visual indicator
	ray.target_position = facing_direction * tile_size
	ray.collision_mask = 2 + 4 
	ray.force_raycast_update()
	
	if not ray.is_colliding():
		spawn_bomb()
	else:
		print("Blocked! Cannot place bomb.")

func spawn_bomb() -> void:
	# Spawn at the LOGICAL position, even if animation is still playing
	var target_pos = global_position + (facing_direction * tile_size)
	spawn_bomb_at(target_pos)

func spawn_bomb_at(pos: Vector2) -> Node:
	var new_bomb = bomb_scene.instantiate()
	new_bomb.global_position = pos
	
	active_bombs.append(new_bomb)
	new_bomb.tree_exiting.connect(_on_bomb_removed.bind(new_bomb))
	
	# Add to Level (Grandparent of component)
	get_parent().get_parent().add_child(new_bomb)
	
	queue_redraw()
	return new_bomb

func actual_explode_logic() -> void:
	for bomb in active_bombs:
		if is_instance_valid(bomb) and bomb.has_method("explode"):
			bomb.explode()
			break # STOP after exploding the first bomb found (FIFO order)

func _on_bomb_removed(bomb: Node) -> void:
	if bomb in active_bombs:
		active_bombs.erase(bomb)
		queue_redraw()

func _draw() -> void:
	var color = Color(1, 0, 0, 0.4)
	if active_bombs.size() >= max_bombs:
		color = Color(0.2, 0.2, 0.2, 0.4)
		
	var size = Vector2(tile_size, tile_size)
	
	# [NEW] Draw using the animated 'indicator_pos'
	var draw_pos = indicator_pos - (size / 2.0)
	draw_rect(Rect2(draw_pos, size), color, false, 2.0)

func record_data() -> Dictionary:
	var bombs_data = []
	for bomb in active_bombs:
		if is_instance_valid(bomb) and bomb.has_method("record_data"):
			bombs_data.append(bomb.record_data())
	
	return {
		"bombs": bombs_data,
		"facing_direction": facing_direction
	}

func restore_data(data: Dictionary) -> void:
	# 1. Clear current bombs
	var current_list = active_bombs.duplicate()
	active_bombs.clear()
	for bomb in current_list:
		if is_instance_valid(bomb):
			if bomb.has_method("is_floating_object") and bomb.is_floating_object():
				if bomb.has_method("restore_water"):
					bomb.restore_water()
			bomb.queue_free()
	
	# 2. Respawn bombs from data
	if "bombs" in data:
		for bomb_data in data.bombs:
			var new_bomb = spawn_bomb_at(bomb_data.pos)
			if new_bomb.has_method("restore_data"):
				new_bomb.restore_data(bomb_data)
	
	# 3. Restore Rotation
	if "facing_direction" in data:
		facing_direction = data.facing_direction
		
		# [NEW] Snap instantly when restoring (no animation)
		if tween: tween.kill()
		indicator_pos = facing_direction * tile_size
		queue_redraw()
