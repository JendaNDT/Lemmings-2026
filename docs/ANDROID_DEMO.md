# Android demo 0.4.0

Vývojové APK se všemi osmi dovednostmi: původní mise, tři nové zkušební
mise a hřiště se všemi schopnostmi. Společné jádro je stejné pro všechny
platformy. Verze 0.4.0 přidává první výtvarnou úpravu skutečné scény;
[technické podklady a ověření](GRAFIKA_04.md).

## Stažení a instalace

[Stáhnout APK z GitHubu](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.4.0/android/Lemmings-2026-Android-0.4.0.apk).

Soubor `Lemmings-2026-Android-0.4.0.apk` je v samostatné větvi
`downloads/android-0.4.0`, spolu s návodem a SHA-256 kontrolním součtem.
Místní kopie je v `/workspace/artifacts/lemmings-android-0.4.0/`.
Stáhnout na telefon nebo tablet,
otevřít a případně povolit instalaci z použitého prohlížeče či správce souborů.
Hra se jmenuje **Lemmings 2026 Demo** a běží na šířku.

- Android 7.0 / API 24 a novější, OpenGL ES 3.0.
- Architektury `arm64-v8a` a `armeabi-v7a` v jednom APK.
- Verze 0.4.0, versionCode 5, balíček `org.lemmings2026.demo`.
- Target SDK 36; aplikace nepožaduje žádná Android oprávnění.
- Testovací podpis Android Debug, schémata v2/v3. Není určený pro vydání
  do Google Play; soukromý klíč je mimo repozitář i předávané artefakty.

Podpis je stejný jako u 0.3.0, takže APK lze instalovat jako aktualizaci.
SHA-256: `125fad60fc480ce8c9715ffd4c6e755d5123575f265170196d8a13c25341914d`.

## Ovládání a profil

Klepnutí na dovednost a potom na postavu přidělí příkaz. Posun jedním prstem
posouvá kameru, dva prsty ji posouvají i přibližují. Dovednost se přidělí
až při uvolnění prstu bez významného pohybu. Emulovaná myš nevytvoří druhý
příkaz. Dotyky začaté na HUDu se nepřenesou do herní plochy.

Zkušební mise se vybírají vlevo v dolní liště. Osm dovedností se vejde
na společný spodní řádek. **Ukončit** vyžaduje potvrzení; v dialogu se
čas zastaví a klepnutí nepřidělí dovednost postavě pod oknem.

Dotykový výběr má širší dosah a vybírá nejbližší postavu, které lze aktuální
dovednost přidělit. Zpět přepíná pauzu; přechod na pozadí vždy hru pozastaví
a vymaže rozpracovaná gesta. Obnovení pohybu zůstává na hráči.

Android používá Compatibility / OpenGL ES 3, návrhový viewport 1280 × 720,
75% rozlišení 3D, menší stíny a vypnuté SSAO/MSAA. Světla jsou vyvážená
pro tento renderer. Herní logika se podle platformy nevětví.

## Ověření a omezení

- Prošlo 186 automatických kontrol v osmi sadách, parser a linter
  56 GDScriptů, import v čisté kopii a výchozí spuštění.
- Deset kontrol ověřuje dotyk, posun, pinch, zrušení, HUD, jediný
  příkaz při emulaci myši a pauzu při odchodu na pozadí.
- Skutečné vykreslování v Compatibility rendereru na Linuxu se softwarovým
  ovladačem llvmpipe a simulovanými dotykovými událostmi dokončilo level:
  **20 zachráněných, 0 ztracených**, včetně výběru dovedností přes HUD.
  Nové mise zachránily 6/6, 6/6 a 3/4; všechny nové dovednosti byly
  přidělené přes skutečnou lištu a dotyk. Tento nový průchod prošel také
  nad herními soubory vytaženými přímo z APK 0.4.0.
- Ověřený podpis APK, CRC souborů, manifest, obě ARM architektury,
  16KiB zarovnání APK a shoda podpisu s předchozí verzí. Licence písma
  Nunito je přiložená přímo v APK, editovatelné zdroje Blenderu se nebalí.

Linuxové vykreslování nepotvrzuje instalaci ani běh Android Activity.
V tomto cloudu nebylo dostupné připojené Android zařízení ani použitelný
emulátor. Nativní spuštění, výkon, zahřívání a specifika telefonu/tabletu
proto ještě nejsou ověřené. Technické výsledky zachovává záznam ověření; staré grafické náhledy
byly při změně výtvarného směru odstraněny.

## Opakování exportu

Použít Godot 4.7 stable a stejné Android exportní šablony. V nastavení
editoru vyplnit Android SDK a Java SDK. V tomto cloudu stačily Java 21,
Build Tools 35.0.1 a standardní APK export bez Gradlu. Stažené SDK balíčky
byly ověřené kontrolními součty z oficiálního Google repozitáře.

```bash
python scripts/check.py
bash scripts/export_android.sh
```

Výstup je `build/android/Lemmings-2026-Android.apk`. Debug klíč spravuje
Godot mimo projekt. Pro aktualizace stejné instalace uchovat stejný klíč.
Pro produkční distribuci připravit samostatný spravovaný podpis.

Grafický test dotyků na Linuxu:

```bash
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 1280x720 --script res://scripts/qa_3d.gd \
  -- --touch --mobile-preview --capture-dir=/tmp/lemmings-touch
```

Varování llvmpipe o V-Sync a desktopovém 2D MSAA při přepnutí rendereru
jsou zaznamenaná; Android profil MSAA vypíná. Výsledky neuvádějí FPS telefonu.
