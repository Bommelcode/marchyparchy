export const INTERESTS = [
  'wandelen', 'films', 'koffie', 'sport', 'lezen',
  'koken', 'reizen', 'gamen', 'muziek', 'kunst',
  'festivals', 'ondernemen',
];

export const CITIES = [
  'Amsterdam', 'Rotterdam', 'Den Haag', 'Utrecht',
  'Eindhoven', 'Groningen', 'Breda',
];

export const EDUCATION_LEVELS = ['mbo', 'hbo', 'wo'];

export const DATE_ACTIVITIES = [
  { id: 'borrel', label: 'Borrel' },
  { id: 'koffie', label: 'Koffie' },
  { id: 'sportief', label: 'Sportieve date' },
  { id: 'wandelen', label: 'Wandeling' },
  { id: 'diner', label: 'Diner' },
];

export const DAYS = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
export const TIMES_OF_DAY = ['ochtend', 'middag', 'avond'];

// Likert-persoonlijkheidsschalen, 1-5 (1 = linkerlabel, 5 = rechterlabel)
export const PERSONALITY_TRAITS = [
  { id: 'social', left: 'introvert', right: 'extravert' },
  { id: 'planning', left: 'planner', right: 'spontaan' },
  { id: 'risk', left: 'voorzichtig', right: 'avontuurlijk' },
  { id: 'pace', left: 'huismus', right: 'altijd op pad' },
];

export const INTERVIEW_SCHEMA = {
  interests: INTERESTS,
  dateActivities: DATE_ACTIVITIES.map(({ id, label }) => ({ id, label })),
  days: DAYS,
  timesOfDay: TIMES_OF_DAY,
  personalityTraits: PERSONALITY_TRAITS,
};

export const PROFILE_SCHEMA = {
  cities: CITIES,
  educationLevels: EDUCATION_LEVELS,
  minAge: 18,
};

export function validateProfile({ birthYear, city, education }) {
  const currentYear = new Date().getFullYear();
  if (typeof birthYear !== 'number' || currentYear - birthYear < 18 || currentYear - birthYear > 99) {
    return 'Vul een geldig geboortejaar in (18+)';
  }
  if (!CITIES.includes(city)) {
    return 'Kies een stad uit de lijst';
  }
  if (!EDUCATION_LEVELS.includes(education)) {
    return 'Kies een opleidingsniveau';
  }
  return null;
}

export function validateInterview(answers) {
  if (!answers || typeof answers !== 'object') return 'Antwoorden ontbreken';

  const { interests, personality, preferredActivities, availability } = answers;

  if (!Array.isArray(interests) || interests.length === 0) {
    return 'Kies minstens één interesse';
  }
  if (!interests.every((i) => INTERESTS.includes(i))) {
    return 'Onbekende interesse';
  }

  if (!personality || typeof personality !== 'object') return 'Persoonlijkheidsvragen ontbreken';
  for (const trait of PERSONALITY_TRAITS) {
    const v = personality[trait.id];
    if (typeof v !== 'number' || v < 1 || v > 5) {
      return `personality.${trait.id} moet een getal 1-5 zijn`;
    }
  }

  if (!Array.isArray(preferredActivities) || preferredActivities.length === 0) {
    return 'Kies minstens één soort date';
  }
  if (!preferredActivities.every((a) => DATE_ACTIVITIES.some((d) => d.id === a))) {
    return 'Onbekend soort date';
  }

  if (!availability || typeof availability !== 'object') return 'Beschikbaarheid ontbreekt';
  const { days, timesOfDay } = availability;
  if (!Array.isArray(days) || days.length === 0 || !days.every((d) => DAYS.includes(d))) {
    return 'Kies minstens één dag waarop je kunt';
  }
  if (
    !Array.isArray(timesOfDay) ||
    timesOfDay.length === 0 ||
    !timesOfDay.every((t) => TIMES_OF_DAY.includes(t))
  ) {
    return 'Kies minstens één dagdeel';
  }

  return null;
}
