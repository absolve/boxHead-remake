shader_type canvas_item;

// 玩家换色（原版 Boxhead 多人也是「同一套精灵 + 染色」，不是每人一套独立图片）
//
// 做法：把像素从 RGB 转到 HSV，只旋转色相、保留明暗与饱和度，
// 这样角色的立体感/阴影全部保留，只是主色变成另一个颜色。
//
// 玩家默认色是绿（0x00FF00，doc/04 §2.1），所以：
//   绿   -> 1 号玩家，hue_shift = 0.0
//   红   -> 2 号玩家，hue_shift = 0.667
//   蓝   -> 3 号玩家，hue_shift = 0.333
//   黄   -> 4 号玩家，hue_shift = -0.167

uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation_scale : hint_range(0.0, 2.0) = 1.0;
uniform float value_scale : hint_range(0.0, 2.0) = 1.0;

// ---- 皮肤保护 ----
//
// 只换「衣服」的颜色，脸和手的肤色保持原样。
// 肤色实测（玩家站立图采样）：H 0.056~0.083，S 0.22~0.27，V 0.5~0.69
// 而服装绿是 H 0.333 / S 0.75~1.0，头盔上的橙色条是 H 0.04 / S 1.0。
// 所以用「色相在肤色区间 + 饱和度不高」两个条件就能把皮肤单独挑出来。
uniform float skin_hue_lo : hint_range(0.0, 1.0) = 0.015;
uniform float skin_hue_hi : hint_range(0.0, 1.0) = 0.130;
uniform float skin_sat_max : hint_range(0.0, 1.0) = 0.45;
uniform float skin_value_min : hint_range(0.0, 1.0) = 0.15;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// COLOR 进 fragment 时已经是 texture × modulate，直接改 rgb 即可
	vec3 hsv = rgb2hsv(COLOR.rgb);

	// 肤色 / 灰阶（黑、白、阴影）不动
	// 注意：Godot 的 fragment 里不能用 return，只能用条件包住改写
	bool is_skin = hsv.x >= skin_hue_lo && hsv.x <= skin_hue_hi
			&& hsv.y <= skin_sat_max && hsv.z >= skin_value_min;
	if (!is_skin) {
		hsv.x = fract(hsv.x + hue_shift);
		hsv.y = clamp(hsv.y * saturation_scale, 0.0, 1.0);
		hsv.z = clamp(hsv.z * value_scale, 0.0, 1.0);
		COLOR.rgb = hsv2rgb(hsv);
	}
}
