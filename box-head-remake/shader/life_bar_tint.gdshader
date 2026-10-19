shader_type canvas_item;

// 生命条染色：血量越低越偏红
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 full_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 empty_color : source_color = vec4(1.0, 0.12, 0.12, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// hp_ratio = 1 满血 -> t = 0；hp_ratio = 0 空血 -> t = 1
	float t = 1.0 - clamp(hp_ratio, 0.0, 1.0);
	vec3 target = mix(full_color.rgb, empty_color.rgb, t);
	// 相乘保留纹理明暗，不把贴图压平
	c.rgb *= mix(vec3(1.0), target, strength);
	COLOR = c;
}
