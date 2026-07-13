import { DATE_ACTIVITIES, DAYS, PERSONALITY_TRAITS } from './questions.js';
import { partnersFor } from './venues.js';

function jaccard(a, b) {
  const setA = new Set(a);
  const setB = new Set(b);
  const intersection = [...setA].filter((x) => setB.has(x));
  const union = new Set([...setA, ...setB]);
  if (union.size === 0) return 0;
  return intersection.length / union.size;
}

function personalityCloseness(a, b) {
  const diffs = PERSONALITY_TRAITS.map((t) => Math.abs(a[t.id] - b[t.id]) / 4);
  const avgDiff = diffs.reduce((s, d) => s + d, 0) / diffs.length;
  return 1 - avgDiff;
}

// Leeftijdsverschil: 0-2 jaar telt vol mee, daarna lineair af tot 0 bij 12 jaar.
function ageCloseness(userA, userB) {
  const diff = Math.abs(userA.birthYear - userB.birthYear);
  if (diff <= 2) return 1;
  return Math.max(0, 1 - (diff - 2) / 10);
}

const WEIGHTS = {
  interests: 0.25,
  personality: 0.2,
  activities: 0.2,
  availability: 0.15,
  age: 0.15,
  education: 0.05,
};

/**
 * Scoort compatibiliteit tussen twee gebruikers (0-100). Stad is een harde
 * filter vóór deze functie; leeftijd en opleiding wegen hier mee, zoals bij
 * Breeze waar je standaard rond je eigen leeftijd en niveau gematcht wordt.
 */
export function scoreCompatibility(userA, userB) {
  const a = userA.interview;
  const b = userB.interview;

  const interestScore = jaccard(a.interests, b.interests);
  const personalityScore = personalityCloseness(a.personality, b.personality);
  const activityScore = jaccard(a.preferredActivities, b.preferredActivities);
  const dayOverlap = jaccard(a.availability.days, b.availability.days);
  const timeOverlap = jaccard(a.availability.timesOfDay, b.availability.timesOfDay);
  const availabilityScore = (dayOverlap + timeOverlap) / 2;
  const ageScore = ageCloseness(userA, userB);
  const educationScore = userA.education === userB.education ? 1 : 0.5;

  const total =
    interestScore * WEIGHTS.interests +
    personalityScore * WEIGHTS.personality +
    activityScore * WEIGHTS.activities +
    availabilityScore * WEIGHTS.availability +
    ageScore * WEIGHTS.age +
    educationScore * WEIGHTS.education;

  return {
    score: Math.round(total * 100),
    breakdown: {
      interests: Math.round(interestScore * 100),
      personality: Math.round(personalityScore * 100),
      activities: Math.round(activityScore * 100),
      availability: Math.round(availabilityScore * 100),
      age: Math.round(ageScore * 100),
    },
    sharedInterests: a.interests.filter((i) => b.interests.includes(i)),
    sharedActivities: a.preferredActivities.filter((x) => b.preferredActivities.includes(x)),
  };
}

export function buildRationale({ sharedInterests, sharedActivities, score }) {
  const parts = [];
  if (sharedInterests.length > 0) {
    parts.push(`jullie houden allebei van ${sharedInterests.slice(0, 3).join(', ')}`);
  }
  if (sharedActivities.length > 0) {
    const activityLabels = sharedActivities
      .map((id) => DATE_ACTIVITIES.find((d) => d.id === id)?.label?.toLowerCase() ?? id)
      .slice(0, 2);
    parts.push(`een ${activityLabels.join(' of ')} zien jullie allebei zitten`);
  }
  if (parts.length === 0) {
    parts.push('jullie persoonlijkheden passen goed bij elkaar');
  }
  return `${score}% match — ${parts.join(' en ')}.`;
}

/** Beste nog niet gematchte kandidaat voor `user`, of null. */
export function findBestMatch(user, candidates) {
  let best = null;
  for (const candidate of candidates) {
    if (candidate.id === user.id) continue;
    if (!candidate.interview) continue;
    const result = scoreCompatibility(user, candidate);
    if (!best || result.score > best.score) {
      best = { candidate, ...result };
    }
  }
  return best;
}

function nextOccurrence(dayAbbrev, fromDate = new Date()) {
  const idx = DAYS.indexOf(dayAbbrev);
  const jsDayIdx = (idx + 1) % 7; // DAYS is ma..zo; JS Date.getDay() is zo=0..za=6
  const d = new Date(fromDate);
  d.setHours(0, 0, 0, 0);
  let diff = (jsDayIdx - d.getDay() + 7) % 7;
  if (diff === 0) diff = 7; // altijd een toekomstige dag, nooit "vandaag"
  d.setDate(d.getDate() + diff);
  return d;
}

const TIME_ORDER = ['ochtend', 'middag', 'avond'];

// Begintijden per dagdeel; een date duurt nominaal 2 uur.
export const SLOT_START_HOUR = { ochtend: 10, middag: 14, avond: 20 };
export const DATE_DURATION_HOURS = 2;

export function slotEndTime(slot) {
  const d = new Date(`${slot.date}T00:00:00`);
  d.setHours(SLOT_START_HOUR[slot.timeOfDay] + DATE_DURATION_HOURS, 0, 0, 0);
  return d;
}

/**
 * Bouwt de datumprikker voor een match: een gedeelde activiteit bij een
 * partner in hun stad, plus max 3 concrete tijdsloten waarop zowel beide
 * gebruikers als de partnerlocatie kunnen (dagdeel open + capaciteit vrij).
 * `bookingsFor(venueId, slotId)` telt (async) bestaande reserveringen.
 */
export async function buildDatePicker(userA, userB, bookingsFor, fromDate = new Date()) {
  const a = userA.interview;
  const b = userB.interview;

  const sharedActivities = a.preferredActivities.filter((x) =>
    b.preferredActivities.includes(x)
  );
  const activityOrder = [
    ...sharedActivities,
    ...a.preferredActivities.filter((x) => !sharedActivities.includes(x)),
  ];

  const sharedDays = a.availability.days.filter((d) => b.availability.days.includes(d));
  const dayPool = sharedDays.length > 0 ? sharedDays : a.availability.days;
  const orderedDays = dayPool
    .map((d) => ({ day: d, date: nextOccurrence(d, fromDate) }))
    .sort((x, y) => x.date - y.date);

  const sharedTimes = a.availability.timesOfDay.filter((t) =>
    b.availability.timesOfDay.includes(t)
  );
  const timePool = (sharedTimes.length > 0 ? sharedTimes : a.availability.timesOfDay)
    .slice()
    .sort((x, y) => TIME_ORDER.indexOf(x) - TIME_ORDER.indexOf(y));

  for (const activityId of activityOrder) {
    const activity = DATE_ACTIVITIES.find((d) => d.id === activityId);
    for (const venue of partnersFor(userA.city, activityId)) {
      const venueTimes = timePool.filter((t) => venue.openTimes.includes(t));
      if (venueTimes.length === 0) continue;

      const candidateSlots = orderedDays.flatMap(({ day, date }) =>
        venueTimes.map((timeOfDay) => ({
          id: `${date.toISOString().slice(0, 10)}-${timeOfDay}`,
          day,
          date: date.toISOString().slice(0, 10),
          timeOfDay,
        }))
      );
      const slots = [];
      for (const slot of candidateSlots) {
        if (slots.length === 3) break;
        if ((await bookingsFor(venue.id, slot.id)) < venue.capacityPerSlot) {
          slots.push(slot);
        }
      }

      if (slots.length > 0) {
        return {
          activityId: activity.id,
          activityLabel: activity.label,
          venueId: venue.id,
          venue: venue.name,
          city: userA.city,
          slots,
        };
      }
    }
  }

  // Geen partner met vrije capaciteit op hun overlap: geen prikker mogelijk.
  return null;
}
