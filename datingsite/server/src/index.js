import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';

import { db } from './db.js';
import { hashPassword, verifyPassword, signToken, requireAuth } from './auth.js';
import { INTERVIEW_SCHEMA, PROFILE_SCHEMA, validateInterview, validateProfile } from './questions.js';
import { findBestMatch, buildRationale, buildDatePicker, slotEndTime } from './matching.js';

const app = express();
app.use(cors());
app.use(express.json());

const auth = requireAuth(db);

const MAX_STRIKES = 2;
const PRICE_EUR = 7.5;
const DROP_HOUR = 19;
const ACTIVE_STATUSES = ['proposed', 'awaiting_payment', 'booked', 'completed'];

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

app.post('/api/auth/signup', (req, res) => {
  const { email, password, firstName, birthYear, city, education } = req.body || {};
  if (!email || !password || !firstName) {
    return res.status(400).json({ error: 'E-mail, wachtwoord en voornaam zijn verplicht' });
  }
  const profileError = validateProfile({ birthYear, city, education });
  if (profileError) return res.status(400).json({ error: profileError });
  if (db.users.some((u) => u.email.toLowerCase() === String(email).toLowerCase())) {
    return res.status(409).json({ error: 'Er bestaat al een account met dit e-mailadres' });
  }
  const user = {
    id: crypto.randomUUID(),
    email,
    firstName,
    birthYear,
    city,
    education,
    passwordHash: hashPassword(password),
    interview: null,
    verified: false,
    strikes: 0,
    paused: false,
    lastDropDate: null,
    createdAt: new Date().toISOString(),
  };
  db.users.push(user);
  db.save();
  res.status(201).json({ token: signToken(user), user: publicUser(user) });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  const user = db.users.find((u) => u.email.toLowerCase() === String(email || '').toLowerCase());
  if (!user || !verifyPassword(password || '', user.passwordHash)) {
    return res.status(401).json({ error: 'Onjuist e-mailadres of wachtwoord' });
  }
  res.json({ token: signToken(user), user: publicUser(user) });
});

app.get('/api/me', auth, (req, res) => {
  res.json({ user: publicUser(req.user) });
});

// ---- verificatie ----

// Mock-ID-check: in productie een echte identiteits-/fotoverificatie zoals
// Breeze's screening. Hier keurt de "check" direct goed.
app.post('/api/verify', auth, (req, res) => {
  req.user.verified = true;
  db.save();
  res.json({ user: publicUser(req.user) });
});

// ---- interview ----

app.get('/api/profile/schema', (_req, res) => {
  res.json(PROFILE_SCHEMA);
});

app.get('/api/interview/schema', (_req, res) => {
  res.json(INTERVIEW_SCHEMA);
});

app.post('/api/interview', auth, (req, res) => {
  const error = validateInterview(req.body);
  if (error) return res.status(400).json({ error });
  req.user.interview = req.body;
  db.save();
  res.json({ user: publicUser(req.user) });
});

// ---- matching, datumprikker, betaling, feedback ----

function otherUserId(match, userId) {
  return match.userIds.find((id) => id !== userId);
}

function age(user) {
  return new Date().getFullYear() - user.birthYear;
}

// Reserveringen op een partnerslot: prikkers die dat slot nog kunnen worden
// (proposed) tellen niet mee; betalende/geboekte dates wel.
function bookingsFor(venueId, slotId) {
  return db.matches.filter(
    (m) =>
      ['awaiting_payment', 'booked', 'completed'].includes(m.status) &&
      m.datePicker.venueId === venueId &&
      m.confirmedSlot?.id === slotId
  ).length;
}

// Booked → completed zodra de date voorbij is; lui geëvalueerd.
function refreshMatch(match, now = new Date()) {
  if (match.status === 'booked' && slotEndTime(match.confirmedSlot) < now) {
    match.status = 'completed';
    db.save();
  }
}

function activeMatchFor(userId) {
  const match = db.matches.find(
    (m) => m.userIds.includes(userId) && ACTIVE_STATUSES.includes(m.status)
  );
  if (match) refreshMatch(match); // 'completed' blijft actief tot de feedback binnen is
  return match ?? null;
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

function matchView(match, userId) {
  const partner = db.users.find((u) => u.id === otherUserId(match, userId));
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

function eligibleForDrop(user, dropKey) {
  return (
    user.interview &&
    user.verified &&
    !user.paused &&
    user.lastDropDate !== dropKey &&
    !activeMatchFor(user.id)
  );
}

// De dagelijkse drop: zoekt voor `user` de beste kandidaat in dezelfde stad.
// Lui uitgevoerd wanneer iemand na 19:00 zijn status opvraagt.
function runDropFor(user, { force = false } = {}) {
  const dropKey = currentDropKey();
  if (!force && !eligibleForDrop(user, dropKey)) return null;
  if (force && (activeMatchFor(user.id) || !user.interview || !user.verified || user.paused)) {
    return null;
  }

  const alreadyPaired = new Set(
    db.matches.filter((m) => m.userIds.includes(user.id)).map((m) => otherUserId(m, user.id))
  );

  const candidates = db.users.filter(
    (u) =>
      u.id !== user.id &&
      u.interview &&
      u.verified &&
      !u.paused &&
      u.city === user.city &&
      !alreadyPaired.has(u.id) &&
      !activeMatchFor(u.id)
  );

  const best = findBestMatch(user, candidates);
  if (!best) return null;

  const datePicker = buildDatePicker(user, best.candidate, bookingsFor);
  if (!datePicker) return null; // geen partnerlocatie met vrije capaciteit

  const match = {
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
    dropDate: currentDropKey(),
    createdAt: new Date().toISOString(),
  };
  db.matches.push(match);
  user.lastDropDate = currentDropKey();
  best.candidate.lastDropDate = currentDropKey();
  db.save();
  return match;
}

app.get('/api/match/status', auth, (req, res) => {
  let match = activeMatchFor(req.user.id);
  if (!match) {
    match = runDropFor(req.user);
  }
  if (!match) {
    return res.json({ match: null, nextDropAt: nextDropAt() });
  }
  res.json({ match: matchView(match, req.user.id), nextDropAt: nextDropAt() });
});

app.post('/api/match/:id/respond', auth, (req, res) => {
  const { response, slotIds } = req.body || {};
  const match = db.matches.find((m) => m.id === req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  if (match.status !== 'proposed') {
    return res.status(400).json({ error: 'De datumprikker van deze match is al afgerond' });
  }

  if (response === 'decline') {
    match.responses[req.user.id] = { response: 'decline' };
    match.status = 'declined';
    req.user.strikes = (req.user.strikes ?? 0) + 1;
    if (req.user.strikes >= MAX_STRIKES) {
      req.user.paused = true;
    }
    db.save();
    return res.json({ match: matchView(match, req.user.id), user: publicUser(req.user) });
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

  match.responses[req.user.id] = { response: 'accept', slotIds };

  const partnerId = otherUserId(match, req.user.id);
  const partnerResponse = match.responses[partnerId];
  if (partnerResponse?.response === 'accept') {
    const common = match.datePicker.slots.find(
      (s) => slotIds.includes(s.id) && partnerResponse.slotIds.includes(s.id)
    );
    if (common) {
      match.status = 'awaiting_payment';
      match.confirmedSlot = common;
    } else {
      // Beiden willen, maar geen gedeeld moment: geen strike, match vervalt.
      match.status = 'no_overlap';
    }
  }
  db.save();
  res.json({ match: matchView(match, req.user.id), user: publicUser(req.user) });
});

// Mock-betaling: in productie een echte PSP (iDEAL). €7,50 p.p. vooraf,
// eerste drankje inbegrepen — de commitment-drempel van Breeze.
app.post('/api/match/:id/pay', auth, (req, res) => {
  const match = db.matches.find((m) => m.id === req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  if (match.status !== 'awaiting_payment') {
    return res.status(400).json({ error: 'Deze match wacht niet op betaling' });
  }
  match.payments[req.user.id] = true;
  const partnerId = otherUserId(match, req.user.id);
  if (match.payments[partnerId]) {
    match.status = 'booked';
  }
  db.save();
  res.json({ match: matchView(match, req.user.id) });
});

// Feedback na de date: kwam je match opdagen, en wil je haar/hem terugzien?
// Een gemelde no-show krijgt een strike; wederzijds "ja" deelt contactgegevens.
app.post('/api/match/:id/feedback', auth, (req, res) => {
  const { partnerShowedUp, wantsSecondDate } = req.body || {};
  const match = db.matches.find((m) => m.id === req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  refreshMatch(match);
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

  match.feedback[req.user.id] = {
    partnerShowedUp,
    wantsSecondDate: partnerShowedUp ? wantsSecondDate : false,
    submittedAt: new Date().toISOString(),
  };

  if (!partnerShowedUp) {
    const partner = db.users.find((u) => u.id === otherUserId(match, req.user.id));
    partner.strikes = (partner.strikes ?? 0) + 1;
    if (partner.strikes >= MAX_STRIKES) partner.paused = true;
  }

  const partnerId = otherUserId(match, req.user.id);
  if (match.feedback[partnerId]) {
    match.status = 'closed';
  }
  db.save();
  res.json({ match: matchView(match, req.user.id) });
});

// Laatste afgeronde match, zodat het dashboard de uitkomst kan tonen.
app.get('/api/match/last-result', auth, (req, res) => {
  const closed = db.matches
    .filter((m) => m.userIds.includes(req.user.id) && m.status === 'closed')
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  if (closed.length === 0) return res.json({ match: null });
  res.json({ match: matchView(closed[0], req.user.id) });
});

// ---- dev-hulpmiddelen (niet in productie) ----

if (process.env.NODE_ENV !== 'production') {
  // Forceer een drop buiten het 19:00-ritme om, voor demo's en tests.
  app.post('/api/dev/drop', auth, (req, res) => {
    const match = activeMatchFor(req.user.id) ?? runDropFor(req.user, { force: true });
    if (!match) return res.json({ match: null, message: 'Geen kandidaat beschikbaar' });
    res.json({ match: matchView(match, req.user.id) });
  });

  // Zet de geboekte date in het verleden zodat de feedbackfase testbaar is.
  app.post('/api/dev/finish-date/:id', auth, (req, res) => {
    const match = db.matches.find((m) => m.id === req.params.id);
    if (!match || match.status !== 'booked') {
      return res.status(400).json({ error: 'Geen geboekte match met dit id' });
    }
    const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
    match.confirmedSlot.date = yesterday;
    refreshMatch(match);
    db.save();
    res.json({ match: matchView(match, req.user.id) });
  });
}

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`datingsite server luistert op :${PORT}`);
});
