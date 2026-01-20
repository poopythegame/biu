shader_type canvas_item;

uniform bool enabled = true; // Simple toggle for script control
uniform vec4 line_color : source_color = vec4(1, 1, 1, 0.5);
uniform float line_thickness = 1.0; // Simplified for Inspector visibility

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
    } else {
        vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
        
        // Sample 4 directions
        float outline = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a; // Left
        outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;      // Down
        outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;      // Right
        outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;     // Up
        
        outline = min(outline, 1.0);
        vec4 color = texture(TEXTURE, UV);
        
        // Mix outline based on alpha difference
        COLOR = mix(color, line_color, outline - color.a);
    }
}