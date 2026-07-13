import pg from 'pg';

const DATABASE_URL =
  process.env.DATABASE_URL || 'postgres://datingsite:datingsite@localhost:5432/datingsite';

export const pool = new pg.Pool({ connectionString: DATABASE_URL });

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  first_name    TEXT NOT NULL,
  birth_year    INT  NOT NULL,
  city          TEXT NOT NULL,
  education     TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  interview     JSONB,
  verified      BOOLEAN NOT NULL DEFAULT FALSE,
  strikes       INT NOT NULL DEFAULT 0,
  paused        BOOLEAN NOT NULL DEFAULT FALSE,
  last_drop_date TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS matches (
  id             UUID PRIMARY KEY,
  user_a         UUID NOT NULL REFERENCES users(id),
  user_b         UUID NOT NULL REFERENCES users(id),
  score          INT NOT NULL,
  breakdown      JSONB NOT NULL,
  rationale      TEXT NOT NULL,
  date_picker    JSONB NOT NULL,
  status         TEXT NOT NULL,
  responses      JSONB NOT NULL DEFAULT '{}'::jsonb,
  confirmed_slot JSONB,
  payments       JSONB NOT NULL DEFAULT '{}'::jsonb,
  feedback       JSONB NOT NULL DEFAULT '{}'::jsonb,
  drop_date      TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS matches_user_a_idx ON matches(user_a);
CREATE INDEX IF NOT EXISTS matches_user_b_idx ON matches(user_b);
CREATE INDEX IF NOT EXISTS matches_status_idx ON matches(status);
CREATE INDEX IF NOT EXISTS users_city_idx ON users(city);
`;

export async function initSchema() {
  await pool.query(SCHEMA);
}

// ---- rijen ↔ objecten ----

function rowToUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    email: row.email,
    firstName: row.first_name,
    birthYear: row.birth_year,
    city: row.city,
    education: row.education,
    passwordHash: row.password_hash,
    interview: row.interview,
    verified: row.verified,
    strikes: row.strikes,
    paused: row.paused,
    lastDropDate: row.last_drop_date,
    createdAt: row.created_at,
  };
}

function rowToMatch(row) {
  if (!row) return null;
  return {
    id: row.id,
    userIds: [row.user_a, row.user_b],
    score: row.score,
    breakdown: row.breakdown,
    rationale: row.rationale,
    datePicker: row.date_picker,
    status: row.status,
    responses: row.responses,
    confirmedSlot: row.confirmed_slot,
    payments: row.payments,
    feedback: row.feedback,
    dropDate: row.drop_date,
    createdAt: row.created_at,
  };
}

// ---- users ----

export async function createUser(user) {
  const { rows } = await pool.query(
    `INSERT INTO users (id, email, first_name, birth_year, city, education, password_hash)
     VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
    [user.id, user.email, user.firstName, user.birthYear, user.city, user.education, user.passwordHash]
  );
  return rowToUser(rows[0]);
}

export async function getUserById(id) {
  const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return rowToUser(rows[0]);
}

export async function getUserByEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE lower(email) = lower($1)', [email]);
  return rowToUser(rows[0]);
}

export async function updateUser(id, fields) {
  const map = {
    interview: 'interview',
    verified: 'verified',
    strikes: 'strikes',
    paused: 'paused',
    lastDropDate: 'last_drop_date',
  };
  const sets = [];
  const values = [];
  for (const [key, column] of Object.entries(map)) {
    if (key in fields) {
      values.push(key === 'interview' ? JSON.stringify(fields[key]) : fields[key]);
      sets.push(`${column} = $${values.length}`);
    }
  }
  if (sets.length === 0) return getUserById(id);
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE users SET ${sets.join(', ')} WHERE id = $${values.length} RETURNING *`,
    values
  );
  return rowToUser(rows[0]);
}

const ACTIVE_STATUSES = ['proposed', 'awaiting_payment', 'booked', 'completed'];

/**
 * Kandidaten voor de matchdrop van `user`: zelfde stad, geverifieerd,
 * interview af, niet gepauzeerd, nog nooit met `user` gematcht en op dit
 * moment zonder actieve match.
 */
export async function findCandidates(user) {
  const { rows } = await pool.query(
    `SELECT * FROM users u
     WHERE u.id <> $1
       AND u.city = $2
       AND u.verified
       AND NOT u.paused
       AND u.interview IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM matches m
         WHERE (m.user_a = u.id AND m.user_b = $1) OR (m.user_b = u.id AND m.user_a = $1)
       )
       AND NOT EXISTS (
         SELECT 1 FROM matches m
         WHERE (m.user_a = u.id OR m.user_b = u.id) AND m.status = ANY($3)
       )`,
    [user.id, user.city, ACTIVE_STATUSES]
  );
  return rows.map(rowToUser);
}

// ---- matches ----

export async function createMatch(match) {
  const { rows } = await pool.query(
    `INSERT INTO matches (id, user_a, user_b, score, breakdown, rationale, date_picker,
                          status, responses, confirmed_slot, payments, feedback, drop_date)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING *`,
    [
      match.id,
      match.userIds[0],
      match.userIds[1],
      match.score,
      JSON.stringify(match.breakdown),
      match.rationale,
      JSON.stringify(match.datePicker),
      match.status,
      JSON.stringify(match.responses),
      match.confirmedSlot ? JSON.stringify(match.confirmedSlot) : null,
      JSON.stringify(match.payments),
      JSON.stringify(match.feedback),
      match.dropDate,
    ]
  );
  return rowToMatch(rows[0]);
}

export async function getMatchById(id) {
  const { rows } = await pool.query('SELECT * FROM matches WHERE id = $1', [id]);
  return rowToMatch(rows[0]);
}

export async function getActiveMatchForUser(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM matches
     WHERE (user_a = $1 OR user_b = $1) AND status = ANY($2)
     ORDER BY created_at DESC LIMIT 1`,
    [userId, ACTIVE_STATUSES]
  );
  return rowToMatch(rows[0]);
}

export async function getLastClosedMatchForUser(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM matches
     WHERE (user_a = $1 OR user_b = $1) AND status = 'closed'
     ORDER BY created_at DESC LIMIT 1`,
    [userId]
  );
  return rowToMatch(rows[0]);
}

export async function updateMatch(id, fields) {
  const map = {
    status: ['status', false],
    responses: ['responses', true],
    confirmedSlot: ['confirmed_slot', true],
    payments: ['payments', true],
    feedback: ['feedback', true],
  };
  const sets = [];
  const values = [];
  for (const [key, [column, isJson]] of Object.entries(map)) {
    if (key in fields) {
      const v = fields[key];
      values.push(isJson && v != null ? JSON.stringify(v) : v);
      sets.push(`${column} = $${values.length}`);
    }
  }
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE matches SET ${sets.join(', ')} WHERE id = $${values.length} RETURNING *`,
    values
  );
  return rowToMatch(rows[0]);
}

/** Aantal reserveringen (betalend of geboekt) op een partnerslot. */
export async function countBookings(venueId, slotId) {
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM matches
     WHERE status IN ('awaiting_payment', 'booked', 'completed')
       AND date_picker->>'venueId' = $1
       AND confirmed_slot->>'id' = $2`,
    [venueId, slotId]
  );
  return rows[0].n;
}
