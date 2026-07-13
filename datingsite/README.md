# Blind Date

Een datingapp naar het model van [Breeze](https://breeze.social/nl), gericht op
dezelfde doelgroep: hoogopgeleide young professionals (±20-35) die klaar zijn
met swipen en eindeloos chatten. Kort interview, matchen op compatibiliteit,
en bij een match meteen een **datumprikker** voor een echte date op een
partnerlocatie in je eigen stad. Geen chat — alleen komen opdagen.

## Breeze-mechanics in deze app

- **Profiel**: geboortejaar, stad en opleidingsniveau (mbo/hbo/wo).
- **Matching**: harde filter op stad; leeftijdsverschil en opleidingsniveau
  wegen mee naast interesses, persoonlijkheid, date-voorkeuren en
  beschikbaarheid.
- **Datumprikker**: bij een match krijgen beide gebruikers max. 3 concrete
  tijdsloten uit hun overlappende beschikbaarheid. Een gedeeld geprikt slot
  maakt de date definitief.
- **Partnerlocaties**: elk datevoorstel noemt een concrete horecazaak of plek
  per stad en activiteit (borrel, koffie, sportief, wandeling, diner) —
  "eerste drankje geregeld", à la Breeze's horecapartners.
- **Commitment-regel**: wie twee keer een datumprikker afwijst, wordt
  gepauzeerd. De app is voor mensen die écht op date willen.

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

- Dagelijkse matchdrop om 19:00 in plaats van een "zoek match"-knop
- Betalen vooraf (~€7,50 incl. eerste drankje) en no-show-afhandeling
- Profielverificatie/screening en feedback na de date
- Echte partnerdatabase met beschikbaarheid per locatie
