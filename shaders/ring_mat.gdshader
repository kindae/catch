// Tapis du ring : couleurs du drapeau (bleu ciel, diagonale rouge bordée de jaune, étoile).
shader_type spatial;
render_mode diffuse_burley;

uniform vec4 blue : source_color = vec4(0.0, 0.42, 0.85, 1.0);
uniform vec4 red : source_color = vec4(0.78, 0.05, 0.08, 1.0);
uniform vec4 yellow : source_color = vec4(0.97, 0.82, 0.1, 1.0);
uniform float wear = 0.25;

// étoile à 5 branches (distance signée)
float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = blue.rgb;
	float d = (uv.x - (1.0 - uv.y));
	col = mix(col, yellow.rgb, step(abs(d), 0.11));
	col = mix(col, red.rgb, step(abs(d), 0.075));
	vec2 sp = (uv - vec2(0.2, 0.2)) * vec2(1.0, -1.0);
	col = mix(col, yellow.rgb, 1.0 - smoothstep(0.0, 0.004, sd_star5(sp, 0.09, 0.45)));
	// bordure
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	col = mix(col, vec3(0.95), step(edge, 0.012));
	// usure et traces sur la toile
	float n = fract(sin(dot(floor(uv * 180.0), vec2(12.9898, 78.233))) * 43758.5453);
	float center = 1.0 - smoothstep(0.0, 0.5, length(uv - 0.5));
	col *= 1.0 - wear * (n * 0.25 + center * 0.25);
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
