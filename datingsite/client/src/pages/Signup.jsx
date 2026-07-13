import { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../AuthContext.jsx';

export default function Signup() {
  const { signup } = useAuth();
  const navigate = useNavigate();
  const [schema, setSchema] = useState(null);
  const [form, setForm] = useState({
    firstName: '',
    email: '',
    password: '',
    birthYear: '',
    city: '',
    education: '',
  });
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.profileSchema().then(setSchema);
  }, []);

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await signup({ ...form, birthYear: Number(form.birthYear) });
      navigate('/interview');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const maxYear = new Date().getFullYear() - 18;

  return (
    <div className="card">
      <h1>Maak je account</h1>
      <p className="muted">Geen foto's om te swipen, geen eindeloos gechat. Een kort interview en je staat op de datelijst.</p>
      <form onSubmit={handleSubmit}>
        <label>
          Voornaam
          <input
            required
            value={form.firstName}
            onChange={(e) => setForm({ ...form, firstName: e.target.value })}
          />
        </label>
        <label>
          E-mailadres
          <input
            type="email"
            required
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
        </label>
        <label>
          Wachtwoord
          <input
            type="password"
            required
            minLength={6}
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
          />
        </label>
        <label>
          Geboortejaar
          <input
            type="number"
            required
            min={maxYear - 81}
            max={maxYear}
            placeholder="bijv. 1998"
            value={form.birthYear}
            onChange={(e) => setForm({ ...form, birthYear: e.target.value })}
          />
        </label>
        <label>
          Stad
          <select
            required
            value={form.city}
            onChange={(e) => setForm({ ...form, city: e.target.value })}
          >
            <option value="" disabled>
              Kies je stad
            </option>
            {schema?.cities.map((city) => (
              <option key={city} value={city}>
                {city}
              </option>
            ))}
          </select>
        </label>
        <label>
          Opleidingsniveau
          <select
            required
            value={form.education}
            onChange={(e) => setForm({ ...form, education: e.target.value })}
          >
            <option value="" disabled>
              Kies je niveau
            </option>
            {schema?.educationLevels.map((level) => (
              <option key={level} value={level}>
                {level.toUpperCase()}
              </option>
            ))}
          </select>
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={busy}>
          {busy ? 'Account maken…' : 'Aan de slag'}
        </button>
      </form>
      <p className="muted">
        Al een account? <Link to="/login">Log in</Link>
      </p>
    </div>
  );
}
