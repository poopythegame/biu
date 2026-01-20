extends Node

# Configuration
@export var max_history: int = 50
const SAVE_PATH = "user://savegame.dat"

# State
var state_history: Array[Dictionary] = []

func record_snapshot() -> void:
	var snapshot = _capture_state()
	state_history.append(snapshot)
	if state_history.size() > max_history:
		state_history.pop_front()

func undo_last_action() -> void:
	if state_history.is_empty():
		return
	
	var player = get_parent()
	if player and player.get("is_moving"):
		return

	var snapshot = state_history.pop_back()
	restore_state(snapshot)

# --- CHECKPOINT LOGIC ---

func save_checkpoint() -> void:
	record_snapshot()
	
	if not state_history.is_empty():
		state_history.back()["is_tag"] = true
		print("Checkpoint tagged at history step: %d" % state_history.size())

func load_checkpoint() -> void:
	if state_history.is_empty():
		return
	
	print("Loading checkpoint (Rewinding to tag)...")
	
	while not state_history.is_empty():
		var current_snapshot = state_history.back()
		
		if current_snapshot.get("is_tag", false):
			restore_state(current_snapshot)
			break
		
		undo_last_action()

# --- DISK SERIALIZATION ---

func save_game_to_disk() -> void:
	# 1. Find the latest tagged snapshot (Checkpoint)
	var snapshot_to_save = {}
	
	# Iterate backwards to find the most recent tag
	for i in range(state_history.size() - 1, -1, -1):
		if state_history[i].get("is_tag", false):
			snapshot_to_save = state_history[i]
			break
	
	if snapshot_to_save.is_empty():
		print("No tagged checkpoint found to save.")
		# Optional: Force a save if none exists
		snapshot_to_save = _capture_state()
		snapshot_to_save["is_tag"] = true

	# 2. Serialize to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# var_to_str handles Vector2, Color, and basic types automatically
		file.store_string(var_to_str(snapshot_to_save))
		print("Game saved to %s" % SAVE_PATH)
	else:
		push_error("Failed to save game to %s" % SAVE_PATH)

func load_game_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var snapshot = str_to_var(content)
		
		if snapshot is Dictionary:
			print("Loading game from disk...")
			# Restore the world state
			restore_state(snapshot)
			
			# Reset history to just this state (New session)
			state_history.clear()
			state_history.append(snapshot)
		else:
			push_error("Corrupt save file.")

# --- HELPERS ---

func _capture_state() -> Dictionary:
	var snapshot = {}
	var revertables = get_tree().get_nodes_in_group("revertable")
	
	for node in revertables:
		# Use NodePath as key (stable across saves if hierarchy is static)
		var path = node.get_path()
		
		if node.has_method("record_data"):
			snapshot[path] = node.record_data()
	return snapshot

func restore_state(snapshot: Dictionary) -> void:
	for node_path in snapshot:
		# Skip metadata keys
		if node_path is String and node_path == "is_tag": continue
		
		var node = get_node_or_null(node_path)
		
		if node and node.has_method("restore_data"):
			node.restore_data(snapshot[node_path])
func get_last_checkpoint_player_data() -> Dictionary:
	# Iterate backwards to find the most recent tag
	for i in range(state_history.size() - 1, -1, -1):
		if state_history[i].get("is_tag", false):
			var snapshot = state_history[i]
			# The HistoryManager is a child of Player, so we look for parent's path
			var player = get_parent()
			var player_path = player.get_path()
			
			if snapshot.has(player_path):
				return snapshot[player_path]
	return {}
