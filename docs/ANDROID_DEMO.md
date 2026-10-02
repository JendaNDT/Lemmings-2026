# Android demo 0.3.0

Vývojové APK se všemi osmi dovednostmi: původní mise, tři nové zkušební
mise a hřiště se všemi schopnostmi. Společné jádro je stejné pro všechny
platformy. Grafika je stále provizorní a nedosahuje schváleného mockupu.

## Stažení a instalace

[Stáhnout APK z GitHubu](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.3.0/android/Lemmings-2026-Android-0.3.0.apk).

Soubor `Lemmings-2026-Android-0.3.0.apk` je v samostatné větvi
`downloads/android-0.3.0`, spolu s návodem a SHA-256 kontrolním součtem.
Místní kopie je v `/workspace/artifacts/lemmings-android-0.3.0/`.
Stáhnout na telefon nebo tablet,
otevřít a případně povolit instalaci z použitého prohlížeče či správce souborů.
Hra se jmenuje **Lemmings 2026 Demo** a běží na šířku.

- Android 7.0 / API 24 a novější, OpenGL ES 3.0.
- Architektury `arm64-v8a` a `armeabi-v7a` v jednom APK.
- Verze 0.3.0, versionCode 4, balíček `org.lemmings2026.demo`.
- Target SDK 36; aplikace nepožaduje žádná Android oprávnění.
- Testovací podpis Android Debug, schémata v2/v3. Není určený pro vydání
  do Google Play; soukromý klíč je mimo repozitář i předávané artefakty.

Podpis je stejný jako u 0.2.1, takže APK lze instalovat jako aktualizaci.
SHA-256: `867208599aad64b213ab360b466278ed810cef7c837eaa309dea73df9807cfe9`.

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

- Prošlo 184 automatických kontrol v osmi sadách, parser a linter
  53 GDScriptů, import v čisté kopii a výchozí spuštění.
- Nových 10 kontrol ověřuje dotyk, posun, pinch, zrušení, HUD, jediný
  příkaz při emulaci myši a pauzu při odchodu na pozadí.
- Skutečné vykreslování v Compatibility rendereru na Linuxu se softwarovým
  ovladačem llvmpipe a simulovanými dotykovými událostmi dokončilo level:
  **20 zachráněných, 0 ztracených**, včetně výběru dovedností přes HUD.
  Nové mise zachránily 6/6, 6/6 a 3/4; všechny nové dovednosti byly
  přidělené přes skutečnou lištu a dotyk. Tento nový průchod prošel také
  nad herními soubory vytaženými přímo z APK 0.3.0.
- Ověřený podpis APK, CRC souborů, manifest, obě ARM architektury,
  16KiB zarovnání APK a shoda podpisu s předchozí verzí.

Linuxové vykreslování nepotvrzuje instalaci ani běh Android Activity.
V tomto cloudu nebylo dostupné připojené Android zařízení ani použitelný
emulátor. Nativní spuštění, výkon, zahřívání a specifika telefonu/tabletu
proto ještě nejsou ověřené. Protokoly a snímky jsou u předaného APK.

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
