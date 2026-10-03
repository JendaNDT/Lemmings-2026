# Podklady současného technického prototypu

Tento soubor eviduje závislosti dosud běžící hry, nikoli výtvarný návrh.
Aktuální výtvarný směr je [2D origami](VYTVARNY_SMER.md). Starší náhledy,
galerijní prezentace a samostatná studie byly na přání autora odstraněny.

Dosavadní hra používá `assets/clay/` (50 kontrolovaných souborů): terénní
textury, modely, animace, nástroje, objekty a ikony. Původ a podmínky jsou
v `assets/clay/provenance.json` a `assets/clay/LICENSE.txt`; kontrolní
součty v `assets/clay.lock.json`. Původní názvy referencí v záznamu původu
jsou historická metadata, nikoli odkazy na aktuálně vystavený návrh.

Odvozený model postavy, ikony a font Nunito jsou v `assets/art_v2/`,
s vlastními podmínkami a manifestem `assets/art_v2.lock.json` (13 souborů).
Licence fontu OFL musí zůstat součástí distribuce.

Obě sady ověřuje `python scripts/check_assets.py`. Dosavadní technické
zapojení popisuje [ověření etapy 3](ETAPA_3_OVERENI.md).
Dokud nový renderer nepřevezme jejich funkci, tyto herní soubory nemažeme.
