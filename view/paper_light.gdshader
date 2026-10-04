shader_type canvas_item;
render_mode blend_add, unshaded;
// Teplé světlo slunce zleva shora: měkká záře a jemné šikmé paprsky,
// které se pomalu posouvají s herním časem. Jen přidává světlo, HUD je nad tím.

uniform float time = 0.0;
uniform vec3 warm = vec3(1.0, 0.82, 0.52);
uniform float glow = 0.085;
uniform float rays = 0.03;
// Záblesk blesku (téma Bouřková hora), 0 = bez záblesku.
uniform float flash = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 sun = vec2(-0.08, -0.12);
	vec2 d = (uv - sun) * vec2(aspect, 1.0);
	float dist = length(d);
	float halo = glow * (1.0 - smoothstep(0.0, 1.25, dist));
	// Paprsky: pruhy podle úhlu od slunce, každý trochu jinak široký.
	float ang = atan(d.y, d.x);
	float band = sin(ang * 38.0 + time * 0.012) * 0.5 + sin(ang * 17.0 - time * 0.008 + 1.3) * 0.5;
	float shafts = rays * smoothstep(0.35, 0.95, band) * (1.0 - smoothstep(0.2, 1.4, dist));
	COLOR = vec4(warm * (halo + shafts) + vec3(0.85, 0.9, 1.0) * flash * 0.22, 1.0);
}
