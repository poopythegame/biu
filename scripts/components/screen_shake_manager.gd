extends Node
class_name ScreenShakeManager

# Settings
@export var trauma_reduction_rate: float = 1.0
@export var max_offset: Vector2 = Vector2(50.0, 50.0) # Max pixels to shake
@export var noise_shake_speed: float = 30.0 # How fast the noise scrolls
@export var trauma_power: float = 2.0 # Non-linear falloff (2 = squared, 3 = cubed)

# Internal State
var trauma: float = 0.0
var time: float = 0.0
var noise: FastNoiseLite = FastNoiseLite.new()

func _ready() -> void:
	# Initialize Noise
	noise.seed = randi()
	noise.frequency = 0.5
	noise.fractal_octaves = 2

func shake(intensity: float) -> void:
	# Add trauma (clamped between 0.0 and 1.0)
	trauma = clamp(trauma + intensity, 0.0, 1.0)

func _process(delta: float) -> void:
	if trauma > 0:
		# Decay trauma over time
		trauma = max(trauma - trauma_reduction_rate * delta, 0.0)
		_apply_shake(delta)
	else:
		# Reset parent offset to zero when not shaking
		var camera = get_parent()
		if camera is Camera2D and camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO

func _apply_shake(delta: float) -> void:
	var camera = get_parent()
	if not (camera is Camera2D): return
	
	# Trauma is non-linear (so small shakes are subtle, big shakes are violent)
	var amount = pow(trauma, trauma_power)
	
	# Advance noise time
	time += delta * noise_shake_speed
	
	# Calculate offset using noise
	# noise.seed is an int that can be very large, causing float precision issues (NaN/Grey Screen).
	camera.offset.x = max_offset.x * amount * noise.get_noise_2d(0, time)
	camera.offset.y = max_offset.y * amount * noise.get_noise_2d(100, time)
