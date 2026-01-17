@tool

func post_import(tilesets: Dictionary) -> Dictionary:
	# Behaviour goes here
	for tilemap_node in tilesets.values():
		# Verify the node exists and is a valid instance before accessing properties
		tilemap_node.z_index = -50
	return tilesets
