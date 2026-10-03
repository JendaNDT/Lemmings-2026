# Výtvarný směr — 2D origami

Aktuální zadání z 3. října 2026: **čistě 2D papírová hra s paralaxním
posunem i zoomováním**. Jediná současná výtvarná předloha je
[origami mockup](MOCKUP_ORIGAMI.md). Autor jej označil za pěkný a požádal
ponechat na GitHubu pouze tento návrh. Starší koncepty a výtvarné studie
byly z aktuálního stromu odstraněny.

- Terén tvoří barevné papírové vrstvy s trhanými hranami; postavy mají přehyby.
- Pozadí má klidné odstíny, ostrá herní vrstva tyrkysovou a okrovou,
  terén terakotovou. Jemné stíny oddělují vystřižené části.
- Vzdálená krajina, střední kulisy a popředí reagují různě na posun a zoom.
  Postavy, schůdný terén a schody sdílejí jednu 2D herní soustavu.
- Kopání uvolňuje papírové ústřižky, stavitel rozkládá schody. Změny
  schůdnosti vždy určuje simulační maska, nikoli výtvarný efekt.
- Kopání pouze vodorovně, šikmo dolů a svisle dolů; vzhůru vedou schody.
- HUD zůstává ukotvený na obrazovce. Popředí nesmí zakrývat interakce.

Pořadí: **mockup → grafické vrstvy → postavička a animace → scéna Godotu**.
Všechny kroky jsou provedené: výchozí scéna `main/game_origami.tscn` kreslí
papírový terén z masky, origami postavy s animacemi všech stavů, líheň,
východ a čtyři paralaxní vrstvy krajiny s popředím. Podklady jsou
v `assets/origami/`, ověření v [`ORIGAMI_OVERENI.md`](ORIGAMI_OVERENI.md).
Pracovní nápis „Papírové údolí“ v obrázku nepřejmenovává projekt.

Scéna `main/game_3d.tscn` (2.5D) stále používá `assets/clay/`
a `assets/art_v2/`; obě sady proto zůstávají. Font Nunito z `assets/art_v2/`
používá i nový HUD. Nejsou to další výtvarné návrhy.
