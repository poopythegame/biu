extends "res://scripts/actors/box.gd"

@export var blast_range: int = 5
@export var explosion_effect_scene: PackedScene

func _ready() -> void:
	# Calls box.gd _ready() to setup groups ("box", "revertable") and layers
	super._ready()

func explode() -> void:
	print("Bomb exploded!")

	if explosion_effect_scene:
		var effect = explosion_effect_scene.instantiate()
		effect.global_position = global_position
		# Add to parent (Level) so it doesn't get deleted with the bomb
		get_parent().add_child(effect)

	var space_state = get_world_2d().direct_space_state
	
	# If the bomb is floating (bridge), the player might be standing ON it.
	# We check the exact center for the player to kill them.
	if is_floating:
		var center_query = PhysicsPointQueryParameters2D.new()
		center_query.position = global_position
		center_query.collide_with_bodies = true
		center_query.collision_mask = 1 # Check specifically for Player (Layer 1)
		
		var center_results = space_state.intersect_point(center_query)
		for result in center_results:
			var collider = result.collider
			if collider.has_method("die"):
				print("Player caught in floating bomb explosion!")
				collider.die()

	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	# Detect and push targets
	for dir in directions:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position + (dir * tile_size)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.collision_mask = 0xFFFFFFFF # Check everything
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			if collider == self: continue
			
			# Constraint: If bomb is floating (in water), ONLY affect other floating boxes
			if is_floating:
				var collider_is_floating = false
				if collider.has_method("is_floating_object"):
					collider_is_floating = collider.is_floating_object()
				
				if not collider_is_floating:
					continue
			
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(dir, blast_range)

	# Restore water if this bomb was a bridge before it dies
	if is_floating:
		restore_water()

	queue_free()
