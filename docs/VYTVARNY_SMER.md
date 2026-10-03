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
Nyní existuje pouze celkový generovaný obrázek. Rozdělené podklady,
animace a paralaxa se teprve implementují. Pracovní nápis „Papírové údolí“
v obrázku nepřejmenovává projekt.

Současná hratelná verze stále potřebuje `assets/clay/` a `assets/art_v2/`.
Jejich ponechání zachovává funkčnost hry; nepředstavují další výtvarné
návrhy. Nahrazení herní grafiky není součástí úklidu podkladů.
