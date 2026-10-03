shader_type canvas_item;

void fragment() {
	// Klidný gradient zůstává v obrazovém prostoru i u ortografické kamery.
	COLOR = vec4(mix(vec3(0.36, 0.64, 0.89), vec3(0.62, 0.82, 0.91), UV.y), 1.0);
}
