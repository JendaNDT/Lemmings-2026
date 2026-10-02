# Android demo 0.2.1

První instalovatelné APK ukázkové mise „První kroky“. Sdílí stejné pravidlo,
level a podklady s macOS verzí. Nejde o dokončení celé pozdější Android etapy.

## Stažení a instalace

[Stáhnout APK z GitHubu](https://github.com/JendaNDT/Lemmings-2026/raw/refs/heads/downloads/android-0.2.1/android/Lemmings-2026-Android-0.2.1.apk).

Soubor `Lemmings-2026-Android-0.2.1.apk` je v samostatné větvi
`downloads/android-0.2.1`, spolu s návodem a SHA-256 kontrolním součtem.
Místní kopie je v `/workspace/artifacts/lemmings-android/`.
Stáhnout na telefon nebo tablet,
otevřít a případně povolit instalaci z použitého prohlížeče či správce souborů.
Hra se jmenuje **Lemmings 2026 Demo** a běží na šířku.

- Android 7.0 / API 24 a novější, OpenGL ES 3.0.
- Architektury `arm64-v8a` a `armeabi-v7a` v jednom APK.
- Verze 0.2.1, versionCode 3, balíček `org.lemmings2026.demo`.
- Target SDK 36; aplikace nepožaduje žádná Android oprávnění.
- Testovací podpis Android Debug, schémata v2/v3. Není určený pro vydání
  do Google Play; soukromý klíč je mimo repozitář i předávané artefakty.

## Ovládání a profil

Klepnutí na dovednost a potom na postavu přidělí příkaz. Posun jedním prstem
posouvá kameru, dva prsty ji posouvají i přibližují. Dovednost se přidělí
až při uvolnění prstu bez významného pohybu. Emulovaná myš nevytvoří druhý
příkaz. Dotyky začaté na HUDu se nepřenesou do herní plochy.

Dotykový výběr má širší dosah a vybírá nejbližší postavu, které lze aktuální
dovednost přidělit. Zpět přepíná pauzu; přechod na pozadí vždy hru pozastaví
a vymaže rozpracovaná gesta. Obnovení pohybu zůstává na hráči.

Android používá Compatibility / OpenGL ES 3, návrhový viewport 1280 × 720,
75% rozlišení 3D, menší stíny a vypnuté SSAO/MSAA. Světla jsou vyvážená
pro tento renderer. Herní logika se podle platformy nevětví.

## Ověření a omezení

- Prošlo 131 automatických kontrol v šesti sadách, parser a linter
  46 GDScriptů, import v čisté kopii a výchozí spuštění.
- Nových 10 kontrol ověřuje dotyk, posun, pinch, zrušení, HUD, jediný
  příkaz při emulaci myši a pauzu při odchodu na pozadí.
- Skutečné vykreslování v Compatibility rendereru na Linuxu se softwarovým
  ovladačem llvmpipe a simulovanými dotykovými událostmi dokončilo level:
  **20 zachráněných, 0 ztracených**, včetně výběru dovedností přes HUD.
  Stejný průchod prošel i nad herními soubory vytaženými přímo z finálního APK.
- Ověřený podpis APK, CRC souborů, manifest, obě ARM architektury,
  zarovnání APK a 16KiB zarovnání segmentů 64bitových knihoven.

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
