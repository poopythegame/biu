extends Node2D

# Settings
@export var spread_radius: float = 16.0 # Slightly smaller than bomb for the button
@export var duration: float = 0.5
@export var particle_color: Color = Color(0.5, 1.5, 0.5) # Bright Green for activation

func _ready() -> void:
	# 1. Create Texture (Same as bomb_explosion.gd)
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) 
	
	# Draw white circle
	for x in range(8):
		for y in range(8):
			if Vector2(x-3.5, y-3.5).length() <= 3.0:
				img.set_pixel(x, y, Color.WHITE)
	
	var tex = ImageTexture.create_from_image(img)
	
	# 2. Spawn 4 Particles (Diagonal Directions)
	# Normalized vectors ensure they travel the exact 'spread_radius' distance
	var directions = [
		Vector2(1, 1).normalized(),   # Down-Right
		Vector2(-1, 1).normalized(),  # Down-Left
		Vector2(1, -1).normalized(),  # Up-Right
		Vector2(-1, -1).normalized()  # Up-Left
	]
	
	var particles: Array[Sprite2D] = []
	
	for dir in directions:
		var p = Sprite2D.new()
		p.texture = tex
		p.modulate = particle_color
		p.position = Vector2.ZERO
		p.scale = Vector2.ONE * 0.8 # Slightly smaller particles for the button
		
		add_child(p)
		particles.append(p)

	# 3. Animate
	var tween = create_tween().set_parallel(true)
	
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

	# 4. Cleanup
	tween.chain().tween_callback(queue_free)
