@tool

func post_import(level: LDTKLevel) -> LDTKLevel:
	# Z level & Optimization
	var children = level.get_children()
	for child in children:
		# Check if the node is specifically a TileMapLayer (Backgrounds, Floors, etc.)
		if child is TileMapLayer:
			child.z_index = -50
			
			var visible_enabler = VisibleOnScreenEnabler2D.new()
			# Use the level size as the rect, assuming the layer is aligned with the level
			visible_enabler.rect = Rect2(Vector2.ZERO, level.size)
			# Add to the child (TileMapLayer) so only IT gets disabled, not the whole level
			child.add_child(visible_enabler)
	
	return level
