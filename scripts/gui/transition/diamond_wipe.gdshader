shader_type canvas_item;

// Ranges from 0.0 (fully transparent) to 1.0 (fully black)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Size of the diamond grid cells in pixels
uniform float diamond_pixel_size = 40.0;

void fragment() {
	float x_fract = fract(FRAGCOORD.x / diamond_pixel_size);
	float y_fract = fract(FRAGCOORD.y / diamond_pixel_size);
	
	// Calculate distance from the center of the diamond (0.5, 0.5)
	// Manhattan distance creates the diamond shape
	float dist = abs(x_fract - 0.5) + abs(y_fract - 0.5);
	
	// Logic to fill screen:
	// When progress is 0.0, we want 'limit' to be < 0.0 (so dist is always > limit -> discard)
	// When progress is 1.0, we want 'limit' to be > 1.0 (so dist is always < limit -> draw)
	// Multiplier 2.5 ensures diamonds fully overlap and close gaps.
	float limit = progress * 2.5 - 0.75;
	
	if (dist > limit) {
		discard;
	}
	
	// Draw black (or the rect's color)
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
