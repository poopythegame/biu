extends "res://scripts/actors/box.gd"

@export var blast_range: int = 5
@export var explosion_effect_scene: PackedScene

func _ready() -> void:
	# Calls box.gd _ready() to setup groups ("box", "revertable") and layers
	super._ready()

func explode() -> void:
	print("Bomb exploded!")

	# [NEW] Trigger Screen Shake (Medium Intensity)
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake_screen"):
		camera.shake_screen(0.35)

	if explosion_effect_scene:
		var effect = explosion_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)

	var space_state = get_world_2d().direct_space_state
	
	# Check for player on top (Floating Logic)
	if is_floating:
		var center_query = PhysicsPointQueryParameters2D.new()
		center_query.position = global_position
		center_query.collide_with_bodies = true
		center_query.collision_mask = 1 
		
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
		query.collision_mask = 0xFFFFFFFF 
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			if collider == self: continue
			
			if is_floating:
				var collider_is_floating = false
				if collider.has_method("is_floating_object"):
					collider_is_floating = collider.is_floating_object()
				
				if not collider_is_floating:
					continue
			
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(dir, blast_range)

	if is_floating:
		restore_water()

	queue_free()
