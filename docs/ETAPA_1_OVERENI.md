# Etapa 1 — ověření a první sestavení

Datum: 2. října 2026. Rozsah: současný první level ve 2D, desktopové
ovládání a samostatný balíček pro autorův MacBook. Přechod na 2.5D
patří do etapy 3. Windows zůstávají pozdějším cílem a Android následnou
platformou s vlastní úpravou vstupu a grafického profilu.

## Výsledky

| Kontrola | Výsledek |
|---|---|
| Import v Godotu 4.7 | Prošel. |
| Původní test: bez zásahu nikdo nezemře | Prošel, 20 lumíků venku, 0 ztracených. |
| Původní test: řešení prvního levelu | Prošel, zachráněno 20/20. |
| Syntaxe a styl 27 sledovaných GDScriptů | Prošly. |
| Start scény, HUD, pauza, pokračování, restart | Prošly v automatické kontrole. |
| Skutečné vykreslování Forward+ | Ověřeno na virtuálním X11 displeji se softwarovým Vulkanem Mesa. |
| Celý level v samostatném Linux QA exportu | Dokončen přes klávesnici a myš, zachráněno 20/20. |
| Pauza, přidělení dovednosti během pauzy, rychlost 3× | Ověřeno během průchodu. |
| Kamera klávesami, tažení, uvolnění tažení nad HUD, zoom | Ověřeno. |
| Změna velikosti okna | Ověřeno 1600×900, 1280×800 a 1024×768; ovládací lišta zůstala dostupná. |
| Opakované restarty | Ověřen restart tlačítkem výsledku i opakovaně klávesou R. |
| Export aplikace pro macOS | Prošel; univerzální Mach-O pro arm64 i x86_64, vložená herní data a ad-hoc podpis. |
| Herní data vytažená z výsledného Mac balíčku | Znovu vykreslena Godotem na Linuxu bez chyb; ověřuje obsah balíčku, nikoli nativní Mac spustitelný soubor. |
| Spuštění na skutečném Macu | Neprovedeno v linuxovém cloudu; zbývá uživatelské ověření. |
| Spuštění na skutečných Windows | Na přání autora odloženo do závěru vývoje. |
| Android, dotykové ovládání, zvuk a výkon na cílovém zařízení | Neověřeno; nejsou součástí první fáze. |

Softwarové vykreslování v cloudu ověřuje funkčnost obrazu, není měřením
výkonu MacBooku ani důkazem dosažení cílových 60 FPS.

## Jak proběhl herní průchod

Použit byl skutečný Linux release export se zabalenými scénami a skripty,
nikoli spuštění projektu v editoru. Do jeho okna byly odesílány běžné
události klávesnice a myši přes X11; stav simulace nebyl ručně měněn.

1. Restart, pauza a výběr raziče klávesou 3.
2. Po příchodu k pilíři přidělení raziče kliknutím na lumíka během pauzy.
3. Výběr stavitele klávesou 2 a přidělení před vyvýšenou plošinou.
4. Výběr kopáče klávesou 4 a prokopání plošiny do jeskyně.
5. Zrychlení klávesou F a kontrola výsledku „Zachráněno 20 z 20“.
6. Restart výsledkovým tlačítkem, zkouška rozlišení, kamery a dalších restartů.

Snímky a logy z cloudového běhu jsou v
`/workspace/artifacts/lemmings-phase-1/`. Dřívější snímek byl při úklidu
grafických podkladů z aktuálního repozitáře odstraněn.


## Připravené exporty

- `macOS`: první uživatelská distribuce, univerzální aplikace pro Apple Silicon a Intel.
- `Linux QA`: pomocný export pro ověřování zabalené hry v cloudu.
- `Windows Desktop`: exportní nastavení pro pozdější použití; nyní není vyžadované testování ani distribuce.

Všechny používají stejné zdrojové scény a skripty. Export nepřidává
alternativní simulaci pro jednotlivé platformy. Pro Mac s ARM byl zapnut
import ETC2/ASTC textur; bez něj Godot univerzální export odmítal.

K reprodukci exportu slouží `scripts/export_desktop.sh`. Vyžaduje Godot
4.7 stable a odpovídající exportní šablony. V cloudu byly nástroje a šablony
staženy z oficiálních zdrojů a ověřeny kontrolními součty; Debian balíčky
navazují na ověřený podpis distribučního indexu.

## Kontrola na MacBooku

Rozbalit ZIP, spustit aplikaci, ověřit obraz, kliknutí na lumíka, pauzu,
posun/zoom a dokončení prvního levelu. Godot není potřeba instalovat.
Balíček není notarizovaný Applem; případné potvrzení prvního spuštění
se týká pouze této aplikace. Postup je uveden v README.

Případné platformní problémy z tohoto hraní se opraví před pokračováním
do grafických změn. Herní logiku nebylo při cloudové kontrole potřeba měnit.
