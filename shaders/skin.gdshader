// Peau semi-réaliste + peintures corporelles procédurales (kaolin / ocre).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 skin_color : source_color = vec4(0.36, 0.22, 0.14, 1.0);
uniform vec4 paint_color : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform int paint_pattern = 0;
uniform float paint_amount = 1.0;
uniform float flash = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform float glow = 0.0;

float paint_mask(vec2 uv) {
	if (paint_pattern == 1) {
		// bandes de kaolin
		// deux fines bandes de kaolin et une rangée de points
		float b1 = 1.0 - smoothstep(0.012, 0.022, abs(uv.y - 0.38));
		float b2 = 1.0 - smoothstep(0.012, 0.022, abs(uv.y - 0.46));
		float dots = 1.0 - smoothstep(0.06, 0.09, length(vec2(fract(uv.x * 8.0) - 0.5, (uv.y - 0.54) * 10.0)));
		return max(max(b1, b2), dots);
	} else if (paint_pattern == 2) {
		// éclair en zigzag
		float z = abs(fract(uv.x * 4.0) - 0.5) * 0.16 + 0.42;
		return 1.0 - smoothstep(0.012, 0.024, abs(uv.y - z));
	}
	return 0.0;
}

void fragment() {
	float m = paint_mask(UV) * paint_amount;
	vec3 base = mix(skin_color.rgb, paint_color.rgb, m * 0.9);
	// légère variation de teinte (pores / volume)
	float v = sin(UV.x * 40.0) * sin(UV.y * 31.0) * 0.015;
	ALBEDO = base + v;
	ROUGHNESS = mix(0.52, 0.8, m);
	SPECULAR = 0.42;
	RIM = 0.35;
	RIM_TINT = 0.5;
	EMISSION = vec3(flash) * 0.9 + glow_color.rgb * glow * m * 2.5;
}
