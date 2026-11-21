# Endringslogg

Kort oversikt over hva som er endret i den helhetlige oppgraderingen (v8). Planen, funnene
og målingene står i [OPPGRADERING.md](OPPGRADERING.md). Historikken før v8 står i
[PLAN.md](PLAN.md).

## v8.9 – Bygg din runde

Etter hver bølge velger du nå selv én av tre oppgraderinger. Før fikk du én tilfeldig.
De fleste av de nye endrer hvordan du spiller, og noen passer godt sammen, så to runder
kan bli ganske ulike.

### Nytt

- **Du velger etter hver bølge.** Når en bølge er renset, kommer tre kort, og runden står
  stille mens du velger: ingen tid går, ingenting kommer, og spretterten kan ikke trekkes.
  - Minst ett av kortene endrer hvordan du spiller.
  - Kortet viser hva oppgraderingen gjør og hvilket nivå du får.
  - Når du allerede har en oppgradering som passer, står det på kortet («Passer med
    Splitt»).
- **Åtte nye oppgraderinger:**
  - **Splitt:** kulas første treff deler den i to (i tre på nivå 2).
  - **Rikosjett:** når kula skyter ned en fiende, hopper den videre til den nærmeste (to
    ganger på nivå 2).
  - **Smell:** en fiende du skyter ned, smeller. Den nærmeste får et treff og dyttes unna
    (de to nærmeste på nivå 2, og smellet når lenger).
  - **Frost:** et treff fryser fienden og de som henger tett inntil. De slutter å synke
    og flytte seg i 1,5 sekunder (2,5 på nivå 2), og etterpå tåler de frost i 3 sekunder.
    Spinneren rister det av seg.
  - **Fokus:** tiden går saktere mens du sikter (80 % fart, 70 % på nivå 2).
  - **Stor kule:** kulene er større og treffer bredere, men lades 10 % saktere per nivå.
  - **Vegg-mester:** kulene mister ikke fart i veggen, og veggskudd gir dobbelt så mye.
  - **Glasskanon:** +1 på multiplikatoren, men én knute mindre resten av runden.
- **De ni gamle** er med som før: Tunge kuler, Skarp egg, Lang flyt, Større stativ,
  Rask lading, Langt sikte, Magnetkule, Superlading og Ny knute.
- **Slik spiller du** har fått en linje om oppgraderingene.

### Rettferdig

- **Et trykk i det første halve sekundet velger ingenting.** Det kan være ment for siste
  skudd.
- **Siktelinjen følger oppgraderingene.** Med Vegg-mester og Stor kule viser den sprett
  der kula faktisk spretter.
- **Splitt og Rikosjett virker ikke på gjennomslagskuler.** De går gjennom alt fra før.
  Det gjelder også under overbelastning, der alle kuler går gjennom.
- **Kort som kommer mens et panel er oppe, venter.** Før kunne et kort gå sin tid bak
  pausemenyen uten å bli sett. Nå vises det når panelet lukkes.

### Balanse

Oppgraderingene gjør deg sterkere, og et endeløst spill må likevel bli vanskeligere til
slutt. Derfor er tre ting endret:

- **En knute du vinner tilbake med poeng, koster mer jo lenger ut du er:** 1 500 poeng i
  bølge 1, 3 000 i bølge 5 og 4 875 i bølge 10. Før var det alltid 1 500. Med
  oppgraderinger scoret en sen runde så raskt at en tapt knute var tilbake på under to
  sekunder, og da betydde knutene nesten ingenting.
- **Vanskelighetsgraden har ikke lenger tak.** Synkefarten sluttet å øke etter om lag sju
  minutter. Nå fortsetter den å stige, litt saktere enn før.
- **Feltet kan romme flere fiender sent i runden:** opptil 26 samtidig, mot 22 før.

Målt med botspillerne på de samme åtte frøene (median overlevelse):

| Spiller | v8.8 | v8.9 |
|---|---|---|
| Svak | 215 s | 245 s |
| Middels | 248 s | 465 s |
| God | 348 s | 304 s |

- **En middels botspiller varer klart lengre,** fordi oppgraderingene passer en jevn
  stil. Runden ender likevel når farten tar igjen.
- **Den gode botspilleren varer kortere** fordi den alltid velger de nye oppgraderingene
  først. I v8.8 fikk den ofte Skarp egg og kuttet 40–180 snorer per runde, nå nesten
  ingen. Folk velger det som passer dem.
- **Målingene spriker mer enn før,** fordi en runde enten tar av eller ender tidlig.
  Hvordan balansen ble funnet, står i [OPPGRADERING.md](OPPGRADERING.md) (trinn 9).

### Ytelse

Uendret: 6,9–7,0 ms per bilde i både v8.8 og v8.9, i et fast, travelt felt målt i omganger
på samme maskin. Med Splitt kan det være opptil ti kuler i lufta (før seks).

## v8.8 – Dybde

Feltet har fått dybde, som i et 2.5D-spill. Under panseret er spillet fortsatt 2D, med
samme styring og samme fysikk. Bildet viser at fiendene henger på ulik avstand, og at
rommet har lag.

### Nytt

- **Tre rader på ulik avstand:**
  - **Bakerste rad** (omtrent 3 av 10) henger fra en egen, slankere skinne litt bak og
    under den fremste. Fiendene der er 10 % mindre, og de glir inn i rommets dis: de tar
    farge fra veggen og har tynnere tau.
  - **Midterste rad** (omtrent 4 av 10) er som før. Vokteren og Spinneren henger alltid
    her, og det gjør også rekkene.
  - **Fremste rad** (omtrent 3 av 10) er 5 % større og litt lysere, og skyggen deres
    faller lenger ut og mykere på veggen.
- **Treffsonen følger størrelsen du ser.** Før var en fiende tegnet opptil 12 % større
  eller mindre enn treffsonen sin. Nå er de like. Bare når du vipper telefonen, svinger
  fienden inntil 4 % i størrelse, og det er bare for øyet.
- **Lagene beveger seg hver for seg:**
  - Når du vipper telefonen, flytter veggen seg minst, så bakerste rad, så midten og den
    fremste raden. Nærmest deg driver noen store, myke støvkorn som flytter seg mest.
  - Når du sikter, glir veggen og bakerste rad litt med siktet og støvkornene mot det,
    som om du lener deg for å se langs skuddet. Feltet du skyter i og spretterten står
    stille under fingeren.
- **Lys med avstand:** fiendene nær lampen er litt lysere, og skyggene på veggen følger
  svaiingen.

### Rettferdig

- **Ingenting du treffer eller får poeng for, flytter seg med lagene.** Bare tegningen
  forskyves, med høyst noen få punkter.
- **Mindre bevegelse** skrur av lagbevegelsen når du sikter, og støvkornene driver
  saktere. Vippingen har sin egen bryter i innstillingene, som før. **Kamerabevegelse
  av** skrur også av lagbevegelsen når du sikter.
- På laveste effektnivå er støvkornene av.

### Balanse

Målt med botspillerne på de samme åtte frøene:

| Spiller | v8.6 | v8.7 | v8.8 | Treff i v8.8 |
|---|---|---|---|---|
| Svak | 197 s | 193 s | 215 s | 69 % |
| Middels | 283 s | 272 s | 248 s | 73 % |
| God | 308 s | 273 s | 348 s | 68 % |

Snittet av de tre er 270 s, mot 263 s i v8.6, og treffprosenten er den samme. Nivåene
svinger i hver sin retning fra måling til måling. Med åtte runder per nivå kan medianen
for ett nivå flytte seg 15–25 % av tilfeldigheter alene. Radene gjør altså ikke spillet
merkbart lettere eller vanskeligere.

### Ytelse

I et fast, travelt felt med 21 fiender er skripttiden per bilde 8,7 ms i v8.6 og 8,9 ms
i v8.8, målt på utviklingsmaskinen i omganger. Svaiingen og dybden koster altså rundt
0,2 ms per bilde, innenfor støyen. En første versjon av dybden kostet 0,6 ms, fordi
fargen på disen ble slått opp for hver fiende hver gang. Den slås nå opp én gang per
bilde.

## v8.7 – Liv i rekkene

Fiendene kommer ikke lenger bare inn og blir hengende. De svinger inn, svaier i hver sin
rytme og erter deg.

### Nytt

- **Innganger med personlighet:**
  - De fleste svinger inn i tauet fra siden de henger på og gynger seg inn i svaiingen.
  - Dykkeren stuper ned i en strikk og spretter et par ganger før den roer seg.
  - Snella kommer rullende langs skinnen fra nærmeste kant mens den firer ut snøret.
  - Tungvekten og Spinneren dunker ned så skinna rister og støvet drysser, og
    småfiendene i nærheten skvetter.
  - En rekke svinger inn etter hverandre fra samme side, som en dansetropp.
- **De svaier rolig fram og tilbake,** hver i sin egen rytme (2,8–3,6 sekunder per
  svai). En rekke svaier i takt med lederen sin, med en bølge som går bortover rekka. I
  starten av en runde svaier de nesten ikke. Etter omtrent fire minutter svaier de opptil
  en tredjedel til en halv kroppsbredde til hver side, og aldri mer enn naboene gir plass
  til.
- **De erter deg:**
  - Bommer du, ler den du var nærmest med tunga ute. Så ler naboene etter tur, og den
    nærmeste dulter borti den første.
  - Ryker en knute, svaier hele flokken i takt et øyeblikk, med en bølge som går tvers
    over feltet, og ler.
  - Skallfiendene vugger når de ler, og de myke vrikker.
- **Slik spiller du** har fått en setning om svaiingen: tim skuddet til de snur.

### Rettferdig

- **Jo lavere de henger, jo roligere.** I den øverste tredjedelen av feltet svaier de
  fullt. Nærmere linjen roer de seg, og helt nede ved den henger de nesten stille. Det er
  en rettferdig siste sjanse.
- **Svaiingen stopper for varsler.** Når en fiende smalner blikket før et stup, eller ser
  dit den skal før den glir til siden, henger den rett. Den svaier heller ikke mens den
  glir raskt langs skinnen.
- **Ertingen stopper når du sikter.** En fiende du sikter på, ler ikke og dulter ikke.
- **Treffsonen følger svaiingen.** Fienden er der du ser den.
- **Mindre bevegelse:** svaiingen er 40 % av vanlig bredde, og inngangene svinger halvt
  så mye. Da er fiendene litt lettere å treffe.

### Balanse

Målt med botspillerne på de samme åtte frøene som før:

| Spiller | v8.6 | v8.7 | Treff |
|---|---|---|---|
| Svak | 197 s | 193 s | 71 % → 69 % |
| Middels | 283 s | 272 s | 72 % → 73 % |
| God | 308 s | 273 s | 68 % → 68 % |

Den første versjonen gjorde rundene 10–14 % kortere. Svaiingen ble derfor dempet nær
linjen, og den bygger seg opp saktere. Svak og middels spiller varer nå like lenge som
før. God spiller varer 35 s kortere med samme treffprosent. Det er innenfor spredningen
(±40 s), men alle tre målingene lå 30–40 s under.

## v8.6 – Myke farger, ekte figurer

Mykere og mer behagelige farger, og fiender som hver har sin egen karakter. Inspirasjonen
er sjangeren: runde, tydelige figurer med store ansikter som viser hva de føler. Figurene
og utseendet er Spenns egne og ikke hentet fra noe annet spill.

### Nytt

- **Mykere farger.** Veggene er lysere og har omtrent halvparten så sterk farge som før.
  Figurene er lysere pastellfarger med mindre metning, og midten av ringene er en lys
  plate i stedet for et mørkt hull. Hver verden beholder sin egen fargeklang fra v8.4.
- **En mørk kontur rundt hver figur.** Konturen følger formen når figuren bøyer seg og
  klemmes, så figurene står tydelig mot den lysere veggen. Den tegnes på skjermkortet og
  koster nesten ingenting.
- **Ekte ansikter.** Alle figurtypene har to øyne med pupiller, bryn og en munn som
  passer karakteren (Skyggen har fortsatt ett øye). Hver type har sitt kjennetegn:
  - **Vakt:** nervøse bryn og store fortenner. Klaprer tenner når du sikter på den.
  - **Tungvekt:** ett tykt bryn, underbitt og hoggtenner, med skjeggstubb.
  - **Splitter:** to ulike øyne og en sydd munn. Det ene øyet vandrer for seg selv.
  - **Pendel:** blide øyne og en nynnende munn. Små noter stiger når den er rolig.
  - **Dykker:** buede bryn, trutmunn og svømmebrillene på pannen. Blåser bobler.
  - **Vokter:** rett bryn og hvalrossbart.
  - **Spinneren:** sinte bryn og et glis fullt av sagtenner.
  - **Snelle:** late øyelokk og et strå i munnviken.
  - **Skygge:** ett øye, et lurt smil og solbrillene på hodet.
  - **Legen:** runde messingbriller og et vennlig smil.
  - **Speilet:** lange vipper, rosenrøde kinn og trutmunn.
  - **Pipp:** store øyne, et lite nebb og røde kinn.
  - **Pakkis:** buskete bryn og glugg i tanna.
  - **Kommandøren:** sinte bryn under hjelmen og en munn som bjeffer ordre.
  - **Leseren:** ett løftet bryn, monokkel og en snerpete munn.
  - **Luringen:** skjeve blikk og et skjevt glis.
- **Én linje om hver figur i samlingen**, for eksempel «Bølla: ett bryn, underbitt og
  kort lunte.»
- **Tekst som står rett på veggen leses bedre.** Rekorden og oppdragene på menyen,
  kortene, bølgen og poengene som spretter opp, har fått en myk mørk glorie, så de leses
  like godt på de lysere veggene.

### Uendret, med vilje

- **Spillet er det samme:** samme fiender, fart, varsler og poeng. Botspilleren får
  nøyaktig samme resultat som i v8.5 med samme frø.
- **Varslene er like tydelige.** Øynene smalner før et stup, og pupillene ser dit figuren
  skal før den glir til siden. Nå vises det i begge øynene.
- **Figurene skilles fortsatt på form først.** Typer med samme form (ringene, sekskantene
  og de runde) ligger godt fra hverandre i farge.

## Kontroller etter v8.5 (bare dokumentasjon)

- **Ingenting signaliseres bare med farge eller bare med lyd.** Alle signaler er gått
  gjennom, og fargeblindhet er simulert på figurer nær linjen i alle fem verdener.
- **Fire skjermformer** (16:9, 20:9, nettbrett og brettbar) er kontrollert med
  skjermbilder. Alt får plass.
- **Ytelse målt per del:** fiendene 2,9 ms, bakteppet 1,7 ms, fysikken 1,3 ms og
  grensesnittet 0,6 ms av 6,8 ms per bilde på utviklingsmaskinen.
- **Motoren:** Godot 4.3 beholdes for APK-en fra GitHub. Skal spillet på Google Play,
  må motoren først oppgraderes til minst 4.5.1 (krav om 16 KB minnesider).

## v8.5 – Kom tilbake

En ærlig grunn til å komme tilbake, og en side som forklarer spillet.

### Nytt

- **Dager på rad.** Spillet teller dagene du har spilt på rad. Fra to dager står det ved
  siden av rekorden på menyen, og første runde på en ny dag får et kort: «Dag 4 på rad».
  Sju dager på rad gir prestasjonen «En hel uke», og statistikken viser flest dager på
  rad.
- **Slik spiller du.** En hjelpeside bak ?-knappen på menyen: skyting, pause, linjen og
  knutene, fiendenes varsler, flyt og overbelastning, veggskudd og snorkutt, og dagens
  utfordring.

### Uendret, med vilje

- **Ingen varsler, ingen påminnelser og ingen meldinger om å miste noe.** Hopper du over
  en dag, forsvinner tallet stille, og den lengste rekka huskes.
- **Prestasjonene** er gått gjennom mot de nye nivåene etter v8.0. De måler ferdighet og
  er innen rekkevidde, så de er ikke endret.
- Statistikken har ni plasser. Totale poeng står på kulesiden, og plassen i statistikken
  viser nå flest dager på rad.

## v8.4 – Farger og figurer

Hver verden har fått sin egen fargeklang, og figurene har fått mer personlighet.

### Nytt

- **Hver verden er én palett.** Før hang de samme blå, grønne og turkise figurene i alle
  fem verdener. Nå er veggen, figurene og gullet i kula laget sammen: smaragd mot kobolt
  i Blåtime, orkidé og rosa mot havgrønt i Dyphav, fiolett mot nattegrønt i Nordlys,
  akvamarin mot fiolett i Skumring og himmelblått mot rosa i Morgen.
- **Figurene står klarere mot veggen.** Den svakeste figuren har nå 2,2–2,5 i kontrast mot
  veggen, mot 1,7–1,9 før. Hver type har samme lyshet i alle verdener, og typene skilles
  fortsatt på form og lyshet.
- **Figurene har fått mer personlighet:**
  - Omtrent hver tredje Vakt har på seg noe eget: en spire, en lue med dusk, en sløyfe
    eller en propellhatt som snurrer.
  - Dykkeren har svømmebriller på pannen, og Skyggen har solbriller på hodet.
  - En figur som tåler et treff, ser stjerner: de går rundt hodet, øyet ruller og munnen
    vingler.
  - En figur som er slått ut, faller med kryss i øyet, tunga ute og stjerner rundt hodet.
  - De siste i en bølge svetter så dråpene spruter.
  - Søvnige figurer som får være i fred, døser med «z z».
  - Av og til blunker en figur til deg, og når de erter deg, lukker de øynene av fryd.

### Rettet

- **Fare-fargen er bare fare.** En rosa figur lå 36° fra korall på fargesirkelen. Nå er
  ingen figur nærmere enn 52°. I Morgen er lyset over linjen kjølig, så det korallrøde
  varselet ved linjen ikke forveksles med morgenrosa.
- **Legen var gulaktig** og pastellfigurene sterkere enn de var satt til. Det kom av en
  nedre grense for fargemetning i hver figurs egen nyanse. Grensen er fjernet.

### Uendret

- **Ingenting av det nye skjuler et varsel.** Blunk, fryd og døsing vises bare når
  ingenting er siktet mot figuren og den ikke er i ferd med å flytte seg. Hatter og
  briller sitter aldri over øyet.
- **Spillet oppfører seg helt likt.** Det nye er bare utseende. Testene på faste frø gir
  nøyaktig samme runder som i v8.3.
- **Ytelsen er den samme.** Skripttiden per bilde i et travelt felt er 7,7 ms både før og
  etter.
- Gull er fortsatt bare kula, og korall bare fare.

## v8.3 – Rettferdig og tilpasset

Fiendene spiller rent, og du kan stille spillet etter hånden og øynene dine.

### Nytt

- **Draglengde.** Ny innstilling: kort, normal eller lang. Med kort får du full kraft på
  et kortere drag, som går raskere og sikter grovere. Lang sikter finere, men på de
  fleste telefoner må draget da begynne litt over lomma for å nå full kraft.
  Innstillingen sier fra om det.
- **Kamerabevegelse kan slås av for seg.** Risting, rykk og innzooming forsvinner, og
  alle andre effekter blir som før. «Redusert bevegelse» demper fortsatt alt.
- **Større tekst.** Poeng, kort og varsler i feltet og teksten på resultatskjermen blir
  en femtedel større.
- **Ny rekord feires på resultatskjermen.** Når stempelet slår ned, kastes papirstrimler
  opp fra begge sider og daler ned bak poengsummen. De går bak tall og knapper og dekker
  aldri noe.
- **Menyen lever.** Bakteppet på hovedmenyen skifter rolig mellom de fem verdenene.

### Rettet

- **Fiendene kunne unnvike før varselet rakk å vises.** En fiende smalner blikket før
  den flytter seg, og det er det varselet du skal kunne lese. Sent i en runde ble
  reaksjonstiden ganget ned av flere ting samtidig, helt ned til 0,02–0,06 s. I en målt
  runde kom hver tiende unnvikelse under 0,1 s etter at siktet la seg på fienden. Nå ser
  en fiende alltid på deg i minst 0,16 s før den flytter seg, og minst 0,10 s på en kule
  som alt er i lufta.
- **Treff-stoppet var likt for alle treff.** Et treff som ikke knuser, stopper nå spillet
  i 24 ms, et som knuser i 40 ms som før, og en knust sjef i 60 ms. Store treff kjennes
  større, og små treff bremser ikke rytmen.
- **En svak vibrasjon kunne kutte en sterk.** Den lange vibrasjonen når en sjef går ned
  eller et liv går tapt, ble avbrutt av det korte tikket fra neste treff. Nå får den
  sterkeste gå ferdig. (Rettet i koden. Ikke kjent på en telefon.)

### Balanse

Grensen for reaksjonstid gjør ikke spillet målbart lettere. Botspillere på de samme åtte
frøene, median overlevelse (laveste og høyeste runde i parentes):

| Spiller | v8.2 | v8.3 |
|---|---|---|
| Svak | 165 s (137–302) | 197 s (133–245) |
| Middels | 293 s (228–333) | 283 s (265–400) |
| God | 286 s (203–552) | 308 s (157–486) |

Forskjellene er mindre enn spredningen mellom runder, og treffprosenten er den samme
(68–73 %). Vanskelighetsgraden er derfor ikke justert.

## v8.2 – Én runde til

Det som skal få deg til å ta en runde til: mål som alltid er i sikte, og belønninger som
ikke stopper opp.

### Nytt

- **Resultatskjermen ser fremover.** Under tallene står oppdraget du var nærmest
  («2 av 3»), og neste kule med en linje som fylles av det runden ga. Vinner du en kule i
  runden, står det der.
- **Rekordtempo.** Ved hver ny bølge ser du om du ligger foran eller bak rekordrunden din
  på samme sted («1 250 foran rekorden din»). Tempoet lagres første gang du setter ny
  rekord i denne versjonen.
- **Tre nye kuler** å spille seg til: Is (600 000 poeng), Ametyst (1 500 000) og Perlemor
  (4 000 000). Etter v8.0 gir gode runder mye høyere poengsummer, og de seks første kulene
  var vunnet på få runder.

### Rettet

- **Oppdragene kunne låse seg for godt.** Kravene vokste uten tak og ujevnt: etter ti
  fullførte oppdrag kunne du få «bryt 11 formasjoner» eller «nå bølge 13», som ingen
  klarer, mens «få 18 000 poeng» var gjort på et halvt minutt. Et umulig oppdrag ble
  stående i ruten sin for alltid, og til slutt kom det ingen belønninger. Nå stopper hvert
  krav på det en god runde når omtrent annenhver gang (målt på botrunder), og et oppdrag
  som har stått uløst i åtte runder, byttes ut med et annet.

### Uendret

- Veien tilbake i spill er målt: resultatene kommer 0,9 s etter tapet, knappene virker
  0,6 s senere, og ny runde starter 0,12 s etter trykket. Det er kort nok, og er ikke
  endret.
- Spillet har ingen kjøp, reklame, varsler eller tidsbegrensede tilbud. Det som skal få
  deg tilbake, er tydelige mål og rask omstart.

## v8.1 – Lys og liv

Spillet har fått et nytt uttrykk: fra et mørkt rom med én lampe til en lyssatt scene.
Spretterten, figurene og snorene er de samme.

### Nytt

- **Fem verdener.** Veggen bak bjelken er nå et lyssatt bakteppe med dyp farge øverst,
  langsomme fargeslør som driver over den, og et lys som samler seg over linjen. Hver
  bølge spilles i en ny verden: Blåtime, Dyphav, Nordlys, Skumring og Morgen. Gulvet
  speiler veggens lys.
- **Figurene står klarere.** Fargene er litt rikere, og hver figur får kantlys fra
  verdenen den henger i.
- **Rommet svarer på det du gjør.** Hvert treff lyser opp veggen rundt seg, og en knust
  fiende kaster av seg et dryss av lysglimt.
- **Kula lyser.** Den har fått en lengre hale og et svakt lys rundt seg, så et skudd
  leses som en lysstripe over veggen.
- **Feiring.** Når en bølge er ryddet, flommer veggen av lys og konfetti slippes fra
  bjelken. Det samme skjer i det øyeblikket du passerer rekorden din.
- **Poengtall spretter inn** i stedet for bare å dukke opp.
- **Tettere siktelinje.** Mellom hver av de åtte prikkene står en mindre, så banen leses
  som en linje. Den rekker ikke lenger enn før.

### Rettet

- **Dagens utfordring var ikke lik på alle telefoner.** Fiendenes valg ble trukket med
  de samme terningene som partikkeleffektene bruker. Hvor mange gnister en telefon viste,
  og hvor mange bilder i sekundet den tegnet, endret dermed hva fiendene gjorde. Fiendene
  har nå egne terninger.
- **Titler som ble kuttet i kanten.** En lang prestasjonstittel gikk ut av skjermen på
  begge sider. Lange titler settes nå mindre.
- Tekst midt i feltet står på et mykt, mørkt bånd, så den er like lesbar i alle verdener.

### Tilgjengelighet

- Med «Reduserte animasjoner» står fargeslørene stille, lysglimtene i veggen er halvert
  og langsommere, og det slippes ikke konfetti.
- Faresignalet ved linjen er uendret: korall varme fra linjen, mørkere hjørner, hjerteslag
  i lyd og vibrasjon. Ingen verden bruker korall.

### Ytelse

- Skripttiden per bilde er målt før og etter på samme felt: 7,9 ms før og 8,7 ms etter
  (median av tre kjøringer, med én fiende mer i feltet etter). Selve effektene tegnes av
  motoren og grafikkbrikken, ikke av spillkoden.

## v8.0.1 – Samme frø, samme runde

- **To runder på samme frø er nå helt like.** Før skilte de lag etter 15–45 sekunder.
  Det hadde to årsaker:
  - Når et oppdrag ble fullført midt i en runde, ble det neste oppdraget trukket med
    rundens egne terninger. Hvilke oppdrag du hadde, endret dermed resten av runden,
    også i dagens utfordring, som skal være lik for alle. Oppdragene har nå egne
    terninger.
  - Kontrollen av om to snorer har krysset hverandre, ble fordelt i tid etter motorens
    interne objektnummer. Runden avhang dermed av hva appen hadde gjort før den startet.
    Kontrollen følger nå fiendens plass i spillet, og klokken starter på nytt for hver
    runde.
- **Ny test (`repeat`):** to spill på samme frø og med samme skudd, men ulike oppdrag,
  skal være like steg for steg.
- Målinger blir sikrere: samme frø kan nå sammenlignes direkte før og etter en endring.

## v8.0 – Stabilitet, kontroll og jevn flyt

Første trinn retter feil som påvirket hele spillfølelsen, og legger et testgrunnlag under
resten av oppgraderingen. Lyden er ikke endret, og utseendet bare på ett punkt:
siktelinjen er litt tydeligere.

### Rettet

- **Sanntidsklokken.** Hvert treff fikk alle sanntidsklokker til å hoppe 0,83 s frem.
  Derfor varte overload i praksis ca. 2,5 s (ikke 5), flyt ca. 3 s (ikke 7) og vindkast og
  mørke ca. 3 s (ikke 8–9), kortere jo flere treff du fikk. Skjermristing, kameraets
  innzooming og sakte film som ble utløst av et treff, ble kuttet før de rakk å vises.
  Klokken går nå riktig. Varighetene er satt til det spillet faktisk har vært spilt med
  (overload 2,5 s, flyt 3 s, vindkast 4 s, mørke 3,5 s), og effektene vises som de var
  tenkt.
- **Låst pausemeny.** Hvis appen ble lagt i bakgrunnen midt i nedtellingen 3-2-1, svarte
  ikke pausemenyen eller Tilbake-knappen etterpå. Nedtellingen avbrytes nå ordentlig.
- **Skudd du ikke ba om.** En berøring som systemet avbrøt (sveip fra kanten,
  varslingsskuff, innkommende anrop) fyrte av et skudd. Nå slippes strikken rolig ned.
- **0,8 s ventetid etter hvert skudd.** Et nytt drag ble avvist til lomma hadde svingt
  seg til ro, og trykket ble bare ignorert. Lomma kan nå tas igjen straks kula har forlatt
  den, og et trykk som kommer litt for tidlig, huskes. Skuddtakten styres i stedet av
  ladetiden (omtrent én kule i sekundet), så et fullt magasin er en reserve du kan tømme
  raskt når det trengs.
- **Full kraft var utenfor rekkevidde.** Full kraft krevde 3,5 cm drag, men under lomma
  er det bare ca. 2 cm skjerm. Et rett drag fra lomma ga 51–67 % kraft, for lite til å
  kutte en snor. Draglengden følger nå plassen på skjermen, og du kan dra fingeren litt
  opp først for å få mer å gå på.
- **Siktelinjen viste feil etter veggtreff** (opptil 120 px avvik) og tok ikke hensyn til
  vind. Siktelinjen og kula bruker nå samme regnestykke.
- **Snorkutt som ikke ble registrert.** Raske, skrå skudd kunne passere snora mellom to
  fysikksteg (opptil 28 % bom ved full kraft). Hele steget testes nå.
- **Fiender over bjelken.** En kropp som ble slått oppover, kunne fly over bjelken og inn
  i toppfeltet. Bjelken stopper dem nå.
- **Risting i tette felt.** En kropp klemt mellom en nabo og en snor ble dyttet 1–4 px
  frem og tilbake hvert steg. Kropper viker nå rolig, og motstridende dytt dempes
  (fra 1,4–4,2 ristinger per kropp per sekund til 0,01–0,25).
- **Lagring.** Fremgangen skrives nå til en ny fil som byttes inn hel, med forrige fil som
  sikkerhetskopi. En halvskrevet eller skadet fil mister ikke lenger prestasjoner og
  statistikk, og feil verdier i fila kan ikke stoppe oppstarten. Flere endringer på rad
  (som ved rundeslutt) gir én skriving i stedet for fire til seks.
- **Dagens utfordring** var ikke lik for alle: tempo og bølgestemning fulgte ikke dagens
  frø. Nå gjør de det.
- Kula forsvant fra lomma i 0,8 s etter et drag som var for kort til å gi skudd.
- Skuddet forlater lomma like raskt i sakte film og treff-stopp som ellers.
- Lyd trekker ikke lenger fra spillets terninger, så lyden kan ikke påvirke hvordan en
  runde utvikler seg.
- Siktelinjens prikker er større og har mørk kant, så de synes både mot den mørke
  bakgrunnen og mot lyse kropper.

### Balanse

Rettingene over gjør spretterten raskere og sterkere enn før. Tre ting er justert for at
de første minuttene skal være like vanskelige som du kjenner dem:

- **Ladetid:** omtrent 1 s per kule (før 0,6–0,88 s, men bak ventetiden på 0,8 s).
- **Overload** lades saktere fra bølge 5 (15 % per bølge), så den ikke kjeder seg sammen
  sent i en runde. De fire første bølgene lades som før.
- **Nedstigningen** fortsetter å øke sent i runden. Før flatet den ut på et nivå ingen
  runde nådde.

Målt med botspillere varer en svak spiller like lenge som før (median 190 s mot 182 s).
Det som er nytt, er at dyktighet lønner seg: en middels spiller varer 289 s (før 194 s)
og en god 326 s (før 196 s). I originalen varte alle omtrent like lenge, fordi ventetiden
og den korte draglengden holdt alle igjen. Poengsummene øker mer enn overlevelsen, så
rekorder fra originalen blir lettere å slå.

### Ytelse

- Små prikker, buer og streker i ansiktene tegnes i samlede operasjoner i stedet for
  punkt for punkt. Prikker og buer er 7–8 ganger raskere, et helt ansikt omtrent dobbelt
  så raskt, med samme bilde.
- Ubrukte lydfiler (de stille strengene) lastes ikke lenger ved oppstart.

### Tester

- Testene spiller nå på en skjerm formet som en telefon. Før var feltet et kvadrat på
  1280 × 1280 piksler i testene, og alle botskudd gikk på full kraft, så tidligere
  balansetall gjaldt en geometri ingen telefon har.
- Nye tester: hel økt (`flow`), lagring (`save`), sanntid og spilltid (`timing`) og
  fysikk (`physics`). Testene bruker egen lagringsfil og fast frø.
- `tools/tests/balance.sh` måler overlevelse for botspillere på tre ferdighetsnivåer.
