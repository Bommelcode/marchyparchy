// Mock partnerlocaties per stad, à la Breeze's horecapartners. In productie
// komt dit uit een partnerdatabase met beschikbaarheid en afrekenen vooraf.
const VENUES = {
  Amsterdam: {
    borrel: 'Café De Zeevaart (Oostelijke Eilanden)',
    koffie: 'Koffiebar Bocca (Kerkstraat)',
    sportief: 'Padelbaan Amstelpark',
    wandelen: 'het Vondelpark, ingang Van Baerlestraat',
    diner: 'Bistro Flore (De Pijp)',
  },
  Rotterdam: {
    borrel: 'Aloha Bar (Maasboulevard)',
    koffie: 'Man met Bril Koffie (Hofbogen)',
    sportief: 'Klimhal Monte Cervino',
    wandelen: 'het Kralingse Bos, bij de molens',
    diner: 'Restaurant Fenix (Katendrecht)',
  },
  'Den Haag': {
    borrel: 'De Paas (Dunne Bierkade)',
    koffie: 'Single Estate Coffee (Zeeheldenkwartier)',
    sportief: 'Beachvolleybal Scheveningen',
    wandelen: 'de Scheveningse Bosjes',
    diner: 'WOX (Buitenhof)',
  },
  Utrecht: {
    borrel: 'Café Ledig Erf',
    koffie: 'The Village Coffee (Voorstraat)',
    sportief: 'Boulderhal Sterk',
    wandelen: 'de Uithof botanische tuinen',
    diner: 'LE:EN (Wittevrouwen)',
  },
  Eindhoven: {
    borrel: 'Stadsbrouwerij Eindhoven (Strijp-S)',
    koffie: 'Coffeelab (Stationsplein)',
    sportief: 'Padel Next Level',
    wandelen: 'de Genneper Parken',
    diner: 'Radio Royaal (Strijp-S)',
  },
  Groningen: {
    borrel: 'Café De Sigaar (Hoge der A)',
    koffie: 'Black & Bloom (Oude Kijk in het Jatstraat)',
    sportief: 'Bouldercentrum Bjoeks',
    wandelen: 'het Noorderplantsoen',
    diner: 'Roezemoes (Gedempte Zuiderdiep)',
  },
  Breda: {
    borrel: 'Café De Beyerd',
    koffie: "Barista's Koffiebar (Ginnekenweg)",
    sportief: 'Padelclub Breda',
    wandelen: 'het Mastbos, bij Kasteel Bouvigne',
    diner: 'Dickens & Jones (Grote Markt)',
  },
};

export function venueFor(city, activityId) {
  return VENUES[city]?.[activityId] ?? `een partnerlocatie in ${city}`;
}
