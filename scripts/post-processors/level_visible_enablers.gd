@tool

## Level Post-Import: Add VisibleEnablers
## VisibleOnScreenEnablers are used to enable/disable nodes when they appear/disappear on screen.
## This is useful to optimise your game by reducing unnecessary processing.

func post_import(level: LDTKLevel) -> LDTKLevel:
	# Z level
	var children = level.get_children()
	for child in children:
		# Check if the node is specifically a TileMapLayer
		if child is TileMapLayer:
			child.z_index = -50
	
	# Create a new VisibleOnScreenEnabler
	var visible_enabler = VisibleOnScreenEnabler2D.new()
	# Supply it the Level's bounding rect.
	visible_enabler.rect = Rect2(Vector2.ZERO, level.size)
	# Add it to the Level node.
	level.add_child(visible_enabler)
	
	return level
