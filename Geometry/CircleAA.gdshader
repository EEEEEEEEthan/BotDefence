shader_type canvas_item;

instance uniform vec4 fill_color : source_color = vec4(0.22, 0.62, 1.0, 1.0);
instance uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float outline_width : hint_range(0.0, 0.5, 0.001) = 0.06;
instance uniform float outline_soft : hint_range(0.0, 0.5, 0.001) = 0.06;

void fragment() {
	vec2 center_uv = UV - vec2(0.5);
	float distance_to_center = length(center_uv);
	float circle_radius = 0.5;
	float anti_alias_width = max(fwidth(distance_to_center), 0.0005);
	float outer_fade_width = max(outline_soft, anti_alias_width);
	float outer_fade_start = circle_radius - outer_fade_width;
	float circle_mask = 1.0 - smoothstep(outer_fade_start, circle_radius, distance_to_center);
	float ring_start = max(circle_radius - outline_width, 0.0);
	float ring_start_soft = max(outline_soft, anti_alias_width);
	float inner_ring = smoothstep(ring_start - ring_start_soft, ring_start + ring_start_soft, distance_to_center);
	float ring_mask = clamp(inner_ring * circle_mask, 0.0, 1.0);
	vec4 mixed_color = mix(fill_color, outline_color, ring_mask);
	COLOR = vec4(mixed_color.rgb, mixed_color.a * circle_mask);
}
