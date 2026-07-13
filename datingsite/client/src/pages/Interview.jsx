import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../AuthContext.jsx';

function toggle(list, value) {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

export default function Interview() {
  const { refresh } = useAuth();
  const navigate = useNavigate();
  const [schema, setSchema] = useState(null);
  const [interests, setInterests] = useState([]);
  const [personality, setPersonality] = useState({});
  const [preferredActivities, setPreferredActivities] = useState([]);
  const [days, setDays] = useState([]);
  const [timesOfDay, setTimesOfDay] = useState([]);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.interviewSchema().then((s) => {
      setSchema(s);
      const defaults = {};
      s.personalityTraits.forEach((t) => {
        defaults[t.id] = 3;
      });
      setPersonality(defaults);
    });
  }, []);

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api.submitInterview({
        interests,
        personality,
        preferredActivities,
        availability: { days, timesOfDay },
      });
      await refresh();
      navigate('/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (!schema) return <div className="card">Interview laden…</div>;

  return (
    <div className="card wide">
      <h1>Een paar korte vragen</h1>
      <p className="muted">
        Hiermee zoeken we iemand die bij je past en plannen we meteen een eerste date —
        geen geswipe, geen gechat.
      </p>
      <form onSubmit={handleSubmit}>
        <fieldset>
          <legend>Waar word je blij van? (kies er een paar)</legend>
          <div className="chip-row">
            {schema.interests.map((interest) => (
              <button
                type="button"
                key={interest}
                className={`chip ${interests.includes(interest) ? 'selected' : ''}`}
                onClick={() => setInterests(toggle(interests, interest))}
              >
                {interest}
              </button>
            ))}
          </div>
        </fieldset>

        <fieldset>
          <legend>Hoe zou je jezelf omschrijven?</legend>
          {schema.personalityTraits.map((trait) => (
            <label key={trait.id} className="slider-row">
              <span>{trait.left}</span>
              <input
                type="range"
                min={1}
                max={5}
                value={personality[trait.id] ?? 3}
                onChange={(e) =>
                  setPersonality({ ...personality, [trait.id]: Number(e.target.value) })
                }
              />
              <span>{trait.right}</span>
            </label>
          ))}
        </fieldset>

        <fieldset>
          <legend>Wat voor eerste date zie je zitten?</legend>
          <div className="chip-row">
            {schema.dateActivities.map((activity) => (
              <button
                type="button"
                key={activity.id}
                className={`chip ${preferredActivities.includes(activity.id) ? 'selected' : ''}`}
                onClick={() => setPreferredActivities(toggle(preferredActivities, activity.id))}
              >
                {activity.label}
              </button>
            ))}
          </div>
        </fieldset>

        <fieldset>
          <legend>Wanneer kun je meestal?</legend>
          <div className="chip-row">
            {schema.days.map((day) => (
              <button
                type="button"
                key={day}
                className={`chip ${days.includes(day) ? 'selected' : ''}`}
                onClick={() => setDays(toggle(days, day))}
              >
                {day}
              </button>
            ))}
          </div>
          <div className="chip-row">
            {schema.timesOfDay.map((t) => (
              <button
                type="button"
                key={t}
                className={`chip ${timesOfDay.includes(t) ? 'selected' : ''}`}
                onClick={() => setTimesOfDay(toggle(timesOfDay, t))}
              >
                {t}
              </button>
            ))}
          </div>
        </fieldset>

        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={busy}>
          {busy ? 'Opslaan…' : 'Vind mijn match'}
        </button>
      </form>
    </div>
  );
}
