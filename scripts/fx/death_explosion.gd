extends Node2D

# Settings for the animation
@export var particle_count: int = 8
@export var spread_radius: float = 24.0
@export var duration: float = 1.0
@export var particle_color: Color = Color.WHITE

func _ready() -> void:
	# 1. Create a simple circular texture programmatically
	# (Matches the visual style of the previous implementation)
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Transparent background
	
	# Draw white circle in center
	for x in range(8):
		for y in range(8):
			if Vector2(x-3.5, y-3.5).length() <= 3.0:
				img.set_pixel(x, y, Color.WHITE)
	
	var tex = ImageTexture.create_from_image(img)
	
	# 2. Spawn Particles
	var particles: Array[Sprite2D] = []
	
	for i in range(particle_count):
		var p = Sprite2D.new()
		p.texture = tex
		p.modulate = particle_color
		
		# Start at the center (where the player was)
		p.position = Vector2.ZERO
		p.scale = Vector2.ONE
		
		add_child(p)
		particles.append(p)

	# 3. Animate using Tween
	var tween = create_tween().set_parallel(true)
	
	# Loop through particles to set individual spread targets
	for i in range(particle_count):
		var p = particles[i]
		
		# Calculate angle for EVEN distribution (Circle)
		var angle = i * (TAU / float(particle_count))
		var target_pos = Vector2(cos(angle), sin(angle)) * spread_radius
		
		# A. Spread Out with BOUNCY effect (Elastic)
		tween.tween_property(p, "position", target_pos, duration * 0.7)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# B. Decrease Size (Shrink to nothing)
		# Delay slightly so they pop out before shrinking
		tween.tween_property(p, "scale", Vector2.ZERO, duration * 0.5)\
			.set_delay(duration * 0.3).set_ease(Tween.EASE_IN)

	# C. Rotate around the player center
	# We rotate the entire container (self) to make all particles orbit the center
	tween.tween_property(self, "rotation", PI, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Cleanup after animation finishes
	tween.chain().tween_callback(queue_free)
