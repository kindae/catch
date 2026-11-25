// Effets énergétiques additifs (ondes de choc, orbes, flashs).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform float alpha = 1.0;
uniform int mode = 0; // 0 = anneau, 1 = sphère fresnel, 2 = cône lumineux

void fragment() {
	float a = 1.0;
	if (mode == 0) {
		float r = length(UV - 0.5) * 2.0;
		a = smoothstep(0.55, 0.85, r) * (1.0 - smoothstep(0.85, 1.0, r));
		a *= 0.7 + 0.3 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 12.0 + TIME * 20.0);
	} else if (mode == 1) {
		a = 0.08 + pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0) * 0.9;
	} else {
		a = (1.0 - UV.y) * 0.35 * (1.0 - abs(UV.x - 0.5) * 1.6);
	}
	ALBEDO = color.rgb * 1.8;
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
