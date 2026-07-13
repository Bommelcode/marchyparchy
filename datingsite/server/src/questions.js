export const INTERESTS = [
  'hiking', 'movies', 'coffee', 'sports', 'reading',
  'cooking', 'travel', 'gaming', 'music', 'art',
];

export const DATE_ACTIVITIES = [
  { id: 'coffee', label: 'Coffee', venue: 'a cozy local coffee shop' },
  { id: 'sport', label: 'Sport / active date', venue: 'the park for a light workout or walk' },
  { id: 'walk', label: 'Walk & talk', venue: 'a scenic walking trail' },
  { id: 'dinner', label: 'Dinner', venue: 'a casual neighborhood restaurant' },
  { id: 'museum', label: 'Museum / culture', venue: 'a local museum or gallery' },
];

export const DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
export const TIMES_OF_DAY = ['morning', 'afternoon', 'evening'];

// Likert-scale personality traits, 1-5 (1 = left label, 5 = right label)
export const PERSONALITY_TRAITS = [
  { id: 'social', left: 'introvert', right: 'extrovert' },
  { id: 'planning', left: 'planner', right: 'spontaneous' },
  { id: 'risk', left: 'cautious', right: 'adventurous' },
  { id: 'pace', left: 'homebody', right: 'always out' },
];

export const INTERVIEW_SCHEMA = {
  interests: INTERESTS,
  dateActivities: DATE_ACTIVITIES.map(({ id, label }) => ({ id, label })),
  days: DAYS,
  timesOfDay: TIMES_OF_DAY,
  personalityTraits: PERSONALITY_TRAITS,
};

export function validateInterview(answers) {
  if (!answers || typeof answers !== 'object') return 'Missing answers';

  const { interests, personality, preferredActivities, availability } = answers;

  if (!Array.isArray(interests) || interests.length === 0) {
    return 'Pick at least one interest';
  }
  if (!interests.every((i) => INTERESTS.includes(i))) {
    return 'Unknown interest value';
  }

  if (!personality || typeof personality !== 'object') return 'Missing personality answers';
  for (const trait of PERSONALITY_TRAITS) {
    const v = personality[trait.id];
    if (typeof v !== 'number' || v < 1 || v > 5) {
      return `personality.${trait.id} must be a number 1-5`;
    }
  }

  if (!Array.isArray(preferredActivities) || preferredActivities.length === 0) {
    return 'Pick at least one preferred date activity';
  }
  if (!preferredActivities.every((a) => DATE_ACTIVITIES.some((d) => d.id === a))) {
    return 'Unknown date activity value';
  }

  if (!availability || typeof availability !== 'object') return 'Missing availability';
  const { days, timesOfDay } = availability;
  if (!Array.isArray(days) || days.length === 0 || !days.every((d) => DAYS.includes(d))) {
    return 'availability.days must be a non-empty list of valid days';
  }
  if (
    !Array.isArray(timesOfDay) ||
    timesOfDay.length === 0 ||
    !timesOfDay.every((t) => TIMES_OF_DAY.includes(t))
  ) {
    return 'availability.timesOfDay must be a non-empty list of valid times';
  }

  return null;
}
