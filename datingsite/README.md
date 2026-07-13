# Met

**Met — eindelijk iemand ontmoet.** De naam werkt dubbel: Engels *met*
(elkaar ontmoet) én Nederlands *met* — daten doe je mét iemand, en de app
zegt het overal ("date met Emma").

Een datingapp naar het model van [Breeze](https://breeze.social/nl), gericht op
dezelfde doelgroep: hoogopgeleide young professionals (±20-35) die klaar zijn
met swipen en eindeloos chatten. Kort interview, matchen op compatibiliteit,
en bij een match meteen een **datumprikker** voor een echte date op een
partnerlocatie in je eigen stad. Geen chat — alleen komen opdagen.

## Breeze-mechanics in deze app

- **Profiel + verificatie**: geboortejaar, stad en opleidingsniveau
  (mbo/hbo/wo). Zonder (mock-)ID-verificatie doe je niet mee aan de
  matchronde.
- **Dagelijkse matchdrop om 19:00**: geen zoekknop — elke dag om 19:00 word
  je (lazy, bij de eerstvolgende statuscheck) gekoppeld aan je beste
  kandidaat. Het dashboard toont een countdown naar de volgende ronde.
- **Matching**: harde filter op stad; leeftijdsverschil en opleidingsniveau
  wegen mee naast interesses, persoonlijkheid, date-voorkeuren en
  beschikbaarheid.
- **Datumprikker**: bij een match krijgen beide gebruikers max. 3 concrete
  tijdsloten waarop zowel zijzelf als de partnerlocatie kunnen. Een gedeeld
  geprikt slot legt het moment vast.
- **Partnerdatabase**: partners per stad met activiteiten (borrel, koffie,
  sportief, wandeling, diner), open dagdelen en capaciteit per tijdslot.
  Volgeboekte sloten worden niet meer voorgesteld.
- **Vooraf betalen**: na het prikken betalen beide kanten €7,50 (mock-PSP),
  eerste drankje inbegrepen; pas dan is de date geboekt.
- **Feedback na de date**: kwam je date opdagen, en wil je hem/haar
  terugzien? Wederzijds "ja" deelt contactgegevens; een gemelde no-show
  levert de wegblijver een strike op.
- **Commitment-regel**: twee strikes (afgewezen prikkers en/of no-shows) en
  je account wordt gepauzeerd. De app is voor mensen die écht op date willen.

### Match-lifecycle

`proposed` (prikker open) → `awaiting_payment` (gedeeld slot geprikt) →
`booked` (beiden betaald) → `completed` (date voorbij, feedback open) →
`closed` (beide feedbacks binnen). Zijpaden: `declined` (prikker afgewezen,
strike) en `no_overlap` (beiden geprikt, geen gedeeld moment — geen strike).

### Dev-endpoints (niet in productie)

- `POST /api/dev/drop` — forceer een matchdrop buiten het 19:00-ritme.
- `POST /api/dev/finish-date/:id` — zet een geboekte date in het verleden om
  de feedbackfase te testen.

## Structuur

- `server/` — Express-API, JWT-auth, JSON-bestand als datastore. Matching- en
  datumprikkerlogica in `src/matching.js`, partnerlocaties in `src/venues.js`.
- `client/` — React (Vite) frontend, volledig Nederlandstalig: registratie,
  interview en een dashboard met datumprikker.

## Lokaal draaien

```sh
cd server && npm install && npm run dev   # http://localhost:4000
cd client && npm install && npm run dev   # http://localhost:5173
```

De client praat standaard met `http://localhost:4000/api`; overschrijf met
`VITE_API_URL` indien nodig.

## Nog niet gebouwd (ideeën)

- Echte ID-verificatie en een echte PSP (iDEAL) i.p.v. de mocks
- Terugstorting bij no-show automatisch afhandelen
- Partnerportaal waarin locaties zelf capaciteit en dagdelen beheren
- Pushnotificatie bij de 19:00-drop i.p.v. polling
