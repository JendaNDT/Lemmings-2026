shader_type canvas_item;
// Papírový terén přímo z logické masky (R zem, G ocel, B cihly).
// Hrana leží na izočáře 0,5 bilineárně interpolované masky s šumem menším než
// ±0,5: středy všech buněk si proto vždy zachovají obsazení podle simulace.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
// Stejná maska s mipmapami: rozmazané úrovně dávají měkké stíny a šířku okrajů.
uniform sampler2D mask_soft : filter_linear_mipmap, repeat_disable;
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

// Rozmazaná maska (kanál podle `channel`): lod 1 ≈ 2 px, lod 2 ≈ 4 px.
vec4 soft(vec2 p, float lod) {
	return textureLod(mask_soft, p / mask_size, lod);
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

// Vystřižený kus v řadě k: (index, vzdálenost od levého švu, šířka, posun
// horní hrany dolů). Švy jsou natržené, každý kus je mírně nakloněný.
vec4 piece(float k, vec2 p) {
	float pw = 26.0 + 46.0 * hash(vec2(k, 5.0));
	// Šikmé, zvlněné švy; každá řada má jiný sklon i posun.
	float slant = (hash(vec2(k, 9.0)) - 0.5) * 0.4;
	float seam = (noise(vec2(p.y * 1.3, k * 7.0), 10.0).r - 0.5) * 5.0 + p.y * slant;
	float px = p.x + seam + k * 17.3;
	float idx = floor(px / pw);
	float pf = px - idx * pw;
	float tilt = (hash(vec2(idx, k * 3.0 + 1.0)) - 0.5) * 0.1;
	float lift = 0.6 + hash(vec2(idx, k * 3.0 + 2.0)) * 3.2 + tilt * (pf - pw * 0.5);
	return vec4(idx, pf, pw, max(lift, 0.0));
}

// Vláknitý okraj: šířka kolísá podle šumu, uvnitř drobná vlákna.
float fiber_rim(float dist, vec2 p, float width) {
	float w = width * (0.55 + 0.9 * noise(p, 3.0).g);
	return (1.0 - smoothstep(w * 0.35, w, dist)) * (0.75 + 0.5 * paper(p, 18.0));
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
	// Měkký stín vrhaný terénem doprava dolů: terén je list zvednutý nad krajinou.
	float drop = soft(p - vec2(1.3, 1.9), 1.2).r * 0.55 + soft(p - vec2(2.4, 3.4), 2.3).r * 0.45;
	if (debug_mode == 1) {
		COLOR = vec4(vec3(step(thr, m.r)), 1.0);
	} else if (m.r < 0.002 && st.r < 0.5 && st.g < 0.5) {
		// Volný prostor bez zadní stěny: jen stín, zbytek výpočtu se přeskočí.
		COLOR = vec4(0.0, 0.0, 0.0, drop * 0.36);
	} else {
		float steel = inside * smoothstep(0.4, 0.6, m.g);
		float brick = inside * smoothstep(0.4, 0.6, m.b) * (1.0 - steel);

		// --- Listy trhaného papíru složené z vystřižených kusů -----------------
		// Horní list leží na dolním: na spodní hraně má světlé vláknité jádro
		// a vrhá měkký stín. Řada se dělí na kusy s natrženými švy.
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
		vec4 cur = piece(bi, p);
		float row = bi;
		float from_top;
		float to_bottom;
		if (yy - top < cur.w) {
			// Nad posunutou hranou kusu ještě leží spodek listu z řady výš.
			row = bi - 1.0;
			float own_top = band_top(row, band_h);
			cur = piece(row, p);
			from_top = yy - own_top - cur.w;
			to_bottom = top + piece(bi, p).w - yy;
		} else {
			from_top = yy - top - cur.w;
			to_bottom = bottom + piece(bi + 1.0, p).w - yy;
		}
		vec3 col = band_color(row);
		float tint = hash(vec2(cur.x, row * 2.0 + 7.0));
		col *= 0.93 + 0.12 * tint;
		col = mix(col, TERRA_DARK, step(0.82, tint) * 0.35);
		col *= 1.0 + (noise(p, 40.0).a - 0.5) * 0.12;
		// Švy mezi kusy: horní kus má světlou hranu, spodní dostane stín.
		float over_left = step(0.5, hash(vec2(cur.x, row * 5.0 + 4.0)));
		float right_over = step(0.5, hash(vec2(cur.x + 1.0, row * 5.0 + 4.0)));
		float seam_shadow = (1.0 - over_left) * (1.0 - smoothstep(0.0, 3.0, cur.y)) * 0.26;
		float seam_rim = max(over_left * fiber_rim(cur.y, p, 0.65),
			(1.0 - right_over) * fiber_rim(cur.z - cur.y, p, 0.55));
		float band_shadow = (1.0 - smoothstep(0.0, 3.6, from_top)) * 0.3;
		float rim_band = fiber_rim(to_bottom, p, 0.95);
		col *= 1.0 - max(band_shadow, seam_shadow);
		col *= 1.0 + fib * 0.26 + (paper(p, 40.0) - 0.5) * 0.1;
		col = mix(col, RIM * (1.0 + fib * 0.2), clamp(max(rim_band, seam_rim), 0.0, 1.0) * 0.82);

		// Světlo zleva shora: měkce světlejší horní okraj siluety, tmavší spodní.
		float lit = 1.0 - soft(p + vec2(-1.1, -1.3), 0.7).r;
		float shade = 1.0 - soft(p + vec2(1.0, 1.3), 0.7).r;
		col *= 1.0 + lit * 0.1 - shade * 0.2;
		// Světlé vláknité jádro na obrysu vystřiženého terénu (i stěny výkopů).
		float edge_soft = soft(p, 0.8).r;
		float outer_rim = inside * (1.0 - smoothstep(0.52, 0.93, edge_soft + (noise(p, 2.5).b - 0.5) * 0.3));
		outer_rim *= 0.7 + 0.6 * paper(p, 14.0);
		col = mix(col, RIM * (1.0 + fib * 0.25), clamp(outer_rim, 0.0, 1.0) * 0.75);
		// Ocelová výztuha je nalepený díl: vrhá stín na okolní zem.
		float steel_drop = soft(p - vec2(0.9, 1.3), 1.0).g;
		col *= 1.0 - steel_drop * (1.0 - smoothstep(0.4, 0.6, m.g)) * 0.32;

		// --- Mech z lístků na původním povrchu -------------------------------
		// Dvě řady oblých lístků (zadní tmavší a delší, přední světlejší) visí
		// přes horní hranu; vrchní světlý pruh je plocha trávníku.
		float depth = st.a * 255.0 / 16.0;
		float support = inside * (1.0 - steel) * (1.0 - brick) * step(0.5, st.r);
		vec3 leaf = vec3(0.0);
		float grass = 0.0;
		float leaf_shadow = 0.0;
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
			// Lístek je zvednutý: pod ním leží jeho měkký stín.
			leaf_shadow = max(leaf_shadow, support * (1.0 - smoothstep(lim + 0.2, lim + 1.6, depth - 0.6)));
			float pick = hash(vec2(li, 7.0 + float(row)));
			vec3 c = row == 0 ? (pick < 0.5 ? GRASS_DARK : GRASS) : (pick < 0.5 ? GRASS : GRASS_LIT);
			c *= lf < 0.5 ? 1.07 : 0.9;
			float vein = (1.0 - smoothstep(0.0, 0.035, abs(lf - 0.5))) * smoothstep(0.6, 1.2, depth);
			c = mix(c, GRASS_TOP, vein * 0.3);
			// Okraj lístku: světlé jádro papíru.
			float edge = smoothstep(lim - 0.45, lim - 0.12, depth);
			c = mix(c, mix(GRASS_TOP, RIM, 0.4), edge * 0.45);
			leaf = mix(leaf, c, in_leaf);
			grass = max(grass, in_leaf);
		}
		leaf = mix(leaf, GRASS_TOP, 1.0 - smoothstep(0.35, 0.7, depth));
		leaf *= 1.0 + fib * 0.18;
		// Stín pod lístky na terakotě.
		col *= 1.0 - leaf_shadow * (1.0 - grass) * 0.34;
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

		// Velmi tenká hrana střihu (tloušťka papíru) na samém obrysu.
		float outline = inside * (1.0 - smoothstep(thr, thr + 0.12, m.r));
		col *= 1.0 - outline * 0.18;

		// --- Zadní stěna výkopu a jeskyně ------------------------------------
		float dug = step(0.5, st.r) * (1.0 - inside);
		float cave = step(0.5, st.g) * (1.0 - step(0.5, st.r)) * (1.0 - inside);
		float back = max(dug, cave);
		// Zadní stěna leží hlouběji: přední list na ni vrhá širší měkký stín.
		float near_top = soft(p + vec2(-0.6, -1.4), 1.0).r * 0.6 + soft(p + vec2(-1.2, -2.6), 2.0).r * 0.4;
		vec3 back_col = mix(TUNNEL, mix(TUNNEL_DARK, CAVE, 0.3), cave);
		back_col *= 1.0 + fib * 0.35 + (paper(p, 30.0) - 0.5) * 0.12;
		back_col *= 1.0 - near_top * 0.42;

		drop *= 1.0 - inside;

		vec4 outside = vec4(0.0, 0.0, 0.0, drop * 0.36);
		vec4 back_rgba = vec4(back_col * (1.0 - drop * 0.25), 1.0);
		outside = mix(outside, back_rgba, back);
		COLOR = mix(outside, vec4(col, 1.0), inside);
	}
}
