import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';

import * as db from './db.js';
import { hashPassword, verifyPassword, signToken, requireAuth } from './auth.js';
import { INTERVIEW_SCHEMA, PROFILE_SCHEMA, validateInterview, validateProfile } from './questions.js';
import { findBestMatch, buildRationale, buildDatePicker, slotEndTime } from './matching.js';

const app = express();
app.use(cors());
app.use(express.json());

const auth = requireAuth(db.getUserById);

const MAX_STRIKES = 2;
const PRICE_EUR = 7.5;
const DROP_HOUR = 19;

// Express 4 vangt rejections in async handlers niet zelf af.
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    birthYear: user.birthYear,
    city: user.city,
    education: user.education,
    hasInterview: !!user.interview,
    verified: !!user.verified,
    strikes: user.strikes ?? 0,
    paused: !!user.paused,
  };
}

// ---- auth ----

app.post('/api/auth/signup', wrap(async (req, res) => {
  const { email, password, firstName, birthYear, city, education } = req.body || {};
  if (!email || !password || !firstName) {
    return res.status(400).json({ error: 'E-mail, wachtwoord en voornaam zijn verplicht' });
  }
  const profileError = validateProfile({ birthYear, city, education });
  if (profileError) return res.status(400).json({ error: profileError });
  if (await db.getUserByEmail(email)) {
    return res.status(409).json({ error: 'Er bestaat al een account met dit e-mailadres' });
  }
  const user = await db.createUser({
    id: crypto.randomUUID(),
    email,
    firstName,
    birthYear,
    city,
    education,
    passwordHash: hashPassword(password),
  });
  res.status(201).json({ token: signToken(user), user: publicUser(user) });
}));

app.post('/api/auth/login', wrap(async (req, res) => {
  const { email, password } = req.body || {};
  const user = await db.getUserByEmail(email || '');
  if (!user || !verifyPassword(password || '', user.passwordHash)) {
    return res.status(401).json({ error: 'Onjuist e-mailadres of wachtwoord' });
  }
  res.json({ token: signToken(user), user: publicUser(user) });
}));

app.get('/api/me', auth, (req, res) => {
  res.json({ user: publicUser(req.user) });
});

// ---- verificatie ----

// Mock-ID-check: in productie een echte identiteits-/fotoverificatie zoals
// Breeze's screening. Hier keurt de "check" direct goed.
app.post('/api/verify', auth, wrap(async (req, res) => {
  const user = await db.updateUser(req.user.id, { verified: true });
  res.json({ user: publicUser(user) });
}));

// ---- interview ----

app.get('/api/profile/schema', (_req, res) => {
  res.json(PROFILE_SCHEMA);
});

app.get('/api/interview/schema', (_req, res) => {
  res.json(INTERVIEW_SCHEMA);
});

app.post('/api/interview', auth, wrap(async (req, res) => {
  const error = validateInterview(req.body);
  if (error) return res.status(400).json({ error });
  const user = await db.updateUser(req.user.id, { interview: req.body });
  res.json({ user: publicUser(user) });
}));

// ---- matching, datumprikker, betaling, feedback ----

function otherUserId(match, userId) {
  return match.userIds.find((id) => id !== userId);
}

function age(user) {
  return new Date().getFullYear() - user.birthYear;
}

// Booked → completed zodra de date voorbij is; lui geëvalueerd.
async function refreshMatch(match, now = new Date()) {
  if (match.status === 'booked' && slotEndTime(match.confirmedSlot) < now) {
    return db.updateMatch(match.id, { status: 'completed' });
  }
  return match;
}

async function activeMatchFor(userId) {
  const match = await db.getActiveMatchForUser(userId);
  if (!match) return null;
  return refreshMatch(match); // 'completed' blijft actief tot de feedback binnen is
}

function feedbackOutcome(match) {
  const [idA, idB] = match.userIds;
  const fa = match.feedback?.[idA];
  const fb = match.feedback?.[idB];
  if (!fa || !fb) return null;
  if (!fa.partnerShowedUp || !fb.partnerShowedUp) return 'no_show';
  if (fa.wantsSecondDate && fb.wantsSecondDate) return 'second_date';
  return 'ended';
}

async function matchView(match, userId) {
  const partner = await db.getUserById(otherUserId(match, userId));
  const yourResponse = match.responses[userId] ?? null;
  const partnerResponse = match.responses[otherUserId(match, userId)] ?? null;
  const outcome = feedbackOutcome(match);
  return {
    id: match.id,
    status: match.status,
    score: match.score,
    rationale: match.rationale,
    partner: { firstName: partner.firstName, age: age(partner), education: partner.education },
    datePicker: match.datePicker,
    confirmedSlot: match.confirmedSlot ?? null,
    price: PRICE_EUR,
    yourResponse,
    partnerResponded: partnerResponse != null,
    payment: {
      youPaid: !!match.payments?.[userId],
      partnerPaid: !!match.payments?.[otherUserId(match, userId)],
    },
    feedback: {
      youSubmitted: !!match.feedback?.[userId],
      partnerSubmitted: !!match.feedback?.[otherUserId(match, userId)],
      outcome,
      // Contact wordt pas gedeeld als jullie elkaar allebei terug willen zien.
      partnerEmail: outcome === 'second_date' ? partner.email : null,
    },
  };
}

function currentDropKey(now = new Date()) {
  const d = new Date(now);
  if (d.getHours() < DROP_HOUR) d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10);
}

function nextDropAt(now = new Date()) {
  const d = new Date(now);
  d.setHours(DROP_HOUR, 0, 0, 0);
  if (d <= now) d.setDate(d.getDate() + 1);
  return d.toISOString();
}

// De dagelijkse drop: zoekt voor `user` de beste kandidaat in dezelfde stad.
// Lui uitgevoerd wanneer iemand na 19:00 zijn status opvraagt.
async function runDropFor(user, { force = false } = {}) {
  const dropKey = currentDropKey();
  if (!user.interview || !user.verified || user.paused) return null;
  if (!force && user.lastDropDate === dropKey) return null;
  if (await activeMatchFor(user.id)) return null;

  const candidates = await db.findCandidates(user);
  const best = findBestMatch(user, candidates);
  if (!best) return null;

  const datePicker = await buildDatePicker(user, best.candidate, db.countBookings);
  if (!datePicker) return null; // geen partnerlocatie met vrije capaciteit

  const match = await db.createMatch({
    id: crypto.randomUUID(),
    userIds: [user.id, best.candidate.id],
    score: best.score,
    breakdown: best.breakdown,
    rationale: buildRationale(best),
    datePicker,
    status: 'proposed',
    responses: { [user.id]: null, [best.candidate.id]: null },
    confirmedSlot: null,
    payments: {},
    feedback: {},
    dropDate: dropKey,
  });
  await db.updateUser(user.id, { lastDropDate: dropKey });
  await db.updateUser(best.candidate.id, { lastDropDate: dropKey });
  return match;
}

app.get('/api/match/status', auth, wrap(async (req, res) => {
  let match = await activeMatchFor(req.user.id);
  if (!match) {
    match = await runDropFor(req.user);
  }
  if (!match) {
    return res.json({ match: null, nextDropAt: nextDropAt() });
  }
  res.json({ match: await matchView(match, req.user.id), nextDropAt: nextDropAt() });
}));

app.post('/api/match/:id/respond', auth, wrap(async (req, res) => {
  const { response, slotIds } = req.body || {};
  let match = await db.getMatchById(req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  if (match.status !== 'proposed') {
    return res.status(400).json({ error: 'De datumprikker van deze match is al afgerond' });
  }

  if (response === 'decline') {
    const responses = { ...match.responses, [req.user.id]: { response: 'decline' } };
    match = await db.updateMatch(match.id, { responses, status: 'declined' });
    const strikes = (req.user.strikes ?? 0) + 1;
    const user = await db.updateUser(req.user.id, {
      strikes,
      paused: strikes >= MAX_STRIKES,
    });
    return res.json({ match: await matchView(match, req.user.id), user: publicUser(user) });
  }

  if (response !== 'accept') {
    return res.status(400).json({ error: "response moet 'accept' of 'decline' zijn" });
  }
  const validSlotIds = match.datePicker.slots.map((s) => s.id);
  if (
    !Array.isArray(slotIds) ||
    slotIds.length === 0 ||
    !slotIds.every((id) => validSlotIds.includes(id))
  ) {
    return res.status(400).json({ error: 'Prik minstens één van de voorgestelde momenten' });
  }

  const responses = { ...match.responses, [req.user.id]: { response: 'accept', slotIds } };
  const updates = { responses };

  const partnerResponse = responses[otherUserId(match, req.user.id)];
  if (partnerResponse?.response === 'accept') {
    const common = match.datePicker.slots.find(
      (s) => slotIds.includes(s.id) && partnerResponse.slotIds.includes(s.id)
    );
    if (common) {
      updates.status = 'awaiting_payment';
      updates.confirmedSlot = common;
    } else {
      // Beiden willen, maar geen gedeeld moment: geen strike, match vervalt.
      updates.status = 'no_overlap';
    }
  }
  match = await db.updateMatch(match.id, updates);
  res.json({ match: await matchView(match, req.user.id), user: publicUser(req.user) });
}));

// Mock-betaling: in productie een echte PSP (iDEAL). €7,50 p.p. vooraf,
// eerste drankje inbegrepen — de commitment-drempel van Breeze.
app.post('/api/match/:id/pay', auth, wrap(async (req, res) => {
  let match = await db.getMatchById(req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  if (match.status !== 'awaiting_payment') {
    return res.status(400).json({ error: 'Deze match wacht niet op betaling' });
  }
  const payments = { ...match.payments, [req.user.id]: true };
  const updates = { payments };
  if (payments[otherUserId(match, req.user.id)]) {
    updates.status = 'booked';
  }
  match = await db.updateMatch(match.id, updates);
  res.json({ match: await matchView(match, req.user.id) });
}));

// Feedback na de date: kwam je match opdagen, en wil je haar/hem terugzien?
// Een gemelde no-show krijgt een strike; wederzijds "ja" deelt contactgegevens.
app.post('/api/match/:id/feedback', auth, wrap(async (req, res) => {
  const { partnerShowedUp, wantsSecondDate } = req.body || {};
  let match = await db.getMatchById(req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  match = await refreshMatch(match);
  if (match.status !== 'completed') {
    return res.status(400).json({ error: 'Feedback kan pas na de date' });
  }
  if (match.feedback[req.user.id]) {
    return res.status(400).json({ error: 'Je hebt al feedback gegeven' });
  }
  if (typeof partnerShowedUp !== 'boolean') {
    return res.status(400).json({ error: 'Geef aan of je date kwam opdagen' });
  }
  if (partnerShowedUp && typeof wantsSecondDate !== 'boolean') {
    return res.status(400).json({ error: 'Geef aan of je een tweede date wilt' });
  }

  const feedback = {
    ...match.feedback,
    [req.user.id]: {
      partnerShowedUp,
      wantsSecondDate: partnerShowedUp ? wantsSecondDate : false,
      submittedAt: new Date().toISOString(),
    },
  };
  const updates = { feedback };

  if (!partnerShowedUp) {
    const partner = await db.getUserById(otherUserId(match, req.user.id));
    const strikes = (partner.strikes ?? 0) + 1;
    await db.updateUser(partner.id, { strikes, paused: strikes >= MAX_STRIKES });
  }

  if (feedback[otherUserId(match, req.user.id)]) {
    updates.status = 'closed';
  }
  match = await db.updateMatch(match.id, updates);
  res.json({ match: await matchView(match, req.user.id) });
}));

// Laatste afgeronde match, zodat het dashboard de uitkomst kan tonen.
app.get('/api/match/last-result', auth, wrap(async (req, res) => {
  const match = await db.getLastClosedMatchForUser(req.user.id);
  if (!match) return res.json({ match: null });
  res.json({ match: await matchView(match, req.user.id) });
}));

// ---- dev-hulpmiddelen (niet in productie) ----

if (process.env.NODE_ENV !== 'production') {
  // Forceer een drop buiten het 19:00-ritme om, voor demo's en tests.
  app.post('/api/dev/drop', auth, wrap(async (req, res) => {
    const match = (await activeMatchFor(req.user.id)) ?? (await runDropFor(req.user, { force: true }));
    if (!match) return res.json({ match: null, message: 'Geen kandidaat beschikbaar' });
    res.json({ match: await matchView(match, req.user.id) });
  }));

  // Zet de geboekte date in het verleden zodat de feedbackfase testbaar is.
  app.post('/api/dev/finish-date/:id', auth, wrap(async (req, res) => {
    let match = await db.getMatchById(req.params.id);
    if (!match || match.status !== 'booked') {
      return res.status(400).json({ error: 'Geen geboekte match met dit id' });
    }
    const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
    match = await db.updateMatch(match.id, {
      confirmedSlot: { ...match.confirmedSlot, date: yesterday },
    });
    match = await refreshMatch(match);
    res.json({ match: await matchView(match, req.user.id) });
  }));
}

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Interne serverfout' });
});

const PORT = process.env.PORT || 4000;
await db.initSchema();
app.listen(PORT, () => {
  console.log(`datingsite server luistert op :${PORT}`);
});
