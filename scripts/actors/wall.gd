extends StaticBody2D

# Default recovery time, overwritten by LDtk import
@export var recover_time: float = 1.0

# Store initial layers to restore them later
var _initial_layer: int
var _initial_mask: int

func _ready() -> void:
	add_to_group("wall")
	
	# Layer 2: Blocks Player movement (Wall Layer)
	# Layer 4: Blocks Box Pushing (Box Layer)
	collision_layer = 2 + 4 
	collision_mask = 0 
	
	_initial_layer = collision_layer
	_initial_mask = collision_mask

# Interface called by Bomb.gd when exploded
# We ignore direction/force and simply destroy the wall
func apply_knockback(_direction: Vector2, _force: int) -> void:
	destroy()

func destroy() -> void:
	# Prevent multiple destruction calls
	if not visible: return

	print("Wall destroyed! Recovering in %s seconds." % recover_time)
	
	# Disable collision and hide visuals
	collision_layer = 0
	visible = false
	
	# Start recovery timer
	var timer = get_tree().create_timer(recover_time)
	timer.timeout.connect(_on_recover_timeout)

func _on_recover_timeout() -> void:
	# Recover the wall
	print("Wall recovering...")
	visible = true
	collision_layer = _initial_layer
