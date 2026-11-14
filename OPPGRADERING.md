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
| 3 | Én runde til: mål i sikte, oppdrag som ikke låser seg, nye kuler (v8.2), rettferdige fiender (v8.3), dager på rad (v8.5) | Ferdig |
| 4 | Farger og figurer: fargeharmoni, kulere og morsommere fiender (v8.4) | Ferdig |
| 5 | Lyd | Gjenstår |
| 6 | Grensesnitt og tilgjengelighet: draglengde, kamera, tekststørrelse (v8.3), hjelpeside (v8.5), kontroll av farge og lyd, skjermformer | Ferdig |
| 7 | Kode og motor | Vurdert: ytelse målt per del, motoren blir på 4.3 (se beslutninger) |
| 8 | Sluttkontroll og levering | Ferdig for denne runden (v8.5). Det som gjenstår, er å prøve spillet på en telefon |

Rekkefølgen følger det du har bedt om underveis. Etter v8.0 ba du om et visuelt løft og
et spill man vil spille om og om igjen, så det visuelle (trinn 2) og det som får deg til
å ta én runde til (trinn 3) ble flyttet foran lyd, innstillinger og kode. Etter v8.2 ba
du om fargeharmoni og kulere, morsommere fiender. Det ble trinn 4 (v8.4).

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
| Farger | De samme figurfargene hang i alle fem verdener og var ikke laget sammen med veggen. Den mørkeste figuren hadde 1,7–1,9 i kontrast mot veggen, og en rosa figur lå 36° fra fare-fargen korall | ✔ (v8.4) |
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

### Trinn 4 – Farger og figurer (v8.4, ferdig)

Du ba om fargeharmoni i det visuelle og om kulere fiender som er morsommere og mer
gøyale.

#### Fargeharmoni

Før v8.4 hang de samme blå, grønne og turkise figurene i alle fem verdener. Fargene var
håndplukket i v7 og ikke laget sammen med verdenene fra v8.1. Nå bygges hver verden
etter én regel:

- **Tre fargeroller som er laget sammen:** scenen (veggen), figurene og gullet i kula.
  Figurene er én fargefamilie med sentrum 80–140° fra veggens farge på fargesirkelen, og
  gull holdes unna begge.
- **Fargene settes i OKLCH**, et fargerom som følger øyet. En type har samme lyshet og
  styrke i alle verdener, og bare fargetonen følger verdenen. De dempede typene ligger
  nær veggens farge og trekker seg tilbake, de sterke ligger lengst unna og står frem.
- **Typene skilles på form og lyshet.** Stål (Vokteren), perlemor (Legen) og sølv
  (Speilet) er fortsatt materialer, nesten uten farge.
- **Gull og korall er reservert.** Figurene holder seg mellom grønt og rosa, og veggen
  holder seg på den kalde siden. Lampen kan være varm, siden den er lys og ikke en
  flate. I Morgen er lyset over linjen kjølig, så det korallrøde varselet ved linjen
  ikke forveksles med morgenrosa.
- **Variantene** (sprett-, tvilling- og kjempedykker, hoppe- og kjempering) er nyanser av
  sin egen type, ikke fire faste farger som før. Hver figur har fortsatt sin egen lille
  nyanse, men spredningen er smalere, så typene ikke flyter over i hverandre.

| Verden | Scene | Figurer |
|---|---|---|
| Blåtime | Kobolt | Smaragd og turkis |
| Dyphav | Havgrønt | Orkidé og rosa |
| Nordlys | Nattegrønt | Fiolett |
| Skumring | Fiolett skumring | Akvamarin |
| Morgen | Rosa under en varm sol | Himmelblått |

Målt på fargene spillet bygger, før (v8.3) og etter (v8.4). Kontrast er målt som for
tekst (WCAG) mot midten av veggen. ΔE er avstand i OKLab, og 0,05 er omtrent det øyet
skiller lett.

| Verden | Svakeste kontrast mot veggen | Median kontrast | Nærmeste figur til korall | Figurenes fargespenn | Minste forskjell mellom to typer (ΔE) |
|---|---|---|---|---|---|
| Blåtime | 1,89 → 2,54 | 5,77 → 6,18 | 36° → 100° | 239° → 58° | 0,057 → 0,054 (ringene 0,114 → 0,096) |
| Dyphav | 1,75 → 2,25 | 5,36 → 5,62 | 36° → 52° | 239° → 58° | 0,057 → 0,054 (ringene 0,114 → 0,108) |
| Nordlys | 1,86 → 2,21 | 5,68 → 5,57 | 36° → 73° | 239° → 58° | 0,057 → 0,053 (ringene 0,114 → 0,100) |
| Skumring | 1,91 → 2,53 | 5,85 → 6,31 | 36° → 137° | 239° → 59° | 0,057 → 0,053 (ringene 0,114 → 0,087) |
| Morgen | 1,69 → 2,45 | 5,15 → 6,23 | 36° → 124° | 239° → 59° | 0,057 → 0,053 (ringene 0,114 → 0,100) |

- **Den svakeste figuren (Kommandøren) står klarere** mot veggen i alle verdener.
- **Fargespennet er smalere med vilje.** Det er det som gir harmonien. Prisen er at
  typene ligger litt nærmere hverandre i farge. Minste forskjell er omtrent som før
  (0,053 mot 0,057), og ringtypene, som har samme form, ligger mellom 0,087 og 0,108.
  Typene skilles derfor først og fremst på form og lyshet, slik regelen sier.
- **Veggen er like lys som før** (lysstyrke 0,33–0,39 målt i skjermbildene, mot
  0,34–0,42 i v8.1), og jevnere fra verden til verden.
- **En ny test (`colours`) passer på reglene** i alle fem verdener: kontrast mot veggen
  minst 2,0, ingen figur nærmere enn 45° fra gull eller korall, minste forskjell mellom
  to typer 0,05, og samme lyshet for en type i alle verdener.

#### Kulere og morsommere figurer

Figurene hadde allerede mye personlighet i koden: humør, temperament, damp, tårer,
erting og en kikk når de spiller døde. Det som manglet, var det man ser med en gang. Nå
er dette lagt til:

| Hva | Når |
|---|---|
| Spire, lue med dusk, sløyfe eller propellhatt (propellen snurrer, fort når figuren flytter seg eller faller) | Omtrent hver tredje Vakt |
| Svømmebriller på pannen | Dykkeren, alltid |
| Solbriller på hodet | Skyggen, alltid |
| Stjerner rundt hodet, øyet ruller, munnen vingler | En figur som tåler et treff, i 1,2 s etter et kort grimase (ikke sjefen: den lar seg aldri imponere) |
| Kryss i øyet, tunga ute, stjerner rundt hodet | En figur som er slått ut og faller |
| Svettedråper som spruter | De siste i en bølge |
| «z z» som stiger opp | Søvnige figurer som får være i fred |
| Blunk med et lite glimt og et skjevt smil | Av og til, når figuren får være i fred |
| Øynene lukket av fryd | Når de erter deg |

- **Ingenting av dette skjuler et varsel.** Det smale blikket og øyet som peker dit
  figuren skal, er varslene om at den skal flytte seg (se rettferdige fiender over).
  Blunk, fryd og døsing vises derfor bare når ingenting er siktet mot figuren, ingen kule
  er på vei, den ikke er i ferd med å flytte seg, og den ikke er nær linjen. Hatter og
  briller sitter aldri over øyet, og stjernene viker for øyet som peker.
- **Bare utseende.** Det nye trekker ikke fra rundens terninger og endrer ikke hva
  figurene gjør. Botrundene på faste frø gir nøyaktig samme resultat som i v8.3.
- **Redusert bevegelse:** stjernene og propellen går saktere, og svetten står stille.
- **Ytelse:** alt er tegnet med streker og sirkler i samme tegnekall som ansiktet. Et
  ansikt tar 79 µs å tegne mot 76 µs før (median av tre målinger), og skripttiden per
  bilde i et travelt felt under ild er 7,7 ms både før og etter (median av fire). En
  første versjon med mangekanter kostet merkbart mer og ble skrevet om.

#### Dager på rad og prestasjonene (v8.5)

En ærlig grunn til å komme tilbake: spillet teller dagene du har spilt på rad.

- **Telleren** står ved siden av rekorden på menyen fra to dager på rad («3 dager på
  rad»), og bare så lenge den lever. Når en dag er hoppet over, forsvinner den stille.
- **Første runde på en ny dag** får et kort: «Dag 4 på rad», med lengste rekke under.
- **Sju dager på rad** gir prestasjonen «En hel uke».
- **Statistikken** viser flest dager på rad (på plassen til totale poeng, som står på
  kulesiden).
- **Ærlig:** ingen varsler, ingen påminnelser og ingen meldinger om at du mister noe.
  Det eneste som går tapt når du hopper over en dag, er tallet, og den lengste rekka
  huskes. En klokke som stilles tilbake, endrer ingenting.
- Dagen regnes etter kalenderen, også over månedsskifte, skuddår og nyttår. Testen
  `save` passer på det.

**Prestasjonene** ble gått gjennom mot de nye nivåene etter v8.0. De måler ferdighet
(veggskudd, kjeder, snorkutt, treffprosent) og ikke poeng, så de fleste er upåvirket. To
avhenger av hvor langt du kommer, og begge er innen rekkevidde: «Bølgebryter» (bølge 5)
nås av middels botspiller (bølge 7–8 i median), og «Fem minutter» av god botspiller (308
s i median). De er derfor ikke endret.

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

Gjort i v8.5:

- **Hjelpeside** («Slik spiller du», ?-knappen på menyen): skyting, pause, linjen og
  knutene, fiendenes varsler, flyt og overbelastning, veggskudd og snorkutt, og dagens
  utfordring. Teksten følger «Større tekst».

**Ingenting signaliseres bare med farge eller bare med lyd.** Hvert signal ble gått
gjennom:

| Signal | Farge | I tillegg |
|---|---|---|
| En fiende nær linjen | Korall over figuren | Plassen selv (nær linjen), tråden over linjen svinger mer jo nærmere den er, hjerteslag i lyden, veggen gløder ved linjen |
| Liv | – | Antall knuter i toppfeltet |
| Fiendetype | Fargetone | Form, lyshet og detaljer (nagler, kors, eiker, briller) |
| Stemning (vaktsom, rasende, veteran) | Toning | Et tegn over figuren (!, flamme, stjerne) |
| Triks-merker | Perlens farge | Et lite symbol på perlen |
| Gullfiende | Gull | Blinker i lyshet |
| Leder og mester | Gull | Krone og gullring |
| Tempo mot rekorden | Grønn eller korall | Pil og tekst («1 250 foran rekorden din») |
| Overbelastning og flyt | Glød | Kort med tekst og merke i toppfeltet |
| Ny rekord | Gull | Stempel med tekst |
| Av og på i innstillinger | Gull | Spakens stilling og ordene Av og På |
| Lyder (treff, kutt, tap, nedtelling) | – | Alle har noe som vises samtidig |

Fargeblindhet ble i tillegg simulert (protanopi, deuteranopi og tritanopi) på figurer
nær linjen i alle fem verdener. For rød-grønn fargeblindhet skiller korall-tonen seg
mindre ut i noen verdener, men faren vises også med plass, tråd, lyd og vegg.

**Fire skjermformer kontrollert:** 16:9 (720 × 1280), 20:9 (720 × 1600), nettbrett 3:4
(960 × 1280) og brettbar (1066 × 1280). Meny, felt, innstillinger og resultatskjerm får
plass på alle, uten overlapp. Testen `layout` regner i tillegg på ni telefonformer.

### Trinn 7 – Kode og motor

**Ytelse, målt per del** (skripttid per bilde i et travelt felt på utviklingsmaskinen,
hver del skrudd av og på i omganger, median):

| Del | Tid |
|---|---|
| Hele bildet | 6,8 ms |
| Fiendene (kropp, tau, ansikt) | 2,9 ms, av det ansiktene 1,1 ms |
| Bakteppet (fibre, skygger, tråden) | 1,7 ms |
| Fysikken (to steg à 0,66 ms) | 1,3 ms |
| Toppfeltet og resten av grensesnittet | 0,6 ms |
| Effektlaget | under 0,1 ms |

- Toppfeltet koster mindre enn anslått før (0,6 ms, ikke 2,5), og effektlaget nesten
  ingenting, så det er ikke noe å hente der.
- **Spillet senker effektnivået selv** hvis bildefrekvensen synker under spill
  (`Device`, tre nivåer), og velger et lavere nivå fra start på telefoner med få kjerner
  eller lite minne. En tregere telefon får derfor færre partikler og glorier i stedet for
  hakking.
- Det som er igjen å hente, ligger i tegningen av fiendene og fibrene i bakteppet. Det er
  mange små beregninger per bilde i GDScript. Gevinsten er usikker uten en telefon å måle
  på, så det er ikke gjort.

**Motor.** Godot 4.3 beholdes (se beslutninger). Dobbel kode er ikke fjernet ut over det
som ble gjort underveis: der det gjenstår, er risikoen for å endre oppførsel større enn
gevinsten.

### Trinn 8 – Sluttkontroll (v8.5)

- **Testene:** hele pakken passerer, lokalt og i byggingen på GitHub: `layout`, `colours`,
  `flow`, `save`, `timing`, `physics`, `repeat`, `soak` og botrundene.
- **Spillet er det samme fra v8.3 til v8.5.** Fargene, figurenes utseende, dager på rad
  og hjelpesiden endrer ikke hva som skjer i en runde: botrundene på faste frø gir
  nøyaktig de samme tallene.
- **Balansen** er målt med botspillere fra originalen til i dag (se målingene under).
- **Skjermbilder:** fem verdener, fire skjermformer, alle hovedskjermer.
- **Endringslogg:** [CHANGELOG.md](CHANGELOG.md). **Slik kjører du spillet og testene:**
  [README.md](README.md). **Kjente feil og forbehold:** nederst i dette dokumentet.
- **Ikke kontrollert:** spillet på en fysisk telefon (berøring, haptikk, lydnivå,
  bildefrekvens og hvordan fargene ser ut på en ekte skjerm).

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
  Retningen jeg har valgt, er å beholde materialene og figurene og endre lyset.
- **Farger etter regel, ikke håndplukket (v8.4).** Med 16 typer og fem verdener blir
  80 håndplukkede farger fort ujevne. Nå er hver verden fire fargetoner i `Pal.HARMONY`
  (scene, figurer, lampe og lyset over linjen), og hver type en plass i familien i
  `Pal.KIND_LCH`. Vil du ha en verden varmere, kaldere eller med andre figurfarger, er
  det ett tall å endre, og lyshet og kontrast følger med.
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
- **Motor: blir på Godot 4.3, med én viktig forutsetning.** En oppgradering endrer
  tegning og oppførsel i over 19 000 linjer egen kode og må testes på nytt fra bunnen. For
  APK-en som lastes ned fra GitHub, gir den ingen dokumentert gevinst i dag.
  **Forutsetningen er Google Play.** Play krever støtte for 16 KB minnesider for nye apper
  og oppdateringer som retter seg mot Android 15 eller nyere (se Androids egen side om
  dette). Godot 4.3 har ikke denne støtten. Ifølge Godots forum og prosjektets egne saker
  kom den med Godot 4.5.1 (dette er ikke bekreftet i Godots utgivelsesnotater). Skal
  spillet publiseres på Google Play, må motoren oppgraderes til minst 4.5.1 først, som et
  eget trinn med full testrunde.

## Kjente feil og det som gjenstår

**Kjente feil**

- **Poengtekster kan overlappe hverandre** når to kommer på samme sted (for eksempel
  «Dobbelttreff» og poengsummen).
- **Det nye uttrykket er ikke sett på en telefon.** Farger, lysstyrke og effekter er
  vurdert på skjermbilder fra PC og målt i tall. Skjermer er forskjellige, og bevegelse
  kan ikke bedømmes på stillbilder.
- **Tilbehøret er lite på de minste figurene.** En spire eller propell på en liten Vakt
  er 10–15 piksler i spillets oppløsning. Det synes, men bare så vidt på en liten
  telefon.
- **Meldinger om «leaked instance» i loggen når spillet avsluttes på PC** mens
  menymusikken spiller. Ufarlig, og gjelder ikke telefon.

**Gjenstår**

- **Ytelse på telefon er ikke målt.** Skripttiden er 6,8 ms per bilde i et travelt felt
  på utviklingsmaskinen (fordelt per del i trinn 7). På en mellomklasse-telefon kan det
  være to til tre ganger så mye. Spillet senker selv effektnivået hvis bildefrekvensen
  synker, men om det holder 60 bilder i sekundet sent i en runde, må prøves på en telefon.
- **Google Play krever en nyere motor** (16 KB minnesider, se beslutninger). For APK-en
  fra GitHub gjelder det ikke.
- **Balansen sent i runden er ny** og bare prøvd av botspillere. Gode spillere varer nå
  halvannen gang så lenge som før. Om det er riktig nivå, bør avgjøres av en person som
  spiller, ikke av boter. Vil du ha det strammere, er det to tall å endre (hvor fort
  nedstigningen øker, og hvor mye overload bremses).
- **Større tekst gjelder feltet og resultatskjermen.** Menyer, innstillinger og
  toppfeltet er ikke endret.
- **Lang draglengde når ikke full kraft fra lomma** på de fleste telefoner. Draget må
  da begynne litt høyere. Innstillingen sier fra om det.
- **Det jeg ikke kan prøve herfra:** spillet er ikke kjørt på en fysisk telefon i dette
  arbeidet. Berøring, haptikk, lydnivå i høyttaler og faktisk bildefrekvens er bare
  kontrollert gjennom kode, tester og målinger på PC.
