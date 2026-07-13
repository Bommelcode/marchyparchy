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

function euro(n) {
  return `€${n.toFixed(2).replace('.', ',')}`;
}

function Countdown({ until }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const ms = new Date(until).getTime() - now;
  if (ms <= 0) return <span>nu</span>;
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  return (
    <span>
      {h > 0 && `${h} uur `}
      {m} min {s} sec
    </span>
  );
}

export default function Dashboard() {
  const { user, refresh } = useAuth();
  const [match, setMatch] = useState(undefined); // undefined = laden
  const [nextDrop, setNextDrop] = useState(null);
  const [lastResult, setLastResult] = useState(null);
  const [pickedSlots, setPickedSlots] = useState([]);
  const [showedUp, setShowedUp] = useState(null);
  const [secondDate, setSecondDate] = useState(null);
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const loadStatus = useCallback(async () => {
    try {
      const result = await api.matchStatus();
      setMatch(result.match);
      setNextDrop(result.nextDropAt);
      if (!result.match) {
        const { match: last } = await api.lastResult();
        setLastResult(last);
      }
    } catch (err) {
      setError(err.message);
    }
  }, []);

  useEffect(() => {
    if (!user?.hasInterview || !user?.verified) return;
    loadStatus();
    const t = setInterval(loadStatus, 20000); // pollt de matchronde
    return () => clearInterval(t);
  }, [user, loadStatus]);

  if (user && !user.hasInterview) return <Navigate to="/interview" replace />;
  if (user && !user.verified) return <Navigate to="/verify" replace />;

  async function act(fn, after) {
    setBusy(true);
    setError(null);
    try {
      const result = await fn();
      if (after) after(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function handleAccept() {
    act(
      () => api.respondToMatch(match.id, 'accept', pickedSlots),
      async (result) => {
        await refresh();
        if (result.match.status === 'no_overlap') {
          setMatch(null);
          setMessage(
            'Jullie wilden allebei, maar prikten geen gedeeld moment. Morgen om 19:00 sta je weer in de matchronde.'
          );
        } else {
          setMatch(result.match);
        }
      }
    );
  }

  function handleDecline() {
    act(
      () => api.respondToMatch(match.id, 'decline'),
      async () => {
        await refresh();
        setMatch(null);
        setMessage('Datumprikker afgewezen.');
      }
    );
  }

  function handlePay() {
    act(
      () => api.payForMatch(match.id),
      (result) => setMatch(result.match)
    );
  }

  function handleFeedback() {
    act(
      () =>
        api.submitFeedback(match.id, {
          partnerShowedUp: showedUp,
          wantsSecondDate: showedUp ? !!secondDate : false,
        }),
      async (result) => {
        await refresh();
        setMatch(result.match.status === 'closed' ? null : result.match);
        if (result.match.status === 'closed') {
          setLastResult(result.match);
        }
        setShowedUp(null);
        setSecondDate(null);
      }
    );
  }

  if (user?.paused) {
    return (
      <div className="card">
        <h1>Account gepauzeerd</h1>
        <p>
          Je account staat op pauze — door twee afgewezen datumprikkers of een gemelde no-show.
          Blind Date is voor mensen die écht op date willen.
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
          Let op: je hebt één strike. Bij een tweede (afgewezen prikker of no-show) pauzeren we
          je account.
        </p>
      )}

      {!match && (
        <div>
          <p className="muted">{message || 'Je hebt op dit moment geen actieve match.'}</p>
          {nextDrop && (
            <p>
              Volgende matchronde: <strong>elke dag om 19:00</strong> — nog{' '}
              <Countdown until={nextDrop} />.
            </p>
          )}

          {lastResult && (
            <div className="proposal">
              <h2>Je vorige date met {lastResult.partner.firstName}</h2>
              {lastResult.feedback.outcome === 'second_date' && (
                <p className="success">
                  Jullie willen elkaar allebei terugzien! Neem contact op via{' '}
                  <strong>{lastResult.feedback.partnerEmail}</strong>. 💌
                </p>
              )}
              {lastResult.feedback.outcome === 'ended' && (
                <p className="muted">
                  Geen wederzijdse klik deze keer. Morgen om 19:00 sta je weer in de matchronde.
                </p>
              )}
              {lastResult.feedback.outcome === 'no_show' && (
                <p className="muted">
                  Deze date is als no-show afgesloten. Het gemelde bedrag wordt teruggestort.
                </p>
              )}
            </div>
          )}
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
            <p className="muted">
              {match.datePicker.city} · {euro(match.price)} p.p. vooraf, eerste drankje
              inbegrepen
            </p>

            {match.status === 'proposed' && !match.yourResponse && (
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

            {match.status === 'proposed' && match.yourResponse && (
              <p className="muted">
                Jij hebt geprikt — nu {match.partner.firstName} nog. We laten het weten zodra
                jullie een gedeeld moment hebben.
              </p>
            )}

            {match.status === 'awaiting_payment' && (
              <>
                <p>
                  Gedeeld moment gevonden: <strong>{slotLabel(match.confirmedSlot)}</strong>.
                  Leg de date vast door vooraf te betalen.
                </p>
                {match.payment.youPaid ? (
                  <p className="muted">
                    Jij hebt betaald.{' '}
                    {match.payment.partnerPaid
                      ? ''
                      : `Zodra ${match.partner.firstName} ook betaalt, staat de date vast.`}
                  </p>
                ) : (
                  <div className="actions">
                    <button onClick={handlePay} disabled={busy}>
                      Betaal {euro(match.price)} (demo)
                    </button>
                  </div>
                )}
              </>
            )}

            {match.status === 'booked' && (
              <p className="success">
                De date staat: {slotLabel(match.confirmedSlot)}. Beiden betaald — je hoeft
                alleen maar te komen opdagen. 🎉
              </p>
            )}

            {match.status === 'completed' && !match.feedback.youSubmitted && (
              <>
                <p>
                  <strong>Hoe was je date van {slotLabel(match.confirmedSlot)}?</strong>
                </p>
                <p>Kwam {match.partner.firstName} opdagen?</p>
                <div className="chip-row">
                  <button
                    type="button"
                    className={`chip ${showedUp === true ? 'selected' : ''}`}
                    onClick={() => setShowedUp(true)}
                  >
                    Ja
                  </button>
                  <button
                    type="button"
                    className={`chip ${showedUp === false ? 'selected' : ''}`}
                    onClick={() => setShowedUp(false)}
                  >
                    Nee (no-show)
                  </button>
                </div>
                {showedUp && (
                  <>
                    <p>Wil je {match.partner.firstName} nog eens zien?</p>
                    <div className="chip-row">
                      <button
                        type="button"
                        className={`chip ${secondDate === true ? 'selected' : ''}`}
                        onClick={() => setSecondDate(true)}
                      >
                        Ja, graag
                      </button>
                      <button
                        type="button"
                        className={`chip ${secondDate === false ? 'selected' : ''}`}
                        onClick={() => setSecondDate(false)}
                      >
                        Nee
                      </button>
                    </div>
                  </>
                )}
                <div className="actions">
                  <button
                    onClick={handleFeedback}
                    disabled={busy || showedUp === null || (showedUp && secondDate === null)}
                  >
                    Verstuur feedback
                  </button>
                </div>
              </>
            )}

            {match.status === 'completed' && match.feedback.youSubmitted && (
              <p className="muted">
                Bedankt voor je feedback! Zodra {match.partner.firstName} ook reageert, hoor je
                of er een tweede date in zit.
              </p>
            )}
          </div>
        </div>
      )}

      {error && <p className="error">{error}</p>}
    </div>
  );
}
