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

---

# v2.1 – Fysikk, grafikk og spillbarhet

Tilbakemelding etter test på telefon: spillet ser bra ut og skal løftes videre. Grafikk,
dynamikk, fysikk og spillbarhet skal bli mer realistiske, og tredjepartsressurser skal
brukes der det er mulig.

## Funn fra skjermbildene
- **Nedre halvdel av målfeltet står tom.** Målene henger bare i øvre ~55 %. Mellom
  laveste mål og faresonen, og mellom faresonen og spretterten, er det store tomme
  felt. Dette bryter akseptkriteriet om maks 25 % tom flate.
- **Parallakselaget leses som «spøkelsesmål».** Særlig de fjerne sekskantene og ringene
  forstyrrer.
- **Målene er stive.** De roterer bare med snoren, reagerer ikke på hverandre og står
  helt stille mellom treff.
- **Bakgrunnen er flat.** Den gir ingen følelse av rom eller lys fra øvre venstre.
- **Sikteprikkene er korte og rette.** De viser ikke tyngdekraft eller sprett mot vegg.

## Tredjepart
- **Inter** (rsms/inter v4.1, SIL OFL 1.1) er lagt i `fonts/` med lisensfil. Den gir
  samme typografi på alle enheter og tabulære tall uten hopp i poengsummen.
- **Godots innebygde lydeffekter:** en kort romklang på en egen SFX-buss gir de genererte
  lydene rom uten nye filer.
- Kenney, OpenGameArt og Freesound er blokkert av nettverket i byggmiljøet (403), så
  lydene syntetiseres fortsatt i kode. De er forbedret med lag og romklang.
- Ingen GDExtension-addons (for eksempel Ropesim). Native biblioteker for Android øker
  risikoen i CI, og Verlet-tauet i GDScript koster bare ~0,3 ms.

## Q1 Fysikk og dynamikk (`target.gd`, `game.gd`)
- **Rotasjon med treghet:** treff utenfor senter gir dreiemoment, og målet slingrer
  rundt opphenget med dempet vinkelfjær mot snorvinkelen.
- **Mål–mål-kollisjon:** et truffet mål kan dytte naboen. Det gir myk, masseavhengig
  impuls, men ingen skade.
- **Ball mot snor:** ballen plukker snoren den passerer (impuls på nærmeste tau-punkter)
  med en svak «twang».
- **Luftdrag:** en rolig, støybasert bris gjør at målene svaier litt i hvile.
- **Nesten-bom:** når ballen passerer nær et mål, spretter øyet opp og målet rykker til.

## Q2 Grafikk og effekter (`backdrop.gd`, nye `shaders/backdrop.gdshader`, `target.gd`, `ball.gd`, `fx.gd`, `hud.gd`)
- **Bakgrunn:** shader med mykt lysfall fra øvre venstre og fint, statisk korn med
  dithering. Matt, uten glød.
- **Myke skygger:** en bred, svak kontaktskygge under den skarpe skyggen. Mål og ball
  løftes fra veggen, i samme retning (ned/høyre).
- **Ball:** strekkes etter fart langs bevegelsen og skvises kort ved sprett.
- **Snorer i to toner:** lys kant oppe/venstre, og en svak lysrefleks som følger strekket.
- **Treff:** en tynn trykkring (180 ms, lokal). Drepte mål slipper 3–5 skår som faller
  med spinn, i målets farge og fra en pool.
- **Parallakselaget:** bare rene snorer med små perler (fortsatt 8 % opasitet). Ingen
  silhuetter som kan forveksles med mål.
- **Inter** brukes i HUD, popups og menyer.

## Q3 Spillbarhet (`game.gd`, `slingshot.gd`)
- **Siktebane:** prikkbanen viser tyngdekraft og første sprett mot vegg. Den er kort
  (ca. 0,4 s flytid), så det fortsatt krever presisjon.
- **Fyll feltet:** målene spres over 3–4 rader ned til ~70 % av feltet, med flere mål per
  nivå (5 + n, maks 14). Tom flate holdes under ~25 %.
- **Rolige mellomspill:** ny bølge henges inn med stagger mens forrige treff fortsatt
  faller ut.

## Risikoer
- **Mål–mål-kollisjon (O(n²), n ≤ 14):** billig, men impulsene begrenses så kjeder ikke
  eksploderer.
- **Kornshader over hele skjermen:** én ekstra fullskjerm-pass i GL Compatibility. Den er
  billig (ingen teksturoppslag), men må verifiseres på mellomklassetelefon.
- **Prosjektstørrelse:** fonter gir +0,8 MB i APK-en.

## Status v2.1

| Fase | Status | Merknad |
|---|---|---|
| Q1 | Ferdig | Masse per type og vinkeltreghet med dempet fjær (k 55, c 2,6). Friksjon: sklifarten langs overflaten gir dreiemoment, så streifskudd spinner målet. Mål–mål-kontakt med invers-masse-separasjon og begrenset impuls, pluss en svak «knock»-lyd og haptikk. Ballen plukker snorer (Gauss-fordelt kick på tau-punktene) med «twang». Lagdelt bris på noen px/s². Nesten-bom (< 34 px) gir vidt øye, krympet pupill og et lite rykk. Snoren blir stivere nær faresonen. Stabilitetstest på nivå 8 med 15 skudd: ingen NaN, farten klinger av. |
| Q2 | Ferdig | Bakgrunnsshader med lysfall fra øvre venstre, statisk korn og triangulær dithering. Myk kontaktskygge (radial tekstur, bygget én gang) under skarp skygge på mål og ball. Ballen strekkes etter fart og skvises ved sprett (R·S·R⁻¹, så lyset står stille). Snorer i to toner med lys kant. Trykkring på 180 ms og 4–5 skår per drept mål (poolet data, 32 skår). Popups stables i stedet for å overlappe. Parallaksen er bare snorer med perler. Inter-fonter i hele UI-et. Romklang på egen SFX-buss. |
| Q3 | Ferdig | Siktebanen simulerer samme tyngdekraft og veggsprett som ballen: 8 prikker over ca. 0,4 s, fading, og den stopper ved bjelken. Flere mål per nivå (5 + n, maks 14) i 2–4 forskjøvne rader. Radene dekker 12–62 % av feltet (12–54 % med to rader), så den nedre halvdelen er i spill fra start. Poolen er økt til 20 for splittdråper. |

---

# v3 – Motor, fiender med vilje og premium presentasjon

Tilbakemelding: for lett og for forutsigbart, med for enkle effekter. Spillet skal være
interaktivt, utfordrende og premium, og Claude Design skulle brukes.

## Design (Claude Design)
Designlerret med tittel, spillskjerm (nivå 7), resultat og fiendeoversikt ble laget
først: https://claude.ai/artifact/1uTucQ8W5j6Vr5SZ4Hxm3G. Typografien i designet
(Fraunces display over Manrope) er brukt i spillet, begge under SIL OFL fra
google/fonts, med lisensfiler i `fonts/`. Inter er fjernet.

## Motor
- **Tilstandsmaskin:** TITTEL → SPILL → MELLOMSPILL → RESULTAT (`game.gd`).
- **Direktør (`director.gd`):** treffprosenten (EMA) og nivået gir aggresjon 0..1. Den
  styrer reaksjonstid, cooldown, synkefart og fiendemiks. Spiller du godt, blir
  fiendene skarpere; går det dårlig, roer de seg.
- **Bølger:** 1–3 per nivå. Neste bølge henges inn når ≤2 mål gjenstår eller etter 22 s.
  Ankrene legges i ledige spor, så snorene fletter seg.
- **Liv:** 3 knuter. Når et mål når linjen, ryker en knute: bjelken gir etter og svinger,
  resten av feltet rykkes opp som pusterom, og rister 3 px.
- **Serie og multiplikator:** ×1–×4 (hver 3. treffende serie), og bom nullstiller.
  Hvert 5. treff i serien gir en tredelt ball (vifte med 3 baller). Et dobbeltreff gir
  gjennomslagsball.
- **Snorkutt:** en ball over 1500 px/s (skalert) kapper snoren den krysser, med dobbel
  poengsum. Det gjelder også skjoldmål og tunge mål (ikke bossen).

## Fiender (hver har et varsel før den handler)
- **Vakt (ring):** unnviker et sikte som holdes, reaksjon 0,75→0,3 s.
- **Tungvekt:** blir rasende etter første treff (sinte bryn), stuper 60 px og synker ×1,6.
- **Splitter:** deler seg i to dykkere.
- **Pendel:** pumper sin egen svingning og er aldri stille.
- **Dykker:** skjelver og myser 0,45 s, så stuper den 50 px.
- **Vokter (ny):** et metallskjold dreier mot spretteren. Treff forfra preller av (klang),
  så du må bruke veggen eller kappe snoren.
- **Spinneren (boss, hvert 5. nivå):** 8 liv, to skjold i bane med en glipe mellom,
  slipper dykkere, stuper av og til og blir rasende ved 4 liv.

## Presentasjon
- Tittel: S-P-E-N-N henger i snorer med Verlet-fjær og kan skytes på. Første skudd
  starter spillet, og snorene ryker én etter én.
- Nivåkort med Fraunces og undertekst. Boss-nivå har eget kort og lyd.
- Sakte film og kamerapuls på siste treff i et nivå og når bossen dør. Hit-stop og sakte
  film deler én tidsstyring.
- Blink ved treff (matt, lysere), sinte bryn, skjelving som varsel og helsepunkter på
  bossen.
- Resultatskjerm: poengsum, NY REKORD, nivå, treffprosent, beste serie, snorkutt,
  SPILL IGJEN i gull og MENY.
- Nye lyder: klang, sus, kutt, brudd, boss og serie. Lyd av/på lagres.

## Status v3

| Del | Status | Merknad |
|---|---|---|
| Design | Ferdig | 4 tavler på lerretet |
| Motor | Ferdig | Headless: 0,28 ms/frame simulering, 0 nye noder under spill |
| Fiender | Ferdig | 7 typer inkludert boss, alle med varsel |
| Presentasjon | Ferdig | Tittel, kort, resultat, tidsstyring, kamera |

**Avvik:** rekorden er flyttet fra toppfeltet til tittel, pause og resultat. Til høyre i
toppfeltet står nå de tre knutene (liv), som vist i designet.

---

# v3.1 – Subtil lyd, brudd-effekter, gjemming og nye fiender

Tilbakemelding: mye bedre, men lydene er overveldende. Ønsker elegante brudd-effekter og
mer av at fiender gjemmer seg, pluss bedre UI, brukervennlighet og mer krevende fiender.

- **Lyd:** ny miks.
  - Lyder: 5 ms myk start, dobbelt lavpasset støy, tanh-metning, lavere partialer og en
    egen styrke per lyd (−8 til −27 dB).
  - SFX-buss: lavpass 4,2 kHz, kompressor (−20 dB, 4:1) og et lite, mørkt rom.
  - Samme lyd kan ikke spilles oftere enn hvert 60. ms, og det er maks 6 stemmer.
  - Volumnivåer: av, lav, middels (standard) og høy. Vibrasjon er dempet til 80 %.
- **Brudd:** drepte mål brytes opp etter egen form.
  - Ring, Vokter og Snelle: buer (6–8).
  - Sekskant og boss: kanter.
  - Stav: to kapselhalvdeler.
  - Dråpe og Skygge: dråper.
  - I tillegg en tynn stråle-vifte på 0,26 s. Bossen sprekker i tre trinn.
  - Alt er poolet data (64 fragmenter), uten glød.
- **Gjemming:** Vakta søker dekning. Hvis et lavere mål står mellom spretteren og Vakta,
  glir den inn bak det. Uten dekning unnviker den som før.
- **Nye fiender:**
  - **Snelle** (nivå 3+): eiker i ring. Vinsjer seg opp mot bjelken når du sikter eller
    en ball nærmer seg, og senker seg igjen når det er rolig.
  - **Skygge** (nivå 7+): månesigd. Toner ut, og da går skuddene rett gjennom den. Øyet
    og snoren synes alltid, så den kan kappes.
- **UI og brukervennlighet:**
  - Introkort «NY FIENDE» første gang en type dukker opp (lagres), med en markeringsring
    rundt målet.
  - Seriemåler (tre prikker mot neste multiplikator).
  - Innstillingspanel fra tittel og pause: lydnivå, vibrasjon, siktelinje og språk.
  - Pausen er ryddigere: fortsett, start på nytt, innstillinger og meny.

---

# v4 – Endeløs overlevelse

Tilbakemelding: nivåer bremser spillet. Det skal være som Tetris, Space Invaders, Pac-Man
og Flappy Bird: fiender kommer hele tiden, du fokuserer på å overleve, og det skal være
gøy og vanskelig samtidig.

## Spilldesign
- **Ingen nivåer.** Én endeløs runde der presset bare øker. Direktøren
  (`director.gd`) bruker intensitet = overlevd tid / 45 s. Kurven stiger bratt først og
  deretter saktere, men flater aldri helt ut. Det er det samme prinsippet som
  tyngdekraften i Tetris.
  - **Synkefart:** 7 + 9·I^0,85 px/s (maks 70).
  - **Innslipp:** hvert 2,3/(1 + 0,5·I) s (min 0,3 s).
  - **Tak:** 6 + 2·I mål samtidig (maks 22).
  - **Omlading:** 1,05 s, ned mot 0,72 s.
- **Rytme:** en hendelse omtrent hvert 38. sekund (tettere senere), fulgt av 4 s pusterom
  med halvert innslipp.
  - **Formasjon:** en rekke like mål i V, som i Space Invaders.
  - **Storm:** dykkere slippes ned fra bjelken.
  - **Boss:** Spinneren, hver 3. hendelse (~2 min).
- **Faser:** «FASE n» med måler i toppfeltet. Nye fiender låses opp etter intensitet: Vakt
  → Tungvekt 0,4 → Snelle 0,8 → Splitter 1,0 → Pendel 1,4 → Dykker 1,8 → Vokter 2,4 →
  Skygge 3,0.
- **Poeng:**
  - Serie-multiplikator ×1–×4.
  - **Kjede** (drap innen 1,2 s): +20 % per ledd fra 3, maks +120 %.
  - **Nære på** (drap med fare > 0,55): +50 × multiplikator, med 0,28 s sakte film.
  - **+1 knute** hver 3000 poeng (maks 3).
  - Poengene flyr som gullkorn til telleren.
- **Snorkutt** er et presisjonsskudd: ballsenteret (±5 px) må krysse den øverste
  tredjedelen av snoren på vei opp, med over 1400 px/s og før ballen har truffet bjelken.
  Første treff frynser snoren (synlige fibrer i 4 s), og et nytt treff mens den er frynset
  kapper den. Kuttet bremser ballen til 45 %.
- **Spenning:** et svakt hjerteslag (og lett vibrasjon) når et mål er nær linjen, og et
  korallbånd som stiger fra linjen.
- **Resultat:** tid overlevd, treffprosent, beste serie og snorkutt. Omstart med ett trykk.

## Balansering (robotspiller, `--fixed-fps 60`)
Roboten sikter på det laveste målet med litt forskyvning for bevegelsen og tilfeldig
unøyaktighet.

| Profil | Skudd | Treff | Overlevd |
|---|---|---|---|
| Overmenneskelig | 3/s, ±0,03 rad | ~88 % | 6–8 min (før innstramming) |
| Dyktig | 1,3/s, ±0,06 rad | ~90 % | 2,5–5 min |
| Slurvete | 0,86/s, ±0,14 rad | ~81 % | 3–5 min |

Før innstrammingen fikk roboten opptil 314 snorkutt per runde, og kurven flatet ut etter
~5 min. Begge deler er rettet.

**Gulv for antall mål:** en dyktig spiller tømte brettet og fikk et tomt, kjedelig felt.
Nå fylles feltet raskt opp igjen når det er færre enn 5 + 1,5·I mål (maks 14, 3 i pusterom), og nye mål kan henge seg inn ned til 30 % av feltet.
Presset følger dermed ferdighetene. Med gulvet ender alle robotprofilene etter 4–6 min
(før intensitetssteget ble strammet fra 50 til 45 s). Mennesker sikter mindre presist enn roboten, så en typisk
runde bør ende etter 1,5–3 min, mens de beste holder ut i 5.

**Endelig balanse (etter frynsing, gulv 5 + 1,5·I og steg på 45 s):** den dyktige roboten
overlever ~3,6 min med 96 % treff, den slurvete 2,6–3,5 min, og snorkutt skjer 0–7 ganger per
runde. Siden roboten sikter bedre enn et menneske, er forventet runde 1,5–2,5 min. Det
passer til «ett forsøk til».

---

# v5 – Presentasjonslaget som eget system

Kravspesifikasjon: premium intro, overganger, pause, game over, lyd og lokalisering.
Implementert i spesifikasjonens rekkefølge.

## Fase 1 – Fundament
- **State-system** (`game.gd`): BOOT → INTRO → MAIN_MENU → STARTING → PLAYING ↔
  PAUSED → RESUMING → PLAYING, eller DEATH → GAME_OVER → RESTARTING → STARTING. Alle
  bytter går gjennom `_set_state()`. Input og tidsstyring leser tilstanden.
- **Lokalisering** (`loc.gd`): alle tekster ligger under nøkler i punktnotasjon
  (`game.title`, `pause.resume`, `gameOver.bestScore`, `record.new` …). Ingen tekst er
  hardkodet i UI-et (grep-sjekket). `game.title` brukes i intro, meny og
  tittelbokstaver. `language_changed` oppdaterer alt live, og tittelbokstavene henges
  om hvis ordet endres.
- **Design tokens** (`tokens.gd`, `Tok`): farger (Background, Surface, Primary,
  TextPrimary/Secondary, Success, Danger), radius S/M/L, spacing XS–XL, typeskala og
  minste berøringsflate.
- **Motion-system** (`motion.gd`, autoload): FAST 120 / NORMAL 220 / SLOW 400 /
  CINEMATIC 700 ms, med easing Standard/Enter/Exit/Emphasized. Driveren går i sanntid,
  så UI beveger seg riktig under hit-stop, sakte film og pause, og den respekterer
  reduserte animasjoner.
- **Lagring** (`prefs.gd`): språk, musikk- og effektvolum, haptikk, reduserte
  animasjoner, siktelinje, rekord, «intro sett» og sette fiender. Eldre lagringsfil
  migreres.

## Fase 2 – Gameplay-UX
- Pauseknapp øverst til venstre: en diskret skive med 72 px (≥ 48 dp) berøringsflate,
  større enn ikonet.
- **Dobbelttrykk for pause:** to trykk innen 300 ms og 90 px på det åpne feltet over
  sikteområdet. Dette området brukes aldri til å sikte, så det kan ikke kollidere med
  skyting.
- **Pause:** spillet stopper umiddelbart (treet pauses). Så mørkner scrimen (0–150 ms),
  blur kommer (50–250 ms), og menyen skaleres 0,97 → 1 og toner inn (100–300 ms).
  Menyen har Fortsett (gull), Start på nytt, Innstillinger og Hovedmeny, pluss hint om
  dobbelttrykk.
- **Fortsett:** nedtelling 3 → 2 → 1 (420 ms per tall, med lyd og lett haptikk) over
  dempet felt, og scrimen løftes på siste tall.
- **Restart:** tilbakestiller spilltilstanden uten å laste scenen på nytt. Du er tilbake i
  spill på ~0,5 s.
- **HUD:** poeng vises først, så pause (+80 ms), så resten (+160 ms), hver med fade og
  6 px glid.
- **Inputlås:** knapper går gjennom `_act()`, som låser i 250 ms, og overganger setter
  `hud.locked`. Testet: 5 × «Prøv igjen» og 5 × «Hovedmeny» i samme frame gir én
  omstart.

## Fase 3 – Premium-overganger
- **Intro** (`intro.gd`):
  - 0–0,3 s: mørkt.
  - 0,3–1,2 s: emblemet toner inn og skaleres 96 → 100 % (ease-out). Ballens lysrefleks
    glir på plass med en lydaksent ved 0,85 s, og musikken starter der.
  - 1,2–1,8 s: tittelen kommer inn bokstav for bokstav (opasitet, sporing 26 → 10 px,
    blur → skarp, 8 px løft), fulgt av taglinen.
  - 2,6–3,15 s: den mørke bunnen løftes og avslører menyverdenen, der bokstavene henger
    seg inn fra bjelken.
  - Senere oppstarter bruker en kort versjon (~1,3 s), og «trykk for å hoppe over» vises
    når introen er sett.
- **Meny → spill:** første skudd kapper bokstavenes snorer, HUD-en kommer inn med
  stagger, og første rekke henger seg inn. Det er ingen svart skjerm.
- **Død:**
  - Treff: korallring, gnister, rist, dyp lyd og haptikk.
  - Tid: 1,0 → 0,35 (150 ms) → 0,15 (300 ms) → nesten stille (600 ms).
  - HUD-en fader fra 300 ms, scrimen mørkner fra 300 ms, og resultatet kommer ved 900 ms.
  - Musikken filtreres ned og fader ut.
- **Game over:**
  - Poengsummen teller 0 → score på 0,8 s med myke tikk.
  - Deretter vises beste resultat og en kompakt linje med tid og treff.
  - Ved **ny rekord**: merket popper med liten overshoot, en ring av gullkorn åpner seg,
    en egen klokkelyd spilles og haptikken gir to pulser.
  - Knappene kommer inn etter 0,55 s, og input låses opp ved 0,6 s.

## Fase 4 – Polish
- `UIButton`: ved berøring 1,0 → 0,97 (120 ms), og ved slipp tilbake med liten overshoot
  (220 ms). Klikklyd og svært lett haptikk.
- Haptisk vokabular (`Sfx.haptic_pattern`): light, soft (pause/fortsett), impact (død),
  record (to stigende pulser) og error (to raske, f.eks. når du sikter uten ball). Kan
  slås av.
- **Reduserte animasjoner:** ingen rist, kamerapuls eller blur, en tredjedel av strålene,
  kortere varigheter og alltid kort intro.

## Fase 5 – Lyd
- Nye UI-lyder: click, panel, pause, resume, countdown, reveal (logo), death, count,
  record, restart og deny.
- **Musikksystem** (`music.gd`): to stems syntetiseres i en bakgrunnstråd og looper i
  takt.
  - **Stems:** en pad (Dm–B♭–F–C, 92 BPM) og en puls (arpeggio, myk kick, svak tikk).
  - **Meny:** bare pad, litt mørk.
  - **Spill:** pad og puls. Pulsen stiger med intensiteten.
  - **Pause:** lavpass 700 Hz og lavere volum.
  - **Død:** lavpass 350 Hz og fade over ~1,2 s.
  - **Restart:** musikken kommer tilbake med rask fade.
  - Musikkvolum og effektvolum stilles separat (av/lav/middels/høy).

## Fase 6 – QA
- Headless-oppstart uten skriptfeil. Hele reisen er kjørt og fotografert: intro → meny →
  start → dobbelttrykk-pause → innstillinger → fortsett med nedtelling → død → game over
  med ny rekord → omstart.
- Går appen i bakgrunnen under spill eller nedtelling, havner den i pausemenyen.
  Tilbake-knappen er tilpasset hver tilstand (hopper over intro, avslutter fra menyen,
  går til menyen fra game over, fortsetter fra pause).
- Kjent: headless-avslutning logger lydavspillinger som «leaked» med dummy-lyddriveren.
  Det skjer bare ved avslutning, og både spillet og CI er upåvirket.

---

# v5.1 – Profesjonell lyd, ekte musikk og teksturbaserte effekter

**Tilbakemelding:** effekter og animasjoner føltes svake, og musikk og lydeffekter hørtes
uprofesjonelle ut. Årsaken var ikke Godot, men at all lyd var syntetisert i koden og alle
partikler var tegnede prikker. Når nettverkstilgangen var åpnet, ble alt dette byttet ut
med innspilte og tegnede ressurser med fri lisens.

## Kilder og lisenser (detaljer i `CREDITS.md`)
- **Musikk:** Kevin MacLeod (incompetech.com), CC BY 4.0. Kreditering vises i
  innstillingene på norsk og engelsk.
  - «Mesmerizing Galaxy» (loop-versjon, 124 BPM, 48 takter) brukes i spill.
  - «Envision» brukes i menyen.
- **Lyd og partikler:** Kenney, CC0 (Interface Sounds, Impact Sounds, Music Jingles og
  Particle Pack).
- `tools/import_assets.py` gjør hele prosesseringen, så den kan gjentas:
  - **Lyd:** trimmer, legger på fades (2 ms inn, 25 ms ut), lydstyrkematcher alt til
    −20 dBFS aktiv RMS med topper maks −1 dBFS, og koder om til mono OGG Vorbis.
  - **Musikk:** kutter spillsporet på takten og legger en 10 ms equal-power-fold i
    skjøten, så loopen er uten klikk. Menysporet får en innbakt 3 s crossfade fra slutt
    til start. Begge sporene matches til −18 dBFS.
  - **Teksturer:** beskjærer og skalerer ned til hvit-på-alfa, 64–128 px.

## Lyd (`sfx.gd`)
- 33 lydnavn med 1–5 opptak hver, totalt 87 filer (660 KB). Hver avspilling velger et
  annet opptak enn forrige gang og legger på en liten pitch-drift (±3–6 %), så gjentakelser
  ikke låter mekaniske.
- **Miksen er én tabell (`MIX`):**
  - Hyppige spillyder ligger lavt: treff −9 dB, avfyring −11, kontakt −17, token −22.
  - Aksenter får plass: brudd −5, død −3, rekord −5.
  - UI-lyder ligger diskré: −13 til −17 dB.
- **Sfx-bussen:** high-shelf-demping over 7 kHz, kompressor, et lite mørkt rom og en
  limiter på −1 dB. 10 stemmer; når alle er i bruk, tas den eldste.
- **Valg av lyder:**
  - Kjernelyder: avfyring = pluck, treff = plate, knusing = glass, skjold = metall,
    snorkutt = scratch, brudd = tungt slag, hjerteslag = mykt dunk.
  - Jingler (pizzicato/steel), valgt etter analysert tonehøydekontur: stigende for rekord
    og clear, fallende for tap, to toner for intro og logo.
  - Whoosh fantes ikke i pakkene, så den lages av skriptet: filtrert støy med
    båndpass-sveip.
- **Tapsjingel:** spilles på game over når det ikke er ny rekord (rekord har sin egen).

## Musikk (`music.gd`)
- Samme tilstandssystem som før:
  - **Meny:** menysporet, lavpass 6,5 kHz.
  - **Spill:** spillsporet, åpent, litt sterkere med intensiteten.
  - **Pause:** lavpass 700 Hz, −5 dB.
  - **Død:** 350 Hz og fade over 1,2 s.
- Sporene crossfades i lineært domene (rask inn, rolig ut). Et spor som har fadet helt ut
  stopper og starter fra toppen neste gang, så hver runde begynner på første slag.
- I headless (CI) spilles ingen strømmer, så avslutningen er ren. Den gamle
  lekkasjeadvarselen er også borte.

## Effekter (`fx.gd`, `backdrop.gd`)
- **Gnister:** korte strek (trace) som roteres etter fartsretningen, i stedet for runde
  prikker.
- **Røyk (ny, poolet data og ingen noder):** myke dotter (smoke) som blomstrer, driver
  oppover og roterer. De tones mot bakgrunnsfargen, så de er matte og aldri glør.
  - Knusing: 2 dotter (boss: 6).
  - Brudd: 3 korall-dotter.
  - Død: 6 store korall-dotter.
- **Trykkring:** en myk tekstur-ring under den skarpe linjen, 220 ms.
- **Støv i bakgrunnen:** myke partikler i flere dybder som toner inn og ut.
- **Reduserte animasjoner:** halvparten så mange røykdotter.
- **Stilreglene holdes:** ingen stjerner, flares eller glød.

## QA
- Headless-oppstart er ren, uten ERROR og uten WARNING.
- Hele reisen er kjørt med skjermbilder: intro → meny → spill → pause → innstillinger (med
  kreditering) → nedtelling → død (røyk og strekgnister) → game over med ny rekord →
  omstart.
- APK-størrelsen øker med ca. 3,4 MB (musikk 2,7 MB, lyd 0,66 MB, teksturer 48 KB).

---

# v5.2 – Smartere fiender og dempet lyd

**Tilbakemelding:** du likte at fiendene trekker seg tilbake, og ønsket at de skal skjønne
når du sikter og flytte seg både opp og sidelengs. Lyd og musikk var for høyt.

## Fiendene leser skuddet ditt
- **Hele banen:** mens du sikter, beregnes den faktiske skuddbanen med tyngdekraft og
  veggsprett (`Slingshot.predict`). Hver fiende måler hvor midt i banen den står
  (`threat_lvl`) og hvilken side av banen den er på. Tidligere var det bare den ene
  fienden nærmest en rett linje som reagerte.
- **Ball i luften:** en ball som allerede er skutt, følges 0,6 s frem i tid. Fiender den
  vil passere nær, med minst ~0,2 s margin, kan rykke unna. Det krever høyere aggresjon,
  og bevegelsen er kortere.
- **Signal før handling:** alt som står i skuddlinjen, smalner øyet først, så du ser at
  det følger med. Deretter kommer bevegelsen, og så en nedkjølingstid (2,6 → 1,1 s),
  slik at det alltid finnes et vindu å treffe i.
- **Glir sidelengs:** kroken glir langs skinnen bort fra banen, med myk start og stopp.
  Kroppen henger etter på snora som en ekte pendel.
  - Rommet begrenses av skjermkanten og naboer i samme høyde, så fiender aldri glir inn i
    hverandre.
  - Er de stengt inne på den ene siden, skjærer de tilbake på tvers av skuddet (ved høy
    aggresjon).
- **Trekker seg opp:** er det ikke plass, eller på høyere nivå i tillegg, drar de seg opp
  langs snora. De senker seg igjen når det har vært rolig en stund.
- **Egen stil per fiende** (`EVADE`-tabellen):

  | Fiende | Reaksjon |
  |---|---|
  | Vakt | Gjemmer seg bak andre (glir nå langs skinnen), ellers glir den og hopper |
  | Tungvekt | Treg og kort bevegelse |
  | Splitter | Rask og lang bevegelse |
  | Pendel | Glir mens den svinger |
  | Vokter | Glir og snur skjoldet |
  | Snelle | Vinsjer seg opp og glir |
  | Dykker | Dukker under skuddet ved å stupe tidlig |
  | Skygge | Blekner ut tidlig når den blir siktet på |
  | Spinneren | Spinner platene raskere |

- **Læring:** fiender som har hengt lenge, blir smartere etter hvert som runden blir
  vanskeligere, fordi aggresjonen oppdateres hver frame.
- **Lyder:** en metallisk gli-lyd og en knirkende snor (Kenney RPG Audio, CC0), lavt i
  miksen.

**Balansering:** testet med en bot som sikter som et menneske (holder siktet i 0,4–0,8 s
og følger målet med siktet). Tallene er snitt av 4 runder:

| Versjon | Overlevelse (snitt) | Treff |
|---|---|---|
| v5.1 | 166 s | 95 % |
| v5.2 | 149 s | 89 % |

Merkbart vanskeligere, men fortsatt rettferdig.

## Lyd og musikk mer subtilt
- **Effekter:** ca. 9 dB lavere på alle nivåer (middels: −4 → −13 dB).
- **Store aksenter:** død, brudd, rekord, tap, logo, clear og boss er i tillegg senket med
  2–4 dB.
- **Kompressor:** strammere (−22 dB, 3,5:1), så toppene tas ned.
- **Musikk:** 10 dB lavere (middels: −17 → −27 dB). Den ligger nå som et teppe under
  spillet.

---

# v5.3 – Myke og stive kropper, ekte ballfysikk, personligheter og farger

**Tilbakemelding:** fiendene skal være både stive og myke kropper, med lyder deretter.
De skal oppføre seg mer variert, tau og fiender skal være mer fargerike, og ballen traff
flere fiender, noe som ikke virket fysisk riktig.

## Ballfysikk (`game.gd`)
- **Impulsbasert kollisjon:** kollisjonen regnes ut fra masser og relativ fart. Ballen
  har masse 1, og en fiende har 6 × sin egen masse. Retur (restitusjon) og friksjon
  avhenger av materialet:

  | Materiale | Retur | Friksjon |
  |---|---|---|
  | Gelé | 0,12 | 0,45 |
  | Stivt skall | 0,5 | 0,12 |
  | Skjoldplate | 0,7 | 0,08 |

- **Hvor mye ballen mister:** gelé sluker nesten hele slaget. Et stivt skall sender
  ballen tilbake med redusert fart. Fienden får den faktiske impulsen, ikke et fast
  dytt.
- **Taket:** ballen som treffer taket, er brukt opp. Den mister mesteparten av farten,
  treffer ingenting mer og blekner på 0,35 s. Før kom den tilbake og traff fiender på
  vei ned.
- **Resultat:** kombinasjoner er nå ekte rikosjett-skudd du må sikte for. Gjennomslag
  (pierce) går fortsatt gjennom, men mister 15 % fart per kropp.

## Myke kropper (Vakt, Splitter, Dykker, Skygge)
- **Fjærring:** en ring med 18 radielle fjærer. Kontaktpunktet bulker inn, resten buler
  ut (arealet bevares), og bulken brer seg som bølger rundt kroppen.
- **Treghet:** når kroppen svinger eller glir, slurper geleen etter.
- **Tegning:** ring, sekskant (også kantene bøyer seg), dråpe og halvmåne følger alle
  overflaten.
- **Ved dødelig treff:** geleen klemmes flat i 80 ms, så sprekker den i dråper av ulik
  størrelse. Dråpene strekker seg i fartsretningen og har en fuktig sprutring. Kroppen
  er borte, og tauet trekker seg tilbake.
- **Kontakt:** myke fiender som dunker borti hverandre, bulker også inn.
- **Lyder:** «squish» ved treff og «splat» når de sprekker (freesound, CC0). Tonehøyden
  følger størrelsen, og volumet følger slagkraften.

## Stive kropper (Tungvekt, Pendel, Vokter, Snelle, Spinneren)
- **Ingen deformasjon:** i stedet vibrerer de kort og stivt langs slaget (160 ms),
  vugger og spinner fra friksjon.
- **Lyder etter materiale:** Pendel = tre, Vokter/Snelle = metallklang, Spinneren =
  tungt metall, Tungvekt = plate. Volumet følger slagkraften.
- **Knusing:** kroppen brekker i sin egen form (buer, kanter, halvdeler), med skår og
  røyk.

## Personlighet og variasjon (`Temper`)
Hver fiende får et tilfeldig temperament. Blandingen blir livligere når aggresjonen
stiger.

| Temperament | Reaksjon | Særtrekk | På tomgang |
|---|---|---|---|
| Forsiktig | ×0,7 | Unnviker lenger og drar seg alltid opp | Skjelver lett, holder seg i ro |
| Dristig | ×1,35 | 35 % sjanse for at den står imot og bare trasser (en sjanse for deg) | Patruljerer bredt og svinger seg |
| Uberegnelig | ×0,9 | Fint: et kort rykk feil vei (60 % sjanse), deretter ekte unnvikelse | Rykker ofte |
| Rolig | ×1 | – | Driver av og til litt langs skinnen |

- **Følger kroken:** kroppen drar seg aktivt tilbake under kroken, så lange tau ikke
  henger på skrå i flere sekunder. Pendel er unntatt.

## Farger
- **Fiender:** rikere juveltoner. Vakt asurblå, Tungvekt smaragd, Splitter turkis,
  Pendel fiolett, Dykker himmelblå, Vokter stålblå, Spinneren orkidé, Snelle lime,
  Skygge rosa. Lysheten er fortsatt spredt, så typene skilles i gråtoner.
- **Variasjon:** hver fiende får en liten tilfeldig nyansevariasjon innen typen.
- **Tau:** fiendens farge. Myke henger i en farget snor (2,4 px), stive i en mørkere
  tonet wire (1,8 px).
- **Tauets bøyestivhet:** raske glid gir en glatt bølge nedover tauet, ikke sikksakk.

## Balansering
Ballen tar nå bare én fiende per skudd, uten gratis-kombinasjoner. Det er kompensert
med:
- raskere omlading: 0,88 → 0,6 s (før 1,05 → 0,72 s);
- en knute hvert 1500. poeng (før 3000).

Menneskelignende bot, snitt av 4 runder:

| Versjon | Overlevelse (snitt) |
|---|---|
| v5.2 | 149 s |
| v5.3 | 135 s |

Poengene er lavere, fordi kombinasjoner nå må fortjenes.

---

# v5.4 – Ryddigere HUD, ertende fiender og engelsk navn

**Tilbakemelding:** buen ved spretterten var uklar, og pauseknappen skal bort siden
dobbelttrykk finnes. Fiendene skal være mer ertende når de nærmer seg, og logoen skal
bytte til et engelsk navn når språket er engelsk.

## HUD
- **Kraftbuen er fjernet.** Den tomme gullbuen rundt spretterten var kraftmåleren, men
  den leste som en løs strek. Kraften vises nå i siktepunktene: de blir lysere og
  større jo hardere du drar, og varmere i de siste 15 %. Strikken viser den også.
- **Pauseknappen er fjernet.** Pause skjer med dobbelttrykk på feltet eller
  Tilbake-knappen. I de tre første rundene sier startkortet «DOBBELTTRYKK FOR PAUSE» i
  stedet for undertittelen. Antall runder lagres i `Prefs.runs`.

## Ertende fiender
- **Selvgode:** når de nærmer seg linjen, glir et tungt øyelokk ned, og det ene brynet
  går opp. Dristige fiender begynner tidligere (fare 0,25), rolige og uberegnelige ved
  0,4, og forsiktige aldri.
- **Dans:** selvgode fiender danser av og til. De vrikker (±0,28 rad) og hopper (5 px)
  i 0,9 s og blunker. Myke fiender gynger i hele kroppen. Dristige gjør det hvert
  1,5–3 s, andre hvert 2,5–4,5 s, og aldri mens de blir siktet på.
- **Håner bom:** når ballen suser like forbi, skvetter fienden først og gjør narr av deg
  et halvt sekund senere.
- **Ler ved brudd:** når en knute ryker, danser fiendene i nærheten.
- **Lyd:** et lite «na-na» (Kenney pizzicato-jingler, lyst stemt). Det spilles høyst én
  gang per 1,6 s og ligger lavt i miksen (−19 dB).

## Engelsk navn: TAUT
- **Navnet:** «taut» betyr stram, som et spent tau, og er en direkte parallell til
  «Spenn».
- **Tittelen:** den skifter levende med språket, både i introen og i bokstavene som
  henger i snorer i menyen. Gullbokstaven (ballen) er språkstyrt: E i SPENN, A i TAUT
  (`game.titleAccent`).
- **Appnavnet på telefonen:** «Spenn» med norsk systemspråk (nb/nn/no), ellers «Taut»
  (`config/name_localized`, `package/name`).

---

# v5.5 – Ekte kraft, tydelig ammo, samarbeidende fiender og telefontilpasning

**Tilbakemelding:** ammo-kolonnen var uklar, og ballen gikk like fort uansett hvor mye
strikken ble dratt. Fiendene skal samarbeide og skjerme hverandre. Spillet skal bruke
hele skjermen og tilpasse seg telefonen (Samsung Galaxy osv.) automatisk.

## Kraft
- **Feilen:** kraften ble målt på pungens korte visuelle vei (`max_pull` ≈ 115 px, rundt
  1,5 cm finger). Nesten alle drag ga derfor full kraft.
- **Nå:** kraften følger fingerens vei over en fysisk avstand, `drag_range` = 220 dp
  (≈ 3,5 cm på alle telefoner), og strikken strekkes i samme forhold.
- **Fart:** 620 → 2250 px/s med en svak kurve (`power^1.15`). Myke drag lobber i bue,
  fulle drag flyr.

## Ammo
- **Hva som var galt:** ladde kuler i kø ble tegnet som tomme ringer, akkurat som tomme
  plasser.
- **Nå:** et lite mørkt stativ ved skaftet med reservekulene som ekte gullkuler, tegnet
  som ballen i luften. Gjennomslag viser stålbåndet, trippel viser tre frø.
- **Lading:** plassen som lades, fyller seg med en voksende kule og en tynn
  fremdriftsring. Tomme plasser er svake fordypninger.
- Kulen i strikken er neste skudd og står ikke i stativet.

## Samarbeid (livvakter)
- **Hvem og når:** når du sikter på en mindre fiende, kan en Tungvekt eller Vokter som
  henger lavere (mellom deg og den) gli inn i skuddlinjen. Skjæringspunktet regnes ut fra
  den forutsagte banen.
- **Signal:** først et kort, lesbart øyeblikk der livvaktens øye vender seg mot den den
  beskytter. En stiplet linje i livvaktens farge viser paret.
- **Den beskyttede:** stoler på livvakten og holder seg i ro. Livvakten flykter ikke fra
  skuddlinjen mens den er på vakt.
- **Begrensninger:** krever aggresjon ≥ 0,25. Rasende Tungvekter vokter ikke. Nedkjøling
  2,4 → 1,2 s.
- **Motspill:** skudd via veggen, et snorkutt, eller å skyte livvakten først. Tungvekten
  har 2 liv.

## Telefontilpasning (`Device`, ny autoload)
- **Leser telefonen:** modell, kjerner, minne og oppdateringsfrekvens. Velger
  effektnivå: høy (8+ kjerner og ≥ 5,5 GB), middels eller lav.
- **Effekter etter nivå:** partikkelmengder skaleres (gnister, røyk, dråper, stråler,
  støv) med ×1 / ×0,8 / ×0,5.
- **Live-tilpasning:** faller bildefrekvensen under ~80 % i 4 s under spill, går nivået
  ned ett trinn, aldri opp igjen i samme økt.
- **Bildefrekvens:** tegner i panelets egen takt (60/90/120 Hz), ikke raskere.
- **Skjermen:** holdes våken under spill.
- **Hele skjermen:** immersive fullskjerm og stretch «expand» fyller alle formater, fra
  16:9 til 21:9 og sammenleggbare. Trygg sone holder HUD unna kamerahull og gestlinje.
  Dragavstand og måleenheter er fysiske (dp), så følelsen er lik på alle tettheter.

## Balansering
Menneskelignende bot, snitt av 4 runder:

| Versjon | Overlevelse (snitt) |
|---|---|
| v5.4 | 135 s |
| v5.5 | 126 s |

Litt lavere, fordi livvaktene tar skudd.

---

# v5.6 – Visuell overhaling

**Tilbakemelding (med skjermbilder):** forbedre det visuelle – effekter, animasjoner og
fiender.

**Utgangspunkt i skjermbildene:**
- Fiendene var flate ringer uten volum eller uttrykk.
- Rommet var svart og tomt.
- Farelinjen syntes nesten ikke, og skinnen var en tynn strek.
- Treff manglet slagkraft.
- Eventkortet druknet i fiendene.

## Miljø
- **Rommet (`backdrop.gdshader`):**
  - En lampe over bjelken til venstre kaster en myk kjegle ned gjennom feltet, med
    svake, sakte lyssøyler.
  - Veggen har stor og liten materialmarmorering.
  - Under farelinjen tar gulvet over, med en mykere horisont og et lysbasseng rundt
    spretterten.
  - Når en fiende nærmer seg, stiger en korallvarme fra linjen (i shaderen, ikke
    rektangler).
  - Kornet og ditheringen er beholdt, så det ikke blir bånding.
- **Farelinjen:** en ekte vaier boltet til veggplater på begge sider. I ro er den en
  stille ståltråd. Når fare stiger, strammes den, summer (stående bølge, både utslag og
  frekvens øker), varmes til korall og får en varm glorie. En sakte røyktåke driver
  langs den.
- **Skinnen:** en stålbjelke med myk slagskygge, mørk underkant, lys toppkant og
  nagler hver 64. px. Den følger fortsatt bøyningen ved brudd.

## Fiendene
- **Hud:** ringformede kropper har en farget membran i midten, så ansiktet sitter på
  skapningen og ikke på veggen bak. Geleen er litt gjennomskinnelig med bobler som
  stiger sakte, og innsiden skygges mot nedre høyre.
- **Materialdetaljer:** nagler på Tungvektens ring (borte når den er knust), bolter på
  Vokteren og et nav på Snellen.
- **Glans:** et høylys øverst til venstre som står stille i verden mens kroppen svinger.
  Geleen er blankere enn de malte skallene.
- **Ansikt med munn:** øyet flyttes litt opp for å gi plass. Uttrykket følger
  tilstanden:

  | Tilstand | Munn |
  |---|---|
  | Hvile | Lite smil |
  | Siktet på eller fare | Bekymret, dirrende strek |
  | Skvett | «o» |
  | Selvgod | Flir |
  | Erting | Glis med tunge ute |
  | Raseri | Surmule |
  | Truffet | Grimase |

- **Pust:** geleen sveller og legger seg (±3 %), skallene knapt (±1 %).
- **Landing:** tauet strammes idet fienden kommer ned. Geleen bulker nedenfra, skallet
  dirrer, og det kommer et lavt dunk.

## Effekter
- **Lysglimt:** en hvit skive som kollapser på 70 ms der ballen treffer.
- **Trykkbølge (`shockwave.gdshader`):** en ring i skjermrommet som bøyer bildet utover
  i et tynt, voksende bånd, som brytning og ikke glød. Opptil 4 samtidig. Laget er
  skjult når ingen bølger lever, så det koster ingenting ellers. Styrke og rekkevidde:

  | Hendelse | Styrke | Radius |
  |---|---|---|
  | Drap | 9 | 170 px |
  | Boss | 18 | 320 px |
  | Brudd | 12 | 240 px |
  | Død | 20 | 460 px |

  Av med reduserte animasjoner og på laveste nivå.

## UI
- **Eventkort:** et mykt mørkt bånd bak teksten, rammet inn av to tynne gullstreker som
  tegnes utover fra midten.

## Balansering
Landingsdyttet ga i første versjon merkbart tøffere sikting (snitt 106 s). Det er dempet,
og snittet er nå 133 s, på nivå med før.

---

# v6.0 – Grundig gjennomgang: lyssatt rendering, ytelse, feilrettinger og onboarding

**Oppdrag:** gjøre spillet bedre med en grundigere gjennomgang enn før. Arbeidet startet
med måling og kodegjennomgang, ikke med nye funksjoner.

## Funn
- **Profilering av en travel sen fase (18–24 fiender):**
  - **Tegnekall:** 1651 per frame. Et mobilspill bør ligge godt under 500.
  - **Tegning:** ~96 000 trekanter.
  - **Spillogikk** (fysikk, AI, kollisjoner): bare 1,6 ms. Det var tegningen som
    kostet.
  - **Fordeling:** hver fiende brukte ~65 tegnekall (skygge, fire kantlag, hud,
    bobler, nagler, øye, munn, glans). Skinne og kroker brukte 213, spretterten 83 og
    bakgrunnen 70.
- **Verifisert i Godot 4.3 GL Compatibility før ombyggingen:**
  - Triangle-arrays med én farge fungerer.
  - `MODEL_MATRIX` inkluderer transformasjonen per kommando.
  - Teksturerte rektangler samles i én batch, også på tvers av transformasjoner.

## Lyssatt rendering (`shaders/lit.gdshader`)
- **Én felles lyskilde** (opp til venstre, litt forfra) for alle fiender og
  spretterten.
- **Normaler i UV:** hver vertex har en overflatenormal i UV. Shaderen regner lys per
  piksel: diffust lys med myk overgang, spekulært høylys, og for geléen lys som slipper
  gjennom kanten på skyggesiden.
- **Kantutjevning:** silhuetten jevnes ut der normalens lengde når 1.
- **Materialer:** UV.x velger materiale i bånd:

  | Bånd | Materiale |
  |---|---|
  | 0 | Gelé |
  | 1 | Kontaktskygge |
  | 2 | Snor |
  | 3 | Wire |
  | 4 | Malt skall |
  | 5 | Innfelt membran |
  | 6 | Polert metall |

- **Hver fiende er to lerretslag som følger kroppens transformasjon:**
  - `_body` (lysmateriale): tau, kontaktskygge og kropp som triangle-mesher, ett
    tegnekall hver.
  - `_face`: øye, munn, bobler og nagler som sirkelsprites, samlet i én batch.
- **Meshene:**
  - bygges én gang per type og helse, og skallene bygger dem aldri om;
  - geleen flytter bare overflatepunktene sine langs fjærfeltet hver frame, via
    forhåndsberegnet spoke-indeks;
  - rør for ringene, kupler for fylte kropper, kapsel med ryggrad for Pendelen,
    halvmåne fra sitt tykke sentrum;
  - Vokteren og Spinnerens plater er polert metall i verdensrommet, med egen skygge.
- **Tauet:** Verlet-punktene glattes med Catmull-Rom og tegnes som en lyssatt sylinder,
  snor for gelé og wire for skall.
- **Spretterten:** gaffelen er polert metall (rør og kuplede ender) over en myk skygge,
  2 tegnekall.

## Batching av resten
- **Sirkler:** `Pal.disc` er nå et teksturert rektangel fra én sirkeltekstur med
  mipmaps, så dusinvis av øyne, nagler og perler blir ett kall. Prosjektets standard
  teksturfilter er lineær med mipmaps.
- **Kroker:** `Pal.hoop` (ringtekstur) brukes til krokøyene. Krokene tegnes i to samlede
  omganger.
- **Skinnen:** vanlige rektangler i ro, polylinjer bare mens den bøyes.
- **Bakgrunnens fjerne tråder:** én multiline, og perlene i én batch.

## Resultat (samme scene)

| Måling | Før | Etter |
|---|---|---|
| Tegnekall | 1651 | 266 |
| Trekanter | 96 000 | 11 600 |
| Tegne-/skripttid (utover testmiljøets ~40 ms grunnlast) | ~47 ms | ~2 ms |

## Feilrettinger
- **Skjelving:** under skjelvingen før et stup fikk hvert tegnelag sin egen tilfeldige
  forskyvning (`randf` i `body_xform`), så skygge, kanter, kropp og øye gled fra
  hverandre. Skjelvingen beregnes nå én gang per frame (`_jit`).
- **Temperament:** ble trukket med forrige livs aggresjon, fordi fiendene gjenbrukes.
  Aggresjonen settes nå før `spawn`.
- **Bildefrekvens:** `Engine.max_fps` lik skjermfrekvensen kjempet mot v-sync og kunne
  droppe frames. Nå går takten bare på v-sync.
- **Gnistsendere:** ble reallokert ved hvert treff (`amount` satt hver gang). Nå settes
  den bare når antallet endres.
- **Opprydding:** fjernet ubrukte variabler (`_feint`, `_feint_dir`) og rettet en utdatert
  kommentar.

## Onboarding
- **Spøkelsesfinger i menyen:** for de tre første rundene, eller etter 6 s uten
  berøring, trykker en halvgjennomsiktig finger, drar pungen ned (siktepunktene vises),
  holder og slipper. Pungen fjærer tilbake, og en spøkelseskule flyr opp langs linjen.
  Løkken går til spilleren tar på skjermen, og starter aldri en runde.

## QA
- Oppstart er ren.
- Hele spillforløpet er kjørt og fotografert.
- Balanse med menneskelignende bot, snitt av 4 runder: 137 s (før: 133 s), altså
  uendret.

# v7.0 – Fase 1: overbelastning, ferdighetsskudd, musikalske treff, Game Over-krok

Første av seks faser i premium-oppgraderingen. Målet er et tydelig belønningsløp:
spill godt, bygg spenning, utløs den, jakt rekorden.

## Overbelastning
- **Måler:** en gullinnlegging i bjelken fyller seg fra midten og utover. Den pulserer
  når den er nesten full.
- **Fylling:** hvert drap gir +0,03 (boss +0,06), og ferdighetsskudd gir 0,09–0,14.
- **Tap:** en bom trekker 0,05, og et brudd trekker 0,35.
- **Utløst:** gir 5 s i sanntid med følgende effekter:
  - tiden går i 0,7;
  - alle kuler går gjennom;
  - omlading tar 30 % av normal tid, og magasinet fylles;
  - poengene dobles, og pillen viser ×2 og gløder;
  - fiendene får panikk: de blekner, sperrer opp øynene og skjelver, slutter å synke,
    klatrer opp strengen, og verken unnviker eller erter.
- **Presentasjon:**
  - kort «OVERBELASTNING / ALT GÅR GJENNOM · DOBBEL POENG»;
  - sjokkbølge, kamerastøt og haptikk;
  - varm gullkant i vignetten;
  - musikken dempes bak et lavpass, mens en syntetisert c-moll-akkord svulmer opp
    (`rise`) og faller bort (`fall`).
- **Førstegangshint:** i de tre første rundene vises «FULL SPENNING GIR
  OVERBELASTNING» når måleren passerer halvveis.

## Ferdighetsskudd
Hvert skudd har eget navn, egen poengsum og egen tonefrase. De vises i gull med en
understrek som tegnes ut fra midten.

| Skudd | Vilkår | Poeng |
|---|---|---|
| Veggskudd | drap etter sprett i sideveggen | 40 |
| Langskudd | drap etter ≥ 0,85 s i lufta | 40 |
| Dobbelttreff | andre drap med samme kule (trippel og flere skalerer) | 60 |
| Snorkutt | kappet streng | 50 |
| Siste sekund | drap like over linjen (erstatter «nære på») | 50 |
| Kjedereaksjon | kobles på i fase 2 | 60 |

Alle poengsummer ganges med multiplikatoren og med ×2 under overbelastning.

## Musikalske treff
- **Toner:** `tools/import_assets.py` syntetiserer ni kalimba-toner stemt i
  spillmusikkens toneart (c-moll, målt med kromagram): C D Ess G over tre oktaver.
- **Stigning:** hvert drap i en kjede spiller ett trinn høyere, en oktav opp under
  overbelastning.
- **Ferdighetsskudd:** hvert skudd har sin egen korte frase.

## Game Over
- **Avstand til rekorden:** i gull, for eksempel «550 POENG FRA REKORDEN». Når
  avstanden er under 10 %, står det i tillegg «SÅ NÆRE».
- **Høydepunkter:** én linje med antall overbelastninger og de hyppigste
  ferdighetsskuddene.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt (21 bilder).
- Balanse med bot, 4 frø:
  - første forsøk ga overbelastning hvert ~18. sekund og 164 s snitt, altså for lett;
  - etter justering blir det ca. én overbelastning per 40–50 s, med 135 s snitt
    (grunnlinje 137 s).

# v7.1 – Fase 2: fysiske kjedereaksjoner

## Fallende kropper
Et drept skall eller en kappet fiende faller med ekte fart. Det som henger i veien:
- får et treff og slås av strengen, eller mister ett liv hvis det tåler flere treff;
- begynner selv å falle, så kjeden kan fortsette.

Fallkroppen mister 60 % av farten og spinner motsatt vei. Fallende kropper forblir
solide litt lenger enn før (falming starter etter 0,6 s i stedet for 0,45 s), så de når
lenger ned.

## Biljard
Et mål som nettopp er truffet (0,45 s) og smeller inn i en nabo med over 240 px/s
lukkehastighet, skader naboen. Hvert mål kan bare gi ett slikt støt per treff.

## Poeng
- Hvert ledd poengsettes som et treff.
- Et drap gir ferdighetsskuddet «KJEDEREAKSJON».
- Dypere ledd betaler mer og vises som «×2», «×3» og så videre.
- Siste sekund gjelder også i kjeder.

## Refaktorering
Treff- og knuseeffektene er samlet i `_break_fx`, som brukes både av kuletreff og av
kjedetreff.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- En egen testrigg viser en kappet Tungvekt som faller og sprenger Vakten under.
- Balanse med bot: 150 s snitt. Boten sikter bare på det laveste målet og lager derfor
  sjelden kjeder, 0–2 per runde.

# v7.2 – Fase 3: bølger, formasjonsledere, nye fiender, bosstrinn, vanelæring

## Bølger
Rundt det endeløse presset ligger nå bølger, i Space Invaders-stil:
- En bølge sender ut kvoten sin, 10 + 3 per bølge (maks 32). Formasjoner teller per
  medlem og bossen teller som 3.
- Deretter kommer ingenting nytt før feltet er tomt. De to siste skjelver og synker
  dobbelt så fort.
- Et renset felt gir kortet «BØLGE n RENSKET» med bonus (100 + 50·n) × multiplikator,
  en tonefrase og 0,12 spenning.
- Så følger 2,4 s pause før neste bølge.
- Hendelser (formasjon, storm, boss) kommer bare mens bølgen sender ut.
- Toppfeltet viser «BØLGE n» med fremdrift etter drap. Intensitetskurven er fortsatt
  tidsstyrt.

## Formasjonsledere
- Rekker på fem eller flere får en kronet leder i midten, som reagerer 30 % raskere.
- De andre holder posisjonen på lederens krok og gjør ingen egne trekk.
- Skytes lederen, blir det «FORMASJON BRUTT» (ferdighetsskudd, 80 poeng). Resten får
  panikk i 2,2 s og er helt åpne.
- Kortet sier nå «FELL LEDEREN MED KRONEN».

## Nye fiender
- **Legen (Medic):** perlehvit gelering med mintmerke.
  - Hvert 2,6.–4,5. sekund leger den den nærmeste skadde allierte (+1 liv), ellers
    gir den den nærmeste en boble som tar ett støt.
  - Gjennomslagskuler og snorkutt går forbi boblen.
  - Den dukker opp fra intensitet 2,0.
- **Speilet (Mirror):** polert sekskant i metall.
  - Rene skudd, altså kuler som ikke har truffet noe ennå, kastes rett tilbake med
    full elastisitet.
  - Kula regnes da som banket og kan ta et annet mål.
  - Speilet selv må treffes av en kule som har sprettet (vegg, speil eller et annet
    mål), av gjennomslag, av snorkutt eller av en kjedereaksjon.
  - Det dukker opp fra intensitet 2,8.
- **Klatreren** er droppet med vilje. Å klatre ned i rykk og stå stille mellom rykkene
  overlapper med Dykkeren (stuper etter varsel) og Snella (vinsjer seg), så den ville
  ikke gitt ny spillmekanikk.

## Bosstrinn (Spinneren)
Bossen går gjennom tre trinn etter gjenværende liv:

| Trinn | Liv | Plater | Rotasjon | Undersåtter |
|---|---|---|---|---|
| 1 | 8–6 | 2 × 76° | ×1 | ×1 |
| 2 | 5–3 | 3 × 60° | ×1,25 | ×0,75 intervall |
| 3 | 2–1 | 1 × 110° | ×2 | ×0,5 intervall, og den stuper ofte |

Ved hvert skifte skjer dette:
- de gamle platene knuses av;
- sjokkbølge, kamerastøt og haptikk;
- teksten «SPINNEREN · TRINN n».

## Vanelæring
- **Registrering:** retningen på hvert skudd legges inn i et glidende snitt
  (-1 venstre, 1 høyre).
- **Plassering:** nye fiender plasseres bort fra siden du foretrekker, med opptil
  50 % lavere plassvekt.
- **Beskjed:** første gang vanen er tydelig (> 0,45 etter 12 skudd), står det én gang
  per runde: «DE HAR MERKET AT DU SIKTER TIL HØYRE/VENSTRE».

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- En egen testrigg viser Legen med boble, Speilet, kronet formasjon og boss i trinn 2.
- Balanse med bot, 4 frø: 147 s snitt, 4–5 bølger. Boten treffer sjeldnere nå
  (65–84 %), fordi fiendene plasseres bort fra der den sikter.

# v7.3 – Fase 4+5: kamera, effekter, adaptiv lyd og musikk

## Kamera
`fx.focus(punkt, mengde, varighet)` lener kameraet inn mot et punkt i sanntid:
rask inn, hold, rolig ut. Det slås av med reduserte animasjoner.

| Øyeblikk | Kamera | Sakte film |
|---|---|---|
| Siste drap i en bølge | 6 % | 0,3 i 0,5 s |
| Bossen faller | 9 % | 0,3 i 0,6 s |
| Trippeltreff, kjede ×2+, formasjon brutt | 4,5 % | 0,4 i 0,3 s |
| Siste sekund | 3,5 % | 0,45 i 0,28 s |

## HUD
- Telleren ruller som før og blinker gull ved gevinster på 100 poeng eller mer.
- Multiplikatorpillen gløder rolig fra ×3, og pulserer raskt under overbelastning.
- Overbelastningen gir allerede varmt fargeskifte i vignetten (v7.0).

## Adaptiv musikk
Det finnes ingen stems, så miksen styres med nivå og filter:
- Musikken blir sterkere med intensiteten.
- Når et mål nærmer seg linjen, lukker et lavpass seg mot 3,2 kHz. Det gir tunnelsyn,
  og hjerteslaget kommer tydeligere frem.
- Under overbelastning lukker lavpasset seg til 1,4 kHz.
- `Music.duck` demper musikken under de store aksentene:
  - overbelastning −6 dB;
  - renset bølge −5 dB;
  - boss −6 dB;
  - sjeldne ferdighetsskudd −3 dB.

## Balanse
- Med bølgenes pauser økte snittet til 153 s.
- Nedstigningen er skrudd opp ca. 7 %, og bølgepausen er kortet til 2,0 s.
- Resultat med 6 frø: 137 s snitt, som er likt grunnlinjen.

# v7.4 – Fase 6: oppdrag, dagens utfordring, kuler (skins), statistikk

Det lange løpet rundt rundene ligger i `scripts/meta.gd` (regler og data) og
`Prefs` (lagring under `[meta]`).

## Oppdrag
- Tre er aktive om gangen. Hvert er et mål for én runde, trukket fra ti maler:
  - knus fiender, poeng, bølge, veggskudd;
  - overbelastninger, kjedereaksjoner, snorkutt, dobbelttreff;
  - overlev sekunder, bryt formasjoner.
- Målene vokser med antall fullførte oppdrag.
- Menyen viser dem under rekorden.
- Når et oppdrag nås midt i en runde, vises «OPPDRAG FULLFØRT +1 000» i gull med
  tonefrase og haptikk. Belønningen er 1 000 + 500 per nivå i livstidspoeng.
- Plassen får et nytt, vanskeligere oppdrag, som vises i menyen.
- Game Over lister oppdragene som ble fullført i runden.

## Dagens utfordring
- En bryter i menyen setter neste runde til dagens seed (ÅÅÅÅMMDD). Seeden brukes både
  for spillets egen RNG og for den globale RNG-en, så alle får samme sekvens av
  fiender og hendelser den dagen.
- Utfordringen har egen rekord, «DAGENS REKORD», som nullstilles ved ny dag, og egen
  tittel og rekordlinje på Game Over.

## Kuler (skins)
- Seks kosmetiske kuler låses opp med livstidspoeng (alle poeng fra alle runder, pluss
  oppdrag): Gull (0), Kobber (15 000), Krom (40 000), Jade (80 000),
  Obsidian (150 000) og Glød (300 000).
- Valgt kule farger kula i flukt, sporet, pungen og magasinet.
- Panelet viser en tegnet prøvekule per knapp. Låste kuler er grå og viser prisen.

## Statistikk
- Panelet viser:
  - runder, rekord, totale poeng, beste bølge;
  - fiender knust, treffsikkerhet, overbelastninger;
  - veggskudd, kjedereaksjoner, snorkutt;
  - fullførte oppdrag og spilletid.
- Tallene oppdateres ved hver rundeslutt (`Prefs.record_run`).

## Meny
Topplinjen har INNSTILLINGER, STATISTIKK, KULER og språk.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- En egen testrigg viser menyen (vanlig og dagens), statistikk, kuler,
  oppdragsmeldingen, jadekula i spill og Game Over med oppdrag.
- Balanse er uendret: 155 s og 122 s på frø 1 og 2.

# v7.5 – Premium-finish: glød, linseeffekt, levende rom, ikon, oppstartsskjerm, overganger

## Glød
Glød er additivt lys som legges oppå bildet i stedet for å dekke det.
- **Treff:** hvert treffblink får en myk lysblomst i målets farge som vokser og falmer
  over 0,22 s.
- **Gjennomslagskule:** gløder svakt.
- **Overbelastning:** alle kuler brenner med en stor glorie i kulefargen, og sporet
  gløder også.

## Linseeffekt
Ved de største øyeblikkene skilles rødt og blått et øyeblikk mot kantene. Effekten
ligger i sjokkbølge-shaderen, så den koster ingenting når den er av.

| Øyeblikk | Styrke |
|---|---|
| Overbelastning | 7 px |
| Boss | 6 px |
| Brudd | 5 px |
| Sjeldne ferdighetsskudd | 4 px |
| Renset bølge | 3 px |

Den slås av med reduserte animasjoner og på svake enheter.

## Levende rom
- Lampen puster sakte, uten flimring.
- Seks store, uskarpe støvfnugg driver gjennom rommet og lyser mer der lampekjeglen
  faller.
- Under overbelastning brenner lampen gull, og støvet blir gyllent.
- Vignettens gullkant er dempet (0,22).

## Ikon og oppstartsskjerm
`tools/make_icons.py` tegner ikonet uten tekst, så det fungerer på begge språk: en
blå geléring med øye henger fra bjelken og ser på gullkula som stiger mot den.
- Adaptive Android-lag (forgrunn innenfor sikker sone og bakgrunn, 432 px).
- 192 px ikon for eldre telefoner og prosjektikon på 512 px.
- Oppstartsskjerm med merket alene på spillets bakgrunnsfarge.

## Overganger
- Paneler (pause, innstillinger, statistikk, kuler) bygger seg opp rad for rad, med
  30 ms mellom hver.
- Popup-tekster stables nå pålitelig, også helt oppe ved bjelken.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- Ytelse: 205 tegnekall, 8 900 trekanter.

# v7.6 – 2.5D: vippeparallakse, skygger på veggen, dybde

Spillet er fortsatt helt i 2D. Dybden er rent visuell, og treffsoner, fysikk og
balanse er uendret.

## Vippeparallakse
- Akselerometeret leses hver frame. Referansen følger telefonens hvilevinkel over
  ca. 3 s, så bare en ny vipping flytter bildet.
- Verden (fiender, bjelke, sprettert) forskyves opptil 9 px. Veggen bak (fjerne
  strenger, støv, skygger) forskyves 40 % av det.
- Mens du sikter står bildet stille.
- Parallaksen er av med reduserte animasjoner og uten sensor.
- Bjelken tegnes nå forbi begge kanter, så endene aldri synes.

## Skygger på veggen
- Hver fiende kaster en myk skygge på veggen, bort fra lampen, med en svak strengskygge
  fra kroken.
- Jo lenger fra veggen fienden henger, desto lenger unna, mykere og svakere blir
  skyggen.
- Pendelen gir en avlang skygge, og Skyggen (Shade) falmer også i skygge.

## Dybde
- Hver fiende får en tilfeldig dybde fra −0,85 (bak) til 0,85 (foran). Vokteren og
  Spinneren står i midten fordi platene deres har verdensstørrelse.
- Fiender foran tegnes opptil 10 % større og litt lysere. Fiender bak tegnes mindre og
  mørkere.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- Før/etter-bilder viser skyggene og dybdeforskjellen.

# v7.7 – 2.5D del 2: glans, perspektiv, kamerarulling

## Glans som følger blikket
- Den delte lysshaderen tar imot seerens helning (`view`, fra vippesensoren). Høylysene
  glir over gelé, skall og metall når du vipper, og det samme gjør høylyset på
  sprettertens metall.
- Høylysene er gjort kraftigere:
  - skall: eksponent 22, styrke 0,3;
  - metall: 0,9;
  - lys som skinner gjennom kanten av geléen: 0,8.
- Speilets to glimt forskyves også med helningen.

## Perspektiv
- **Gulvet:** får svake planker som løper mot et forsvinningspunkt, og skjøter som
  ligger tettere mot linjen. Bakken leses dermed som et plan.
- **Bjelken:** viser undersiden sin, en mørk flate som er dypere mot endene, så den ser
  ut til å løpe inn i veggene.

## Kamerarulling
`fx.focus` ruller verden opptil 1,5° mot den siden øyeblikket skjer på. Rullingen er
størst ved de største øyeblikkene. Zoom, panorering, rulling og parallakse regnes nå ut
i én samlet transform rundt fokuspunktet.

## QA
- Oppstart er ren, og hele spillforløpet er kjørt.
- En egen testrigg viser kamerarulling og gulvperspektiv.

# v7.8 – Rettelser etter test på telefon

- **Svarte streker:** strengskyggene arvet posisjonen og vinkelen til forrige
  kroppsskygge, fordi transformen ikke ble nullstilt. Det ga mørke streker på tilfeldige
  steder. Transformen nullstilles nå før hver strengskygge, og strengskyggen er dempet
  (0,1).
- **Vippeeffekten:** akselerometeret er nå slått eksplisitt på i prosjektet
  (`input_devices/sensors`), og forskyvningen er økt fra 9 til 14 px.
- **Bølgetekst:** «BØLGE n» vises høyere (28 % av feltet), så den ikke havner bak
  hendelseskort som «FORMASJON».

# v7.9 – Vippeeffekt: mer robust, egen innstilling, diagnose

## Brukeren merket ingen vipping på telefonen
- **Sensor:** effekten leser nå først tyngdekraftsensoren (`Input.get_gravity`, glattet
  av Android). Finnes den ikke, brukes akselerometeret.
- **Sterkere:** forsterkningen er økt fra 3,5 til 5 og forskyvningen fra 14 til 18 px.
  Referansen følger hvilevinkelen over 6 s i stedet for 3 s, så en vipping holder seg
  synlig lenger.
- **Innstilling:** «VIPPEEFFEKT: PÅ/AV» er nå en egen innstilling. Knappen viser
  «· INGEN SENSOR» når telefonen ikke gir sensordata, så man kan skille en avslått
  effekt fra en som mangler data.
- **Diagnose:** FPS-visningen (trippeltrykk på knutene) viser også sensorverdiene
  (G x y z).

# v7.10 – Gyroskop i vippeeffekten

- Gyroskopet slås nå på i prosjektet (`sensors/enable_gyroscope`).
- Rotasjonsfarten integreres til en vinkel som glir tilbake til midten over ca. 2 s.
  Vinkelen legges til tyngdekraftdelen.
- Parallaksen reagerer dermed raskere og merker også dreining uten vipping, altså
  rotasjon rundt telefonens loddrette akse.
- «INGEN SENSOR» vises bare når verken tyngdekraft, akselerometer eller gyroskop gir
  data.
- FPS-visningen viser også gyroskopverdiene.

# v7.11 – Vippeeffekten styres bare av sin egen innstilling

På brukerens telefon sto «REDUSERTE ANIMASJONER: PÅ», og det slo av vippeeffekten.
Sensoren fungerte, siden knappen ikke viste «INGEN SENSOR». Nå styres vippeeffekten
bare av «VIPPEEFFEKT».

Reduserte animasjoner slår fortsatt av:
- skjelving og kameraets innlening og rulling;
- rød/blå-splitten og uskarphet;
- inngangsanimasjonene i panelene.

# v7.12 – Fiendene svinger når du vipper telefonen

## Til siden
- Helningen gir en sidekraft på fiendene, lagt til i vindleddet (220 px/s² per enhet
  helning).
- Et spark etter hvor fort helningen endres (40 px/s² per enhet/s) gjør at et raskt vipp
  setter dem i gang med å gynge.
- Strengene og fysikken tar seg av resten: pendelsving, tyngre fiender svinger mindre,
  og de kolliderer med hverandre som før.
- Kraften kommer fra den adaptive helningen og ebber ut når telefonen holdes i ro, så
  vedvarende skjev holding ikke flytter målene permanent.
- Tittelbokstavene i menyen svinger også.

## Mot og bort fra kameraet
- Hver fiende har en egen dempet pendel i dybden (`z_swing`). Frekvensen følger
  strenglengden (g/L), og tyngre fiender påvirkes mindre.
- Svingen legges til fiendens dybde, så den synes i størrelse (±12 %), lysstyrke og
  skygge på veggen. Den er rent visuell.

## Treff
Sidesvingen er ekte fysikk, så treffsonene følger fiendene dit de faktisk er.

## QA
- En testrigg simulerer tyngdekraftsensoren (`Input.set_gravity`).
- Venstrevipp gir tydelig pendelsving mot venstre, og forovervipp gjør fiendene mindre og
  mørkere (bort fra kameraet).
- Første forsøk svingte for kraftig og er dempet (300 → 220, spark 55 → 40,
  dybde 2,2 → 1,4).

# v7.13 – Rykk nedover: fiendene skvetter og klatrer

## Registrering
- Lineær akselerasjon er akselerometeret minus tyngdekraften.
- Et rykk er over 3,2 m/s² nedover langs skjermens loddrette akse.
- Det kan komme ett rykk per 1,5 s. En bevegelse oppover ignoreres, også tilbakeslaget
  fra samme bevegelse.
- Rykk registreres ikke mens du sikter.

## Hvem som klatrer
- Tunge og pansrede fiender holder seg fast og bare svaier: Tungvekt, Vokter,
  Spinneren og Speilet.
- Modige fiender ler det bort med en erting.
- Engstelige fiender klatrer alltid.
- Rolige og uberegnelige fiender klatrer med sannsynlighet 45–55 %, pluss mer jo
  nærmere linjen de henger.
- En formasjon følger lederens valg.
- Hver fiende har 5 s nedkjøling.

## Reaksjon
- Fiendene som klatrer, skvetter med store øyne og klatrer 60 px opp strengen
  (Snella 95 px, og mer nær linjen).
- Deretter slipper de seg sakte ned igjen, med samme mekanikk som etter en unnamanøver,
  så fordelen er kortvarig.
- Bjelken gynger litt, og det kommer en vinsjlyd og en kort vibrasjon.

## QA
En testrigg simulerer et rykk med `Input.set_accelerometer`. Engstelige og noen rolige
fiender klatret ca. 43 px, mens modige, Tungvekt og noen rolige ble hengende.

# v7.14 – Løse streker i menyen, og strenger etter materiale

## Løse streker på startskjermen
Samme feil som med veggskyggene: hver tittelbokstavs streng arvet transformen til
bokstaven før. Bare den første bokstaven hang riktig, og resten ga løse, skrå streker
midt på skjermen. Transformen nullstilles nå før hver streng.

## Strenger etter hva de bærer

| Fiende | Streng |
|---|---|
| Gelé (Vakt, Splitter, Skygge, Legen) | Farget, flettet snor med myk fletting i shaderen |
| Dykker | Tykk strikk som blir tynnere jo mer den strekkes |
| Snelle | Fint, blankt fiskesnøre |
| Vokter og Speilet | Tvunnet stålkabel (nytt lysbånd 7 med spiralslåtte kordeler) |
| Tungvekt og Spinneren | Ekte stålkjetting |
| Pendel | Ren ståltråd som før |

Kjettingen har ledd hver 7. px, annenhver sett flatt (åpen oval) og fra kanten (kort
stang), med skygge og lys fra øvre venstre. Leddene glir med når kjettingen senkes, og
skjules der kroppen dekker enden.

Spillmekanikken er uendret: alle strenger kan kappes som før.

# v7.15 – Fiendenes karakter

## 1. Innganger
Hver type kommer inn på sin egen måte:
- **Dykker:** faller fort med et sus og spretter på strikken.
- **Tungvekt og Spinneren:** senkes sakte i kjettingen med et stille klirr for hvert
  par ledd, og lander tungt.
- **Snella:** sveiver seg ned.
- **Speilet:** snurrer inn og blinker med metallklang.
- **Skyggen:** toner seg inn på vei ned.
- **Gelé:** lander som før med en bløt dump.

## 2. Humør (lagmoral)
- `Target.morale` går fra −1 (kjepphøy) til 1 (nervøs). Den regnes ut av
  treffsikkerheten og serien din.
- **Nervøse:** svettedrope langs siden, hyppigere blunking, store pupiller og
  bekymrede øyenbryn.
- **Etter et brudd:** laget er kjepphøyt i 5 s, med tunge øyelokk og løftet
  øyenbryn, også langt fra linjen.

## 3. Reaksjoner på hverandre
- Når en fiende dør, følger naboene innenfor 260 px fallet med øynene, og de nærmeste
  skvetter.
- En nykommer blir tatt imot med et blikk.
- Legen ser på den den hjelper.

## 4. Stemmer i toneart
- Tre syntetiserte stavelser: opp (skvetter), erting og ned (dør). De går gjennom to
  formantfiltre, så de høres ut som korte stemmer.
- Hver type har sitt register: små piper og store buldrer. Tonen er alltid et trinn i
  c-moll-skalaen, så et helt kor holder seg stemt.
- Høyst én stavelse per 90 ms. Stemmene erstatter den gamle ertelyden.

## 5. Uttrykk
- Frykt gir store pupiller, mens et plutselig sjokk gir knappenålspupiller.
- Bekymrede øyenbryn når fienden er i siktet, i panikk, blant de siste i bølgen eller
  nervøs.
- **Speilet** er forfengelig: av og til ser det på sitt eget glimt, og en liten stjerne
  blinker.
- **Spinneren** får sprekker i skallet for hvert trinn.

## 6. Personlighet i døden
Fiender som faller får et kryss som øye, og de sukker ved døden. Gelé sukker når den
sprekker.

# v7.16 – Rene øyelokk, personligheter og fargetemaer

## Øyne (rettet etter skjermbilder)
Halvlukkede øyne så rotete ut:
- øyet ble klemt flatt;
- det mørke lokket hadde feil farge;
- øyenbrynene var grå klosser;
- munnen var en taggete strek.

Nå fungerer de slik:
- **Øyet er alltid rundt.** Et øvre lokk, og et lite nedre lokk når fienden myser,
  lukker seg over øyet i fargen rundt det: ringens mørke fordypning, eller kroppen for
  fylte former. Lokket har en fin mørk vippekant, og kanten krummer som et ekte lokk
  (mandelform).
- **Samme lokk for alle tilstander:** blunking, myse, selvgodhet og søvnighet er bare
  hvor langt lokket har kommet.
- **Lukket øye:** en myk, bøyd strek.
- **Øyenbryn:** fine buer. Bekymret gir indre ender opp, sint gir indre ender ned, og
  selvgod gir ett bryn opp. Stolte har svake bryn også i hvile.
- **Munn:** bekymret er en liten nedovervendt bue, og sammenbitt er en kort, stram strek
  med knepne hjørner.
- **Polygonfeil:** lokket ble ikke tegnet fordi polygonet hadde doble hjørner der kanten
  møter buen. Endepunktene er nå utelatt.

## Personligheter
Hver fiende får en personlighet (styrt av temperamentet) og egne ansiktsproporsjoner:

| Personlighet | Kjennetegn |
|---|---|
| Nysgjerrig | ser seg om etter naboer med noen sekunders mellomrom |
| Søvnig | tunge lokk, sjelden og langsom blunking |
| Nervøs | blunker ofte og er aldri helt i ro |
| Stolt | bryn opp og munn med snev av surmuling |
| Sjenert | ser bort fra deg og rødmer når du sikter på den |

- Proporsjonene varierer per fiende: øyestørrelse ±12 %, pupill ±15 %, munnbredde
  ±20 %, og hvilemunn fra surmuling til bredt smil.

## Fargetemaer
- Fem kuraterte temaer: Nordlys (originalen), Dyphav, Ametyst, Skog og Is.
- Hver runde starter i et tilfeldig tema, og dagens utfordring gir samme tema for alle.
  Hver ny bølge glir over i neste tema over 2 s.
- Temaene følger samme regler som grunnpaletten:
  - typene holder avstand i fargetone og lyshet;
  - aldri gull (kulas farge) eller korall (fare);
  - Vokter, Legen og Speilet beholder materialene sine.
- Hvert individ har sin egen nyanse rundt temafargen, med litt variasjon i fargetone,
  metning og lyshet.
- Strenger, knuseeffekter og skygger følger fargen automatisk.

# v7.17 – Skarphet

Grafikken er gjennomgått i høy oppløsning (1080×2400 og 1440×3200).

- **Kropper, strenger, bjelke og lys:** tegnes som vektorgeometri i skjermens egen
  oppløsning. Kantutjevningen gjøres i shaderen (`fwidth`) eller med
  antialiaserte linjer, så de er allerede skarpe.
- **Skrift:** ble rastrert ved 720 px-oppsettets størrelse og så skalert opp,
  og ble da myk på telefoner med høy tetthet. Nå rastreres glyfene i skjermens
  faktiske oppløsning (`FontFile.oversampling` = skjermbredde / 720).
  Kantskarpheten måles ca. 18 % høyere ved 1080 px bredde, og mer ved 1440.
- **MSDF-skrift:** ble prøvd og forkastet. Den variable Manrope-fonten har
  overlappende konturer som gir små feil i «A».
- **Sirkelteksturen for øyne, nagler og perler:** 128 → 256 px, og ringen
  64 → 128 px. Store sirkler på skjermer med høy tetthet beholder da en kant
  på én piksel.

# v7.18 – Drømmende og koselig (A og B)

## A. Lys og farger
- **Fargegradering (`shaders/grade.gdshader`):**
  - Et eget lag over rommet, men under HUD-en.
  - Myk glød rundt lyse partier (ring av prøvepunkter, bare det lyse slipper gjennom).
  - Skyggene løftes mot dyp plomme i stedet for nesten-svart.
  - Høylysene varmes mot krem, metningen senkes 8 %, og det legges på fint filmkorn.
  - Kula (gull) og faresignalet (korall) leses fortsatt tydelig.
- **Rommet:**
  - Veggen er plommemørk.
  - Lampen er varm rav og litt sterkere.
  - Gulvet har samme lune tone.
- **Nytt tema «Skumring»:** myk lavendelblå, salvie og pudderfarger.

## B. Atmosfære
- **Måneskinn:** et høyt, skrått lysfelt fra et vindu utenfor bildet.
  - Vindussprossene tegnes i lyset.
  - Venstre kant ligger i skyggen av en gardin som svaier i trekken.
- **Lysslynge under bjelken:** små kremfargede pærer i buer.
  - Pærene blinker rolig og pulserer i takt med musikken (124 BPM, fra
    avspillingsposisjonen).
  - De blusser opp når noe knuses.
  - Gløden tegnes additivt.
- **Ildfluer:** gulgrønne glimt som driver sakte og blinker via fargerampen, tegnet
  additivt og justert etter enhetsnivå.
- **Dybdeskarphet:**
  - Fjerne strenger er myke (bred, svak strek under en fin).
  - Flere og større bokeh-fnugg: varme i lampelyset, måneblå ellers.

## Rettet underveis
- **Demo-sprettert:** i menyens demo-animasjon kunne fjæra «eksplodere» ut av skjermen
  ved lange bilder (eksplisitt Euler med stiv fjær og bildetid). Den integreres nå
  i faste småsteg (1/120 s), som ved ekte slipp.
- **Kjetting:** leddene tegnes nå som ett lyssatt rørnett med skygge, altså to
  tegnekall per kjetting i stedet for ett per ledd. Tegnekallene gikk fra ca. 1 250
  tilbake til ca. 300.

## Ytelse
Gløden bruker 8 prøvepunkter på sterke enheter, 4 på middels og ingen på svake.
Enhetsnivået senkes av seg selv hvis bildene tar for lang tid.

# v7.19 – Drømmende og koselig (C, D og E)

## C. Materialer
- **Kantlys fra månen:** lysshaderen legger et kjølig, blått kantlys på kantene som
  vender mot vinduet oppe til høyre. Det gjelder gelé, skall og metall.
- **Gelé:**
  - Gløder svakt innenfra (ekstra lys midt på kroppen).
  - Fordypningen i gelé-ringene er lysere (mørkning 0,44 i stedet for 0,55), som
    godteri holdt opp mot en lampe.

## D. Pust og lyd
Mellom bølgene «puster» rommet ut. Pusten glir inn over 0,6 s og ut over 1,2 s:
- lampen dempes 30 %;
- lysslyngen gløder sterkere og blinker langsommere;
- ildfluene blir tydeligere;
- musikken er 2,5 dB lavere og filtreres ned mot 4,2 kHz.

Lyden er også gjort varmere:
- Musikken rulles av over 11 kHz i spill og over 5,2 kHz i menyen.
- Lydeffektene har mykere diskant og et litt større, dempet rom (romklang 0,13).
- Musikken er ikke byttet. Et nytt, drømmende spor krever at vi finner et med fri
  lisens.

## E. Frostet glass
- **Knapper:** gjennomskinnelige glassflater med fin lys kant, radius 18 og myk skygge.
- **Paneler:** pause, innstillinger, statistikk og kuler ligger på en stor frostet
  glassrute (radius 28, myk skygge) over den uskarpe scenen.
- **Innslag:** ruten svinger seg inn med en liten overskyting.

## Rettet
- **Uskarp bakgrunn:** fargefilteret og den uskarpe bakgrunnen bak panelene kunne
  begge bruke skjermkopien i samme bilde. Filteret legges nå bort mens den uskarpe
  bakgrunnen vises, og HUD-en styrer dette, så det også virker når spillet er pauset.
- **Testoppsett:** testrammen pauser nå direkte. Et dobbelttrykk rakk ikke gjennom
  på den trege testmaskinen, og pausemenyen ble da liggende over Game Over. Det var
  en feil i testen, ikke i spillet.

# v7.20 – Tilbake til v7.17-utseendet

Brukeren foretrakk v7.17. Utseendet fra v7.18 og v7.19 er tatt ut:
- fargegradering, lysslynge, måneskinn, ildfluer og plommerommet;
- månekantlyset, pusten mellom bølgene og frostet glass;
- «Skumring»-temaet og de nye lydinnstillingene.

To rene feilrettinger er beholdt:
- **Sprettert-demoen i menyen:** integreres i faste småsteg, så fjæra ikke kan
  «eksplodere» ved lange bilder.
- **Kjettingen:** tegnes som ett lyssatt rørnett i stedet for ett tegnekall per ledd.
  Det gir ca. 330 tegnekall i stedet for ca. 1 250.
