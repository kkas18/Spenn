# Helhetlig oppgradering (v8)

Målet er en merkbart bedre og mer gjennomarbeidet versjon av Spenn, med samme grunnidé og
identitet. Arbeidet gjøres trinnvis: hvert hovedtrinn ender i en testet, spillbar versjon.
Stabilitet og spillfølelse kommer først, deretter bilde og lyd, så utvidelser.

- **Originalen er tatt vare på:** koden er merket `spenn-v7.57-original` (commit
  `a4113e8`), og APK-en ligger fast på
  [utgivelsen med samme navn](https://github.com/kkas18/Spenn/releases/tag/spenn-v7.57-original).
- **Kort endringslogg:** [CHANGELOG.md](CHANGELOG.md).
- **Slik kjører du spillet og testene:** [README.md](README.md).

## Status

| Trinn | Innhold | Status |
|---|---|---|
| 0 | Sikre originalen, testgrunnlag og målinger | Ferdig |
| 1 | Stabilitet, kontroll og jevn flyt (v8.0) | Ferdig |
| 2 | Spillfølelse: sikte, tilbakemelding, innstilling for draglengde | Gjenstår |
| 3 | Balanse, progresjon og fiender | Gjenstår (grunnbalansen er justert i v8.0) |
| 4 | Bilde og lyd | Gjenstår |
| 5 | Grensesnitt og tilgjengelighet | Gjenstår |
| 6 | Kode og motor | Gjenstår (vurdering under) |
| 7 | Sluttkontroll og levering | Gjenstår |

## Gjennomgangen: hva som ble funnet

Hele prosjektet ble gått gjennom: 18 800 linjer GDScript, alle skjermer, lyd, lagring,
tester og bygg. Påstander er etterprøvd med målinger eller tester, ikke bare lesing. Funnene
er delt i det som **måtte** rettes (feil som påvirker alle som spiller) og det som er
**valgfritt** (forbedringer).

### Måtte rettes

| # | Funn | Hvordan det ble påvist | Trinn |
|---|---|---|---|
| 1 | **Sanntidsklokken hoppet 0,83 s ved hvert treff.** Overload varte 2,5 s i stedet for 5, flyt 3 s i stedet for 7, vindkast og mørke 3 s i stedet for 8–9. Risting, kamerabevegelse og sakte film utløst av treff ble kuttet før de syntes | Måling av varighet i originalen over 3 botrunder (51 overloads: median 2,48 s) | 1 ✔ |
| 2 | **Pausemenyen låste seg** når appen ble lagt i bakgrunnen midt i nedtellingen | Ny økttest (`flow`) | 1 ✔ |
| 3 | **Avbrutt berøring fyrte av et skudd** (sveip fra kanten, anrop) | `flow` | 1 ✔ |
| 4 | **Nytt drag ble avvist i 0,8 s etter hvert skudd**, uten at trykket ble husket | `flow` | 1 ✔ |
| 5 | **Full kraft var utenfor rekkevidde.** Et rett drag fra lomma ga 51–67 % kraft på vanlige telefoner, for lite til å kutte en snor | Utregning av skjermoppsettet for sju telefoner | 1 ✔ |
| 6 | **Siktelinjen viste feil bane etter veggtreff** (opptil 120 px) og uten vind | Ny fysikktest | 1 ✔ |
| 7 | **Snorkutt ble ikke registrert** for raske, skrå skudd (opptil 28 % bom) | Måling over 4 800 skudd | 1 ✔ |
| 8 | **Kropper fløy over bjelken** og inn i toppfeltet | Fysikktest under ild | 1 ✔ |
| 9 | **Synlig risting i tette felt:** 1,4–4,2 ristinger per kropp per sekund, opptil 6,5 px | Fysikktest (28 kropper i ro) | 1 ✔ |
| 10 | **Lagringen var sårbar:** en fil som ble kuttet under skriving, mistet stille prestasjoner, statistikk og beste runder. Feil verdier i fila kunne stoppe oppstarten | Test med avkuttet og skadet fil | 1 ✔ |
| 11 | **Dagens utfordring var ikke lik for alle** (tempo og stemning fulgte ikke dagens frø) | Kodegjennomgang, bekreftet med frøtest | 1 ✔ |
| 12 | **Testene målte et spill ingen spiller:** kvadratisk felt på 1280 × 1280 og alle botskudd på full kraft. Tidligere balansetall gjaldt derfor ikke telefon | Måling av skjermoppsettet i testmodus | 0 ✔ |
| 13 | Testene skrev til spillerens egen lagringsfil | Kodegjennomgang | 0 ✔ |
| 14 | Lyd trakk fra spillets terninger, så en lyd kunne endre hvordan runden rullet | Sammenligning av to like kjøringer bilde for bilde | 1 ✔ |

### Valgfritt (forbedringer)

| Område | Observasjon | Trinn |
|---|---|---|
| Ytelse | Skripttiden per bilde er høy i travle felt, og tegning av fiendene er største post | 1 (delvis ✔), 6 |
| Sikte | Siktelinjens prikker er svake og vanskelige å se over lyse kropper | 1 (delvis ✔), 2 |
| Kontroll | Ingen innstilling for draglengde (følsomhet) | 2 / 5 |
| Balanse | Dyktighet ga nesten ingen forskjell i overlevelse i originalen (median 182–196 s på alle nivåer) | 1 (delvis ✔), 3 |
| Tilbakemelding | Treff-stopp er lik for alle treff (40 ms), uansett hvor stort treffet er | 2 |
| Grensesnitt | Liten tekst i feltet (16–18 px), ingen tekststørrelse-innstilling, ingen egen hjelpeside | 5 |
| Tilgjengelighet | Kamerabevegelse kan bare slås av sammen med alt annet («redusert bevegelse») | 5 |
| Lyd | Effektene er filtrert for å gi plass til musikk som ikke lenger spilles under runden | 4 |
| Kode | `game.gd` (3 300 linjer) og `hud.gd` (3 600 linjer) er store filer | 6 |
| Motor | Godot 4.3. Nyere versjoner finnes | 6 |

## Planen

### Trinn 0 – Sikring og testgrunnlag (ferdig)

- Originalen merket og APK-en lagt på en fast utgivelse.
- Testene spiller på en skjerm formet som en telefon (720 × 1560, som en Galaxy S23), med
  egen lagringsfil og fast frø.
- Nye tester for hel økt, lagring, tid og fysikk, og et eget balanseverktøy med
  botspillere på tre nivåer som spiller slik en person kan (griper lomma, drar så langt
  skjermen tillater, trenger tid mellom skuddene).

### Trinn 1 – Stabilitet, kontroll og jevn flyt (v8.0, ferdig)

Alle funn merket «1 ✔» over. I tillegg:

- **Skuddtakt:** ladetiden styrer takten (omtrent én kule i sekundet), ikke en skjult
  lås. Et fullt magasin kan tømmes raskt når det trengs.
- **Varigheter satt til det som faktisk er spilt:** overload 2,5 s, flyt 3 s, vindkast
  4 s, mørke 3,5 s. Dermed er spillets rytme den samme som før, bare stabil.
- **Overload lades saktere fra bølge 5** (15 % per bølge), så den ikke kjeder seg sammen
  sent i en runde. De fire første bølgene, der en runde vanligvis sluttet i originalen,
  lades som før.
- **Vanskelighetskurven fortsetter å stige sent i runden.** Før flatet nedstigningen ut på
  et nivå ingen runde nådde. Med en sprettert som svarer med en gang, kommer gode
  spillere dit.
- **Siktelinjen** har fått større prikker med mørk kant (et første steg, resten i
  trinn 2).
- **Ytelse:** tegning av ansiktenes prikker, buer og streker er lagt om.

### Trinn 2 – Spillfølelse

- Tydeligere siktelinje (kontrast mot lys bakgrunn).
- Innstilling for draglengde (kort, normal, lang).
- Treff-stopp og kamera etter hvor stort treffet er.
- Gjennomgang av haptikk.

### Trinn 3 – Balanse, progresjon og fiender

- Vanskelighetskurve målt med bot på tre nivåer, 12 frø. Mål: en nybegynner varer omtrent
  som i dag, og dyktighet skal lønne seg tydeligere.
- Gjennomgang av fiendenes triks for rettferdighet: hvert triks skal varsles, og ingen
  reaksjon skal være raskere enn en spiller kan lese.

### Trinn 4 – Bilde og lyd

- Lesbarhet først: viktig informasjon skal aldri skjules av effekter.
- Lyd: effektene tilpasses at det ikke er musikk under runden. Endringene holdes små og
  kan tas tilbake enkeltvis.

### Trinn 5 – Grensesnitt og tilgjengelighet

- Tekststørrelse, styrke på kamerabevegelse og blink, hjelpeside.
- Kontroll av at ingenting signaliseres bare med farge eller bare med lyd.
- Skjermbilder på flere skjermformer (16:9, 20:9, nettbrett, brettbar).

### Trinn 6 – Kode og motor

- Fjerne dobbel kode der det gir lavere risiko.
- Vurdere motoroppgradering (se beslutninger).

### Trinn 7 – Sluttkontroll

- Full testrunde, tabell før og etter, endringslogg og kjente feil.

## Målinger før og etter

Alle tall er fra samme maskin. «Før» er originalen (v7.57) med bare testkrokene lagt til.

| Mål | Før | Etter v8.0 |
|---|---|---|
| Overload, faktisk varighet | 2,48 s median (1,45–3,62 s, kortere jo flere treff) | 2,50 s, alltid |
| Flyt, faktisk varighet | 2,92 s median (1,28–5,37 s) | 3,0 s, alltid |
| Ventetid før nytt drag etter skudd | ca. 0,8 s | 0,05 s |
| Tid fra slipp til skudd i sakte film (0,2×) | 0,26 s | 0,05 s |
| Kraft ved rett drag fra lomma (Galaxy S23) | 51 % | 100 % |
| Siktelinjens avvik etter veggtreff (0,5 s) | 115–123 px | under 0,05 px |
| Snorkutt som ikke ble sett (72° skrå, full kraft) | 28 % | 0 % |
| Risting i tett felt (per kropp per sekund) | 1,4–4,2 (opptil 6,5 px) | 0,01–0,25, median 0,04 over 20 kjøringer (opptil ca. 2 px) |
| Skrivinger til lagring ved rundeslutt | 4–6 | 1 |
| Skadet lagringsfil | Fremgang tapt uten varsel | Forrige fil brukes |
| Tegning av ett ansikt | 165 µs | 92 µs |
| Skripttid per bilde, travelt felt med ca. 20 fiender (median av tre kjøringer) | 13,2 ms | 11,6 ms |

### Balanse (botspiller, median overlevelse)

Botspillere på tre nivåer spiller hele runder på en telefonformet skjerm. Den svake
bommer mer, drar kortere og bruker lengre tid mellom skuddene enn den middels og den gode.
Tallene er median, med laveste og høyeste runde i parentes.

| Spiller | Før (v7.57) | Etter v8.0 |
|---|---|---|
| Svak | 182 s (94–244), bølge 4, 24 runder | 190 s (112–253), bølge 4, 16 runder |
| Middels | 194 s (157–321), bølge 4–5, 8 runder | 289 s (147–430), bølge 7–8, 8 runder |
| God | 196 s (143–395), bølge 5, 8 runder | 326 s (134–578), bølge 9–10, 8 runder |

- **En svak spiller varer like lenge som før.** Forskjellen på 8 s er mindre enn
  spredningen mellom runder. Kulene treffer like ofte (67 % mot 66 %).
- **Dyktighet lønner seg nå.** I originalen varte alle omtrent like lenge, fordi ventetiden
  på 0,8 s og den korte draglengden holdt alle igjen. Nå varer en middels spiller halvannen
  gang så lenge og en god spiller enda litt lenger.
- **Poengsummene øker mer enn overlevelsen** (median for middels spiller 191 000 mot
  50 000), fordi sene bølger har flere fiender og gir flere overloads. Rekorder fra
  originalen blir derfor lettere å slå.
- **Spredningen er stor.** To runder med samme spiller kan vare 2 og 9 minutter. Med 8
  runder per nivå er medianen for middels og god spiller usikker med omtrent ±40 s.

## Beslutninger

- **Ingen musikk under runden.** Dette ble bestemt i v7.57 og står. Lydarbeidet i trinn 4
  gjelder effektene.
- **Ingen pauseknapp.** Fjernet etter ønske tidligere. Pause er dobbelttrykk eller
  Tilbake-knappen, og de tre første rundene sier det.
- **Varighetene følger det som er spilt, ikke det som sto i koden.** Overload på 5 s ville
  gjort spillet mye lettere enn det du kjenner. Vil du ha lengre overload, er det nå ett
  tall å endre.
- **Samme versjonskode som originalen.** Da kan originalen installeres over v8 (og
  omvendt) uten at fremgangen går tapt. Lagringsfila kan leses av begge. Versjonsnavnet
  er endret fra 2.0.0 til 8.0.0, så du ser på telefonen hvilken som er installert.
- **Motor: blir på Godot 4.3 inntil videre.** En oppgradering endrer tegning og oppførsel
  i 18 800 linjer egen kode og gir ingen dokumentert gevinst for dette spillet i dag.
  Det som kan gjøre den aktuell, er krav fra Google Play (støtte for 16 KB minnesider på
  nyere Android) hvis spillet skal publiseres der. Vurderes i trinn 6.

## Kjente feil og det som gjenstår

**Kjente feil**

- **Siktelinjen har få prikker.** De er gjort større og har fått mørk kant i v8.0, men
  banen er fortsatt bare antydet med fem–seks prikker. Vurderes i trinn 2.
- **Poengtekster kan overlappe hverandre** når to kommer på samme sted (for eksempel
  «Dobbelttreff» og poengsummen). Rettes i trinn 4.
- **Like frø gir ikke helt like runder.** To kjøringer med samme frø er like de første
  15–45 sekundene og skiller så lag. Årsaken er ikke funnet (lyd og veggklokke er
  utelukket). Det påvirker ikke spillet, men gjør at balanse må måles over flere frø.
- **Meldinger om «leaked instance» i loggen når spillet avsluttes på PC** mens
  menymusikken spiller. Ufarlig, og gjelder ikke telefon.

**Gjenstår**

- **Ytelse i travle felt.** Skripttiden er fortsatt 11–12 ms per bilde med 20 fiender på
  utviklingsmaskinen, så 60 bilder i sekundet er på grensen for en mellomklasse-telefon
  sent i en runde. Neste poster er tegning av effekter (ca. 3 ms under ild) og toppfeltet
  (ca. 2,5 ms), som begge tegnes på nytt hvert bilde. Tas i trinn 6.
- **Balansen sent i runden er ny** og bare prøvd av botspillere. Gode spillere varer nå
  halvannen gang så lenge som før. Om det er riktig nivå, bør avgjøres av en person som
  spiller, ikke av boter. Vil du ha det strammere, er det to tall å endre (hvor fort
  nedstigningen øker, og hvor mye overload bremses). Tas i trinn 3.
- **Krav til oppdrag og prestasjoner** er ikke justert for at poengsummene er høyere
  enn før. Gjennomgås i trinn 3.
- **Innstillinger** for draglengde, tekststørrelse og styrke på kamerabevegelse, og en
  hjelpeside (trinn 5).
- **Det jeg ikke kan prøve herfra:** spillet er ikke kjørt på en fysisk telefon i dette
  arbeidet. Berøring, haptikk, lydnivå i høyttaler og faktisk bildefrekvens er bare
  kontrollert gjennom kode, tester og målinger på PC.
