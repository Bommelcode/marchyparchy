# Blind Date

A dating app that skips profile-swiping. Users answer a short interview
(interests, personality, preferred date activities, availability), a
compatibility matcher pairs them up, and each pair gets a concrete blind-date
proposal (coffee, a walk, sport, etc.) at a time that works for both. No
photos, no browsing — just accept or decline the date.

## Structure

- `server/` — Express API, JWT auth, JSON-file datastore, matching + date
  proposal logic (`src/matching.js`).
- `client/` — React (Vite) frontend: signup/login, interview form, and a
  dashboard for finding a match and responding to date proposals.

## Run locally

```sh
cd server && npm install && npm run dev   # http://localhost:4000
cd client && npm install && npm run dev   # http://localhost:5173
```

The client talks to `http://localhost:4000/api` by default; override with
`VITE_API_URL` if needed.

## How matching works

`server/src/matching.js` scores two completed interviews on interests,
personality closeness, shared preferred activities, and availability overlap
to produce a 0-100 compatibility score and a human-readable rationale. Once
two users are matched, `proposeBlindDate` picks a shared activity and the
nearest shared availability slot and turns it into a concrete date proposal
(e.g. "Coffee, Saturday morning"). Both users must accept before the date is
confirmed.
