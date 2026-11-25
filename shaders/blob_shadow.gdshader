// Ombre de contact peu coûteuse sous les combattants.
shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled, cull_disabled;

uniform float strength = 0.6;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * strength;
}
