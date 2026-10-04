class_name PaperTheme
extends RefCounted
## Vzhled kapitol: krajina, nebe, barvy hlíny a trávy, světlo a počasí.
## Jen vzhled – kolize, pravidla ani výběr postav se nemění. Krajiny vyrábí
## assets/origami/source/build_themes.py (louka build_backgrounds.py).

## Téma podle kapitoly kampaně (0–3); mimo kampaň (Hřiště) louka.
const BY_CHAPTER := ["louka", "les", "sopka", "bourka"]
const LAYER_ROOT := "res://assets/origami/layers/"
## Klíče barev terénu = uniformy v paper_terrain.gdshader.
const THEMES := {
	"louka": {
		"dir": "", "sky": [Color("8fc3d6"), Color("b4d3d8"), Color("e6e4d2")],
		"terrain": {
			"TERRA": Color(0.745, 0.318, 0.192), "TERRA_DARK": Color(0.624, 0.278, 0.176),
			"OCHRE": Color(0.796, 0.475, 0.212), "OCHRE_LIGHT": Color(0.894, 0.565, 0.247),
			"SAND": Color(0.878, 0.667, 0.376), "TUNNEL": Color(0.863, 0.682, 0.451),
			"TUNNEL_DARK": Color(0.639, 0.396, 0.200), "CAVE": Color(0.420, 0.235, 0.165),
			"GRASS_TOP": Color(0.847, 0.812, 0.494), "GRASS": Color(0.604, 0.604, 0.306),
			"GRASS_LIT": Color(0.710, 0.706, 0.369), "GRASS_DARK": Color(0.486, 0.510, 0.251),
		},
		"grass": [Color("9a9a4e"), Color("b5b45e"), Color("7c8240"), Color("9aa456")],
		"grass_light": Color("d8cf7e"),
		"light": [Color(1.0, 0.82, 0.52), 0.085, 0.03], "lightning": false,
		"weather": "petals",
		"weather_colors": [Color("b5b45e"), Color("e4903f"), Color("f1e9da"), Color("9aa456")],
		"scraps": [Color("be5131"), Color("cb7936"), Color("e4903f"), Color("e0aa60"), Color("dcae73")],
	},
	# II. Skalní les: hnědá lesní hlína, mechový drn, chladné světlo s paprsky mezi jedlemi.
	"les": {
		"dir": "les", "sky": [Color("9cc0c8"), Color("c0d4d0"), Color("e4e3d2")],
		"terrain": {
			"TERRA": Color("8f5a3a"), "TERRA_DARK": Color("734631"), "OCHRE": Color("a87545"),
			"OCHRE_LIGHT": Color("c08d55"), "SAND": Color("c3a678"), "TUNNEL": Color("d0ad7d"),
			"TUNNEL_DARK": Color("8e6640"), "CAVE": Color("3f2a1f"), "GRASS_TOP": Color("b4bd78"),
			"GRASS": Color("6f8a44"), "GRASS_LIT": Color("88a253"), "GRASS_DARK": Color("556b35"),
		},
		"grass": [Color("6f8a44"), Color("88a253"), Color("556b35"), Color("7e9a4c")],
		"grass_light": Color("b4bd78"),
		"light": [Color(0.92, 0.96, 0.85), 0.07, 0.05], "lightning": false,
		"weather": "petals",
		"weather_colors": [Color("7e9a4c"), Color("a1492b"), Color("c08d55"), Color("556b35")],
		"scraps": [Color("8f5a3a"), Color("a87545"), Color("c08d55"), Color("c3a678"), Color("d0ad7d")],
	},
	# III. Voda a oheň: čedičová hlína, vyprahlá tráva, žhnoucí večerní světlo, jiskry.
	"sopka": {
		"dir": "sopka", "sky": [Color("5f5f8c"), Color("d4917a"), Color("f3c58a")],
		"terrain": {
			"TERRA": Color("7e3a2c"), "TERRA_DARK": Color("5e2a22"), "OCHRE": Color("9c5636"),
			"OCHRE_LIGHT": Color("c06a3a"), "SAND": Color("a8826a"), "TUNNEL": Color("b98b66"),
			"TUNNEL_DARK": Color("6e412d"), "CAVE": Color("2a1714"), "GRASS_TOP": Color("c7a866"),
			"GRASS": Color("8a7a40"), "GRASS_LIT": Color("a39046"), "GRASS_DARK": Color("6a5b2e"),
		},
		"grass": [Color("8a7a40"), Color("a39046"), Color("6a5b2e"), Color("96833f")],
		"grass_light": Color("c7a866"),
		"light": [Color(1.0, 0.62, 0.38), 0.13, 0.015], "lightning": false,
		"weather": "embers",
		"weather_colors": [Color("f8c063"), Color("e4903f"), Color("f26a3a"), Color("fbe2a0")],
		"scraps": [Color("7e3a2c"), Color("9c5636"), Color("c06a3a"), Color("a8826a"), Color("b98b66")],
	},
	# IV. Bouřková hora: břidlicová hlína, studený drn, šedé světlo, déšť a blesky.
	"bourka": {
		"dir": "bourka", "sky": [Color("4c5b69"), Color("7a8994"), Color("b5bdb9")],
		"terrain": {
			"TERRA": Color("8c5c4a"), "TERRA_DARK": Color("6c4639"), "OCHRE": Color("9d7656"),
			"OCHRE_LIGHT": Color("b28f6c"), "SAND": Color("b6a284"), "TUNNEL": Color("c3aa8a"),
			"TUNNEL_DARK": Color("7a6250"), "CAVE": Color("2c2729"), "GRASS_TOP": Color("a7b48e"),
			"GRASS": Color("627b5c"), "GRASS_LIT": Color("7b9472"), "GRASS_DARK": Color("4b5f49"),
		},
		"grass": [Color("627b5c"), Color("7b9472"), Color("4b5f49"), Color("6c866a")],
		"grass_light": Color("a7b48e"),
		"light": [Color(0.78, 0.86, 1.0), 0.04, 0.0], "lightning": true,
		"weather": "rain",
		"weather_colors": [Color("eef4f7"), Color("d3e0e8")],
		"scraps": [Color("8c5c4a"), Color("9d7656"), Color("b28f6c"), Color("b6a284"), Color("c3aa8a")],
	},
}


static func for_chapter(chapter: int) -> String:
	if chapter < 0 or chapter >= BY_CHAPTER.size():
		return BY_CHAPTER[0]
	return BY_CHAPTER[chapter]


static func data(name: String) -> Dictionary:
	return THEMES[name] if THEMES.has(name) else THEMES[BY_CHAPTER[0]]


## Složka s vrstvami krajiny tématu (s lomítkem na konci).
static func layer_dir(name: String) -> String:
	var dir: String = data(name)["dir"]
	return LAYER_ROOT + (dir + "/" if not dir.is_empty() else "")


## Záblesk blesku 0–1 v herním čase (tiky): dvojitý záblesk zhruba každých 17 s.
static func lightning(ticks: float) -> float:
	var t := fposmod(ticks + 97.0, 290.0)
	if t < 3.0:
		return 1.0 - t / 3.0
	if t >= 7.0 and t < 9.0:
		return 0.6 * (1.0 - (t - 7.0) / 2.0)
	return 0.0
