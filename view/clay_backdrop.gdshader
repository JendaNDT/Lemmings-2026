shader_type spatial;
render_mode unshaded;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 color = COLOR.rgb;
	float light = 0.76 + 0.24 * max(0.0, dot(normalize(world_normal), normalize(vec3(-0.6, 0.8, 0.7))));
	color *= light;
	if (!OUTPUT_IS_SRGB) {
		color = pow(color, vec3(2.2));
	}
	ALBEDO = color;
}
