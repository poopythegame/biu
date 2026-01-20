extends CharacterBody2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 
@export var death_effect_scene: PackedScene

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D
@onready var bomb_placer: Node2D = $BombPlacer 
@onready var history_manager: Node = $HistoryManager
# REFERENCE TO THE VISUAL SPRITE
# Ensure you have a child node named "Sprite" (or "Sprite2D") for this to work.
@onready var sprite: Node2D = $Sprite2D

var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 
var movement_tween: Tween 
var _target_pos: Vector2

var is_knockback_active: bool = false
var has_pending_level_entry: bool = false
var default_scale: Vector2 = Vector2.ONE # Store original scale here
var current_facing_direction: Vector2 = Vector2.DOWN

var is_dead: bool = false

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _ready() -> void:
	add_to_group("revertable")
	add_to_group("player")
	_target_pos = position 
	
	if sprite:
		default_scale = sprite.scale
	else:
		default_scale = scale
	
	# Initialize direction
	if bomb_placer:
		bomb_placer.update_direction(current_facing_direction)
	
	# Update sprite frame instead of rotation
	update_sprite_direction(current_facing_direction)

	if has_node("/root/TransitionLayer"):
		var transition = get_node("/root/TransitionLayer")
		
		# [NEW] Check if we have a stored reset position from a "Reset All" action
		if "stored_reset_position" in transition and transition.stored_reset_position != null:
			print("Resetting to last checkpoint position: ", transition.stored_reset_position)
			
			# Apply Position
			global_position = transition.stored_reset_position
			_target_pos = global_position # Vital: Update target_pos so logic doesn't lerp us back
			
			# Apply Direction (Optional, but nice)
			if "stored_reset_direction" in transition and transition.stored_reset_direction != null:
				var dir = transition.stored_reset_direction
				update_sprite_direction(dir)
				if bomb_placer:
					bomb_placer.update_direction(dir)
			
			# Clear the data so it doesn't persist forever
			transition.stored_reset_position = null
			transition.stored_reset_direction = null
		
		# [FIX] Always fade in when the level starts.
		if transition.has_method("fade_in"):
			transition.fade_in()
		
		if "should_load_game" in transition and transition.should_load_game:
			transition.should_load_game = false
			if history_manager:
				print("Continue requested: Loading save...")
				history_manager.load_game_from_disk()

func _unhandled_input(event: InputEvent) -> void:
	# UTILITY INPUTS
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_level()
		elif event.keycode == KEY_BACKSPACE:
			if history_manager:
				history_manager.undo_last_action()

	# MOVEMENT INPUTS
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			if history_manager:
				history_manager.record_snapshot()
			attempt_move(inputs[dir])

# --- UPDATED CHECKPOINT LOGIC ---

func on_level_entered() -> void:
	# Called by Camera2D when entering a new room.
	# If we are uncontrolled (knockback), DO NOT save yet.
	# We might be flying over a void or hazard.
	if is_knockback_active:
		has_pending_level_entry = true
		return

	# [NEW] Check if we are on floating ground (Layer 32)
	# This prevents saving if standing on a temporary bridge/bomb
	if _is_on_floating_ground():
		print("Level entered on floating object - Checkpoint skipped.")
		return

	# Normal movement (safe): Save checkpoint immediately.
	if history_manager:
		history_manager.save_checkpoint()

func _is_on_floating_ground() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_bodies = true
	# Layer 32 is used for floating boxes in box.gd
	query.collision_mask = 32 
	
	var results = space_state.intersect_point(query)
	return results.size() > 0

func reset_level() -> void:
	if history_manager:
		history_manager.load_checkpoint()

# ---------------------

func update_sprite_direction(direction: Vector2) -> void:
	current_facing_direction = direction
	
	if not sprite: return
	
	match direction:
		Vector2.DOWN:
			sprite.frame_coords.x = 1
		Vector2.UP:
			sprite.frame_coords.x = 0
		Vector2.RIGHT:
			sprite.frame_coords.x = 2
			sprite.flip_h = false
		Vector2.LEFT:
			# If you have a dedicated Left row:
			sprite.frame_coords.x = 3
			sprite.flip_h = false

func attempt_move(direction: Vector2) -> void:
	if bomb_placer:
		bomb_placer.update_direction(direction)
	
	update_sprite_direction(direction)
		
	if is_moving:
		input_buffer = direction
		return
	
	move(direction)

func move(direction: Vector2) -> void:
	var target_pos = position + (direction * tile_size)
	
	# 1. Check WALLS
	ray.target_position = direction * tile_size
	ray.collision_mask = wall_layer
	ray.force_raycast_update()
	if ray.is_colliding(): return 

	# 2. Check BOXES
	ray.collision_mask = box_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		var box = ray.get_collider()
		if box.is_in_group("box"):
			if can_push_box(box, direction):
				push_box(box, direction)
				move_player(target_pos, 0.05)
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
	# snapped() is unstable at the center of tiles (e.g. 24 is 1.5 * 16), causing random rounding errors.
	var grid_pos = (box.position / tile_size).floor()
	var start_pos = grid_pos * tile_size + Vector2(tile_size, tile_size) / 2.0
	
	# Calculate target based on the clean, snapped position
	var box_target = start_pos + (direction * tile_size)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position", box_target, move_speed)
	tween.tween_callback(Callable(box, "check_on_water"))

func move_player(target_pos: Vector2, start_delay: float = 0.0) -> void:
	is_moving = true
	_target_pos = target_pos 
	
	# TRIGGER JELLY ANIMATION
	_animate_jelly(move_speed + 0.04)
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()
	
	if start_delay > 0.0:
		movement_tween.tween_interval(start_delay)

	movement_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "position", target_pos, move_speed)
	movement_tween.tween_callback(_on_move_finished)

func _on_move_finished() -> void:
	is_moving = false
	if input_buffer != Vector2.ZERO:
		var next_move = input_buffer
		input_buffer = Vector2.ZERO
		attempt_move(next_move)

func trigger_explosion_sequence() -> void:
	if is_moving: return
	bomb_placer.actual_explode_logic()

# ------------------------------------------------------------------------------
# KNOCKBACK LOGIC
# ------------------------------------------------------------------------------
func apply_knockback(direction: Vector2, distance: int) -> void:
	if is_moving: return
	is_moving = true
	
	# Enable Knockback Protection Flags
	is_knockback_active = true
	has_pending_level_entry = false
	
	# 1. Calculate Path & Check Obstacles
	var space_state = get_world_2d().direct_space_state
	var valid_distance = 0
	var hit_obstacle = false
	
	for i in range(1, distance + 1):
		var check_pos = global_position + (direction * tile_size * i)
		
		var query = PhysicsPointQueryParameters2D.new()
		query.position = check_pos
		# Check against Walls (2) and Boxes/Bombs (4)
		query.collision_mask = wall_layer + box_layer
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		
		# Check results to see if we hit a REAL obstacle or just Water
		var hit_real_solid = false
		for result in results:
			var collider = result.collider
			
			# If we hit a TileMap, assume it is Water/Floor and fly over it
			# We do this because Water is often on the Wall Layer (2)
			if collider is TileMap or (ClassDB.class_exists("TileMapLayer") and collider.is_class("TileMapLayer")):
				continue
			
			# If we hit a Box or a Wall (Node), we stop.
			hit_real_solid = true
			break
		
		if hit_real_solid:
			hit_obstacle = true
			break
		
		valid_distance = i

	var target_pos = position + (direction * tile_size * valid_distance)
	_target_pos = target_pos 
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()
	
	# 2. Animation Logic
	if hit_obstacle:
		# CRASH: Hard stop!
		var ratio = float(valid_distance) / float(distance) if distance > 0 else 0.0
		var crash_duration = max(0.05, 0.4 * ratio)
		
		_animate_jelly(crash_duration)
		
		movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		movement_tween.tween_property(self, "position", target_pos, crash_duration)
		
	else:
		# FRICTION: Smooth slow down
		_animate_jelly(0.4)
		
		movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		movement_tween.tween_property(self, "position", target_pos, 0.4)
	
	# 3. Landing Logic (Hazards/Void)
	movement_tween.tween_callback(func():
		var space_state1 = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = wall_layer 
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state1.intersect_point(query)
		
		var is_in_void = false
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("is_point_in_level"):
			if not camera.is_point_in_level(global_position):
				is_in_void = true
		
		# CHECK FOR HAZARDS
		if results.size() > 0 or is_in_void:
			print("Player died. Starting sequence...")
			die() 
		else:
			is_moving = false
			is_knockback_active = false
			if has_pending_level_entry:
				has_pending_level_entry = false
				# [NEW] Also check here so we don't save if knockback lands us on a bomb
				if history_manager and not _is_on_floating_ground():
					history_manager.save_checkpoint()
	)

# ------------------------------------------------------------------------------
# BOX INTERACTION
# ------------------------------------------------------------------------------
func carried_by_box(target_pos: Vector2, duration: float) -> void:
	if movement_tween: movement_tween.kill()
	is_moving = true
	_target_pos = target_pos 
	
	# TRIGGER JELLY ANIMATION
	_animate_jelly(duration)
	
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "global_position", target_pos, duration)
	movement_tween.tween_callback(func(): is_moving = false)

# ------------------------------------------------------------------------------
# VISUALS (JELLY EFFECT)
# ------------------------------------------------------------------------------
func _animate_jelly(duration: float) -> void:
	# Use the separate sprite if available, otherwise fallback to self
	var visual_target = sprite if sprite else self
	
	var t = create_tween()
	
	# 1. Stretch (Start of move)
	t.tween_property(visual_target, "scale", default_scale * Vector2(0.8, 1.2), duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 2. Squash (Landing/Impact)
	t.tween_property(visual_target, "scale", default_scale * Vector2(1.2, 0.8), duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 3. Return to Normal (Bounce back)
	t.tween_property(visual_target, "scale", default_scale, duration * 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

# ------------------------------------------------------------------------------
# SAVE/LOAD
# ------------------------------------------------------------------------------
func record_data() -> Dictionary:
	return {
		"position": _target_pos if is_moving else position,
		"facing_dir_x": current_facing_direction.x,
		"facing_dir_y": current_facing_direction.y
	}

func restore_data(data: Dictionary) -> void:
	if movement_tween: movement_tween.kill()
	
	var t = create_tween()
	t.kill()
	
	var visual_target = sprite if sprite else self
	visual_target.scale = default_scale 
	
	# Restore direction from saved vector components
	if "facing_dir_x" in data and "facing_dir_y" in data:
		var dir = Vector2(data.facing_dir_x, data.facing_dir_y)
		update_sprite_direction(dir)
		if bomb_placer:
			bomb_placer.update_direction(dir)
	
	is_moving = false
	is_knockback_active = false
	has_pending_level_entry = false
	
	position = data.position
	_target_pos = data.position
	
	# Only run this check if we are NOT currently dying.
	if not is_dead:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = position
		query.collision_mask = wall_layer 
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			if collider.is_in_group("wall"):
				print("Player reverted into a wall!")
				die()

# Special Reset Function (Reloads Scene instead of Checkpoint)
func restart_level_with_transition() -> void:
	if is_dead: return
	is_dead = true

	# 1. Visual FX (Shake)
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake_screen"):
		camera.shake_screen(0.6) 
	
	# 2. Disable Input and Physics
	set_process_unhandled_input(false)
	set_physics_process(false)
	is_moving = false
	if movement_tween: 
		movement_tween.kill()
	
	# 3. Hide Player Visuals
	if sprite:
		sprite.visible = false
	
	# 4. Spawn Death Particles
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)
	
	# 5. Wait a moment
	await get_tree().create_timer(0.3).timeout
	
	# 6. Transition Out
	if has_node("/root/TransitionLayer"):
		await get_node("/root/TransitionLayer").fade_out(0.4)
		# Ensure we DO NOT load the game on the next start
		get_node("/root/TransitionLayer").should_load_game = false
	else:
		await get_tree().create_timer(0.4).timeout
	
	# 7. Reload the Scene (Full Reset)
	get_tree().reload_current_scene()

func die() -> void:
	if is_dead: return
	is_dead = true

	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake_screen"):
		camera.shake_screen(0.6) 
	
	# 1. Disable Input and Physics
	set_process_unhandled_input(false)
	set_physics_process(false)
	is_moving = false
	if movement_tween: 
		movement_tween.kill()
	
	# 2. Hide Player Visuals
	if sprite:
		sprite.visible = false
	
	# 3. Spawn Death Particles
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)
	
	# 4. Wait a moment
	await get_tree().create_timer(0.3).timeout
	
	# 5. Transition Out
	if has_node("/root/TransitionLayer"):
		await get_node("/root/TransitionLayer").fade_out(0.4)
	else:
		await get_tree().create_timer(0.4).timeout
	
	# 6. Load Checkpoint (Respawn Logic)
	if history_manager:
		history_manager.undo_last_action()
	
	# 7. Restore Player State
	if sprite:
		sprite.visible = true
		sprite.scale = default_scale
		
	set_process_unhandled_input(true)
	set_physics_process(true)
	is_dead = false 
	
	# 8. Transition In
	if has_node("/root/TransitionLayer"):
		get_node("/root/TransitionLayer").fade_in(0.3)
