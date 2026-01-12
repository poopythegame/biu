extends StaticBody2D

# Matches the 'wall_layer' in your player script (Layer 2)
@export_flags_2d_physics var water_layer: int = 2 

# FIX: Add a variable to specify which TileMap layer the water is on.
# Usually Layer 0 is Floor, and Layer 1 is Walls/Water.
@export var tile_map_layer: int = 1

func check_on_water() -> void:
	# Create a point query to check exactly what is under the box
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	
	# We only care about hitting the Water layer
	query.collision_mask = water_layer
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		# We hit water!
		var water_collider = results[0].collider
		become_bridge(water_collider)

func become_bridge(water_collider: Node) -> void:
	print("Box splashed into water!")
	
	# 1. VISUAL: Make it look like a floating crate
	modulate = Color(0.7, 0.7, 0.8) # Dim it slightly
	
	# 2. LOGIC: Stop being a pushable box
	remove_from_group("box")
	
	# Disable collision so Player raycast (Box Layer Check) sees 'empty space' here
	collision_layer = 0
	collision_mask = 0
	
	# 3. ENVIRONMENT: Destroy the water
	# Check for the newer TileMapLayer (Godot 4.3+)
	if ClassDB.class_exists("TileMapLayer") and water_collider.is_class("TileMapLayer"):
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		# TileMapLayer.set_cell takes (coords, source_id, ...) - No layer index needed
		water_collider.set_cell(cell_pos, -1)
		
	# Check for the older TileMap node
	elif water_collider is TileMap:
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		# TileMap.set_cell takes (layer, coords, source_id, ...)
		water_collider.set_cell(0, cell_pos, -1) 
		
	else:
		# If water is an Area2D/StaticBody2D, just delete it
		water_collider.queue_free()
