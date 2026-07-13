// Partnerdatabase à la Breeze's horecapartners. Elke partner geeft op welke
// activiteiten hij host, op welke dagdelen hij Blind Date-tafels heeft en
// hoeveel dates er per tijdslot tegelijk terechtkunnen. In productie beheert
// de partner dit zelf via een portaal.
export const PARTNERS = [
  // Amsterdam
  { id: 'ams-zeevaart', city: 'Amsterdam', name: 'Café De Zeevaart (Oostelijke Eilanden)', activities: ['borrel', 'diner'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'ams-bocca', city: 'Amsterdam', name: 'Koffiebar Bocca (Kerkstraat)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'ams-amstelpark', city: 'Amsterdam', name: 'Padelbaan Amstelpark', activities: ['sportief'], openTimes: ['ochtend', 'middag', 'avond'], capacityPerSlot: 1 },
  { id: 'ams-vondel', city: 'Amsterdam', name: 'het Vondelpark, ingang Van Baerlestraat', activities: ['wandelen'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 5 },
  // Rotterdam
  { id: 'rot-aloha', city: 'Rotterdam', name: 'Aloha Bar (Maasboulevard)', activities: ['borrel'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'rot-manmetbril', city: 'Rotterdam', name: 'Man met Bril Koffie (Hofbogen)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'rot-fenix', city: 'Rotterdam', name: 'Restaurant Fenix (Katendrecht)', activities: ['diner'], openTimes: ['avond'], capacityPerSlot: 2 },
  { id: 'rot-kralingse', city: 'Rotterdam', name: 'het Kralingse Bos, bij de molens', activities: ['wandelen', 'sportief'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 5 },
  // Den Haag
  { id: 'dh-paas', city: 'Den Haag', name: 'De Paas (Dunne Bierkade)', activities: ['borrel'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'dh-singleestate', city: 'Den Haag', name: 'Single Estate Coffee (Zeeheldenkwartier)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'dh-beach', city: 'Den Haag', name: 'Beachvolleybal Scheveningen', activities: ['sportief'], openTimes: ['middag', 'avond'], capacityPerSlot: 2 },
  { id: 'dh-wox', city: 'Den Haag', name: 'WOX (Buitenhof)', activities: ['diner'], openTimes: ['avond'], capacityPerSlot: 2 },
  // Utrecht
  { id: 'utr-ledigerf', city: 'Utrecht', name: 'Café Ledig Erf', activities: ['borrel', 'diner'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'utr-village', city: 'Utrecht', name: 'The Village Coffee (Voorstraat)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'utr-sterk', city: 'Utrecht', name: 'Boulderhal Sterk', activities: ['sportief'], openTimes: ['ochtend', 'middag', 'avond'], capacityPerSlot: 2 },
  { id: 'utr-uithof', city: 'Utrecht', name: 'de Uithof botanische tuinen', activities: ['wandelen'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 4 },
  // Eindhoven
  { id: 'ein-stadsbrouwerij', city: 'Eindhoven', name: 'Stadsbrouwerij Eindhoven (Strijp-S)', activities: ['borrel'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'ein-coffeelab', city: 'Eindhoven', name: 'Coffeelab (Stationsplein)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'ein-radioroyaal', city: 'Eindhoven', name: 'Radio Royaal (Strijp-S)', activities: ['diner'], openTimes: ['avond'], capacityPerSlot: 2 },
  { id: 'ein-genneper', city: 'Eindhoven', name: 'de Genneper Parken', activities: ['wandelen', 'sportief'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 4 },
  // Groningen
  { id: 'gro-sigaar', city: 'Groningen', name: 'Café De Sigaar (Hoge der A)', activities: ['borrel'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'gro-blackbloom', city: 'Groningen', name: 'Black & Bloom (Oude Kijk in het Jatstraat)', activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'gro-bjoeks', city: 'Groningen', name: 'Bouldercentrum Bjoeks', activities: ['sportief'], openTimes: ['middag', 'avond'], capacityPerSlot: 2 },
  { id: 'gro-noorderplantsoen', city: 'Groningen', name: 'het Noorderplantsoen', activities: ['wandelen'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 4 },
  // Breda
  { id: 'bre-beyerd', city: 'Breda', name: 'Café De Beyerd', activities: ['borrel'], openTimes: ['middag', 'avond'], capacityPerSlot: 3 },
  { id: 'bre-baristas', city: 'Breda', name: "Barista's Koffiebar (Ginnekenweg)", activities: ['koffie'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 2 },
  { id: 'bre-dickens', city: 'Breda', name: 'Dickens & Jones (Grote Markt)', activities: ['diner'], openTimes: ['avond'], capacityPerSlot: 2 },
  { id: 'bre-mastbos', city: 'Breda', name: 'het Mastbos, bij Kasteel Bouvigne', activities: ['wandelen', 'sportief'], openTimes: ['ochtend', 'middag'], capacityPerSlot: 4 },
];

export function partnersFor(city, activityId) {
  return PARTNERS.filter((p) => p.city === city && p.activities.includes(activityId));
}

export function partnerById(id) {
  return PARTNERS.find((p) => p.id === id) ?? null;
}
