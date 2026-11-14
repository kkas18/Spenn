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
| 1 | Stabilitet, kontroll og jevn flyt (v8.0, v8.0.1) | Ferdig |
| 2 | Lys og liv: nytt visuelt uttrykk, effekter og feiring (v8.1) | Ferdig |
| 3 | Én runde til: mål i sikte, oppdrag som ikke låser seg, nye kuler (v8.2), rettferdige fiender (v8.3) | Ferdig |
| 4 | Farger og figurer: fargeharmoni, kulere og morsommere fiender (v8.4) | Neste |
| 5 | Lyd | Gjenstår |
| 6 | Grensesnitt og tilgjengelighet | Delvis: draglengde, kamerabevegelse og tekststørrelse er inne (v8.3). Hjelpeside gjenstår |
| 7 | Kode og motor | Gjenstår (vurdering under) |
| 8 | Sluttkontroll og levering | Gjenstår |

Rekkefølgen følger det du har bedt om underveis. Etter v8.0 ba du om et visuelt løft og
et spill man vil spille om og om igjen, så det visuelle (trinn 2) og det som får deg til
å ta én runde til (trinn 3) ble flyttet foran lyd, innstillinger og kode. Etter v8.2 ba
du om fargeharmoni og kulere, morsommere fiender. Det er trinn 4 og kommer nå.

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
| 15 | **Oppdragene trakk fra rundens terninger.** Når et oppdrag ble fullført midt i en runde, ble det neste trukket der. Hvilke oppdrag du hadde, endret dermed resten av runden, også i dagens utfordring | Telling av hvert terningkast per sted i koden, i fire like kjøringer | 1 ✔ (v8.0.1) |
| 16 | **Runden avhang av hva appen hadde gjort før.** En kontroll av kryssede snorer ble fordelt i tid etter motorens interne objektnummer | Ny test (`repeat`): to spill på samme frø i samme økt | 1 ✔ (v8.0.1) |
| 17 | **Dagens utfordring var ikke lik på alle telefoner.** Fiendenes valg og partikkeleffektene trakk fra samme terninger, så antall gnister og bildefrekvens endret hva fiendene gjorde | Kodegjennomgang da flere effekter skulle legges til. `repeat` spiller nå det andre spillet med færre effekter | 2 ✔ (v8.1) |
| 18 | **Lange titler ble kuttet i skjermkanten** (for eksempel «Prestasjon · uten riper») | Skjermbilde | 2 ✔ (v8.1) |
| 19 | **Oppdragene kunne låse seg for godt.** Kravene vokste uten tak og ujevnt. Etter ca. ti fullførte oppdrag var flere umulige («bryt 11 formasjoner», «nå bølge 13»), ruten ble aldri ledig, og belønningene stoppet | Tolv botrunder med telling av det oppdragene måler, sammenholdt med kravene per nivå | 3 ✔ (v8.2) |
| 20 | **Fiendene unnvek før varselet rakk å vises.** Det smale blikket er varselet om at en fiende skal flytte seg. Sent i en runde ble reaksjonstiden ganget ned til 0,02–0,06 s. I en målt runde kom 11 % av unnvikelsene under 0,1 s etter at siktet la seg på fienden, og 33 % av unnvikelsene for en kule i lufta | Logging av tiden fra sikte til unnvikelse gjennom en hel botrunde. Ny test i `timing`, som feiler når grensen tas bort | 3 ✔ (v8.3) |
| 21 | **En svak vibrasjon kuttet en sterk.** Den lange vibrasjonen når en sjef går ned eller et liv går tapt, ble erstattet av tikket fra neste treff | Kodegjennomgang (Android spiller bare én vibrasjon om gangen). Ny test i `timing`. Ikke kjent på en telefon | 3 ✔ (v8.3) |

### Valgfritt (forbedringer)

| Område | Observasjon | Trinn |
|---|---|---|
| Ytelse | Skripttiden per bilde er høy i travle felt, og tegning av fiendene er største post | 1 (delvis ✔), 7 |
| Sikte | Siktelinjens prikker er svake og vanskelige å se over lyse kropper | 1 (delvis ✔), 2 |
| Kontroll | Ingen innstilling for draglengde (følsomhet) | ✔ (v8.3) |
| Balanse | Dyktighet ga nesten ingen forskjell i overlevelse i originalen (median 182–196 s på alle nivåer) | 1 (delvis ✔), 3 |
| Tilbakemelding | Treff-stopp er lik for alle treff (40 ms), uansett hvor stort treffet er | ✔ (v8.3) |
| Grensesnitt | Liten tekst i feltet (16–18 px), ingen tekststørrelse-innstilling, ingen egen hjelpeside | Tekststørrelse ✔ (v8.3). Hjelpeside: 6 |
| Tilgjengelighet | Kamerabevegelse kan bare slås av sammen med alt annet («redusert bevegelse») | ✔ (v8.3) |
| Lyd | Effektene er filtrert for å gi plass til musikk som ikke lenger spilles under runden | 5 |
| Kode | `game.gd` (3 300 linjer) og `hud.gd` (3 600 linjer) er store filer | 7 |
| Motor | Godot 4.3. Nyere versjoner finnes | 7 |

## Planen

### Trinn 0 – Sikring og testgrunnlag (ferdig)

- Originalen merket og APK-en lagt på en fast utgivelse.
- Testene spiller på en skjerm formet som en telefon (720 × 1560, som en Galaxy S23), med
  egen lagringsfil og fast frø.
- Nye tester for hel økt, lagring, tid, fysikk og gjentakelse (samme frø gir samme
  runde), og et eget balanseverktøy med
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

### Trinn 2 – Lys og liv (v8.1, ferdig)

Du ba om et visuelt oppløftende uttrykk med bedre design, effekter og animasjoner. Det
som er Spenn, er beholdt: messing-spretterten, figurene i snorer, håndverket i
grensesnittet. Det som er endret, er lyset.

- **Fra mørkt rom til lyssatt scene.** Fem verdener (Blåtime, Dyphav, Nordlys, Skumring,
  Morgen) som skifter per bølge, med drivende fargeslør, lys over linjen og et gulv som
  speiler veggen.
- **Rikere figurer** med kantlys fra verdenen.
- **Rommet svarer:** treff lyser opp veggen, knuste fiender kaster lysglimt, kula lyser.
- **Feiring** ved ryddet bølge og ny rekord (lysflom og konfetti).
- **Tettere siktelinje** og poengtall som spretter inn.
- Lesbarhet er holdt: veggen er aldri lysere enn at hvit tekst, gullkula og figurene
  står klart mot den, tekst i feltet står på et mørkt bånd, og lysglimtene i veggen har
  et tak.

### Trinn 3 – Én runde til (v8.2 og v8.3, ferdig)

Du ba om et spill man spiller om og om igjen. Tre ting er gjort:

- **Mål i sikte.** Resultatskjermen viser oppdraget du var nærmest og neste kule med en
  linje som fylles. Ved hver ny bølge ser du om du ligger foran eller bak rekordrunden.
- **Belønninger som ikke stopper.** Oppdragenes krav har fått et tak, og et oppdrag som
  står uløst i åtte runder, byttes ut (funn 19).
- **Noe å spille seg til.** Tre nye kuler på 600 000, 1 500 000 og 4 000 000 poeng.

Hva oppdragene nå høyst krever, og hva tolv botrunder nådde (svak, middels, god):

| Oppdrag | Tak | Botrunder nådde |
|---|---|---|
| Knus fiender | 400 | 127–1 545 (middels 359–641) |
| Poeng | 150 000 | 18 000–769 000 (middels 132 000–256 000) |
| Nå bølge | 8 | 3–16 (middels 7–9) |
| Veggskudd | 60 | 12–213 (middels 34–82) |
| Overbelastninger | 24 | 7–67 (middels 20–38) |
| Kjedereaksjoner | 15 | 3–58 (middels 8–34) |
| Snorkutt | 12 | 1–97 (middels 2–48) |
| Dobbelttreff | 150 | 32–631 (middels 112–214) |
| Overlev sekunder | 270 | 147–552 (middels 228–333) |
| Bryt formasjoner | 4 | 1–7 (middels 3–5) |

Veien tilbake i spill ble målt og funnet kort nok (1,5 s fra tap til knappene virker,
0,12 s fra trykk til ny runde), så den er ikke endret.

Alt dette er ærlige virkemidler: tydelige mål, rask omstart og belønning for fremgang.
Spillet har ingen kjøp, reklame, varsler eller tidsbegrensede tilbud, og får det ikke.

#### Rettferdige fiender (v8.3)

Et spill man vil spille igjen, må tape rettferdig. Hvert triks fiendene har, ble gått
gjennom med to spørsmål: vises det før det skjer, og bruker det noe du ikke kan se?

| Triks | Slik varsles det | Vurdering |
|---|---|---|
| Unnvikelse (til siden, på tvers, bak en nabo) | Blikket smalner mens fienden ser på siktet ditt. Så peker øyet dit den skal i 0,08–0,14 s, og så går den | **Rettet (funn 20).** Blikket kunne vare 0,02 s. Nå minst 0,16 s |
| Klatring | Kroppen spenner seg og snora knirker før den vinsjer seg opp | I orden |
| Bløff | Et rykk og et smil. Den blir stående | I orden |
| Sammenkrøpet venting | Den skjelver sammenkrøpet i opptil 1,6 s og spretter unna når kula slippes | I orden. Skjelvingen er varselet |
| Rytme | Den går i det øyeblikket du pleier å slippe | I orden. Den bruker hvor lenge du har holdt før, ikke fingeren din nå. Krever fra v8.3 også at den har sett på deg i 0,10 s |
| Kommandørens ordre | Messingtråder fra Kommandøren til dem som får ordre | Uendret med vilje. Ordren kommer mens du sikter, så du ser den før du slipper. En forsinkelse ville lagt den nærmere slippet og gjort den vanskeligere å lese. Svaret er å ta Kommandøren først |
| Leserens steg | Etterbilde der den sto. Etterpå er den sliten i 1,1 s | Uendret med vilje. Dette er evnen dens, og en rask kule nummer to tar den |
| Snik | En annen fiende myser og siger ned mens du holder siktet lenge (over 0,6 s) | I orden |
| Bytte plass | To naboer bytter plass under siktet. Plassen fylles, så ingen slipper unna | I orden |
| Tom lomme | De to nærmeste linjen stuper 0,25 s etter at de har vist det | I orden |
| Spille død | Den kikker med ett øye midt i. Treffer du den da, er den avslørt (+50) | I orden |
| Dytt | Armen lader opp. Treffer du den da, stoppes dyttet (+60) | I orden |
| Lokkedue og synker | Lokkeduen danser i skuddlinjen. Piler under den som synker | I orden |

De lure triksene (snik, bytte, tom lomme, spille død, dytt, ordre og lesing) navngis på
skjermen første gang de brukes i en runde. Fiendene leser siktet ditt, kuler i lufta og
om lomma er tom. Alt det ser du også. De leser aldri fingeren din før du slipper.

De lærer også vanene dine: hvor lenge du pleier å holde, hvilken side du foretrekker, og
om du skyter dit de flykter. Det huskes mellom runder og glemmes delvis ved hver ny
runde, og spillet sier fra når de har lært noe («De har lært rytmen din»). Fiendene blir
skarpere mot en som spiller godt, og mer klønete mot en som sliter. Det er tilpasning og
ikke juks: de får aldri evner som ikke vises.

Balansen ble målt på nytt med de samme åtte frøene før og etter (se målingene). Den er
uendret innenfor spredningen.

### Trinn 4 – Farger og figurer (v8.4, neste)

Du ba om fargeharmoni i det visuelle og om kulere fiender som er morsommere og mer
gøyale.

- **Fargeharmoni.** Fiendenes farger er i dag fem håndplukkede sett som ikke er laget
  sammen med verdenene fra v8.1. De bygges opp på nytt slik at hver verden og figurene i
  den følger én fargeregel, med jevn lyshet og metning, og målt kontrast mot veggen.
  Gull er fortsatt kulas farge og korall farens, og typene skilles fortsatt på form og
  lyshet, aldri bare på farge.
- **Figurene.** Mer personlighet som synes: tilbehør, komiske reaksjoner på det som
  skjer (nesten-treff, en nabo som knuses, å være sist igjen), småpåfunn når de henger i
  ro, og morsommere måter å gå ned på. Alt tegnes i kode som før, og ingenting av det
  skal skjule det du trenger å se.

### Trinn 5 – Lyd

- Effektene tilpasses at det ikke er musikk under runden. Endringene holdes små og kan
  tas tilbake enkeltvis.

### Trinn 6 – Grensesnitt og tilgjengelighet

Gjort i v8.3:

- **Draglengde** (kort, normal, lang). Spillet har én bevegelse (dra og slipp) og ingen
  knapper under runden, så det er ingenting å tilordne på nytt. Draglengden er
  følsomheten.
- **Kamerabevegelse** kan slås av for seg, uten at andre effekter forsvinner.
- **Større tekst** i feltet og på resultatskjermen.
- **Treff-stopp etter tyngde**, og haptikk der den sterkeste vibrasjonen går ferdig.

Gjenstår:

- Hjelpeside.
- Kontroll av at ingenting signaliseres bare med farge eller bare med lyd.
- Skjermbilder på flere skjermformer (16:9, 20:9, nettbrett, brettbar).

### Trinn 7 – Kode og motor

- Fjerne dobbel kode der det gir lavere risiko.
- Vurdere motoroppgradering (se beslutninger).

### Trinn 8 – Sluttkontroll

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
| Risting i tett felt (per kropp per sekund) | 1,4–4,2 (opptil 6,5 px) | 0,01–0,25, median 0,04 over 20 ulike felt (opptil ca. 2 px) |
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
- **Spredningen er stor.** To runder med samme spiller, på ulike frø, kan vare 2 og 9
  minutter. Med 8 runder per nivå er medianen for middels og god spiller usikker med
  omtrent ±40 s.
- Tallene ble målt før v8.0.1. Fra v8.0.1 gir samme frø samme runde, så senere
  endringer kan måles på de samme frøene.

**Minste reaksjonstid (v8.3), de samme åtte frøene før og etter:**

| Spiller | v8.2 | v8.3 |
|---|---|---|
| Svak | 165 s (137–302), bølge 3–4, treff 68 % | 197 s (133–245), bølge 4, treff 71 % |
| Middels | 293 s (228–333), bølge 8, treff 73 % | 283 s (265–400), bølge 7–8, treff 72 % |
| God | 286 s (203–552), bølge 8–9, treff 68 % | 308 s (157–486), bølge 9, treff 68 % |

- **Uendret innenfor spredningen.** Svak og god spiller varer litt lenger, middels litt
  kortere, og treffprosenten er den samme. Vanskelighetsgraden er derfor ikke justert.
- Samme frø gir samme start, men en endring i fiendenes oppførsel endrer alt som skjer
  etterpå. Rundene kan derfor ikke sammenlignes én og én, bare som gruppe.

## Beslutninger

- **Lyssatt scene i stedet for mørkt rom (v8.1).** Det gamle uttrykket var bevisst
  dempet: nesten svart vegg, én lampe, matte emaljefarger. Du ba om noe mer oppløftende.
  Retningen jeg har valgt, er å beholde materialene og figurene og endre lyset. Vil du
  ha det lysere, mørkere eller med andre farger, er hver verden åtte farger i
  `scripts/pal.gd`.
- **Ingen musikk under runden.** Dette ble bestemt i v7.57 og står. Lydarbeidet i trinn 5
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
  nyere Android) hvis spillet skal publiseres der. Vurderes i trinn 7.

## Kjente feil og det som gjenstår

**Kjente feil**

- **Poengtekster kan overlappe hverandre** når to kommer på samme sted (for eksempel
  «Dobbelttreff» og poengsummen).
- **Det nye uttrykket er ikke sett på en telefon.** Farger, lysstyrke og effekter er
  vurdert på skjermbilder fra PC. Skjermer er forskjellige, og bevegelse kan ikke
  bedømmes på stillbilder.
- **Meldinger om «leaked instance» i loggen når spillet avsluttes på PC** mens
  menymusikken spiller. Ufarlig, og gjelder ikke telefon.

**Gjenstår**

- **Ytelse i travle felt.** Skripttiden er 8–12 ms per bilde med 20 fiender på
  utviklingsmaskinen (den varierer med hvor travel maskinen er), så 60 bilder i sekundet
  er på grensen for en mellomklasse-telefon sent i en runde. Det nye bakteppet og
  partiklene i v8.1 regnes av grafikkbrikken og motoren, ikke av spillkoden, men er ikke
  målt på en telefon. Neste poster er tegning av effekter (ca. 3 ms under ild) og
  toppfeltet (ca. 2,5 ms), som begge tegnes på nytt hvert bilde. Tas i trinn 7.
- **Balansen sent i runden er ny** og bare prøvd av botspillere. Gode spillere varer nå
  halvannen gang så lenge som før. Om det er riktig nivå, bør avgjøres av en person som
  spiller, ikke av boter. Vil du ha det strammere, er det to tall å endre (hvor fort
  nedstigningen øker, og hvor mye overload bremses).
- **Prestasjonene** er ikke gjennomgått mot de nye poengnivåene (oppdragene er, se
  trinn 3).
- **En rekke for dager på rad** er vurdert og ikke lagt inn ennå.
- **Hjelpeside** (trinn 6).
- **Større tekst gjelder feltet og resultatskjermen.** Menyer, innstillinger og
  toppfeltet er ikke endret.
- **Lang draglengde når ikke full kraft fra lomma** på de fleste telefoner. Draget må
  da begynne litt høyere. Innstillingen sier fra om det.
- **Det jeg ikke kan prøve herfra:** spillet er ikke kjørt på en fysisk telefon i dette
  arbeidet. Berøring, haptikk, lydnivå i høyttaler og faktisk bildefrekvens er bare
  kontrollert gjennom kode, tester og målinger på PC.
