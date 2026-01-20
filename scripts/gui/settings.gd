extends Control
@onready var settings = $"."
@onready var close: Button = $"return to game"
@onready var player = $"../../Player"

func _ready() -> void:
	visible = false 
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle_settings():
	var should_be_paused = not get_tree().paused
	get_tree().paused = should_be_paused
	visible = should_be_paused
	
	if should_be_paused and close:
		close.grab_focus()
	#settings.visible = true  
	grab_focus()	

func _on_return_to_game_pressed() -> void:
	toggle_settings()
