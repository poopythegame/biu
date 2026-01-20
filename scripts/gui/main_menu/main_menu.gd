extends Control

const FIRST_LEVEL_SCENE = "res://scenes/tests/test.tscn"
const SAVE_PATH = "user://savegame.dat"

# Assign these in the Inspector
@export var new_game_button: Button
@export var continue_button: Button

func _ready() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		
		# Disable "Continue" if no save file exists
		if not FileAccess.file_exists(SAVE_PATH):
			continue_button.disabled = true

func _on_new_game_pressed() -> void:
	# Tell the global state specifically NOT to load
	if has_node("/root/TransitionLayer"):
		get_node("/root/TransitionLayer").should_load_game = false
		
	get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)

func _on_continue_pressed() -> void:
	# Tell the global state TO load the save
	if has_node("/root/TransitionLayer"):
		get_node("/root/TransitionLayer").should_load_game = true
		
	get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)
