extends Control

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
# Ensure you add this button in the scene editor!
@onready var save_quit_button: Button = $CenterContainer/VBoxContainer/SaveQuitButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var settings = $"../settings"

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	
	if save_quit_button:
		save_quit_button.pressed.connect(_on_save_quit_pressed)
		
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	var should_be_paused = not get_tree().paused
	get_tree().paused = should_be_paused
	visible = should_be_paused
	
	if should_be_paused and resume_button:
		resume_button.grab_focus()

func _on_resume_pressed() -> void:
	_toggle_pause()

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
