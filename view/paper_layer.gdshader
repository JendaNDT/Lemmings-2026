shader_type canvas_item;
// Vrstva krajiny: opar podle vzdálenosti od herní roviny, víc u spodního okraje.
// Rozostření (hloubka ostrosti) je už v podkladech z generátoru.

uniform float haze = 0.0;
uniform vec3 haze_color = vec3(0.86, 0.9, 0.88);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float low = smoothstep(0.35, 1.0, UV.y);
	c.rgb = mix(c.rgb, haze_color, haze * (0.55 + 0.45 * low));
	COLOR = c;
}
