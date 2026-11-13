# Endringslogg

Kort oversikt over hva som er endret i den helhetlige oppgraderingen (v8). Planen, funnene
og målingene står i [OPPGRADERING.md](OPPGRADERING.md). Historikken før v8 står i
[PLAN.md](PLAN.md).

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
