shader_type canvas_item;

instance uniform vec4 fill_color : source_color = vec4(0.22, 0.62, 1.0, 1.0);
instance uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float outline_width : hint_range(0.0, 0.5, 0.001) = 0.06;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float circle_radius = 0.5;
	float distance_to_center = length(centered_uv);
	float anti_alias_width = max(fwidth(distance_to_center), 0.0001);

	float clamped_outline_width = clamp(outline_width, 0.0, circle_radius);
	float fill_radius = circle_radius - clamped_outline_width;

	float circle_mask = 1.0 - smoothstep(
		circle_radius - anti_alias_width,
		circle_radius + anti_alias_width,
		distance_to_center
	);
	float fill_mask = 1.0 - smoothstep(
		fill_radius - anti_alias_width,
		fill_radius + anti_alias_width,
		distance_to_center
	);
	float outline_mask = max(circle_mask - fill_mask, 0.0);

	float output_alpha = fill_color.a * fill_mask + outline_color.a * outline_mask;
	vec3 output_color = vec3(0.0);
	if (output_alpha > 0.0001) {
		output_color = (
			fill_color.rgb * fill_color.a * fill_mask
			+ outline_color.rgb * outline_color.a * outline_mask
		) / output_alpha;
	}

	COLOR = vec4(output_color, output_alpha);
}
