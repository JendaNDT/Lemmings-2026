# Technický záznam verze 0.4.0

> **Historický záznam.** 2.5D zobrazení, jeho scény a podklady byly
> 4. 10. 2026 na přání autora vyřazeny; popsané soubory už v projektu nejsou.

Verze 0.4.0 je dosavadní hratelné 2.5D sestavení. Autor jeho výtvarné
provedení odmítl. Staré grafické návrhy a jejich náhledy byly odstraněny;
jediná současná výtvarná předloha je [origami mockup](MOCKUP_ORIGAMI.md).
Tento soubor zachovává technická fakta a původ používaných souborů.

## Používané podklady

`assets/art_v2/` obsahuje odvozený model se stejnou kostrou a časováním,
ikony dovedností a font Nunito. Původ, podmínky a strukturální kontrola
jsou uvnitř sady; integritu ověřuje `assets/art_v2.lock.json`.
Původní sada `assets/clay/` a její manifest zůstávají beze změny.
Terén, dekorace, animace a rozhraní jsou součástí dosavadního rendereru.

## Dříve provedené technické kontroly

Při dokončení 0.4.0 prošlo 56 GDScriptů, osm sad a 186 ověření. První
mise skončila 20/20, další zkušební mise 6/6, 6/6 a 3/4. Proběhlo
vykreslování na Linuxu ve Forward+ i Compatibility; dotykové průchody
proběhly v Compatibility. [Strojový záznam](art-0.4.0-verification.json)
uchovává hodnoty a kontrolní součet vydaného APK. Staré snímky jsou odstraněné.

Linuxový cloud s llvmpipe neověřuje výkon nebo nativní spuštění na Macu
ani Androidu. Technické kontroly nepotvrzují výtvarnou kvalitu. Aktuální
instalační balíček a omezení jsou v [Android demo](ANDROID_DEMO.md).
