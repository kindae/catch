// Commandes tactiles (cercles, anneaux, recharge) en un seul draw call.
// disc[i] = (cx, cy, rayon, état) ; état : 0 normal, 1 appuyé, 2 indisponible
// extra[i] = (recharge 0..1, pulsation, épaisseur anneau, 0)
shader_type canvas_item;

const int N = 12;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform int count = 0;
uniform float opacity = 0.65;
uniform vec4 disc[N];
uniform vec4 extra[N];
uniform vec4 cols[N] : source_color;

void fragment() {
	vec2 p = UV * screen_size;
	vec4 outc = vec4(0.0);
	for (int i = 0; i < N; i++) {
		if (i >= count) { break; }
		vec4 d = disc[i];
		vec2 q = p - d.xy;
		float dist = length(q);
		if (dist > d.z + 12.0) { continue; }
		float aa = 1.5;
		float inside = 1.0 - smoothstep(d.z - aa, d.z, dist);
		vec4 col = cols[i];
		float fill_a = (d.w == 1.0 ? 0.8 : 0.5) * (d.w == 2.0 ? 0.45 : 1.0);
		vec4 c = vec4(col.rgb, fill_a * inside * col.a);
		float th = extra[i].z;
		float ring = 1.0 - smoothstep(th * 0.5, th * 0.5 + aa, abs(dist - d.z + th * 0.5));
		float ring_a = d.w == 2.0 ? 0.25 : 0.8;
		c = mix(c, vec4(1.0, 1.0, 1.0, ring_a), ring * ring_a);
		// recharge (secteur sombre)
		if (extra[i].x > 0.0) {
			float ang = atan(q.x, -q.y) / 6.2831853 + 0.5;
			ang = fract(ang + 0.5);
			if (ang < extra[i].x && dist < d.z - 2.0) { c = mix(c, vec4(0.0, 0.0, 0.0, 0.6), 0.7); }
		}
		// halo pulsant (ultime disponible)
		if (extra[i].y > 0.0) {
			float halo = 1.0 - smoothstep(2.0, 4.0, abs(dist - d.z - 6.0));
			c = mix(c, vec4(col.rgb, 1.0), halo * extra[i].y);
		}
		outc = mix(outc, c, c.a);
		outc.a = max(outc.a, c.a);
	}
	COLOR = vec4(outc.rgb, outc.a * opacity);
}
