extends Node2D

@export var bomb_scene: PackedScene
@export var tile_size: int = 16
@export var max_bombs: int = 1 

var ray: RayCast2D
var facing_direction: Vector2 = Vector2.DOWN
var active_bombs: Array[Node] = [] 

func _ready() -> void:
	ray = RayCast2D.new()
	ray.enabled = false 
	add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			# Record state before placing
			if active_bombs.size() < max_bombs:
				get_parent().record_snapshot()
				try_place_bomb()
			else:
				print("Bomb limit reached!")
		
		elif event.keycode == KEY_X:
			# Record state before exploding
			get_parent().record_snapshot()
			if get_parent().has_method("trigger_explosion_sequence"):
				get_parent().trigger_explosion_sequence()

func update_direction(new_dir: Vector2) -> void:
	facing_direction = new_dir
	queue_redraw() 

func try_place_bomb() -> void:
	var player = get_parent()
	
	if not bomb_scene or (player.get("is_moving") and player.is_moving):
		return

	ray.position = Vector2.ZERO
	ray.target_position = facing_direction * tile_size
	ray.collision_mask = 2 + 4 
	ray.force_raycast_update()
	
	if not ray.is_colliding():
		spawn_bomb()
	else:
		print("Blocked! Cannot place bomb.")

func spawn_bomb() -> void:
	var target_pos = global_position + (facing_direction * tile_size)
	spawn_bomb_at(target_pos)
	# Removed "register_bomb_placement" call as History Manager handles it now

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
	# CHANGED: Removed clear_history() to allow undoing explosions
	
	for bomb in active_bombs:
		if is_instance_valid(bomb) and bomb.has_method("explode"):
			bomb.explode()

func _on_bomb_removed(bomb: Node) -> void:
	if bomb in active_bombs:
		active_bombs.erase(bomb)
		queue_redraw()

func _draw() -> void:
	var color = Color(1, 0, 0, 0.4)
	if active_bombs.size() >= max_bombs:
		color = Color(0.2, 0.2, 0.2, 0.4)
		
	var size = Vector2(tile_size, tile_size)
	var draw_pos = (facing_direction * tile_size) - (size / 2.0)
	draw_rect(Rect2(draw_pos, size), color, false, 2.0)
