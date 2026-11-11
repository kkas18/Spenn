# Spenn

Et sprettert-arkadespill for Android i stående format. Fiender henger i snorer fra en
bjelke og senker seg mot en linje. Du strekker strikken og skyter dem ned før de når
linjen. Spillet er laget i Godot 4.3 (GDScript, GL Compatibility) og tegner alt selv, uten
ferdige bilder av figurene.

Engelsk navn i appen er «Taut».

## Spille på telefonen

| Versjon | Last ned |
|---|---|
| Siste bygg | [spenn.apk](https://github.com/kkas18/Spenn/releases/download/spenn-latest/spenn.apk) |
| Originalen før oppgraderingen (v7.57) | [spenn-v7.57-original.apk](https://github.com/kkas18/Spenn/releases/download/spenn-v7.57-original/spenn-v7.57-original.apk) |

Åpne fila på telefonen og godta installasjon fra nettleseren. Begge versjonene er signert
med samme nøkkel og har samme versjonskode, så den ene kan installeres over den andre
uten at rekorder og fremgang går tapt. Hvilken som er installert, står under
Innstillinger → Apper → Spenn på telefonen: 8.0.0 er den oppgraderte, 2.0.0 er originalen.

**Slik spiller du:** legg fingeren på lomma i spretterten, dra nedover og slipp. Jo
lenger du drar, jo hardere skudd. Dobbelttrykk på feltet (eller Tilbake-knappen) setter
spillet på pause.

## Kjøre fra kildekoden

1. Installer [Godot 4.3 stable](https://godotengine.org/download/archive/4.3-stable/).
2. Åpne mappa i Godot, eller start direkte:

   ```bash
   godot --path .
   ```

På PC virker musa som finger (klikk og dra). Vinduet åpnes i telefonformat.

## Tester

```bash
tools/tests/run.sh [sti/til/godot]        # hele pakken, ca. 6 minutter
ONLY="flow save" tools/tests/run.sh       # bare noen av testene
tools/tests/balance.sh [sti/til/godot]    # balanse: botspillere på tre nivåer (tar lengre tid)
```

| Test | Hva den passer på |
|---|---|
| `layout` | Skjermoppsettet på ni telefonformer: spretterten får plass, og full kraft er innen rekkevidde |
| `flow` | En hel økt: meny, skudd, pause, nedtelling, omstart, tap, resultat, tilbake til menyen |
| `save` | Lagret fremgang tåler avbrutt skriving, skadet fil og feil verdier |
| `timing` | Sanntid og spilltid: treff-stopp, sakte film, overload og flyt varer det de skal |
| `physics` | Lik bane ved 30–144 Hz, ingen tunnelering, snorkutt, ingenting som setter seg fast eller rister |
| `soak` | Travelt sluttspill under ild: ingen lekkasjer |
| `bot` | Hele runder spilt av en bot, én per frø |

Testene kjører uten skjerm, på en egen lagringsfil og med fast frø. De spiller på en skjerm
som en vanlig høy telefon (720 × 1560 i spillets piksler).

To verktøy står utenfor testpakken: `tools/tests/perf.gd` måler tidsbruk per bilde (og
tegnekall når det kjøres med skjerm eller `xvfb-run`), og `tools/tests/shots.gd` tar
skjermbilder av alle skjermer i spillet.

## Bygg

`.github/workflows/android.yml` kjører testene og bygger en signert APK ved hver push.
Siste bygg legges på utgivelsen `spenn-latest`. Signeringsnøkkelen ligger som hemmeligheter
i repoet (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`).

## Mapper

| Sti | Innhold |
|---|---|
| `scripts/` | All spillkode (se tabellen under) |
| `scenes/main.tscn` | Den ene scenen. Alt annet bygges i kode ved oppstart |
| `shaders/` | Lys, vignett, sjokkbølge og uskarphet |
| `assets/` | Lydeffekter, menymusikk og partikkelteksturer |
| `tools/tests/` | Testene |
| `tools/import_assets.py` | Lager lydfilene fra kildepakkene |

| Fil i `scripts/` | Ansvar |
|---|---|
| `game.gd` | Spilltilstand, runder, poeng, inndata og fysikkens faste steg |
| `contacts.gd` | Kontaktfysikk: kropper, snorer og kuler mot hverandre |
| `target_body.gd`, `target_look.gd`, `target.gd` | Fienden: oppførsel og fysikk, kropp og tau, ansikt |
| `mind.gd`, `smarts.gd`, `habits.gd` | Hvordan fiendene svarer på siktet ditt og hva de lærer om deg |
| `director.gd` | Tempo, bølger og vanskelighetsgrad |
| `slingshot.gd`, `ball.gd` | Spretterten og kula (med én felles regel for kulebanen) |
| `fx.gd`, `backdrop.gd`, `ink.gd` | Effekter, bakgrunn og samlet tegning av små former |
| `hud.gd`, `menu_stage.gd`, `title.gd`, `intro.gd` | Grensesnitt, meny og oppstart |
| `prefs.gd`, `meta.gd`, `feats.gd`, `perks.gd` | Lagring, oppdrag, prestasjoner og oppgraderinger |
| `sfx.gd`, `music.gd` | Lyd |
| `layout.gd`, `device.gd`, `motion.gd`, `pal.gd`, `tokens.gd`, `loc.gd` | Skjermoppsett, enhetstilpasning, sanntidsklokke, farger og tekster |

## Dokumenter

- [OPPGRADERING.md](OPPGRADERING.md): planen for den helhetlige oppgraderingen (v8), funn,
  målinger før og etter, og det som gjenstår.
- [CHANGELOG.md](CHANGELOG.md): kort endringslogg.
- [PLAN.md](PLAN.md): designhistorikken fra første versjon.
- [CREDITS.md](CREDITS.md): lyd, musikk og skrifter.
