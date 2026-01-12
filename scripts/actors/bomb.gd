extends StaticBody2D

# Matches the 'wall_layer' in your player script (Layer 2)
@export_flags_2d_physics var water_layer: int = 2 

# Usually Layer 0 is Floor, and Layer 1 is Walls/Water.
@export var tile_map_layer: int = 1

var _water_collider: Node = null
var _water_cell_pos: Vector2i
var _water_source_id: int = -1
var _water_atlas_coords: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	add_to_group("box")

func explode() -> void:
	print("Bomb exploded!")
	
	if is_instance_valid(_water_collider):
		# Handle Godot 4.3+ TileMapLayer
		if ClassDB.class_exists("TileMapLayer") and _water_collider.is_class("TileMapLayer"):
			_water_collider.set_cell(_water_cell_pos, _water_source_id, _water_atlas_coords)
			
		# Handle older TileMap
		elif _water_collider is TileMap:
			# Note: Using layer 0 to match the deletion logic below
			_water_collider.set_cell(0, _water_cell_pos, _water_source_id, _water_atlas_coords)

	# Trigger visual effects here later
	queue_free()

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
	
	# 3. ENVIRONMENT: Destroy the water (and store it first!)
	# Check for the newer TileMapLayer (Godot 4.3+)
	if ClassDB.class_exists("TileMapLayer") and water_collider.is_class("TileMapLayer"):
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		
		_water_collider = water_collider
		_water_cell_pos = cell_pos
		_water_source_id = water_collider.get_cell_source_id(cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(cell_pos)
		
		# TileMapLayer.set_cell takes (coords, source_id, ...) - No layer index needed
		water_collider.set_cell(cell_pos, -1)
		
	# Check for the older TileMap node
	elif water_collider is TileMap:
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		
		_water_collider = water_collider
		_water_cell_pos = cell_pos
		# Assuming layer 0 as per original code
		_water_source_id = water_collider.get_cell_source_id(0, cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(0, cell_pos)
		
		# TileMap.set_cell takes (layer, coords, source_id, ...)
		water_collider.set_cell(0, cell_pos, -1) 
		
	else:
		# If water is an Area2D/StaticBody2D, just delete it
		water_collider.queue_free()
