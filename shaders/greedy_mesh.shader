shader_type spatial;
uniform sampler2D texture_albedo : hint_albedo;
uniform vec2 tile_size = vec2(0.127, 0.0635);

void fragment() {
	float x_coord = (UV2.x * tile_size.x) + mod(UV.x, 1.0) * tile_size.x;
	float y_coord = (UV2.y * tile_size.y) + mod(UV.y, 1.0) * tile_size.y;
	vec2 base_uv = vec2(x_coord, y_coord);
	ALBEDO = texture(texture_albedo, base_uv).rgb;
}
