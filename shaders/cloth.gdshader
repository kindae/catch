// Tissu imprimé type wax (motifs originaux procéduraux).
shader_type spatial;
render_mode diffuse_burley;

uniform vec4 col_a : source_color = vec4(0.8, 0.07, 0.09, 1.0);
uniform vec4 col_b : source_color = vec4(0.97, 0.84, 0.1, 1.0);
uniform vec4 col_c : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform int pattern = 0;
uniform float scale = 6.0;
uniform float shine = 0.25;
uniform float flash = 0.0;

void fragment() {
	vec2 p = UV * vec2(scale * 2.0, scale);
	vec2 c = fract(p) - 0.5;
	vec3 col = col_a.rgb;
	if (pattern == 0) {
		// « yeux » concentriques
		float r = length(c);
		float ring = step(0.5, fract(r * 6.0));
		col = mix(col_a.rgb, col_b.rgb, ring * step(r, 0.42));
		col = mix(col, col_c.rgb, step(r, 0.08));
	} else if (pattern == 1) {
		// losanges
		float d = abs(c.x) + abs(c.y);
		col = mix(col_a.rgb, col_b.rgb, step(0.5, fract(d * 4.0)));
	} else if (pattern == 2) {
		// zigzag doré
		float z = abs(fract(p.x) - 0.5);
		col = mix(col_a.rgb, col_c.rgb, step(abs(fract(p.y + z) - 0.5), 0.12));
	} else {
		col = col_a.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0 - shine;
	METALLIC = 0.0;
	EMISSION = vec3(flash) * 0.8;
}
