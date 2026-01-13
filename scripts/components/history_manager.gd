extends Node

# Configuration
@export var max_history: int = 50

# State
var state_history: Array[Dictionary] = []

func record_snapshot() -> void:
	var snapshot = {}
	
	# Find all nodes that implement the 'revertable' interface
	var revertables = get_tree().get_nodes_in_group("revertable")
	
	for node in revertables:
		# We use the node's path as the unique ID for persistent objects
		var path = node.get_path()
		
		# Call the interface method
		if node.has_method("record_data"):
			snapshot[path] = node.record_data()
			
	state_history.append(snapshot)
	if state_history.size() > max_history:
		state_history.pop_front()

func undo_last_action() -> void:
	if state_history.is_empty():
		return
	
	# Optional: Prevent undo during movement if the parent Player is moving
	# You might want to move this check to the Player's input handling to keep this generic
	var player = get_parent()
	if player and player.get("is_moving"):
		return

	var snapshot = state_history.pop_back()
	restore_state(snapshot)

func restore_state(snapshot: Dictionary) -> void:
	for node_path in snapshot:
		# Try to find the node in the current scene
		var node = get_node_or_null(node_path)
		
		# If the node exists (Player, Boxes, Managers), restore it
		if node and node.has_method("restore_data"):
			node.restore_data(snapshot[node_path])
