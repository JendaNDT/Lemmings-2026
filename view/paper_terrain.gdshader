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
// Nebezpečí (PaperTerrain.build_hazards): R voda, G láva = vzdálenost od
// hladiny 128 ± 12 × px; B/A jednosměrná zeď doleva/doprava.
uniform sampler2D hazard_tex : filter_nearest, repeat_disable;
// Stejná textura s mipmapami: rozmazaná láva = teplá záře na okolním terénu.
uniform sampler2D hazard_soft : filter_linear_mipmap, repeat_disable;
uniform vec2 mask_size = vec2(640.0, 200.0);
uniform float band_offset = 0.0;
// Herní čas v ticích (vlny, plameny); ve stop-motion po krocích.
uniform float sim_time = 0.0;
// 1 = jen pevný terén bíle (kontrola přesnosti), 2 = přední pruhy vody a lávy
// (kreslí se nad postavami), 0 = běžné vykreslení.
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
const vec3 WATER = vec3(0.498, 0.714, 0.788);
const vec3 WATER_LIGHT = vec3(0.741, 0.867, 0.894);
const vec3 WATER_DARK = vec3(0.243, 0.471, 0.573);
const vec3 FOAM = vec3(0.941, 0.957, 0.941);
const vec3 LAVA = vec3(0.86, 0.33, 0.12);
const vec3 LAVA_LIGHT = vec3(0.96, 0.58, 0.2);
const vec3 LAVA_DEEP = vec3(0.6, 0.16, 0.09);
const vec3 FLAME = vec3(0.98, 0.72, 0.28);
const vec3 FLAME_CORE = vec3(1.0, 0.92, 0.66);
const vec3 ONE_WAY = vec3(0.427, 0.6, 0.53);

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

// Skládání „přes“ (průsvitná vrstva přes průsvitný podklad).
vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	if (a < 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / a, a);
}

// Hloubka pod hladinou v px (záporná nad ní) z buňky textury nebezpečí;
// -99 = žádná voda/láva. Hladina je na horní hraně nejvyšší buňky.
float liquid_depth(float v, float py) {
	if (v < 0.5 / 255.0) {
		return -99.0;
	}
	float idx = floor((v * 255.0 - 128.0) / 12.0 + 0.5);
	return (idx > 0.0 ? idx - 1.0 : idx) + fract(py);
}

float wave(float x, float t, float i) {
	return sin(x * 0.53 + t * 0.31 + i * 1.7) * 0.32 + sin(x * 0.19 - t * 0.17 + i * 2.9) * 0.28;
}

// Voda a láva z vlnitých papírových pruhů; každý nižší pruh leží před vyšším.
// front_only: jen pruhy od druhého dál (přední vrstva nad postavami).
vec4 liquid(vec2 p, float depth, bool lava, bool front_only) {
	float t = sim_time * (lava ? 0.45 : 1.0);
	float spacing = lava ? 3.2 : 2.6;
	float s = -1.0;
	float edge = 0.0;
	float next_edge = 99.0;
	for (int i = 0; i < 6; i++) {
		// Hřeben lávy leží vždy nad hladinou, aby mezi ním a plameny nebyla mezera.
		float lift = i == 0 ? (lava ? 0.85 : 0.25) : 0.0;
		float e = float(i) * spacing + wave(p.x, t, float(i)) * (i == 0 ? 1.0 : 0.75) - lift;
		if (depth >= e) {
			s = float(i);
			edge = e;
		} else if (next_edge > 98.0) {
			next_edge = e;
		}
	}
	if (s < 0.0 || (front_only && s < 1.0)) {
		return vec4(0.0);
	}
	float k = clamp(s / 5.0, 0.0, 1.0);
	vec3 c;
	if (lava) {
		c = mix(mix(LAVA_LIGHT, LAVA_DEEP, k), LAVA, mod(s, 2.0) * 0.35);
	} else {
		c = mix(mix(WATER_LIGHT, WATER_DARK, sqrt(k)), WATER, mod(s, 2.0) * 0.3);
	}
	c *= 1.0 + (paper(p, 60.0) - 0.5) * 0.2 + (paper(p + vec2(s * 37.0, 0.0), 24.0) - 0.5) * 0.08;
	if (lava) {
		// Chladnoucí kůrka: tmavší papírové plátky driftují po hladině.
		float crust = smoothstep(0.6, 0.66, noise(vec2(p.x * 0.7 - t * 0.35, p.y * 1.3), 26.0).b)
			* (1.0 - smoothstep(2.5, 5.0, depth)) * step(0.4, depth - edge);
		c = mix(c, LAVA_DEEP * 0.75 * (1.0 + (paper(p, 14.0) - 0.5) * 0.3), crust * 0.85);
		// Bubliny pod hladinou: v některých úsecích 11 px jedna roste, stoupá a praskne.
		float cell = floor(p.x / 11.0);
		float life = fract(t / (20.0 + 14.0 * hash(vec2(cell, 3.0))) + hash(vec2(cell, 4.0)));
		vec2 center = vec2(cell * 11.0 + 3.0 + 5.0 * hash(vec2(cell, 5.0)),
			2.2 + 2.5 * hash(vec2(cell, 6.0)) - life * 1.6);
		float radius = (0.3 + 1.1 * life) * step(0.35, hash(vec2(cell, 7.0)));
		float dist = length(vec2(p.x, depth) - center);
		float disc = 1.0 - smoothstep(radius - 0.12, radius + 0.12, dist);
		float ring = disc * smoothstep(radius - 0.55, radius - 0.2, dist);
		float popping = step(0.86, life);
		c = mix(c, LAVA_LIGHT * 1.08, disc * (1.0 - popping) * 0.8);
		c = mix(c, FLAME_CORE, ring * 0.9);
	} else {
		// Odlesky: světlé čárky pod hřebenem, šikmé paprsky světla v hloubce.
		float glint = smoothstep(0.62, 0.7, noise(vec2(p.x * 0.45 + t * 0.6, s * 13.0), 40.0).r)
			* (1.0 - smoothstep(0.25, 0.45, abs(depth - edge - 1.0)));
		c = mix(c, FOAM, glint * 0.75);
		float ray = smoothstep(0.58, 0.72, noise(vec2(p.x + depth * 0.6 + t * 0.12, 7.0), 34.0).g);
		c *= 1.0 + ray * 0.07 * smoothstep(1.0, 3.0, s);
	}
	// Světlé vláknité jádro na horní hraně pruhu: pěna, u lávy žhavý okraj.
	float rim = clamp(fiber_rim(depth - edge, p + vec2(0.0, s * 13.0), s < 0.5 ? 0.9 : 0.6), 0.0, 1.0);
	c = mix(c, lava ? FLAME_CORE : FOAM, rim * (s < 0.5 ? 0.85 : 0.5));
	// Těsně nad přednějším pruhem je zadní pruh ve stínu.
	c *= 1.0 - (1.0 - smoothstep(0.0, 1.4, next_edge - depth)) * 0.16;
	return vec4(c, front_only ? 0.72 : (lava ? 1.0 : 0.95));
}

// Papírové plameny nad lávou: sloupce mění výšku po dvou ticích.
// Tři řady: vzadu vysoké červené, uprostřed oranžové, vpředu nízké žluté.
vec4 flames(vec2 p, float up) {
	vec4 out_col = vec4(0.0);
	float step_t = floor(sim_time / 2.0);
	for (int row = 0; row < 3; row++) {
		float w = row == 0 ? 4.6 : (row == 1 ? 3.6 : 2.6);
		float x = p.x + float(row) * 1.7;
		float column = floor(x / w);
		float fx = fract(x / w) * 2.0 - 1.0;
		float base_h = row == 0 ? 2.4 : (row == 1 ? 1.8 : 0.9);
		float extra = row == 0 ? 4.2 : (row == 1 ? 3.0 : 1.8);
		// Některé jazyky na chvíli skoro zhasnou, řada pak není pravidelná.
		extra *= 0.35 + 0.65 * step(0.3, hash(vec2(column, step_t * 0.5 + float(row) * 7.0)));
		float h = base_h + extra * hash(vec2(column, step_t + float(row) * 31.0));
		float lean = (hash(vec2(column + 7.0, step_t + float(row))) - 0.5) * 0.7;
		float profile = h * pow(max(1.0 - abs(fx + lean * up / h), 0.0), 1.3);
		float shape = 1.0 - smoothstep(profile - 0.18, profile + 0.18, up);
		float core = 1.0 - smoothstep(profile * 0.5 - 0.15, profile * 0.5 + 0.15, up);
		vec3 c = row == 0 ? mix(LAVA, LAVA_LIGHT, smoothstep(0.0, h, up))
			: (row == 1 ? mix(LAVA_LIGHT, FLAME, smoothstep(0.0, h, up)) : FLAME);
		c = mix(c, FLAME_CORE, core * (row == 0 ? 0.3 : 0.8)) * (1.0 + (paper(p, 20.0) - 0.5) * 0.12);
		// Tenký světlý okraj vystřiženého plamene.
		float rim = (1.0 - smoothstep(0.0, 0.35, abs(up - profile))) * shape;
		c = mix(c, FLAME_CORE, rim * 0.35);
		out_col = over(vec4(c, shape * (row == 0 ? 0.9 : 1.0)), out_col);
	}
	// Jiskry stoupají z hladiny a cestou hasnou.
	float spark_col = floor(p.x / 5.0);
	float rise = fract(sim_time / 22.0 + hash(vec2(spark_col, 9.0)));
	vec2 spark = vec2(spark_col * 5.0 + 1.0 + 3.0 * hash(vec2(spark_col, 10.0))
		+ sin(rise * 6.0 + spark_col) * 0.6, rise * 10.0);
	float spark_dot = 1.0 - smoothstep(0.22, 0.4, length(vec2(p.x, up) - spark));
	out_col = over(vec4(FLAME_CORE, spark_dot * (1.0 - rise)), out_col);
	return out_col;
}

// Šipka jednosměrné zdi (krokev „>“ nebo „<“) v mřížce 6 px.
float chevron(vec2 p, bool right) {
	vec2 f = fract(p / 6.0 + vec2(0.0, 0.5 * mod(floor(p.x / 6.0), 2.0)));
	float fx = right ? f.x : 1.0 - f.x;
	float v = fx + abs(f.y - 0.5) * 1.1;
	// Samostatné šipky: ramena končí před okrajem buňky, nenavazují v klikatici.
	float arms = 1.0 - smoothstep(0.3, 0.36, abs(f.y - 0.5));
	return (1.0 - smoothstep(0.08, 0.14, abs(v - 0.68))) * arms;
}

void fragment() {
	vec2 p = UV * mask_size;
	vec4 m = texture(mask_tex, UV);
	vec4 st = texture(static_tex, UV);
	vec4 hz = texelFetch(hazard_tex, clamp(ivec2(floor(p)), ivec2(0), ivec2(mask_size) - 1), 0);
	float water_depth = liquid_depth(hz.r, p.y);
	float lava_depth = liquid_depth(hz.g, p.y);
	bool has_liquid = water_depth > -98.0 || lava_depth > -98.0;
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
	} else if (debug_mode == 2) {
		// Přední pruhy: stejné barvy jako hlavní průchod, jen průsvitné, aby
		// ponořená část postavy byla „pod vodou“. Terén zůstává navrchu.
		vec4 front = water_depth > -98.0 ? liquid(p, water_depth, false, true)
			: (lava_depth > -98.0 ? liquid(p, lava_depth, true, true) : vec4(0.0));
		COLOR = vec4(front.rgb, front.a * (1.0 - inside));
	} else if (m.r < 0.002 && st.r < 0.5 && st.g < 0.5 && !has_liquid) {
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

		// --- Jednosměrná zeď: šalvějový papír s nalepenými šipkami ------------
		vec4 hs = textureLod(hazard_soft, UV, 0.0);
		float one_way = inside * max(hs.b, hs.a) * (1.0 - steel) * (1.0 - brick);
		if (one_way > 0.001) {
			bool right = hs.a >= hs.b;
			float arrow = chevron(p, right);
			float arrow_shadow = chevron(p - vec2(0.5, 0.7), right) * (1.0 - arrow);
			vec3 wall = mix(col, ONE_WAY * (1.0 + fib * 0.25), 0.6);
			wall *= 1.0 - arrow_shadow * 0.3;
			wall = mix(wall, RIM * (1.0 + fib * 0.2), arrow * 0.9);
			col = mix(col, wall, one_way);
		}

		// Teplá záře lávy na okolní hlíně (rozmazaná láva z mipmap).
		float heat = smoothstep(0.04, 0.35, textureLod(hazard_soft, UV, 3.2).g);
		col = mix(col, col * vec3(1.2, 0.93, 0.74) + vec3(0.09, 0.035, 0.0), heat * 0.6);

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

		// --- Voda a láva (jen v prázdném prostoru, terén je vždy před nimi) ---
		if (lava_depth > -98.0) {
			float up = -lava_depth;
			// Teplá záře nad hladinou a papírové plameny.
			float glow = up > 0.0 ? exp(-up * 0.32) * 0.42 : 0.0;
			outside = over(vec4(LAVA_LIGHT, glow), outside);
			if (up > 0.0) {
				outside = over(flames(p, up), outside);
			}
			vec4 lv = liquid(p, lava_depth, true, false);
			lv.rgb *= 1.0 - drop * 0.2;
			outside = over(lv, outside);
		}
		if (water_depth > -98.0) {
			vec4 wt = liquid(p, water_depth, false, false);
			wt.rgb *= 1.0 - drop * 0.3;
			outside = over(wt, outside);
		}
		COLOR = mix(outside, vec4(col, 1.0), inside);
	}
}
