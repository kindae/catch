// Toutes les jauges du HUD en un seul draw call.
// rects[i] = (x, y, w, h) en pixels ; vals[i] = (valeur, traînée, de droite à gauche, segments)
shader_type canvas_item;

const int N = 16;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform int count = 0;
uniform vec4 rects[N];
uniform vec4 vals[N];
uniform vec4 cols[N] : source_color;
uniform vec4 ghost_cols[N] : source_color;

void fragment() {
	vec2 p = UV * screen_size;
	vec4 outc = vec4(0.0);
	for (int i = 0; i < N; i++) {
		if (i >= count) { break; }
		vec4 r = rects[i];
		vec4 v = vals[i];
		vec2 lo = r.xy - vec2(2.0);
		vec2 hi = r.xy + r.zw + vec2(2.0);
		if (p.x < lo.x || p.y < lo.y || p.x > hi.x || p.y > hi.y) { continue; }
		vec4 c = vec4(0.0, 0.0, 0.0, 0.65);
		if (p.x >= r.x && p.y >= r.y && p.x <= r.x + r.z && p.y <= r.y + r.w) {
			float t = (p.x - r.x) / r.z;
			if (v.z > 0.5) { t = 1.0 - t; }
			c = vec4(0.12, 0.1, 0.12, 0.85);
			if (t <= v.y) { c = ghost_cols[i]; }
			if (t <= v.x) { c = cols[i]; }
			if (v.w > 0.5) {
				float seg = fract(t * v.w);
				if (seg < 0.012 * v.w || seg > 1.0 - 0.012 * v.w) { c.rgb *= 0.35; }
			}
			// reflet en haut de la jauge
			if (p.y < r.y + r.w * 0.35) { c.rgb = mix(c.rgb, vec3(1.0), 0.12); }
		}
		outc = c;
	}
	COLOR = outc;
}
