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
| 4 | Farger og figurer: fargeharmoni, kulere og morsommere fiender (v8.4), myke farger og figurer med egen karakter (v8.6), svaiing, innganger og erting (v8.7), dybde i 2.5D (v8.8) | Ferdig |
| 5 | Lyd | Gjenstår |
| 6 | Grensesnitt og tilgjengelighet: draglengde, kamera, tekststørrelse (v8.3), hjelpeside (v8.5), kontroll av farge og lyd, skjermformer | Ferdig |
| 7 | Kode og motor | Vurdert: ytelse målt per del, motoren blir på 4.3 (se beslutninger) |
| 8 | Sluttkontroll og levering | Ferdig for denne runden (v8.5). Det som gjenstår, er å prøve spillet på en telefon |
| 9 | Varig moro for voksne: bygg din runde (v8.9), raske økter (v8.10), mål som varer | v8.9 og v8.10 ferdig. Mål som varer er ikke bestilt ennå |

Rekkefølgen følger det du har bedt om underveis. Etter v8.0 ba du om et visuelt løft og
et spill man vil spille om og om igjen, så det visuelle (trinn 2) og det som får deg til
å ta én runde til (trinn 3) ble flyttet foran lyd, innstillinger og kode. Etter v8.2 ba
du om fargeharmoni og kulere, morsommere fiender. Det ble trinn 4 (v8.4). Etter v8.5 ba
du om mykere farger og fiender med hver sin karakter. Det ble v8.6, som en fortsettelse
av trinn 4. Deretter ba du om fiender som svaier og erter, og om mer dybde, som i et
2.5D-spill. Det ble v8.7 og v8.8. Etter v8.8 sa du at spillet er for voksne som kjeder
seg hjemme eller på vei til jobben, og at det ikke blir særlig gøy i lengden. Det er
trinn 9: v8.9 (bygg din runde) og v8.10 (raske økter).

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

### Trinn 4b – Myke farger og ekte figurer (v8.6, ferdig)

Du ba om mykere og mer komfortable farger, og om mye morsommere fiender som hver har sin
egen karakter. De skulle minne om Angry Birds, men være helt egne figurer.

**Grensen jeg har holdt:** ingen figurer, former, farger eller ansikter er hentet fra
Angry Birds. Det som er tatt fra sjangeren, er det generelle: runde, tydelige figurer,
store ansikter som viser hva de føler, kraftige bryn og én tydelig personlighet per type.
Figurene er de samme 16 typene som før, og hver har fått et ansikt som passer det den gjør
i spillet.

#### Mykere farger

**Veggen** er lysere og har omtrent halvparten så sterk farge i alle fem verdener. Hver
verden beholder fargeklangen fra v8.4. Tallene er lyshet og fargestyrke (kroma) i OKLCH,
fra `Pal.STAGE`:

| Del av veggen | Lyshet før → etter | Fargestyrke før → etter |
|---|---|---|
| Toppen | 0,20 → 0,30 | 0,060 → 0,040 |
| Bunnen | 0,34 → 0,44 | 0,100 → 0,055 |
| Lyset over linjen | 0,66 → 0,74 | 0,170 → 0,080 |
| Lampen | 0,87 → 0,90 | 0,105 → 0,060 |

- **Figurene** er lysere og har mindre fargestyrke, nærmere pastell. Vakten går for
  eksempel fra lyshet 0,67 og kroma 0,150 til 0,74 og 0,115.
- **Midten av ringene** er en lys plate (figurens farge blandet med krem) i stedet for et
  mørkt hull, så ansiktet står på lys bunn.
- **En mørk kontur** rundt alle faste figurer. Den regnes i lysshaderen
  (`lit.gdshader`) ut fra avstanden til kanten, som shaderen allerede har. Derfor følger
  den formen når figuren bøyer seg og klemmes, og den koster ingen skripttid.

Målt på fargene spillet bygger, med samme test (`colours`) på v8.5 og v8.6. ΔE er avstand
i OKLab, og 0,05 er omtrent det øyet skiller lett.

| Verden | Svakeste kontrast mot veggen | Minste forskjell mellom typer med samme form (ΔE) | Minste forskjell mellom to typer (ΔE) |
|---|---|---|---|
| Blåtime | 2,51 → 2,51 | 0,073 → 0,085 | 0,054 → 0,043 |
| Dyphav | 2,23 → 2,30 | 0,068 → 0,085 | 0,054 → 0,043 |
| Nordlys | 2,22 → 2,32 | 0,066 → 0,085 | 0,054 → 0,043 |
| Skumring | 2,53 → 2,52 | 0,070 → 0,085 | 0,054 → 0,043 |
| Morgen | 2,46 → 2,48 | 0,066 → 0,084 | 0,054 → 0,043 |

- **Figurene står like klart mot veggen som før**, selv om veggen er lysere, fordi
  figurene også er lysere. Den mørke konturen kommer i tillegg og er ikke regnet med.
- **Typer med samme form ligger lenger fra hverandre** (ringene, sekskantene og de runde).
  Det er de som ellers kunne forveksles.
- **Typer med ulik form kan ligge nærmere hverandre** i farge, fordi fargene er mykere.
  **Testen er derfor endret:** før krevde den 0,05 mellom alle typer. Nå krever den 0,06
  mellom typer med samme form (strengere) og 0,035 mellom de andre (mykere). Typene
  skilles på form og ansikt først og på farge etterpå.
- Ingen figur kommer nærmere gull eller korall enn før (nærmeste er 52–125° unna,
  uendret).

#### Figurer med egen karakter

Hver type har to øyne med pupiller (Skyggen har ett), bryn, en munn og et kjennetegn.

| Type | Karakter | Ansiktet |
|---|---|---|
| Vakt | Nervøs nybegynner | Bekymrede bryn og store fortenner. Klaprer tenner når du sikter på den |
| Tungvekt | Bølla | Ett tykt bryn, underbitt, hoggtenner og skjeggstubb |
| Splitter | I tvil om alt | To ulike øyne og en sydd munn. Det ene øyet vandrer når den er rolig |
| Pendel | Glad i livet | Milde bryn og en nynnende munn. Små noter stiger når den er rolig |
| Dykker | Våghals | Buede bryn, trutmunn og svømmebrillene på pannen. Blåser bobler når den er rolig |
| Vokter | Streng vakt | Rett bryn og hvalrossbart |
| Spinneren | Sjefen | Sinte bryn og et glis fullt av sagtenner |
| Snelle | Avslappet fisker | Late øyelokk og et strå i munnviken |
| Skygge | Alltid kul | Ett øye, et lurt smil og solbrillene på hodet |
| Legen | Snill doktor | Runde messingbriller og et vennlig smil |
| Speilet | Diva | Lange vipper, rosenrøde kinn og trutmunn |
| Pipp | Liten herme-kylling | Store øyne, et lite nebb og røde kinn |
| Pakkis | Lurendreier | Buskete bryn, glugg i tanna og røde kinn |
| Kommandøren | Bjeffer ordre | Sinte bryn under hjelmen og en munn som bjeffer når den gir ordre |
| Leseren | Vet alt best | Ett løftet bryn, monokkel og en snerpete munn |
| Luringen | Sniker | Skjeve blikk og et skjevt glis |

- **Alle ansiktene bygges av de samme delene** og styres av én tabell (`CAST` i
  `target_body.gd`): antall øyne, størrelse, avstand, bryn og munn per type. Å endre en
  figurs ansikt er å endre én linje.
- **Stemningene fra v8.4 gjelder nå hele ansiktet:** redd (munnen blir en «O»), sint
  (snerr og senkede bryn), ler med tunga ute, ertende smil, svimmel med stjerner, slått
  ut med kryss i øynene, blunk og glede.
- **Vaner med bevegelse** (noter, bobler, øyet som vandrer) er av når «Mindre bevegelse»
  er på.
- **Varslene er de samme:** øynene smalner før et stup, og pupillene ser dit figuren skal
  før den glir til siden. Nå vises det i begge øynene.
- **Samlingen** har fått én linje om hver figurs karakter, på norsk og engelsk.

#### Tekst på veggen

Med lysere vegger ble små grå tekster vanskelige å lese: rekorden og oppdragene på
menyen, undertekstene på kortene og linjen om rekorden når en bølge starter. Tekst som
står rett på veggen, har nå en myk mørk glorie (en bred, svak kontur og en tett, mørkere
kontur). Poengene som spretter opp, har fått en mørk kant, og det mørke båndet bak kortene
er tettere.

#### Kostnad

- **Et ansikt koster mer å tegne:** omtrent 82 → 134 µs per tegning (median av seks
  kjøringer for hver versjon på utviklingsmaskinen). Kroppen er uendret (26 µs).
- **For å holde det nede** hentes fargen én gang per tegning, og lokk og bryn har færre
  punkter. Rolige ansikter tegnes dessuten sjeldnere: hvert 2. bilde på høyeste
  effektnivå, hvert 3. på mellomnivået og hvert 4. på laveste. Før var det hvert 2. bilde
  på alle nivåer. Et ansikt som er siktet på, viser et varsel eller et trekk, er truffet
  eller faller, tegnes hvert bilde, så et varsel aldri kommer for sent.
- **Hele bildet** i et travelt felt (skripttid uten tegning på skjermkortet, median av to
  kjøringer for hver versjon): 6,9 → 7,5 ms. Ansiktene alene: 1,1–1,2 → 1,1–1,7 ms per
  bilde.
- **På mellomnivået**, som spillet bytter til av seg selv hvis bildefrekvensen synker,
  koster ansiktene omtrent det samme per bilde som i v8.5 (134 µs hvert 3. bilde mot 82 µs
  hvert 2.). På laveste nivå koster de mindre.

#### Kontroll

- **Hele testpakken passerer.** Botrundene på faste frø gir nøyaktig de samme tallene som
  i v8.5 (frø 1: 270 s og 149 844 poeng, frø 2: 265 s og 172 355 poeng). Fargene og
  ansiktene endrer altså ikke hva som skjer i en runde.
- **Skjermbilder:** alle 16 typene, rolige og i fire stemninger, i Blåtime og Morgen, og
  det samme travle feltet i alle fem verdener før og etter. Hatter, briller, stjerner,
  svette og blunk sitter riktig på de nye ansiktene. I tillegg menyen, samlingen og
  kortene, der teksten nå leses på den lysere veggen.

### Trinn 4c – Liv i rekkene (v8.7, ferdig)

Du ba om at fiendene ikke bare skal komme inn i en pulje, men svaie fram og tilbake og
erte. Før hang de nesten stille. Brisen var svak, og et drag tilbake under kroken stoppet
all svaiing over 10 piksler.

#### Svaiing

- **Ekte bevegelse, ikke bare utseende.** Kroppen styres langs en bane x = A·sin(fase)
  rundt kroken. Styringen tar med det tauet ville trukket den tilbake mot midten, og det
  luften bremser. Treffsonen følger altså kroppen.
- **Hver sin rytme:** 2,8–3,6 sekunder per svai. Rytmen og startpunktet regnes fra
  rundens steg og fiendens plass, så det trekkes ingen terninger. Samme frø gir samme
  runde.
- **En rekke svaier i takt med lederen,** med en bølge bortover rekka. Når en knute ryker,
  trekkes hele flokken mot én takt i 1,8 sekunder, med en bølge tvers over feltet.
- **Bredden:** opptil 17 punkter til hver side på en skjerm 1280 punkter høy. Den
  avhenger av type (Tungvekt 0,45, Vokter 0,5, Spinneren 0,2, Pipp 1,2, Dykker 1,1) og
  temperament (dristig 1,15, forsiktig 0,75). Den bygger seg opp gjennom runden og er
  full etter omtrent fire minutter. En rolig bølge gir 70 %, en vill 115 %.
- **Aldri mer enn naboene gir plass til:** halve avstanden til nærmeste nabo i samme
  høyde, eller til veggen.
- **Slått ut av banen** (truffet, dyttet eller kollidert): da tar tauet over et
  øyeblikk, og svaiingen fortsetter der kroppen er. Den hopper aldri.

#### Innganger

| Type | Inngang |
|---|---|
| De fleste | Svinger inn i tauet fra siden de henger på, ut mot midten, og gynger seg inn i svaiingen |
| Dykker | Stuper ned i en strikk: mykere tau i 1,1 s, dypere dukk og et par sprett |
| Snelle | Ruller langs skinnen fra nærmeste kant mens snøret firer ut |
| Tungvekt, Spinneren | Dunker ned: skinna rister, støv drysser, småfiendene i nærheten skvetter, og den gynger |
| Rekker | Svinger inn etter hverandre fra samme side, som en dansetropp |

#### Erting

- **Bom:** den ballen kom nærmest, ler når skrekken har gått over. Opptil tre naboer
  innen 240 punkter ler etter tur, og den nærmeste dulter borti den første.
- **Tapt knute:** de nærmeste ler med en gang, de andre etter tur, og flokken svaier i
  takt.
- Skallfiendene vugger når de ler, og de myke vrikker.

#### Rettferdighet

- **Stille ved linjen.** Svaiingen er full i den øverste tredjedelen av feltet og avtar
  mot linjen, til 30 % ved 80 % av veien ned. Helt nede (i fare-båndet) henger fienden nesten stille.
  Det er det skuddet som teller mest.
- **Ingen svaiing under varsler:** smalt blikk før et stup, pupiller som ser dit den skal,
  et raskt sprang langs skinnen, en ordre om å stupe, eller mens den kommer inn.
- **Ingen erting når du sikter.** En fiende du sikter på eller som viser et varsel, ler
  ikke og dulter ikke.
- **Mindre bevegelse:** 40 % bredde og halvt så kraftig sving inn. Da er fiendene litt
  lettere å treffe, og dagens utfordring blir bare lik for to spillere med samme
  innstilling.

#### Balanse

Målt med botspillerne på de samme åtte frøene og tre nivåer. Botspilleren skyter alltid
den laveste fienden, og den sikter litt foran en fiende som beveger seg, slik en person
gjør.

| Spiller | v8.6 | Første forsøk | Andre forsøk | v8.7 |
|---|---|---|---|---|
| Svak | 197 s, treff 71 % | 177 s, 68 % | 179 s, 69 % | 193 s, 69 % |
| Middels | 283 s, 72 % | 245 s, 71 % | 302 s, 72 % | 272 s, 73 % |
| God | 308 s, 68 % | 266 s, 68 % | 274 s, 67 % | 273 s, 68 % |

- **Første forsøk** (opptil 22 punkter, halv bredde ved linjen og 60 % bredere under
  jubel) gjorde rundene 10–14 % kortere, med nesten samme treffprosent. Fienden som
  betyr mest, den laveste, svaiet fortsatt, og jubelen gjorde det vanskeligere rett etter
  en tapt knute.
- **Andre forsøk:** stille ved linjen og bare 20 % bredere under jubel.
- **Tredje (v8.7):** opptil 17 punkter, full styrke først etter omtrent fire minutter,
  og roligere allerede fra midten av feltet.
- **Svak og middels spiller varer nå like lenge som før.** God spiller varer 35 s
  kortere med samme treffprosent. Det er innenfor spredningen for gode spillere (±40 s),
  men alle tre målingene lå 30–40 s under. Spillet er laget for å fortsette å presse
  gode spillere, så det er ikke justert mer.

#### Kontroll

- Hele testpakken passerer. `physics` måler 0,00–0,02 rystelser per kropp og sekund i
  tett felt (grensen er 0,5): svaiingen er jevn og regnes ikke som risting. `repeat`
  viser at samme frø fortsatt gir samme runde.
- En egen måling av svaiingen alene ga bredder innenfor 1 punkt av målet og ingen rykk
  (største andrederivert 0,04 punkter per bilde²).

### Trinn 4d – Dybde (v8.8, ferdig)

Du ba om mer dybde, som i et 3D-spill, men i 2.5D. Under panseret er spillet fortsatt 2D,
med samme styring og samme fysikk. Bildet viser at fiendene henger på ulik avstand, og at
rommet har lag. Dette valgte du: de bakerste er litt mindre, og treffsonen følger alltid
det du ser.

**Hva som fantes fra før:** hver fiende hadde en tilfeldig dybde (−0,85 til 0,85). Den
gjorde fienden opptil 12 % større eller mindre på skjermen, mørkere bak og lysere foran,
og ga skyggen på veggen riktig avstand. Treffsonen fulgte ikke med. Telefonens helning
flyttet allerede verden og ett lag med fjerne tråder.

#### Tre rader

| Rad | Andel | Størrelse og treffsone | Utseende |
|---|---|---|---|
| Bakerst | 28 % | 90 % | Henger fra en egen skinne bak og under den fremste. Glir inn i rommets dis (tar farge fra veggen), tynnere tau |
| Midten | 42 % | 100 % | Som før. Vokteren og Spinneren (skjoldene hører til midten) og alle rekker |
| Fremst | 30 % | 107 % | Litt lysere, skyggen på veggen faller lenger ut og mykere |

- **Samme høyde:** en fiende på den bakre skinnen har så mye kortere tau at den henger
  akkurat der den ellers ville hengt. Den når ikke linjen tidligere.
- **Snittstørrelsen er nesten den samme** som før (under 1 % mindre): andelene og
  størrelsene veier hverandre opp.
- **Tau i ulike rader krysser hverandre fritt.** Kroppene kolliderer fortsatt med alle, så
  kjedereaksjoner og trengsel virker som før.
- **Skyggen på veggen** var riktig fra før: en fiende langt fra veggen (foran) kaster
  skygge lenger ut og mykere. (I svaret mitt til deg skrev jeg det motsatt for bakerste
  rad. Det er rettet her, og spillet følger det som er riktig.)

#### Lag som beveger seg hver for seg

Hvor mye hvert lag flytter seg, der feltet du skyter i er 1:

| Lag | Når telefonen vippes | Når du sikter (opptil 8 punkter) |
|---|---|---|
| Veggen og de fjerne trådene | 0,4 | +0,9 (med siktet) |
| Bakerste rad og den bakre skinnen | 0,88 | +0,22 |
| Midten (feltet, spretterten, kulene) | 1 | 0 |
| Fremste rad | 1,08 | −0,12 |
| Støvkornene nærmest deg | 1,5 | −0,6 (mot siktet) |

- **Feltet står stille når du sikter.** Spretterten og kulene flytter seg ikke under
  fingeren. Det er rommet rundt som glir, som om du lener deg for å se langs skuddet.
- **Bare tegningen flytter seg.** Treff og poeng regnes der fienden er. Når telefonen
  vippes, svinger en fiende også inntil 4 % i størrelse (før 12 %), bare for øyet. Bakerste rad kan
  være tegnet opptil om lag 3 punkter fra treffsonen når telefonen vippes helt ut, og
  2 punkter når du sikter (vippingen holdes stille mens du sikter).
- **Støvkornene:** seks store, myke korn uten skarpe kanter, litt lysere i lampens lys. På
  laveste effektnivå er de av.
- **Lys:** fiendene nær lampen er opptil 6 % lysere.

#### Rettferdighet og innstillinger

- **Mindre bevegelse** og **Kamerabevegelse av** skrur av lagbevegelsen når du sikter.
  Med Mindre bevegelse driver støvkornene saktere. Vippingen har sin egen bryter, som før.
- **Testen `repeat` er endret:** den andre runden har nå oppdrag som ikke kan nås på 100
  sekunder (270 sekunder, bølge 8, 150 000 poeng). Før brukte den kjeder, kutt og knuste
  rekker på nivå 30, men de har så lave tak at radene gjorde at testskuddene nådde ett av
  dem. Det testen skal vise, at samme frø gir samme runde, er uendret.

#### Balanse

Målt med botspillerne på de samme åtte frøene og tre nivåer:

| Spiller | v8.6 | v8.7 | v8.8 første forsøk | v8.8 |
|---|---|---|---|---|
| Svak | 197 s, treff 71 % | 193 s, 69 % | 191 s, 69 % | 215 s, 69 % |
| Middels | 283 s, 72 % | 272 s, 73 % | 225 s, 70 % | 248 s, 73 % |
| God | 308 s, 68 % | 273 s, 68 % | 330 s, 68 % | 348 s, 68 % |

- **Første forsøk** hadde to små skjevheter: bakerste rad hang 17 punkter lavere, fordi
  kroken satt på den bakre skinnen, og snittstørrelsen var 1,6 % mindre. Begge er
  rettet: tauet er kortere med det samme, og fremste rad er 7 % større.
- **v8.8:** snittet av de tre nivåene er 270 s, mot 263 s i v8.6, og treffprosenten er den
  samme. Nivåene flytter seg i hver sin retning mellom målinger. Det er tilfeldigheter:
  med åtte runder per nivå kan medianen for ett nivå variere 15–25 %. Det er mer enn
  ±40 s, som jeg anslo tidligere.

#### Ytelse

Den vanlige målingen per del spiller med skudd, så to versjoner får ulikt antall
fiender og effekter (12 mot 21 fiender i samme måling). Til sammenligning er derfor et
fast felt brukt: de samme 21 fiendene holdt der de henger, ingen skudd, median
skripttid per bilde over 600 bilder, beste av tre, versjonene i omganger.

| Versjon | Skripttid per bilde |
|---|---|
| v8.6 | 9,0 og 8,5 ms |
| v8.7 | 9,1, 8,5, 8,8, 8,3, 8,9 og 8,9 ms |
| v8.8 | 9,3, 8,5, 8,9 og 9,1 ms |

- **Svaiing og dybde koster rundt 0,2 ms per bilde,** innenfor støyen.
- **Per fiende:** den nye fargeberegningen koster 1,7 µs mer per kall, og
  lagoppdateringen 14 µs per bilde for hele feltet.
- **Én feil er rettet underveis:** disens farge ble slått opp for hver fiende ved hver
  fargeberegning, og det kostet 0,6 ms per bilde. Den slås nå opp én gang per bilde.

### Trinn 9 – Varig moro: bygg din runde (v8.9, ferdig)

Etter v8.8 sa du at spillet er ment for voksne som kjeder seg hjemme eller på vei til
jobben, at det må være et profesjonelt produkt, og at det ikke blir særlig gøy i lengden.
Jeg foreslo tre steg, og du ba meg starte med de to første:

1. **Bygg din runde (v8.9):** du velger én av tre oppgraderinger etter hver bølge, og
   flere av dem endrer hvordan du spiller.
2. **Raske økter (v8.10):** hurtigstart og «fortsett der du slapp», så en kort tur til
   jobben holder til en god runde.
3. **Mål som varer:** opplåsinger, en ukentlig utfordring og et resultatkort du kan dele.
   Dette er ikke bestilt ennå.

**Hvorfor dette først:** i en runde som varer flere minutter, er det valgene som gjør at
to runder blir ulike. Før kom én tilfeldig oppgradering per bølge, og de fleste var tall
(15 % raskere lading, én kule til). Nå bestemmer du retningen selv, og flere av valgene
endrer hvordan du sikter og hva du sikter på.

#### Valget

- **Når:** 1,4 sekunder etter at en bølge er renset (spilltid, etter feiringen) kommer
  tre kort over et dempet felt.
- **Runden står stille mens du velger.** Ingen tid går i runden, pausen før neste bølge
  teller ikke, ingenting kommer, og spretterten kan ikke trekkes. Rommet lever videre bak
  panelet: kuler som er i lufta, flyr ferdig, og konfettien faller.
- **Et trykk i det første halve sekundet velger ingenting,** så et trykk som var ment for
  siste skudd, ikke velger for deg.
- **Minst ett av kortene endrer hvordan du spiller** (Splitt, Rikosjett, Smell, Fokus,
  Stor kule, Frost eller Vegg-mester), så lenge noen av dem er igjen.
- **Kortet** viser ikon, navn og hva oppgraderingen gjør med tall. Øverst til høyre står
  «NY» eller «NIVÅ 2», med en prikk for hvert nivå: de du har, den du får (lys) og de som
  er igjen. Når du allerede har en oppgradering som passer, står det nederst med en
  stjerne («Passer med Splitt»).
- **Valgt:** ikonet flyr fra kortet til raden øverst til venstre, og spillet fortsetter
  der det sto. Pausen før neste bølge er da om lag 1,5 sekunder.
- **Ny knute** tilbys bare når du har mistet en, som før.

#### De åtte nye

| Oppgradering | Nivå 1 | Nivå 2 |
|---|---|---|
| Splitt | Kulas første treff deler den i to | I tre |
| Rikosjett | Når kula skyter ned en fiende, hopper den videre til den nærmeste innen 320 punkter | To hopp |
| Smell | En fiende du skyter ned, smeller: den nærmeste innen 100 punkter får et treff og dyttes unna | De to nærmeste innen 130 punkter |
| Frost | Et treff fryser fienden og de som henger innen 70 punkter i 1,5 s | 100 punkter, 2,5 s |
| Fokus | Tiden går i 80 % fart mens du sikter | 70 % |
| Stor kule | Kulene er 4 punkter større i radius (17 mot 13), lading 10 % saktere | 8 punkter større, 21 % saktere |
| Vegg-mester | Kulene mister ikke fart i veggen, veggskudd gir dobbelt | (ett nivå) |
| Glasskanon | +1 på multiplikatoren, én knute mindre resten av runden | (ett nivå) |

Detaljer som er valgt med vilje:

- **Splitt:** bitene er litt mindre kuler (radius 10) fra samme skudd. Skuddet teller
  som treff eller bom først når alle bitene er ute av spill. Én bit går mot midten av
  feltet, der fiendene er. Bitene deler seg ikke igjen.
- **Rikosjett:** kula sikter dit fienden vil være når den kommer fram, med fall og
  bevegelse regnet med, og flyr minst 950 punkter per sekund.
- **Smell:** treffene fra smellet regnes som kjedereaksjon og gir poeng som det. De
  smeller ikke videre, så ett skudd kan ikke rydde hele feltet.
- **Frost:** en frossen fiende kan treffes og svinger av et treff, men synker ikke,
  unnviker ikke, glir ikke langs skinnen, svaier ikke og erter ikke. Den er blålig og tiner
  de siste 0,4 sekundene. Et varsel den var i gang med, avbrytes, så den varsler på nytt
  før den flytter seg. **Etter at den har tint, tåler den frost i 3 sekunder,** så de
  laveste kan ikke holdes frosset hele tiden. Spinneren rister det av seg.
- **Fokus:** farten glir ned og opp over om lag 0,2 sekunder, så et raskt skudd knapt
  bremses. Overbelastning og flyt måles i ekte tid, som før.
- **Stor kule og Vegg-mester** gjelder også siktelinjen, så den viser sprett der kula
  faktisk spretter. Kula i lomma er også større.
- **Glasskanon:** knuten forsvinner med det samme (aldri den siste). En knute du vinner
  tilbake med poeng eller Ny knute, fyller bare opp til to. Der den tredje knuten var,
  vises en glassrute.
- **Gjennomslagskuler** (og alle kuler under overbelastning) deler seg ikke og hopper
  ikke videre. De går gjennom alt fra før.

#### Passer sammen

Disse parene står på kortet når du har den andre: Splitt og Smell, Splitt og Rikosjett,
Splitt og Stor kule, Smell og Frost, Frost og Skarp egg, Vegg-mester og Langt sikte,
Vegg-mester og Magnetkule, Fokus og Langt sikte, Fokus og Skarp egg, Glasskanon og Lang
flyt, Glasskanon og Superlading, Rikosjett og Magnetkule, Stor kule og Tunge kuler.

#### Tester

- **Ny test, `perks`:** et renset felt åpner valget med tre ulike kort, minst ett som
  endrer spillet. Runden står stille (ingen tid, ingen skudd), et trykk i første øyeblikk
  velger ingenting, og kortet du velger, blir tatt, går til raden, og neste bølge kommer.
  Deretter prøves hver av de åtte på fiender hengt opp for hånd: bitene fra Splitt,
  hoppet fra Rikosjett (og ingen hopp etter et treff som ikke dreper), treffet fra Smell
  (og ikke på en som henger lenger unna), Frost (synker ikke, tiner etter 1,5 s, tåler
  ikke ny frost med en gang, og synker igjen), størrelse, lading og vegg for Stor
  kule og Vegg-mester, knuten og multiplikatoren for Glasskanon, og farten under sikting
  for Fokus.
- **Alle tester** som spiller runder, velger automatisk (første kort). Botspilleren
  velger det som endrer spillet først og Glasskanon sist.
- **Testen fant en feil i selve testen, ikke i spillet:** fiendene som ble hengt opp,
  spratt fortsatt i tauet da kula kom. De henger nå i ro før skuddet.

#### Balanse

Målt med botspillerne på de samme åtte frøene og tre nivåer (median overlevelse). Det tok
fem målerunder å komme hit, og hver av dem lærte meg noe:

| Spiller | v8.8 | 1. Første forsøk | 2. Oppgraderinger dempet | 3. Uten tak | 4. Fokus dempet | 5. Knutene (v8.9) |
|---|---|---|---|---|---|---|
| Svak | 215 s | 252 s | 235 s | 235 s | 250 s | 245 s |
| Middels | 248 s | 3 av 6 til taket | 3 av 5 til taket | 445 s | 521 s | 465 s |
| God | 348 s | ikke målt | ikke målt | 412 s | 304 s | 304 s |

«Til taket» betyr at roboten fortsatt var i live etter 12 minutter, der målingen stopper.
Runde 1 og 2 ble stoppet før de gode spillerne var målt, fordi svaret allerede var klart.

1. **Første forsøk** var altfor lett for en middels spiller. Frost kunne holde de laveste
   fiendene frosset hele tiden (man skyter jo alltid den laveste), og Rikosjett ga nesten
   sikre ekstra treff.
2. **Oppgraderingene dempet:** Frost varer kortere, og en fiende som har tint, tåler frost
   i 3 sekunder. Rikosjett hopper bare etter et drap og har kortere rekkevidde, og Smell
   treffer én (to på nivå 2). Den svake spilleren ble som i v8.8, men middels gikk
   fortsatt til taket.
3. **Uten tak:** synkefarten sluttet å stige etter om lag sju minutter, og et godt bygg
   holdt unna i det uendelige. Nå stiger den videre, og feltet rommer flere fiender.
   Rundene ender, men middels holdt fortsatt ut nesten dobbelt så lenge.
4. **Hvem bærer runden?** De samme fire middels-rundene ble spilt uten én oppgradering om
   gangen. Uten Smell og uten Frost var de like lange, uten Fokus klart kortere (tre av
   fire). Den som sikter jevnt og rolig, spilte i praksis hele spillet i sakte film.
   Fokus er dempet fra 65 og 50 % til 80 og 70 % fart, og stigningen etter taket er
   brattere. Middels ble likevel ikke kortere, og god ble kortere: målingene spriker
   mer enn før.
5. **Knutene:** en sen runde med oppgraderinger scoret om lag 800 poeng i sekundet, så en
   tapt knute kom tilbake på under to sekunder. Nå koster den mer for hver bølge.

**v8.9:** svak 245 s (+14 %), middels 465 s (+88 %) og god 304 s (−13 %), mot 215, 248 og
348 s i v8.8. Snittet av de tre er 338 s, mot 270 s.

- **Knuteprisen flyttet lite.** De fleste svake og gode rundene ender av at tre fiender
  når linjen tett etter hverandre, ikke av at knutene tar slutt.
- **Den gode botspilleren varer kortere enn i v8.8** fordi den alltid velger de nye
  oppgraderingene først. I v8.8 fikk den ofte Skarp egg og kuttet 40–180 snorer per
  runde, nå 0–8.
- **Den middels botspilleren passer de nye oppgraderingene best.** Den sikter jevnt og
  treffer godt, og hvert treff gir mer.
- **Jeg har stoppet justeringen her.** Endringene er riktige i seg selv: ingen tak, frost
  med hvile og knuter som koster mer sent i runden. Videre finjustering mot roboter
  blir å jage støy. Det viktigste neste signalet er hvordan det føles når du spiller selv.
- **Målingene spriker mer enn før.** Med oppgraderinger tar en runde enten av eller
  ender tidlig, så åtte runder per nivå er få. Medianen for ett nivå kan flytte seg
  20–30 % mellom to målinger uten at noe er endret i spillet.
- **Botspillerne er ikke folk.** De velger alltid på samme måte (det som endrer spillet
  først) og skyter alltid den laveste fienden. Den gode treffer sjeldnere enn i v8.8 (om
  lag 58 mot 68 %), trolig fordi den skyter så raskt at mange skudd går mot fiender som
  bitene fra Splitt allerede har tatt. Tallene viser retningen, ikke hvor lenge du vil
  vare.

#### Ytelse

I det faste, travle feltet (21 fiender holdt der de henger, ingen skudd) er skripttiden
per bilde den samme: 6,95, 6,96 og 6,92 ms i v8.8 og 7,04, 6,94 og 6,90 ms i v8.9, målt
i omganger på samme maskin. Med Splitt kan det være opptil ti kuler i lufta (før seks).
Hver kule sjekkes mot hver fiende, og det koster lite.

### Trinn 9b – Raske økter (v8.10, ferdig)

Det andre steget du ba om: spillet skal passe til en kort tur til jobben eller en pause.
To ting gjør det: en runde kan tas opp igjen der den slapp, og den rolige starten kan
hoppes over.

#### Fortsett der du slapp

- **Når:** runden lagres hver gang en bølge begynner (fra bølge 2), også når den tas opp
  igjen eller begynner med Hurtigstart.
- **Hva:** bølgen og klokka (som styrer hvor vanskelig det er), poengene, knutene,
  oppgraderingene og rekkefølgen i raden, og det runden har talt opp til oppdrag,
  statistikk og rekordtempo. Fiendene lagres ikke: bølgen begynner på nytt.
- **En knute du mister, lagres med det samme.** Å gå til menyen gir aldri en knute
  tilbake, og poengene fra bølgen du var i, er tapt. Det er altså ingen fordel å avbryte.
- **Slettes:** i det siste knute ryker (før resultatene), og når en ny vanlig runde
  begynner. Dagens utfordring lagres ikke og rører ikke den lagrede runden.
- **På menyen:** en gullknapp over Dagens utfordring, «Fortsett runden», med bølge,
  poeng og knuter. Tittelbokstavene henger da litt høyere, så knappen får plass.
  Teksten nederst blir «Dra for ny runde».
- **Ved oppstart:** bølgens tittel sier «Fortsetter der du slapp», og ingenting henger
  inn før den har bleknet.
- **Lagringsfila:** runden ligger i en egen del av fila. En lagring som er skadet, eller
  som har et annet oppsett, blir ikke tilbudt.

#### Hurtigstart

- **Låses opp** når du har nådd bølge 6 én gang. Da kommer en bryter ved siden av Dagens
  utfordring, og valget huskes.
- **En runde med Hurtigstart** begynner på bølge 3, så langt ute som en middels spiller
  normalt er der: 65 sekunder. Målt med botspillerne begynner bølge 3 etter 94 sekunder
  for en svak spiller, 64 for en middels og 52 for en god (median av åtte runder). Du
  velger to oppgraderinger før første fiende («Hurtigstart · 1 av 2»).
- **Rettferdig:** de to oppgraderingene er de du ellers ville valgt etter bølge 1 og 2.
  Poengene fra de to bølgene får du ikke. Runden teller som en vanlig runde.
- **Gjelder ikke Dagens utfordring.** Bryteren er dempet når den er valgt.

#### Tester

- **Ny test, `sessions`:** runden lagres når bølge 2 begynner, med poeng, knuter og
  oppgradering. En knute som ryker, lagres med det samme. Spillet lukkes og åpnes igjen
  med lagringsfila, menyen viser «Fortsett runden», og runden tas opp igjen på bølge 2
  med de samme tallene og klokka der bølgen begynte. Ingenting henger inn før tittelen
  har bleknet. Lagringen slettes når runden tapes og når en ny runde begynner. Dagens
  utfordring verken lagrer eller sletter, og en skadet lagring blir ikke tilbudt.
  Hurtigstart er låst før bølge 6, gir to valg og bølge 3, og gjelder ikke Dagens
  utfordring.

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

- **En lagret runde fortsetter fra starten av bølgen (v8.10).** Å lagre hele feltet midt i
  en bølge (opptil 28 fiender med fysikk, humør og planer) ville vært skjørt. Å begynne
  bølgen på nytt er enkelt og rettferdig: du mister poengene fra den bølgen, og en knute
  du mistet, er fortsatt borte.
- **Hurtigstart teller som en vanlig runde (v8.10).** Du får de to oppgraderingene du
  ellers ville valgt etter bølge 1 og 2, men ikke poengene fra dem. Det er altså ingen
  snarvei til rekorden, bare til spenningen.
- **Du velger selv, men minst ett kort endrer spillet (v8.9).** Tre tilfeldige kort kunne
  gitt tre tall-oppgraderinger på rad, og da blir valget kjedelig. Med minst én som
  endrer hvordan du spiller, blir to runder ulike.
- **Runden står stille mens du velger (v8.9).** Valget skal være et valg, ikke et kappløp
  mot klokka. Rommet lever videre bak panelet, så det føles ikke som en pause.
- **Vanskelighetsgraden har ikke lenger tak (v8.9).** Med oppgraderinger å velge klarte en
  god runde å holde unna i det uendelige når synkefarten nådde taket etter om lag sju
  minutter. I et endeløst spill skal det alltid bli vanskeligere til slutt, så farten
  fortsetter å stige etter taket, saktere enn før.
- **Lyssatt scene i stedet for mørkt rom (v8.1).** Det gamle uttrykket var bevisst
  dempet: nesten svart vegg, én lampe, matte emaljefarger. Du ba om noe mer oppløftende.
  Retningen jeg har valgt, er å beholde materialene og figurene og endre lyset.
- **Farger etter regel, ikke håndplukket (v8.4).** Med 16 typer og fem verdener blir
  80 håndplukkede farger fort ujevne. Nå er hver verden fire fargetoner i `Pal.HARMONY`
  (scene, figurer, lampe og lyset over linjen), og hver type en plass i familien i
  `Pal.KIND_LCH`. Vil du ha en verden varmere, kaldere eller med andre figurfarger, er
  det ett tall å endre, og lyshet og kontrast følger med.
- **Egne figurer, ikke en kopi (v8.6).** Du ba om fiender som minner om Angry Birds.
  Jeg har tatt det sjangeren har felles: runde figurer, store ansikter, kraftige bryn og
  én personlighet per type. Ingen figurer, former, farger eller ansikter er hentet fra det
  spillet. Det holder Spenn som sitt eget spill og unngår problemer med opphavsrett.
- **Rolige ansikter tegnes sjeldnere, travle hvert bilde (v8.6).** Rikere ansikter koster
  mer å tegne. I stedet for å kutte i ansiktene tegnes de rolige på nytt sjeldnere på
  lavere effektnivå, mens alt som er et varsel, tegnes hvert bilde.
- **Dybden er mest for øyet, men treffsonen følger størrelsen (v8.8).** Lagene flytter
  bare tegningen, med høyst noen få punkter, så det du treffer og får poeng for, ikke
  avhenger av hvordan telefonen holdes. Størrelsen på radene er derimot ekte: det var
  ditt valg at de bakerste skulle være litt vanskeligere å treffe. Snittstørrelsen er
  holdt omtrent lik, så spillet ikke blir vanskeligere totalt.
- **Svaiingen er ekte (v8.7).** En svaiing som bare var tegnet, ville flyttet fienden bort
  fra treffsonen. Den er derfor en del av fysikken og gjør spillet vanskeligere. Det er
  veid opp med stille fiender ved linjen og en langsom oppbygging (se trinn 4c).
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

- **Resultatskjermen viser ikke hvilke oppgraderinger runden hadde.** Det passer å ta med
  sammen med resultatkortet du kan dele (steg 3).
- **Gjennomslagskuler deler seg ikke og hopper ikke videre** (Splitt og Rikosjett). Det
  gjelder også alle kuler under overbelastning.
- **En frossen Skygge eller en fiende med spøkelsesmerke** blir værende som den var da
  den frøs, også usynlig, til frosten slipper. Den synker heller ikke så lenge.
- **Balansen er målt med botspillere som alltid velger på samme måte** (det som endrer
  spillet først, Glasskanon sist) og som ikke bruker veggskudd med vilje. Folk velger
  annerledes, så tallene viser retningen, ikke hvor lenge du vil vare.
- **Poengtekster kan overlappe hverandre** når to kommer på samme sted (for eksempel
  «Dobbelttreff» og poengsummen).
- **Det nye uttrykket er ikke sett på en telefon.** Farger, lysstyrke og effekter er
  vurdert på skjermbilder fra PC og målt i tall. Skjermer er forskjellige, og bevegelse
  kan ikke bedømmes på stillbilder.
- **Ansiktene er små på de minste figurene.** På Pendelen, Dykkeren og små Vakter er
  øynene 5–6 piksler i radius i spillets oppløsning, så bryn og munn er bare noen få
  piksler på en liten telefon. Uttrykket leses mest på øynene.
- **Bakerste rad kan være tegnet noen få punkter fra treffsonen** når telefonen vippes
  helt ut (om lag 3 punkter) eller når du sikter (om lag 2 punkter). Det er valgt for at
  treff ikke skal avhenge av hvordan telefonen holdes.
- **Tilbehøret er lite på de minste figurene.** En spire eller propell på en liten Vakt
  er 10–15 piksler i spillets oppløsning. Det synes, men bare så vidt på en liten
  telefon.
- **Meldinger om «leaked instance» i loggen når spillet avsluttes på PC** mens
  menymusikken spiller. Ufarlig, og gjelder ikke telefon.

**Gjenstår**

- **Ytelse på telefon er ikke målt.** Skripttiden er 7,5 ms per bilde i et travelt felt
  på utviklingsmaskinen etter v8.6 (6,8 ms i v8.5, fordelt per del i trinn 7). På en mellomklasse-telefon kan det
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
