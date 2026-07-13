import { useCallback, useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../AuthContext.jsx';

function toggle(list, value) {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

function slotLabel(slot) {
  return `${slot.day} ${slot.date} · ${slot.timeOfDay}`;
}

export default function Dashboard() {
  const { user, refresh } = useAuth();
  const [match, setMatch] = useState(undefined); // undefined = laden
  const [pickedSlots, setPickedSlots] = useState([]);
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
      setPickedSlots([]);
      if (!result.match) setMessage(result.message || 'Nog geen match gevonden.');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleAccept() {
    setBusy(true);
    setError(null);
    try {
      const result = await api.respondToMatch(match.id, 'accept', pickedSlots);
      await refresh();
      if (result.match.status === 'no_overlap') {
        setMatch(null);
        setMessage(
          'Jullie wilden allebei, maar prikten geen gedeeld moment. Geen zorgen — zoek hieronder een nieuwe match.'
        );
      } else {
        setMatch(result.match);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleDecline() {
    setBusy(true);
    setError(null);
    try {
      await api.respondToMatch(match.id, 'decline');
      await refresh();
      setMatch(null);
      setMessage('Datumprikker afgewezen.');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (user?.paused) {
    return (
      <div className="card">
        <h1>Account gepauzeerd</h1>
        <p>
          Je hebt twee keer een datumprikker afgewezen. Blind Date is voor mensen die écht op
          date willen — daarom staat je account nu op pauze.
        </p>
      </div>
    );
  }

  if (match === undefined) return <div className="card">Laden…</div>;

  return (
    <div className="card wide">
      <h1>Hoi {user?.firstName} 👋</h1>

      {user?.strikes === 1 && !match && (
        <p className="error">
          Let op: je hebt één datumprikker afgewezen. Wijs je er nog één af, dan pauzeren we je
          account.
        </p>
      )}

      {!match && (
        <div>
          <p className="muted">{message || 'Je hebt nog geen actieve match.'}</p>
          <button onClick={handleFindMatch} disabled={busy}>
            {busy ? 'Zoeken…' : 'Vind mijn match'}
          </button>
        </div>
      )}

      {match && (
        <div className="match-card">
          <p className="score">
            {match.score}% match met {match.partner.firstName} ({match.partner.age},{' '}
            {match.partner.education.toUpperCase()})
          </p>
          <p>{match.rationale}</p>

          <div className="proposal">
            <h2>
              {match.datePicker.activityLabel} bij {match.datePicker.venue}
            </h2>
            <p className="muted">{match.datePicker.city} · eerste drankje geregeld</p>

            {match.status === 'confirmed' ? (
              <p className="success">
                De date staat: {slotLabel(match.confirmedSlot)}. Je hoeft alleen maar te komen
                opdagen. 🎉
              </p>
            ) : match.yourResponse ? (
              <p className="muted">
                Jij hebt geprikt — nu {match.partner.firstName} nog. We laten het weten zodra de
                date vaststaat.
              </p>
            ) : (
              <>
                <p>Prik de momenten waarop jij kunt:</p>
                <div className="chip-row">
                  {match.datePicker.slots.map((slot) => (
                    <button
                      type="button"
                      key={slot.id}
                      className={`chip ${pickedSlots.includes(slot.id) ? 'selected' : ''}`}
                      onClick={() => setPickedSlots(toggle(pickedSlots, slot.id))}
                    >
                      {slotLabel(slot)}
                    </button>
                  ))}
                </div>
                <div className="actions">
                  <button onClick={handleAccept} disabled={busy || pickedSlots.length === 0}>
                    Prik deze momenten
                  </button>
                  <button className="secondary" onClick={handleDecline} disabled={busy}>
                    Afwijzen
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {error && <p className="error">{error}</p>}
    </div>
  );
}
