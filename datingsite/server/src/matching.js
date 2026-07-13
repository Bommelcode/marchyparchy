import { DATE_ACTIVITIES, DAYS, PERSONALITY_TRAITS } from './questions.js';

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

const WEIGHTS = { interests: 0.3, personality: 0.25, activities: 0.3, availability: 0.15 };

/**
 * Scores compatibility between two completed interviews on a 0-100 scale,
 * standing in for a learned matcher until a real model is wired in.
 */
export function scoreCompatibility(interviewA, interviewB) {
  const interestScore = jaccard(interviewA.interests, interviewB.interests);
  const personalityScore = personalityCloseness(interviewA.personality, interviewB.personality);
  const activityScore = jaccard(interviewA.preferredActivities, interviewB.preferredActivities);
  const dayOverlap = jaccard(interviewA.availability.days, interviewB.availability.days);
  const timeOverlap = jaccard(interviewA.availability.timesOfDay, interviewB.availability.timesOfDay);
  const availabilityScore = (dayOverlap + timeOverlap) / 2;

  const total =
    interestScore * WEIGHTS.interests +
    personalityScore * WEIGHTS.personality +
    activityScore * WEIGHTS.activities +
    availabilityScore * WEIGHTS.availability;

  return {
    score: Math.round(total * 100),
    breakdown: {
      interests: Math.round(interestScore * 100),
      personality: Math.round(personalityScore * 100),
      activities: Math.round(activityScore * 100),
      availability: Math.round(availabilityScore * 100),
    },
    sharedInterests: interviewA.interests.filter((i) => interviewB.interests.includes(i)),
    sharedActivities: interviewA.preferredActivities.filter((a) =>
      interviewB.preferredActivities.includes(a)
    ),
  };
}

export function buildRationale({ sharedInterests, sharedActivities, score }) {
  const parts = [];
  if (sharedInterests.length > 0) {
    parts.push(`you both like ${sharedInterests.slice(0, 3).join(', ')}`);
  }
  if (sharedActivities.length > 0) {
    const activityLabels = sharedActivities
      .map((id) => DATE_ACTIVITIES.find((d) => d.id === id)?.label ?? id)
      .slice(0, 2);
    parts.push(`you're both up for ${activityLabels.join(' or ')} dates`);
  }
  if (parts.length === 0) {
    parts.push('your personalities look like a solid fit');
  }
  return `${score}% match — ${parts.join(' and ')}.`;
}

/** Finds the best unmatched candidate for `user` among `candidates`, or null. */
export function findBestMatch(user, candidates) {
  let best = null;
  for (const candidate of candidates) {
    if (candidate.id === user.id) continue;
    if (!candidate.interview) continue;
    const result = scoreCompatibility(user.interview, candidate.interview);
    if (!best || result.score > best.score) {
      best = { candidate, ...result };
    }
  }
  return best;
}

function nextOccurrence(dayAbbrev, fromDate = new Date()) {
  const idx = DAYS.indexOf(dayAbbrev);
  const jsDayIdx = (idx + 1) % 7; // DAYS is mon..sun; JS Date.getDay() is sun=0..sat=6
  const d = new Date(fromDate);
  d.setHours(0, 0, 0, 0);
  let diff = (jsDayIdx - d.getDay() + 7) % 7;
  if (diff === 0) diff = 7; // propose a future day, never "today"
  d.setDate(d.getDate() + diff);
  return d;
}

/**
 * Picks a shared activity + a shared availability slot for two matched users
 * and turns it into a concrete blind-date proposal.
 */
export function proposeBlindDate(interviewA, interviewB, fromDate = new Date()) {
  const sharedActivities = interviewA.preferredActivities.filter((a) =>
    interviewB.preferredActivities.includes(a)
  );
  const activityId = sharedActivities[0] ?? interviewA.preferredActivities[0];
  const activity = DATE_ACTIVITIES.find((d) => d.id === activityId);

  const sharedDays = interviewA.availability.days.filter((d) =>
    interviewB.availability.days.includes(d)
  );
  const dayPool = sharedDays.length > 0 ? sharedDays : interviewA.availability.days;
  const day = dayPool
    .map((d) => ({ d, date: nextOccurrence(d, fromDate) }))
    .sort((a, b) => a.date - b.date)[0];

  const sharedTimes = interviewA.availability.timesOfDay.filter((t) =>
    interviewB.availability.timesOfDay.includes(t)
  );
  const timeOfDay = sharedTimes[0] ?? interviewA.availability.timesOfDay[0];

  return {
    activityId: activity.id,
    activityLabel: activity.label,
    venue: activity.venue,
    day: day.d,
    date: day.date.toISOString().slice(0, 10),
    timeOfDay,
  };
}
