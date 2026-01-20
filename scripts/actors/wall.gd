@tool
extends StaticBody2D

# Default recovery time, overwritten by LDtk import
@export var recover_time: float = 1.0
@export var tile_size: int = 16 

@export var death_effect_scene: PackedScene
@export var recovery_clock_scene: PackedScene 

# Store initial layers to restore them later
var _initial_layer: int
var _initial_mask: int
# [NEW] Store initial scale to handle LDTK resizing correctly
var _initial_scale: Vector2

func _ready() -> void:
	add_to_group("wall")
	
	# Layer 2: Blocks Player movement (Wall Layer)
	# Layer 4: Blocks Box Pushing (Box Layer)
	collision_layer = 2 + 4 
	collision_mask = 0 
	
	_initial_layer = collision_layer
	_initial_mask = collision_mask
	
	# [NEW] Capture the scale set by LevelEntityMapper before we modify it
	_initial_scale = scale

func import_ldtk_fields(fields: Dictionary) -> void:
	if "recover_time" in fields:
		recover_time = fields.recover_time

# Interface called by Bomb.gd when exploded
func apply_knockback(_direction: Vector2, _force: int) -> void:
	destroy()

func destroy() -> void:
	# Prevent multiple destruction calls
	if not visible: return

	# We add it to the parent so it remains visible even after the wall hides
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		get_tree().get_root().add_child(effect)

	# Spawn the Recovery Clock
	if recovery_clock_scene:
		var clock = recovery_clock_scene.instantiate()
		# Add to parent (Level) instead of root, so it moves with the level if needed
		# and stays organized.
		get_parent().add_child(clock)
		
		# Center the clock on the wall. 
		# If the wall's pivot is Top-Left, add half tile_size.
		# If pivot is Center, just use global_position.
		# Based on death_effect using global_position directly, we use that here.
		clock.global_position = global_position 
		
		if clock.has_method("start"):
			clock.start(recover_time - 0.1)

	print("Wall destroyed! Recovering in %s seconds." % recover_time)
	
	# Disable collision and hide visuals
	collision_layer = 0
	visible = false
	
	# Trigger chain reaction to adjacent walls
	_propagate_destruction()
	
	# Start recovery timer
	var timer = get_tree().create_timer(recover_time)
	timer.timeout.connect(_on_recover_timeout)

func _propagate_destruction() -> void:
	var space_state = get_world_2d().direct_space_state
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for dir in directions:
		# Check adjacent tiles
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position + (dir * tile_size)
		
		# Look specifically for Wall Layer (Bit 1 = Value 2)
		query.collision_mask = 2 
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			
			# If we find a valid neighbor wall that hasn't been destroyed yet
			if is_instance_valid(collider) and collider != self:
				if collider.is_in_group("wall") and collider.has_method("destroy"):
					# This will call destroy(), which checks 'visible' to prevent infinite loops
					collider.destroy()

func _on_recover_timeout() -> void:
	# Recover the wall
	print("Wall recovering...")
	visible = true
	collision_layer = _initial_layer
	
	# Check if Player is trapped inside the restored wall
	# We query Layer 1 (Player) at our position
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 1 # Player Layer
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("die"):
			print("Wall recovered on top of player!")
			collider.die()
	
	# Bounce Animation: Start at zero and spring back to initial size
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _initial_scale, 0.6)
