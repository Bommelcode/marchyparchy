# Met — mobiele app (Expo / React Native)

De native app van Met, gebouwd met [Expo](https://expo.dev) SDK 57. Dezelfde
flow als de webclient (aanmelden → interview → verificatie → dashboard met
datumprikker, betalen en feedback) tegen dezelfde Express/Postgres-API.

## Draaien

```sh
npm install
npm start          # Expo dev server; scan de QR met de Expo Go-app
npm run web        # of in de browser via react-native-web
```

Op een fysiek toestel is `localhost` de telefoon zelf. Zet dan het LAN-adres
van je machine in een `.env`:

```
EXPO_PUBLIC_API_URL=http://192.168.x.x:4000/api
```

## Opzet

- `App.js` — fasegestuurde navigatie (auth → interview → verificatie →
  dashboard); bewust zonder router-dependency zolang er één flow is.
- `src/api.js` — dezelfde API-laag als de webclient.
- `src/storage.js` — JWT in `expo-secure-store` op iOS/Android, localStorage
  op web.
- `src/ui.js` + `src/theme.js` — knoppen/chips/kaarten in de Met-huisstijl.
- `src/screens/` — de vier schermen.

## Nog te doen richting de stores

- Pushnotificaties bij de 19:00-drop (expo-notifications + server-side job)
- Echte betaal-flow (PSP-webview of native SDK)
- App-iconen en splash in Met-huisstijl, EAS Build-configuratie
