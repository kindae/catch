// Spectateurs instanciés (MultiMesh) : animation partagée calculée dans le
// vertex shader (sautillements, bras levés) — aucun squelette, coût GPU minime.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float excitement = 0.3;

varying vec3 v_col;

void vertex() {
	float id = float(INSTANCE_ID);
	float phase = fract(sin(id * 12.9898) * 43758.5453) * 6.2831;
	float speed = 4.0 + fract(id * 0.37) * 4.0;
	float hop = max(0.0, sin(TIME * speed + phase)) * (0.03 + excitement * 0.12);
	// les sommets hauts (bras, y > 1.25) se lèvent quand la foule s'excite
	float arm = smoothstep(1.2, 1.6, VERTEX.y) * excitement;
	VERTEX.y += hop + arm * 0.25 * (0.5 + 0.5 * sin(TIME * speed * 1.3 + phase));
	VERTEX.x += sin(TIME * 2.0 + phase) * 0.02 * VERTEX.y;
	v_col = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = COLOR.rgb * v_col;
	ROUGHNESS = 0.9;
}
