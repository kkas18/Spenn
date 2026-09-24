# Spenn v2 – Premium-pass · PLAN

Spenn er et sprettert-arkadespill for Android i stående format (Godot 4.3, GDScript,
GL Compatibility). Målene henger i elastiske snorer fra en bjelke øverst og senker seg
sakte. Du strekker strikken nederst og skyter en gullball opp mot dem.

> **Utgangspunkt:** Det fantes ikke et eksisterende Spenn-prosjekt i noen tilgjengelig
> repo (`kkas18/Elektro` er en elektro-kalkulator). Etter avklaring bygges spillet
> **fra bunnen** i et nytt repo, `kkas18/Spenn`. Fasene P1–P6 følges likevel som
> rekkefølge og commit-struktur. Spillmekanikk som spesifikasjonen forutsetter uten å
> beskrive (ammo-regler, poeng, tapsvilkår), er valgt og dokumentert under «Valg».

## Research

1. **Juice er lag på lag av små, korte effekter.** Skvis og strekk, partikler, spor og
   lyd gir mer enn én stor effekt. Skjermristing doseres etter hendelsen.
   [gamedeveloper.com](https://www.gamedeveloper.com/design/squeezing-more-juice-out-of-your-game-design-),
   [valdemird.com](https://valdemird.com/blog/game-feel-on-the-web/)
2. **Hit-stop på 3–5 frames** gir hjernen tid til å registrere treffet. I Godot 4 gjøres
   det med `Engine.time_scale` og en `SceneTreeTimer` som ignorerer time scale. Vi
   bruker 40 ms.
   [codingquests.io](https://codingquests.io/blog/godot-4-game-juice-platformer)
3. **Tau med Verlet-integrasjon** tegnes med Line2D (Ropesim, verlet-rope-4). Med 12 tau
   à 10 punkter er ren GDScript-Verlet med 4 iterasjoner billig nok, så vi trenger ingen
   GDExtension.
   [GDNative-Ropesim](https://github.com/mphe/GDNative-Ropesim),
   [verlet-rope-4](https://github.com/TheLoraxPl/verlet-rope-4)
4. **Banding i gradienter** fjernes ved å legge på ±½ LSB støy (interleaved gradient
   noise) før 8-bits kvantisering.
   [godotshaders: vignette with reduced banding](https://godotshaders.com/shader/vignette-with-reduced-banding-artifacts/),
   [godot#17006](https://github.com/godotengine/godot/issues/17006)
5. **`get_display_safe_area()` skalerer ikke med stretch**, så vi regner selv om fra
   skjermpiksler til viewport-piksler.
   [godot#74835](https://github.com/godotengine/godot/issues/74835)
6. **Bunn-innfelt rapporteres ofte ikke** (bare notch øverst). Vi antar derfor minst
   24 dp gestområde nederst.
   [godot#105462](https://github.com/godotengine/godot/issues/105462),
   [LetterLogic#108](https://github.com/OpenGameStack-Games/LetterLogic/pull/108)
7. **Signert APK i CI:** keystore lagres som base64-secret, og Godot 4 leser
   `GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}`. Signaturen må være den samme
   mellom versjoner, ellers kan brukerne ikke oppdatere.
   [dulvui/godot-android-export](https://github.com/dulvui/godot-android-export),
   [patakuti/vfpv#66](https://github.com/patakuti/vfpv/pull/66)
8. **Fjær-demper for slippet** (egen utregning): med k = 900 og c = 12 blir
   ω ≈ 30 rad/s og ζ ≈ 0,2. Periode ≈ 0,21 s og amplitude e^(−6t), altså rundt 12 % igjen
   etter 350 ms. Det gir 2–3 synlige svingninger, som spesifisert.

## Skills

Ingen av skillene i økten gjelder Godot/GDScript, shaders, lyd eller Android-bygg. De
som finnes, er rettet mot web-artifacts, Office-filer og Claude API. Ingen skills er
derfor brukt.

## Arkitektur

Én hovedscene (`scenes/main.tscn`). Alle noder opprettes i `_ready()`, så ingen noder
lages per frame. Mål, baller, partikler, popups og lydspillere ligger i pooler.

| Fil | Ansvar |
|---|---|
| `scripts/pal.gd` | Palett, lysretning, skyggeoffset, tegnehjelpere |
| `scripts/layout.gd` | Layoutberegning fra viewport og safe area (dp → px) |
| `scripts/loc.gd` (autoload `Loc`) | Strenger NO/EN, språkvalg, lagring av rekord |
| `scripts/sfx.gd` (autoload `Sfx`) | Prosedyregenererte lyder (ingen lydfiler) og haptikk |
| `scripts/game.gd` | Spilltilstand, nivåer, kollisjon, poeng, input |
| `scripts/slingshot.gd` | Gaffel, strikk (Line2D + width_curve), lomme, fjær, kraftbue, ammo |
| `scripts/ball.gd` | Ball med spor og rotasjon (pool) |
| `scripts/target.gd` | Mål: Verlet-snor, fysikk, silhuett, øye, fare, fall (pool) |
| `scripts/rail.gd` | Toppbjelke med kroker som vipper |
| `scripts/fx.gd` | Partikkelpool, popup-pool, skjermristing, hit-stop |
| `scripts/backdrop.gd` | Bakgrunn, parallaksesnorer, faresone, støv |
| `scripts/hud.gd` | Toppfelt, pause, game over |
| `shaders/vignette.gdshader` | Vignett med dithering |
| `.github/workflows/android.yml` | Signert APK-bygg |

## Filer per fase

- **P0 Skjelett:** `project.godot`, `export_presets.cfg`, CI-workflow, `Loc`, `Pal`.
- **P1 Layout:** `layout.gd`, `hud.gd`, `game.gd` (kjerneløkke), plassering av
  sprettert og ammo.
- **P2 Sprettert:** `slingshot.gd` (strikk, surring, fjær, gaffel, kraftbue).
- **P4 Respons:** `fx.gd`, `ball.gd` (spor og rotasjon), `target.gd` (snap og fall),
  `hud.gd` (poengpuls), `sfx.gd`.
- **P3 Mål:** `target.gd` (silhuetter, palett, øyne, fare).
- **P5 Miljø:** `rail.gd`, `backdrop.gd`, `vignette.gdshader`.
- **P6 Opprydding:** strenger, berøringsflater, kantklipping, skyggeretning.

## Risikoer

- **Fysikkstabilitet:** fjær- og Verlet-integrasjon kjøres i faste delsteg (1/120 s) med
  begrenset dt, slik at hakk ikke får strikken til å eksplodere.
- **Ytelse:** `_draw()` tegnes på nytt hver frame for 12 mål (~40 primitiver hver).
  Det er billig i GL Compatibility. Partikler er CPUParticles2D med maks 10 per utslipp
  og en pool på 8.
- **Safe area:** varierer mellom enheter. Vi bruker fallback-verdier i dp.
- **CI-signering:** uten keystore-secrets lager workflowen en midlertidig keystore.
  APK-en blir signert, men den kan ikke oppdatere en installasjon som er signert med
  en annen nøkkel.
- **Kan ikke testes lokalt:** haptikk og faktisk 60 fps på enhet kan bare verifiseres
  på telefon.

## Valg

- Ett øye per mål (kyklop). Det gir en ren silhuett og følger spesifikasjonens entall.
- **Ammo:** magasin på 5. Én ball lades hvert 1,1 s. Treffer ett skudd to eller flere
  mål, blir neste ball en gjennomslagsball.
- **Tap:** et mål når farelinjen.
- **Måltyper:** ring (1 treff), dobbel ring (2 treff), sekskant (splitter seg i to
  dråper), stav (1 treff, bredere og svinger mer), dråpe (liten, synker raskt).
- Svake siktepunkter (4 prikker) langs skuddretningen. Uten dem er det nesten umulig
  å sikte på telefon.

## Verifisering

- `godot --headless --import` og `--quit-after` uten feil etter hver fase.
- Skjermbilder via Xvfb og llvmpipe (sikting, slipp, treff, alle typer, gråtoner, pause/game over på begge språk, 20:9 og 16:9).
- Nodeantall målt før og etter 250 frames med partikler og popups: differanse 0.

## Status

| Fase | Status | Merknad |
|---|---|---|
| P0 | Ferdig | Skjelett, eksportoppsett, CI-workflow, Loc/Sfx/Pal |
| P1 | Ferdig | Toppfelt 11 %, målfelt 60 %, sprettert løftet så kraftbuen får 24 dp klaring over gestområdet (safe area regnes om til viewport-piksler), ammo-stabel til venstre for skaftet der lommen ikke kan krysse den. Mål i forskjøvne rader for å fylle feltet. |
| P2 | Ferdig | Strikk som Line2D med width_curve (6→3 px, √-lov) og mørk underkant. Strikken vikles rundt tuppen, og enden er gjemt under surringen (4 linjer). Fjær k 900 / c 12: ballen slippes når lommen passerer hvilepunktet. Lommen vipper med farten. Gaffel i to toner med skygge (4,4) 35 % og rundet håndtak. Kraftbuen fader inn på 120 ms og fylles symmetrisk rundt trekkretningen, med varmere gull de siste 15 % og haptisk puls ved maks. Valg: ladd ball vises først når lommen har roet seg. |
| P4 | Ferdig | Hit-stop 40 ms (time_scale + timer som ignorerer den). Skvis og strekk 1,25 × 0,8 langs treffretningen i 60 ms med elastisk retur. 6–10 CPUParticles2D-gnister i målets farge med tyngdekraft og 600 ms fade, rettet innover nær kantene (pool på 8). Ballspor på 6 segmenter uten glød, og rotasjon etter fart. Når snoren ryker, får den pisk-rekyl opp mot bjelken, og målet faller med spinn og perspektivvipp. Poengtallet pulserer (1,08) og teller opp. Popups i store bokstaver med samme sporing, klemt 24 px fra kantene (pool på 8, bare data). Skjermristing maks 3 px / 150 ms, bare ved flere treff i samme skudd eller tap. Hvert treff gir lyd og haptikk. |
| P3 | Ferdig, med avvik | Silhuetter: ring, dobbel ring (ytre ring sprekker etter første treff), sekskant med splittsøm, avrundet stav og dråpe. Alle har tofarget kant og skygge fra samme lyskilde. Ett øye per mål: pupillen følger nærmeste ball (lerp 0,15/frame, begrenset til øyeringen), målet nærmest siktelinjen myser, øyet lukkes til «–» i 1,2 s etter treff, og målene blunker tilfeldig hvert 3.–7. sekund. Innenfor 15 % av faresonen glir fargen mot korall med puls på 0,8 Hz, og snoren blir lysere og tykkere. **Avvik:** spesifikasjonens egne toner bryter kravet om 40° (blå 210 / teal 180 / grønn 150 ligger bare 30° fra hverandre). Tonene er derfor flyttet ≤15°: grønn 145, teal 185, blå 225, lilla 265, korall 15. Lysheten er trappet 0,36 / 0,47 / 0,58 / 0,71 / 0,85 for gråtoner (verifisert med gråtone-skjermbilde). |
| P5 | Ferdig | Bjelke på 6 px i to toner med skygge (4,4) og en krok per oppheng. Kroken vipper med snorens vinkel, og snoren går ut fra krokens øye. Parallakselag med 9 fjerne snorer/mål i 40 % skala og 8 % opasitet, som svaier og synker med 40 % av forgrunnens fart. Faresonen er en nesten usynlig stiplet linje som går mot korall med tettere stipling og puls på 0,8 Hz når et mål nærmer seg. Vignett-shader med triangulær IGN-dithering, ingen banding. 10 støvpartikler med 3 % opasitet driver oppover. |
| P6 | Ferdig | Nivåetiketten er «NIVÅ n» / «LEVEL n» (ingen «STRIKK» finnes). Alle strenger på begge språk er gjennomgått, og ubrukte nøkler er fjernet. Skygger går ned/høyre over alt (mål, gaffel, ball, bjelke, kroker, ammo, pauseikon, popups, knapper). Pauseflate og menyknapper er minst 48 dp, og popups og gnister klemmes eller rettes innover fra kantene. Tilbake-knappen pauser, og avslutter appen på game over-skjermen. Spillet pauses når appen mister fokus. Ytelse: gaffelen tegnes bare ved layoutendring, og faresonen er ett `draw_multiline`-kall. Målt headless: simulering 0,3 ms/frame med 12 mål, og nodeantallet er uendret under spill (0 nye noder). **Test på telefon:** trykk tre ganger på rekorden for FPS-visning. |
