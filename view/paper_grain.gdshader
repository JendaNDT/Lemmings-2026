shader_type canvas_item;
render_mode blend_mul, unshaded;
// Jemné žíhání papíru a ztmavení rohů přes celou herní scénu (pod HUDem).
// Násobí barvy pod sebou: nikdy nezesvětlí, jen sjednotí scénu do „tisku“.

uniform sampler2D paper_tex : filter_linear_mipmap, repeat_enable;
uniform float mottle = 0.04;
uniform float grain = 0.025;
uniform float vignette = 0.17;
// Strana odvrácená od slunce (vpravo dole) je o něco chladnější a tmavší.
uniform float shade = 0.07;

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float wide = texture(paper_tex, px / 620.0 + vec2(0.31, 0.17)).r - 0.5;
	float fine = texture(paper_tex, px / 170.0).r - 0.5;
	vec2 centered = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float vig = 1.0 - vignette * smoothstep(0.32, 0.78, length(centered));
	float k = (0.975 + wide * mottle * 2.0 + fine * grain * 2.0) * vig;
	float away = smoothstep(0.45, 1.5, SCREEN_UV.x * 0.55 + SCREEN_UV.y * 0.9);
	vec3 tone = vec3(k) * (1.0 - shade * away * vec3(1.0, 0.75, 0.45));
	COLOR = vec4(clamp(tone, 0.0, 1.0), 1.0);
}
