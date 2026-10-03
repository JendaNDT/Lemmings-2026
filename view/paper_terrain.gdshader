shader_type canvas_item;
// Papírový terén přímo z logické masky (R zem, G ocel, B cihly).
// Hrana leží na izočáře 0,5 bilineárně interpolované masky s šumem menším než
// ±0,5: středy všech buněk si proto vždy zachovají obsazení podle simulace.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
// R původní zem, G vnitřek jeskyně, A hloubka pod původním povrchem (×16 px).
uniform sampler2D static_tex : filter_linear, repeat_disable;
uniform sampler2D paper_tex : filter_linear_mipmap, repeat_enable;
// Hladký periodický šum (4 kanály) pro trhané hrany a vlnění vrstev.
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 mask_size = vec2(640.0, 200.0);
uniform float band_offset = 0.0;
// 1 = jen pevný terén bíle (kontrola přesnosti), 0 = běžné vykreslení.
uniform int debug_mode = 0;

const vec3 TERRA = vec3(0.745, 0.318, 0.192);
const vec3 TERRA_DARK = vec3(0.624, 0.278, 0.176);
const vec3 OCHRE = vec3(0.796, 0.475, 0.212);
const vec3 OCHRE_LIGHT = vec3(0.894, 0.565, 0.247);
const vec3 SAND = vec3(0.878, 0.667, 0.376);
const vec3 TUNNEL = vec3(0.863, 0.682, 0.451);
const vec3 TUNNEL_DARK = vec3(0.639, 0.396, 0.200);
const vec3 CAVE = vec3(0.420, 0.235, 0.165);
const vec3 GRASS_TOP = vec3(0.847, 0.812, 0.494);
const vec3 GRASS = vec3(0.604, 0.604, 0.306);
const vec3 GRASS_LIT = vec3(0.710, 0.706, 0.369);
const vec3 GRASS_DARK = vec3(0.486, 0.510, 0.251);
const vec3 STEEL = vec3(0.275, 0.384, 0.455);
const vec3 STEEL_LINE = vec3(0.788, 0.839, 0.863);
const vec3 STAIR_LIGHT = vec3(0.949, 0.886, 0.784);
const vec3 STAIR_MID = vec3(0.898, 0.800, 0.686);
const vec3 STAIR_DARK = vec3(0.702, 0.612, 0.518);
const vec3 RIM = vec3(0.976, 0.902, 0.769);

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

float mask_r(vec2 p) {
	return texture(mask_tex, p / mask_size).r;
}

float paper(vec2 p, float scale) {
	return texture(paper_tex, p / scale).r;
}

vec4 noise(vec2 p, float scale) {
	return texture(noise_tex, p / scale);
}

vec3 band_color(float index) {
	// Nepravidelné střídání: sousední listy nikdy nemají stejnou barvu.
	float k = mod(index * 2.0 + floor(hash(vec2(index, 3.0)) * 1.999) + band_offset, 6.0);
	if (k < 1.0) return TERRA;
	if (k < 2.0) return OCHRE;
	if (k < 3.0) return TERRA_DARK;
	if (k < 4.0) return OCHRE_LIGHT;
	if (k < 5.0) return SAND;
	return TERRA;
}

// Horní hrana listu k: pravidelná mřížka posunutá o ±35 % výšky listu,
// takže listy mají různou tloušťku.
float band_top(float k, float h) {
	return k * h + (hash(vec2(k, 11.0)) - 0.5) * h * 0.7;
}

void fragment() {
	vec2 p = UV * mask_size;
	vec4 m = texture(mask_tex, UV);
	vec4 st = texture(static_tex, UV);
	float fib = paper(p, 96.0) - 0.5;
	// Šum hrany je omezený na ±0,4: středy buněk (hodnota 0 nebo 1) se nezmění.
	float jitter = (noise(p, 24.0).r - 0.5) * 0.6 + (noise(p, 7.0).g - 0.5) * 0.18 + fib * 0.1;
	float thr = 0.5 + clamp(jitter, -0.4, 0.4);
	float aa = max(fwidth(m.r) * 0.6, 0.01);
	float inside = smoothstep(thr - aa, thr + aa, m.r);
	// Stín vrhaný terénem doprava dolů na zadní stěnu i krajinu.
	float drop = mask_r(p - vec2(0.7, 0.9)) * 0.55 + mask_r(p - vec2(1.5, 1.9)) * 0.45;
	if (debug_mode == 1) {
		COLOR = vec4(vec3(step(thr, m.r)), 1.0);
	} else if (m.r < 0.002 && st.r < 0.5 && st.g < 0.5) {
		// Volný prostor bez zadní stěny: jen stín, zbytek výpočtu se přeskočí.
		COLOR = vec4(0.0, 0.0, 0.0, drop * 0.3);
	} else {
		float steel = inside * smoothstep(0.4, 0.6, m.g);
		float brick = inside * smoothstep(0.4, 0.6, m.b) * (1.0 - steel);

		// --- Vrstvy trhaného papíru (terakota, okr, písek) -----------------
		// Široké listy trhaného papíru: horní list překrývá dolní, má světlý
		// vláknitý okraj a vrhá na něj stín.
		float band_h = 22.0;
		float wob = (noise(vec2(p.x, 3.0), 260.0).b - 0.5) * 16.0
			+ (noise(vec2(p.x, 40.0), 60.0).r - 0.5) * 4.0;
		float yy = p.y + wob;
		float bi = floor(yy / band_h);
		float tear_edge = (noise(vec2(p.x, bi * 9.0), 14.0).g - 0.5) * 2.2
			+ (noise(vec2(p.x, bi * 5.0), 4.0).a - 0.5) * 0.3 + fib * 0.08;
		yy += tear_edge;
		bi = floor(yy / band_h);
		float top = band_top(bi, band_h);
		if (yy < top) {
			bi -= 1.0;
		} else if (yy >= band_top(bi + 1.0, band_h)) {
			bi += 1.0;
		}
		top = band_top(bi, band_h);
		float bottom = band_top(bi + 1.0, band_h);
		float bf = yy - top;  // px od horní hrany listu
		float to_bottom = bottom - yy;
		float block = floor((p.x + wob * 2.0) / 52.0);
		vec3 col = band_color(bi);
		col *= 0.95 + 0.08 * hash(vec2(block, bi));
		col *= 1.0 + (noise(p, 40.0).a - 0.5) * 0.12;
		float rim_band = 1.0 - smoothstep(0.15, 0.55, to_bottom);
		float band_shadow = (1.0 - smoothstep(0.0, 1.8, bf)) * 0.24;
		col *= 1.0 - band_shadow;
		col = mix(col, RIM, rim_band * 0.7);
		col *= 1.0 + fib * 0.24;

		// Světlo zleva shora: světlejší horní okraj siluety, tmavší spodní.
		float lit = 1.0 - mask_r(p + vec2(-0.9, -1.0));
		float shade = 1.0 - mask_r(p + vec2(0.8, 1.1));
		col *= 1.0 + lit * 0.08 - shade * 0.16;

		// --- Mech z lístků na původním povrchu -------------------------------
		// Dvě řady oblých lístků (zadní tmavší a delší, přední světlejší) visí
		// přes horní hranu; vrchní světlý pruh je plocha trávníku.
		float depth = st.a * 255.0 / 16.0;
		float support = inside * (1.0 - steel) * (1.0 - brick) * step(0.5, st.r);
		vec3 leaf = vec3(0.0);
		float grass = 0.0;
		for (int row = 0; row < 2; row++) {
			float rw = row == 0 ? 4.4 : 3.1;
			float lx = (p.x + float(row) * 1.3) / rw + (noise(vec2(p.x, 5.0 + float(row) * 11.0), 70.0).r - 0.5) * 0.9;
			float li = floor(lx);
			float lf = fract(lx);
			float h = hash(vec2(li, 2.0 + float(row)));
			float lobe = sqrt(max(1.0 - pow(lf * 2.0 - 1.0, 2.0), 0.0));
			float tipped = mix(lobe, 1.0 - abs(lf * 2.0 - 1.0), 0.55);
			float len = (row == 0 ? 3.2 : 2.0) + (row == 0 ? 3.4 : 2.0) * h;
			float lim = (row == 0 ? 0.9 : 0.7) + len * tipped;
			float in_leaf = support * (1.0 - smoothstep(lim - 0.12, lim + 0.12, depth));
			float pick = hash(vec2(li, 7.0 + float(row)));
			vec3 c = row == 0 ? (pick < 0.5 ? GRASS_DARK : GRASS) : (pick < 0.5 ? GRASS : GRASS_LIT);
			c *= lf < 0.5 ? 1.07 : 0.9;
			float vein = (1.0 - smoothstep(0.0, 0.035, abs(lf - 0.5))) * smoothstep(0.6, 1.2, depth);
			c = mix(c, GRASS_TOP, vein * 0.3);
			// Přední lístek vrhá stín na zadní.
			float edge = smoothstep(lim - 0.5, lim - 0.1, depth);
			c *= 1.0 - edge * 0.12;
			leaf = mix(leaf, c, in_leaf);
			grass = max(grass, in_leaf);
		}
		leaf = mix(leaf, GRASS_TOP, 1.0 - smoothstep(0.35, 0.7, depth));
		leaf *= 1.0 + fib * 0.18;
		// Stín pod lístky na terakotě.
		float under = (1.0 - smoothstep(5.0, 8.0, depth)) * step(0.5, st.r) * (1.0 - grass);
		col *= 1.0 - under * 0.18;
		col = mix(col, leaf, grass);

		// --- Ocelová (nerozbitná) výztuha -------------------------------------
		float l1 = abs(fract((p.x + p.y) / 7.0) - 0.5);
		float l2 = abs(fract((p.x - p.y) / 7.0) - 0.5);
		float line_w = 0.045 + fwidth(p.x) / 14.0;
		float lattice = 1.0 - smoothstep(line_w * 0.4, line_w, 0.5 - max(l1, l2));
		vec3 steel_col = STEEL * (1.0 + fib * 0.25);
		float s_lit = 1.0 - texture(mask_tex, (p + vec2(-0.8, -0.8)) / mask_size).g;
		float s_dark = 1.0 - texture(mask_tex, (p + vec2(0.8, 0.8)) / mask_size).g;
		steel_col *= 1.0 + s_lit * 0.25 - s_dark * 0.2;
		steel_col = mix(steel_col, STEEL_LINE, lattice * 0.65);
		col = mix(col, steel_col, steel);

		// --- Harmonikové schody stavitele -------------------------------------
		float fold_i = floor(p.x / 2.0);
		vec2 fl = fract(vec2(p.x / 2.0, p.y));
		vec3 stair = mod(fold_i, 2.0) < 1.0 ? STAIR_LIGHT : STAIR_MID;
		stair = mix(stair, STAIR_DARK, (1.0 - smoothstep(0.0, 0.07, abs(fl.x - fl.y))) * 0.5);
		float above = 1.0 - texture(mask_tex, (p + vec2(0.0, -0.8)) / mask_size).b;
		float below = 1.0 - texture(mask_tex, (p + vec2(0.0, 0.7)) / mask_size).b;
		stair *= 1.0 + above * 0.06;
		stair = mix(stair, STAIR_DARK, below * 0.55);
		stair *= 1.0 + fib * 0.12;
		col = mix(col, stair, brick);

		// Tenký tmavý okraj vystřiženého papíru.
		float outline = inside * (1.0 - smoothstep(thr, thr + 0.22, m.r));
		col *= 1.0 - outline * 0.35;

		// --- Zadní stěna výkopu a jeskyně ------------------------------------
		float dug = step(0.5, st.r) * (1.0 - inside);
		float cave = step(0.5, st.g) * (1.0 - step(0.5, st.r)) * (1.0 - inside);
		float back = max(dug, cave);
		float near_top = max(mask_r(p + vec2(0.0, -1.0)), max(mask_r(p + vec2(-0.9, -0.6)) * 0.7,
			mask_r(p + vec2(0.0, -2.4)) * 0.55));
		vec3 back_col = mix(TUNNEL, mix(TUNNEL_DARK, CAVE, 0.3), cave);
		back_col *= 1.0 + fib * 0.35 + (paper(p, 30.0) - 0.5) * 0.12;
		back_col *= 1.0 - near_top * 0.32;

		drop *= 1.0 - inside;

		vec4 outside = vec4(0.0, 0.0, 0.0, drop * 0.3);
		vec4 back_rgba = vec4(back_col * (1.0 - drop * 0.3), 1.0);
		outside = mix(outside, back_rgba, back);
		COLOR = mix(outside, vec4(col, 1.0), inside);
	}
}
