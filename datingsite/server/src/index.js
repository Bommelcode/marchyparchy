import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';

import { db } from './db.js';
import { hashPassword, verifyPassword, signToken, requireAuth } from './auth.js';
import { INTERVIEW_SCHEMA, PROFILE_SCHEMA, validateInterview, validateProfile } from './questions.js';
import { findBestMatch, buildRationale, buildDatePicker } from './matching.js';

const app = express();
app.use(cors());
app.use(express.json());

const auth = requireAuth(db);

const MAX_STRIKES = 2;

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    birthYear: user.birthYear,
    city: user.city,
    education: user.education,
    hasInterview: !!user.interview,
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
    strikes: 0,
    paused: false,
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

// ---- matching + datumprikker ----

function activeMatchFor(userId) {
  return db.matches.find(
    (m) => m.userIds.includes(userId) && (m.status === 'proposed' || m.status === 'confirmed')
  );
}

function otherUserId(match, userId) {
  return match.userIds.find((id) => id !== userId);
}

function age(user) {
  return new Date().getFullYear() - user.birthYear;
}

function matchView(match, userId) {
  const partner = db.users.find((u) => u.id === otherUserId(match, userId));
  const yourResponse = match.responses[userId] ?? null;
  const partnerResponse = match.responses[otherUserId(match, userId)] ?? null;
  return {
    id: match.id,
    status: match.status,
    score: match.score,
    rationale: match.rationale,
    partner: { firstName: partner.firstName, age: age(partner), education: partner.education },
    datePicker: match.datePicker,
    confirmedSlot: match.confirmedSlot ?? null,
    yourResponse,
    partnerResponded: partnerResponse != null,
  };
}

app.get('/api/match/status', auth, (req, res) => {
  const match = activeMatchFor(req.user.id);
  if (!match) return res.json({ match: null });
  res.json({ match: matchView(match, req.user.id) });
});

app.post('/api/match/find', auth, (req, res) => {
  if (req.user.paused) {
    return res.status(403).json({
      error:
        'Je account staat op pauze omdat je twee keer een datumprikker hebt afgewezen. Blind Date is voor mensen die écht op date willen.',
    });
  }
  if (!req.user.interview) {
    return res.status(400).json({ error: 'Rond eerst het interview af' });
  }
  const existing = activeMatchFor(req.user.id);
  if (existing) {
    return res.json({ match: matchView(existing, req.user.id) });
  }

  const alreadyPaired = new Set(
    db.matches
      .filter((m) => m.userIds.includes(req.user.id))
      .map((m) => otherUserId(m, req.user.id))
  );

  const candidates = db.users.filter(
    (u) =>
      u.id !== req.user.id &&
      u.interview &&
      !u.paused &&
      u.city === req.user.city &&
      !alreadyPaired.has(u.id) &&
      !activeMatchFor(u.id)
  );

  const best = findBestMatch(req.user, candidates);
  if (!best) {
    return res.json({
      match: null,
      message: `Nog geen match in ${req.user.city} — we laten het weten zodra er iemand voor je klaarstaat.`,
    });
  }

  const match = {
    id: crypto.randomUUID(),
    userIds: [req.user.id, best.candidate.id],
    score: best.score,
    breakdown: best.breakdown,
    rationale: buildRationale(best),
    datePicker: buildDatePicker(req.user, best.candidate),
    status: 'proposed',
    responses: { [req.user.id]: null, [best.candidate.id]: null },
    confirmedSlot: null,
    createdAt: new Date().toISOString(),
  };
  db.matches.push(match);
  db.save();
  res.status(201).json({ match: matchView(match, req.user.id) });
});

app.post('/api/match/:id/respond', auth, (req, res) => {
  const { response, slotIds } = req.body || {};
  const match = db.matches.find((m) => m.id === req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match niet gevonden' });
  }
  if (match.status !== 'proposed') {
    return res.status(400).json({ error: 'Deze match is al afgerond' });
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
      match.status = 'confirmed';
      match.confirmedSlot = common;
    } else {
      // Beiden willen, maar geen gedeeld moment: geen strike, match vervalt.
      match.status = 'no_overlap';
    }
  }
  db.save();
  res.json({ match: matchView(match, req.user.id), user: publicUser(req.user) });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`datingsite server luistert op :${PORT}`);
});
