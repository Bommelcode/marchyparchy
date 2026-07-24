# Madrid Bosbrandenkaart

Statische, losstaande webpagina die actieve-brand-detecties rond Madrid toont op een satellietfoto. Geen build-stap, geen server nodig.

## Gebruik

Open `index.html` direct in een browser, of host de map (bv. via GitHub Pages) en open die URL.

## Wat je ziet

- **Satellietfoto (Esri)** — hoge-resolutie satellietbasislaag, altijd beschikbaar.
- **NASA satellietbeeld (van gekozen datum)** — daadwerkelijke VIIRS-opname van die dag (kan gaten hebben door wolken of nachtelijke doorkomst).
- **🔥 Branden-lagen (VIIRS Suomi NPP / NOAA-20)** — actieve-brand-detecties van NASA GIBS, geen API-key nodig. Ververst automatisch elke 5 minuten wanneer de datum "vandaag" is.
- **Brandenlijst** (optioneel) — losse detecties met afstand/richting t.o.v. Madrid, tijdstip, satelliet, betrouwbaarheid en stralingsvermogen (FRP). Hiervoor is een gratis [NASA FIRMS MAP_KEY](https://firms.modaps.eosdis.nasa.gov/api/map_key/) nodig, in te vullen via het tandwiel-icoon. De key wordt alleen lokaal in de browser (`localStorage`) bewaard.

## Belangrijk om te weten

"Live" betekent hier *near real-time*: satellieten vliegen een paar keer per dag over, dus detecties zijn hooguit een paar uur oud, geen continu videobeeld. Bij bewolking of 's nachts kan de NASA-beeldlaag leeg blijven — de Esri-satellietfoto en de brandenlaag blijven dan wel werken.

## Databronnen

- Satellietbeeld: [Esri World Imagery](https://www.esri.com/) en [NASA GIBS](https://www.earthdata.nasa.gov/engage/open-data-services-software/earthdata-developer-portal/gibs-api) (VIIRS Corrected Reflectance).
- Branddetecties: [NASA FIRMS](https://firms.modaps.eosdis.nasa.gov/) (VIIRS Suomi NPP / NOAA-20 Thermal Anomalies), via de gratis GIBS-tegellaag en optioneel de FIRMS Area API voor puntdata.

## Bekende beperkingen

- De FIRMS Area API staat mogelijk geen directe browseraanvragen toe (CORS). De pagina vangt dat netjes af met een foutmelding in de brandenlijst — de kaartlaag met branden blijft in dat geval gewoon zichtbaar.
- De brandenlaag toont detecties per kalenderdag (UTC), niet per exact tijdstip.
