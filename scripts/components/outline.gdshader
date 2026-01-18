shader_type canvas_item;

// Uniforms allow you to change these variables in the Inspector
uniform vec4 line_color : source_color = vec4(1, 1, 1, 0.5);
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
    
    // Sample the alpha of the pixels in 4 directions around the current pixel
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;   // Left
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;         // Down
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;         // Right
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;        // Up
    
    // Add diagonals for a smoother, less blocky outline (optional)
    // outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;     // Bottom-Left
    // outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;      // Bottom-Right
    // outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;    // Top-Left
    // outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;     // Top-Right
    
    // Clamp the result to 0-1 range
    outline = min(outline, 1.0);
    
    // Get the color of the texture at the current pixel
    vec4 color = texture(TEXTURE, UV);
    
    // Mix the outline with the original color. 
    // If the original pixel has alpha (is visible), we show the original color.
    // If it's transparent but 'outline' > 0, we show the outline color.
    COLOR = mix(color, line_color, outline - color.a);
}