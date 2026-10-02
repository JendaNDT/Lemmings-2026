// Pozadí: barevný přechod oblohy, jemná pohyblivá mlha a hvězdy.
// Placeholder – později nahradí paralaxní vrstvy s ilustracemi.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.04, 0.06, 0.15, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.30, 0.16, 0.30, 1.0);
uniform vec4 horizon_glow : source_color = vec4(1.0, 0.55, 0.35, 1.0);
uniform vec4 mist_color : source_color = vec4(0.45, 0.40, 0.65, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	col += horizon_glow.rgb * pow(uv.y, 4.0) * 0.35;

	float mist = noise(vec2(uv.x * 4.0 + TIME * 0.015, uv.y * 7.0))
		+ 0.5 * noise(vec2(uv.x * 9.0 - TIME * 0.02, uv.y * 15.0));
	col += mist_color.rgb * mist * 0.06 * smoothstep(0.2, 1.0, uv.y);

	vec2 star_cell = floor(uv * vec2(160.0, 90.0));
	float star = step(0.992, hash(star_cell));
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + hash(star_cell + 3.0) * 30.0);
	col += vec3(star * twinkle * (1.0 - uv.y) * 0.8);

	COLOR = vec4(col, 1.0);
}
