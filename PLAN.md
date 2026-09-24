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
