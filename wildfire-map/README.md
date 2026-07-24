# Madrid Bosbrandenkaart

Statische, losstaande webpagina die actieve-brand-detecties rond Madrid toont op een satellietfoto. Geen build-stap, geen server nodig.

## Gebruik

Open `index.html` direct in een browser, of host de map (bv. via GitHub Pages) en open die URL.

## Wat je ziet

- **Satellietfoto (Esri)** — hoge-resolutie satellietbasislaag, altijd beschikbaar, geen key nodig.
- **NASA satellietbeeld (van gekozen datum)** — optionele laag, daadwerkelijke VIIRS-opname van die dag (kan gaten hebben door wolken of nachtelijke doorkomst).
- **🔥 Branden** — individuele actieve-brand-detecties (rode stippen + lijst met tijdstip, satelliet, betrouwbaarheid en stralingsvermogen/FRP) via de [NASA FIRMS Area API](https://firms.modaps.eosdis.nasa.gov/api/area/). Hiervoor is een gratis [FIRMS MAP_KEY](https://firms.modaps.eosdis.nasa.gov/api/map_key/) nodig (± 1 minuut aanvragen, geen kosten), in te vullen via het tandwiel-icoon. De key wordt alleen lokaal in de browser (`localStorage`) bewaard. Ververst automatisch elke 5 minuten.

Een eerdere versie probeerde branden ook als NASA GIBS-rasterlaag te tonen (geen key nodig), maar de exacte laag-/tegelparameters bleken niet betrouwbaar te verifiëren en leverden grijze/zwarte tegels op in plaats van brandpunten — die laag is daarom verwijderd. De FIRMS Area API is de officieel gedocumenteerde, geverifieerde route.

## Belangrijk om te weten

"Live" betekent hier *near real-time*: satellieten vliegen een paar keer per dag over, dus detecties zijn hooguit een paar uur oud, geen continu videobeeld. Bij bewolking of 's nachts kan de NASA-beeldlaag leeg blijven — de Esri-satellietfoto blijft dan wel werken.

## Databronnen

- Satellietbeeld: [Esri World Imagery](https://www.esri.com/) en [NASA GIBS](https://www.earthdata.nasa.gov/engage/open-data-services-software/earthdata-developer-portal/gibs-api) (VIIRS Corrected Reflectance).
- Branddetecties: [NASA FIRMS](https://firms.modaps.eosdis.nasa.gov/) Area API (VIIRS Suomi NPP NRT), puntdata met MAP_KEY.

## Bekende beperkingen

- De FIRMS Area API staat mogelijk geen directe browseraanvragen toe (CORS) — nog niet in de praktijk bevestigd. De pagina vangt dat netjes af met een foutmelding in de brandenlijst i.p.v. een crash.
- Zonder FIRMS-key toont de kaart alleen de satellietfoto, geen brandpunten.
