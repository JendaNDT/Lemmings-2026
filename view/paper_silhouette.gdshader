shader_type canvas_item;
// Jednobarevná silueta dílu: barva z modulace (okraj nebo stín), krytí z textury.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, tint.a * a);
}
