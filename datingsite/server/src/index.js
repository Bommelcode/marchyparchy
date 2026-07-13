import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';

import { db } from './db.js';
import { hashPassword, verifyPassword, signToken, requireAuth } from './auth.js';
import { INTERVIEW_SCHEMA, validateInterview } from './questions.js';
import { findBestMatch, buildRationale, proposeBlindDate } from './matching.js';

const app = express();
app.use(cors());
app.use(express.json());

const auth = requireAuth(db);

function publicUser(user) {
  return { id: user.id, email: user.email, firstName: user.firstName, hasInterview: !!user.interview };
}

// ---- auth ----

app.post('/api/auth/signup', (req, res) => {
  const { email, password, firstName } = req.body || {};
  if (!email || !password || !firstName) {
    return res.status(400).json({ error: 'email, password and firstName are required' });
  }
  if (db.users.some((u) => u.email.toLowerCase() === String(email).toLowerCase())) {
    return res.status(409).json({ error: 'An account with that email already exists' });
  }
  const user = {
    id: crypto.randomUUID(),
    email,
    firstName,
    passwordHash: hashPassword(password),
    interview: null,
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
    return res.status(401).json({ error: 'Invalid email or password' });
  }
  res.json({ token: signToken(user), user: publicUser(user) });
});

app.get('/api/me', auth, (req, res) => {
  res.json({ user: publicUser(req.user) });
});

// ---- interview ----

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

// ---- matching ----

function activeMatchFor(userId) {
  return db.matches.find(
    (m) => m.userIds.includes(userId) && (m.status === 'proposed' || m.status === 'confirmed')
  );
}

function otherUserId(match, userId) {
  return match.userIds.find((id) => id !== userId);
}

function matchView(match, userId) {
  const partner = db.users.find((u) => u.id === otherUserId(match, userId));
  return {
    id: match.id,
    status: match.status,
    score: match.score,
    rationale: match.rationale,
    partner: { firstName: partner.firstName },
    proposal: match.proposal,
    yourResponse: match.responses[userId] ?? null,
    partnerResponded: match.responses[otherUserId(match, userId)] != null,
  };
}

app.get('/api/match/status', auth, (req, res) => {
  const match = activeMatchFor(req.user.id);
  if (!match) return res.json({ match: null });
  res.json({ match: matchView(match, req.user.id) });
});

app.post('/api/match/find', auth, (req, res) => {
  if (!req.user.interview) {
    return res.status(400).json({ error: 'Complete the interview before matching' });
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
      !alreadyPaired.has(u.id) &&
      !activeMatchFor(u.id)
  );

  const best = findBestMatch(req.user, candidates);
  if (!best) {
    return res.json({ match: null, message: 'No compatible candidates yet — check back soon.' });
  }

  const proposal = proposeBlindDate(req.user.interview, best.candidate.interview);
  const match = {
    id: crypto.randomUUID(),
    userIds: [req.user.id, best.candidate.id],
    score: best.score,
    breakdown: best.breakdown,
    rationale: buildRationale(best),
    proposal,
    status: 'proposed',
    responses: { [req.user.id]: null, [best.candidate.id]: null },
    createdAt: new Date().toISOString(),
  };
  db.matches.push(match);
  db.save();
  res.status(201).json({ match: matchView(match, req.user.id) });
});

app.post('/api/match/:id/respond', auth, (req, res) => {
  const { response } = req.body || {};
  if (response !== 'accept' && response !== 'decline') {
    return res.status(400).json({ error: "response must be 'accept' or 'decline'" });
  }
  const match = db.matches.find((m) => m.id === req.params.id);
  if (!match || !match.userIds.includes(req.user.id)) {
    return res.status(404).json({ error: 'Match not found' });
  }
  if (match.status !== 'proposed') {
    return res.status(400).json({ error: `Match already ${match.status}` });
  }

  match.responses[req.user.id] = response;
  if (response === 'decline') {
    match.status = 'declined';
  } else {
    const partnerId = otherUserId(match, req.user.id);
    if (match.responses[partnerId] === 'accept') {
      match.status = 'confirmed';
    }
  }
  db.save();
  res.json({ match: matchView(match, req.user.id) });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`datingsite server listening on :${PORT}`);
});
