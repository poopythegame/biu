extends Node2D

# Configuration
@export var dot_count: int = 24
@export var radius: float = 7.0 # Fits within a 16x16 tile
@export var color_inactive: Color = Color(1, 0.3, 0.3) # Color 1 (Start)
@export var color_active: Color = Color(0.3, 1.0, 0.3) # Color 2 (End)
@export var scale_inactive: Vector2 = Vector2(0.25, 0.25)
@export var scale_active: Vector2 = Vector2(0.6, 0.6)

func start(duration: float) -> void:
	# 1. Create a simple circular dot texture
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	
	# Draw a pixel circle
	img.set_pixel(1, 0, Color.WHITE); img.set_pixel(2, 0, Color.WHITE)
	img.set_pixel(0, 1, Color.WHITE); img.set_pixel(3, 1, Color.WHITE)
	img.set_pixel(1, 1, Color.WHITE); img.set_pixel(2, 1, Color.WHITE)
	img.set_pixel(0, 2, Color.WHITE); img.set_pixel(3, 2, Color.WHITE)
	img.set_pixel(1, 2, Color.WHITE); img.set_pixel(2, 2, Color.WHITE)
	img.set_pixel(1, 3, Color.WHITE); img.set_pixel(2, 3, Color.WHITE)
	
	var tex = ImageTexture.create_from_image(img)
	
	# Calculate the delay between each dot's animation start
	var step_delay = duration / float(dot_count)
	
	for i in range(dot_count):
		var dot = Sprite2D.new()
		dot.texture = tex
		
		# Calculate angle: Start at -PI/2 (12 o'clock) and move Clockwise
		var angle = -PI/2 + (i * TAU / float(dot_count))
		dot.position = Vector2(cos(angle), sin(angle)) * radius
		
		# Set Initial State (Color 1, Small)
		dot.modulate = color_inactive
		dot.scale = scale_inactive
		
		add_child(dot)
		
		# Create the Tween for this specific dot
		# UPDATED: We use .set_parallel(true) immediately and apply .set_delay() 
		# to the properties. This ensures the delay is respected.
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		var delay = step_delay * i
		tween.tween_property(dot, "scale", scale_active, 0.5).set_delay(delay)
		tween.tween_property(dot, "modulate", color_active, 0.5).set_delay(delay)

	await get_tree().create_timer(duration).timeout
	
	var exit_tween = create_tween()
	exit_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	
	await exit_tween.finished
	queue_free()
