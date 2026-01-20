extends Control

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
# Ensure you add this button in the scene editor!
@onready var save_quit_button: Button = $CenterContainer/VBoxContainer/SaveQuitButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var reset_button: Button = $CenterContainer/VBoxContainer/ResetButton

@onready var settings = $"../settings"

# [NEW] State for the confirmation click
var reset_confirmed: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	
	if save_quit_button:
		save_quit_button.pressed.connect(_on_save_quit_pressed)
		
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)

	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	var should_be_paused = not get_tree().paused
	get_tree().paused = should_be_paused
	visible = should_be_paused
	
	if should_be_paused:
		if resume_button:
			resume_button.grab_focus()
		
		# [NEW] Reset the button state every time we open the menu
		reset_confirmed = false
		if reset_button:
			reset_button.text = "Reset All"

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_reset_pressed() -> void:
	if not reset_button: return

	if not reset_confirmed:
		# First click: Change text to warn user
		reset_button.text = "lose all progress?"
		reset_confirmed = true
	else:
		# Second click: Execute Reset
		_toggle_pause() # Unpause immediately so animations can play
		
		# Find player
		var player = get_tree().root.find_child("Player", true, false)
		
		# [NEW] Extract the last checkpoint position BEFORE we wipe the scene
		if player and player.has_node("HistoryManager"):
			var hm = player.get_node("HistoryManager")
			if hm.has_method("get_last_checkpoint_player_data"):
				var data = hm.get_last_checkpoint_player_data()
				
				# If we found valid data, store it in the global TransitionLayer
				if not data.is_empty():
					var transition = get_node("/root/TransitionLayer")
					if transition:
						transition.stored_reset_position = data.position
						if "facing_dir_x" in data and "facing_dir_y" in data:
							transition.stored_reset_direction = Vector2(data.facing_dir_x, data.facing_dir_y)

		# Trigger the transition and reload
		if player and player.has_method("restart_level_with_transition"):
			player.restart_level_with_transition()
		else:
			# Fallback if player not found
			get_tree().reload_current_scene()

func _on_save_quit_pressed() -> void:
	# 1. Find the HistoryManager
	# We search globally because the PauseMenu might be outside the Player's hierarchy
	var history_manager = get_tree().root.find_child("HistoryManager", true, false)
	
	if history_manager and history_manager.has_method("save_game_to_disk"):
		history_manager.save_game_to_disk()
	else:
		push_warning("HistoryManager not found! Quitting without saving.")
	
	# 2. Quit
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	if settings:
		_toggle_pause()
		settings.toggle_settings()
	else:
		print("no settings in tree, sorry :(")
