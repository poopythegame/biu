extends Node2D

# Settings
@export var spread_radius: float = 24.0
@export var duration: float = 0.6 # Slightly faster than player death
@export var particle_color: Color = Color.WHITE # You can change this to Orange/Red in the Inspector

func _ready() -> void:
	# 1. Create Texture (Same as death_explosion.gd)
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) 
	
	# Draw white circle
	for x in range(8):
		for y in range(8):
			if Vector2(x-3.5, y-3.5).length() <= 3.0:
				img.set_pixel(x, y, Color.WHITE)
	
	var tex = ImageTexture.create_from_image(img)
	
	# 2. Spawn 4 Particles (Cardinal Directions)
	# Explicitly define the 4 directions requested
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var particles: Array[Sprite2D] = []
	
	for dir in directions:
		var p = Sprite2D.new()
		p.texture = tex
		p.modulate = particle_color
		p.position = Vector2.ZERO
		p.scale = Vector2.ONE
		
		add_child(p)
		particles.append(p)

	# 3. Animate
	var tween = create_tween().set_parallel(true)
	
	# Loop through our specific directions
	for i in range(directions.size()):
		var p = particles[i]
		var dir = directions[i]
		
		var target_pos = dir * spread_radius
		
		# A. Spread Out (Elastic Pop)
		tween.tween_property(p, "position", target_pos, duration * 0.7)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# B. Shrink to Nothing
		tween.tween_property(p, "scale", Vector2.ZERO, duration * 0.5)\
			.set_delay(duration * 0.3).set_ease(Tween.EASE_IN)

	# Removed: Container Rotation Logic
	
	# 4. Cleanup
	tween.chain().tween_callback(queue_free)
