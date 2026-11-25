// Aura mystique : coque additive en next_pass (le modèle n'est pas remplacé).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float intensity = 0.0;
uniform float grow = 0.025;
uniform float speed = 3.0;

void vertex() {
	float n = sin(VERTEX.y * 18.0 + TIME * speed * 2.0) * 0.5 + 0.5;
	VERTEX += NORMAL * grow * (0.6 + 0.6 * n);
}

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float flick = 0.75 + 0.25 * sin(TIME * speed * 7.0 + UV.y * 20.0);
	ALBEDO = aura_color.rgb * 2.2;
	ALPHA = clamp(f * intensity * flick, 0.0, 1.0);
}
