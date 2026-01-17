extends CanvasLayer

# Preload the shader we just created
const TRANSITION_SHADER = preload("res://scripts/gui/transition/diamond_wipe.gdshader")

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Create ColorRect if it doesn't exist
	if not color_rect:
		color_rect = ColorRect.new()
		color_rect.color = Color.BLACK
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block mouse when transparent
		add_child(color_rect)
	
	# Create and assign the ShaderMaterial
	var material = ShaderMaterial.new()
	material.shader = TRANSITION_SHADER
	color_rect.material = material
	
	# Initial state: Invisible and progress at 0
	material.set_shader_parameter("progress", 0.0)
	color_rect.visible = false
	visible = false

func fade_out(duration: float = 0.4) -> void:
	visible = true
	color_rect.visible = true
	
	var mat = color_rect.material as ShaderMaterial
	var tween = create_tween()
	
	# Animate 'progress' from 0.0 to 1.0 (Diamonds grow to fill screen)
	tween.tween_property(mat, "shader_parameter/progress", 1.0, duration)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		
	await tween.finished

func fade_in(duration: float = 0.4) -> void:
	var mat = color_rect.material as ShaderMaterial
	var tween = create_tween()
	
	# Animate 'progress' from 1.0 to 0.0 (Diamonds shrink to reveal game)
	tween.tween_property(mat, "shader_parameter/progress", 0.0, duration)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		
	await tween.finished
	
	# Hide rect to save performance
	color_rect.visible = false
	visible = false
