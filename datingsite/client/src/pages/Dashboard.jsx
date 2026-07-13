import { useCallback, useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../AuthContext.jsx';

const ACTIVITY_LABELS = {
  coffee: 'Coffee',
  sport: 'a sport / active date',
  walk: 'a walk & talk',
  dinner: 'dinner',
  museum: 'a museum / culture date',
};

export default function Dashboard() {
  const { user } = useAuth();
  const [match, setMatch] = useState(undefined); // undefined = loading
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const loadStatus = useCallback(async () => {
    try {
      const { match } = await api.matchStatus();
      setMatch(match);
    } catch (err) {
      setError(err.message);
    }
  }, []);

  useEffect(() => {
    if (user?.hasInterview) loadStatus();
  }, [user, loadStatus]);

  if (user && !user.hasInterview) {
    return <Navigate to="/interview" replace />;
  }

  async function handleFindMatch() {
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const result = await api.findMatch();
      setMatch(result.match);
      if (!result.match) setMessage(result.message || 'No compatible candidates yet.');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleRespond(response) {
    setBusy(true);
    setError(null);
    try {
      const result = await api.respondToMatch(match.id, response);
      setMatch(result.match.status === 'declined' ? null : result.match);
      if (response === 'decline') setMessage('No worries — find another match below.');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (match === undefined) return <div className="card">Loading…</div>;

  return (
    <div className="card wide">
      <h1>Hi {user?.firstName} 👋</h1>

      {!match && (
        <div>
          <p className="muted">{message || "You don't have an active match yet."}</p>
          <button onClick={handleFindMatch} disabled={busy}>
            {busy ? 'Searching…' : 'Find my match'}
          </button>
        </div>
      )}

      {match && (
        <div className="match-card">
          <p className="score">{match.score}% compatibility with {match.partner.firstName}</p>
          <p>{match.rationale}</p>

          <div className="proposal">
            <h2>Proposed blind date</h2>
            <p>
              {ACTIVITY_LABELS[match.proposal.activityId] || match.proposal.activityLabel} at{' '}
              {match.proposal.venue}
            </p>
            <p>
              {match.proposal.day.toUpperCase()} {match.proposal.date} —{' '}
              {match.proposal.timeOfDay}
            </p>
          </div>

          {match.status === 'proposed' && !match.yourResponse && (
            <div className="actions">
              <button onClick={() => handleRespond('accept')} disabled={busy}>
                Accept
              </button>
              <button className="secondary" onClick={() => handleRespond('decline')} disabled={busy}>
                Decline
              </button>
            </div>
          )}

          {match.status === 'proposed' && match.yourResponse === 'accept' && (
            <p className="muted">You're in! Waiting on {match.partner.firstName} to respond…</p>
          )}

          {match.status === 'confirmed' && (
            <p className="success">
              It's a date! You and {match.partner.firstName} both said yes.
            </p>
          )}
        </div>
      )}

      {error && <p className="error">{error}</p>}
    </div>
  );
}
