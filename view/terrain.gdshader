// Vzhled terénu. Vstupem je logická mapa (TerrainMask) jako textura:
//   R = pevný terén, G = ocel, B = postavené cihly.
// Shader z ní v plném rozlišení obrazovky „domaluje“ hladké okraje, trávu,
// vrstvy hlíny, stínování a ocelové pláty. Logika hry o tom nic neví.
shader_type canvas_item;

uniform vec4 grass_color : source_color = vec4(0.40, 0.80, 0.33, 1.0);
uniform vec4 grass_tip_color : source_color = vec4(0.75, 0.95, 0.45, 1.0);
uniform vec4 soil_light : source_color = vec4(0.66, 0.45, 0.28, 1.0);
uniform vec4 soil_dark : source_color = vec4(0.27, 0.16, 0.11, 1.0);
uniform vec4 brick_color : source_color = vec4(0.85, 0.55, 0.30, 1.0);
uniform vec4 steel_light : source_color = vec4(0.74, 0.79, 0.86, 1.0);
uniform vec4 steel_dark : source_color = vec4(0.30, 0.34, 0.42, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform vec2 light_dir = vec2(-0.45, -1.0);
uniform float grass_depth = 2.5;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 cell = UV / px; // pozice v logických pixelech
	vec4 m = texture(TEXTURE, UV);

	// Hladký okraj místo kostiček: práh v půlce lineárně filtrované masky.
	float aa = max(fwidth(m.r), 0.0001);
	float coverage = smoothstep(0.5 - aa, 0.5 + aa, m.r);
	if (coverage <= 0.001) {
		discard;
	}
	float steel = smoothstep(0.35, 0.65, m.g);
	float brick = smoothstep(0.35, 0.65, m.b) * (1.0 - steel);

	// Jak hluboko pod povrchem jsme (pro stínování a trávu).
	float above_near = texture(TEXTURE, UV - vec2(0.0, px.y * grass_depth)).r;
	float above_mid = texture(TEXTURE, UV - vec2(0.0, px.y * 7.0)).r;
	float above_far = texture(TEXTURE, UV - vec2(0.0, px.y * 16.0)).r;
	float depth = (above_near + above_mid + above_far) / 3.0;

	// Hlína: vrstvy + šum + kamínky.
	float n = fbm(cell * 0.12);
	float strata = sin(cell.y * 0.45 + n * 5.0) * 0.5 + 0.5;
	vec3 soil = mix(soil_light.rgb, soil_dark.rgb,
		clamp(depth * 0.55 + strata * 0.2 + n * 0.35 - 0.1, 0.0, 1.0));
	float pebble = smoothstep(0.78, 0.84, noise(cell * 0.55 + 17.0));
	soil = mix(soil, soil * 1.35 + vec3(0.03), pebble * 0.6);

	// Tráva na horních hranách (jen na hlíně).
	float grass = (1.0 - smoothstep(0.3, 0.7, above_near)) * (1.0 - steel) * (1.0 - brick);
	float blades = noise(vec2(cell.x * 1.7, 0.0)) * 0.5 + 0.5;
	vec3 grass_col = mix(grass_color.rgb, grass_tip_color.rgb, blades * (1.0 - above_near));

	// Cihly od stavitele.
	vec2 bc = fract(vec2(cell.x / 6.0 + floor(cell.y) * 0.5, cell.y));
	float mortar = step(bc.x, 0.08) + step(0.82, bc.y);
	vec3 brick_col = brick_color.rgb * (0.9 + 0.2 * hash(floor(vec2(cell.x / 6.0, cell.y))));
	brick_col = mix(brick_col, brick_col * 0.55, clamp(mortar, 0.0, 1.0));

	// Ocel: pláty se spárami a nýty.
	vec2 plate = fract(cell / 16.0);
	float seam = 1.0 - step(0.06, plate.x) * step(0.06, plate.y);
	float rivet = 1.0 - smoothstep(0.6, 1.0, length((plate - vec2(0.18)) * 16.0));
	vec3 steel_col = mix(steel_light.rgb, steel_dark.rgb, plate.y * 0.7 + n * 0.25);
	steel_col = mix(steel_col, steel_dark.rgb * 0.6, seam * 0.8);
	steel_col += vec3(0.25) * rivet;

	vec3 col = soil;
	col = mix(col, grass_col, grass);
	col = mix(col, brick_col, brick);
	col = mix(col, steel_col, steel);

	// Osvětlení okrajů: hrany natočené ke světlu svítí, odvrácené jsou ve stínu.
	vec2 grad = vec2(
		texture(TEXTURE, UV + vec2(px.x, 0.0)).r - texture(TEXTURE, UV - vec2(px.x, 0.0)).r,
		texture(TEXTURE, UV + vec2(0.0, px.y)).r - texture(TEXTURE, UV - vec2(0.0, px.y)).r);
	vec2 outward = -grad / max(length(grad), 0.0001);
	float lit = clamp(dot(outward, normalize(light_dir)), 0.0, 1.0);
	float edge = 1.0 - smoothstep(0.5, 1.0, m.r);
	col += rim_color.rgb * edge * lit * 0.45;
	col *= 1.0 - edge * (1.0 - lit) * 0.35;

	// Jemná „ambient occlusion“ – hlouběji uvnitř je tmavší.
	col *= mix(1.0, 0.72, depth * (1.0 - steel));

	COLOR = vec4(col, coverage);
}
