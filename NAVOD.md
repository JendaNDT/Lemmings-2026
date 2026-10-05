# Paperlings – návod pro hráče

Papírová logická hra: provedeš zástup origami postaviček nástrahami
k východu. 24 misí ve čtyřech kapitolách (louka, skalní les, voda a oheň,
bouřková hora), v každé jedna patrová mise v podzemí, a Hřiště se všemi
dovednostmi. Hra je zdarma, bez reklam a bez připojení k internetu.

## Stažení a instalace

Všechny verze jsou na stránce
[Vydání (Releases)](https://github.com/JendaNDT/Lemmings-2026/releases).
U každého souboru je kontrolní součet SHA-256 (`SHA256SUMS.txt`).

**Windows 10/11 (64 bit):** stáhni `Paperlings-<verze>-Windows.zip`, rozbal
ho a spusť `Paperlings.exe`. Hra není podepsaná certifikátem, takže
Windows napoprvé ukáže „Systém Windows ochránil váš počítač“ – klikni
na **Další informace → Přesto spustit**.

**macOS (Apple Silicon i Intel):** stáhni
`Paperlings-<verze>-macOS.zip`, rozbal ho a přetáhni `Paperlings.app`
do Aplikací. Hra není notarizovaná Applem: napoprvé na ni klikni pravým
tlačítkem → **Otevřít** (nebo Nastavení systému → Soukromí a zabezpečení
→ **Přesto otevřít**).

**Android 7.0 a novější:** stáhni `Paperlings-<verze>-Android.apk` přímo
do telefonu a otevři ho. Android se zeptá, jestli smí prohlížeč nebo
správce souborů instalovat aplikace – povol to. Hra se hraje na šířku
a nepotřebuje žádná oprávnění.

## Aktualizace a uložený postup

Na počítači při aktualizaci přepiš složku hry. Postup, hvězdy, nastavení
i rozehraná mise zůstanou. **Android 1.0.0-rc2 je nová samostatná instalace:**
začne od první mise bez převzetí starého postupu. Starší testovací aplikaci
nepřepíše. Další aktualizace této nové aplikace už instaluj přes ni.
Data se ukládají zvlášť od hry:

- Windows: `%APPDATA%\Paperlings`
- macOS: `~/Library/Application Support/Paperlings`
- Linux: `~/.local/share/Paperlings`
- Android: úložiště aplikace (smaže se jen odinstalací)

Postup z testovacích verzí s pracovním názvem *Lemmings 2026* se na
počítači při prvním spuštění přenese sám. Android rc2 má vlastní úložiště
a vypnuté zálohování do systému. Svůj nový postup si ukládá běžně při hraní.

## Jak hrát

Z líhně vycházejí postavičky a slepě kráčí vpřed. Klepni (klikni)
na dovednost v liště a pak na postavičku. Do východu jich musí dojít
aspoň tolik, kolik mise žádá; za víc zachráněných dostaneš až tři hvězdy.
Celý návod s ovládáním a popisem všech osmi dovedností je ve hře
v **O hře → Jak hrát**, nápověda k misi v pauze (tlačítko **Menu**).

- **Počítač:** levé tlačítko myši přiděluje, pravé nebo prostřední táhne
  pohledem, kolečko přibližuje. Klávesy 1–8 dovednosti, mezerník pauza,
  F rychlost, Backspace −5 s, Esc menu.
- **Telefon:** jedním prstem posouváš krajinu, dvěma přibližuješ. Když prst
  podržíš na postavičce, štítek ukáže, koho klepnutí zasáhne. Tlačítko Zpět
  otevře menu.

## Hudba (od verze 1.0.0-rc2)

Každá mise má jednu ze čtyř skladeb; po čtvrté misi se pořadí opakuje.
Skladba hraje dokola, i během pauzy. Restart mise, zrychlení, zpomalení
a přetočení hry hudbu nerestartují ani nemění její tempo.
V **Nastavení → Zvuk → Hudba** ji zeslabíš nebo vypneš nezávisle na efektech.
Při návratu do hlavního menu dozní a při uspání aplikace se pozastaví.
Dosud vydané balíčky 1.0.0-rc1 tuto novinku ještě neobsahují.

## Známá omezení

- Sestavení pro Windows a macOS nejsou podepsaná, proto varování při
  prvním spuštění (viz výše).
- Android verze se instaluje mimo Google Play. Rc2 používá nový podpis
  a vlastní instalaci; další aktualizace musí zachovat tento nový podpis.
- Hra je ověřená automatickými testy a průchody v cloudu; na skutečných
  zařízeních ji zatím zkoušelo jen pár lidí. Na velmi slabých telefonech
  pomůže Nastavení → Zobrazení → Kvalita efektů: Nízká.
- Texty jsou jen česky.

## Našel jsi chybu?

Ve hře otevři **O hře → Nahlásit chybu**. Otevře se formulář na GitHubu
s předvyplněnými údaji o verzi a zařízení (bez osobních údajů); stačí
popsat, co se stalo. Údaje jsou zároveň ve schránce, takže je můžeš
autorovi poslat i jinak. Formulář je i na stránce
[Issues](https://github.com/JendaNDT/Lemmings-2026/issues/new?template=chyba.yml).

## Licence

Paperlings © 2026 Jenda. Hru můžeš zdarma stahovat, hrát a sdílet odkaz
na ni; ostatní práva vyhrazena. Godot Engine (MIT) a písmo Nunito
(SIL OFL 1.1) mají vlastní licence – viz ve hře **O hře → Licence**
a soubor `THIRD_PARTY_NOTICES.txt` u vydání. Inspirováno hrou Lemmings
(1991); Paperlings s ní ani s jejími vlastníky není nijak spojená.
