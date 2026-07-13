import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { api } from '../api.js';
import { useAuth } from '../AuthContext.jsx';

export default function Verify() {
  const { user, refresh } = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  if (user?.verified) return <Navigate to="/dashboard" replace />;

  async function handleVerify() {
    setBusy(true);
    setError(null);
    try {
      await api.verify();
      await refresh();
      navigate('/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card">
      <h1>Verifieer je profiel</h1>
      <p className="muted">
        Iedereen op Met is gescreend en geverifieerd, zodat je veilig op date gaat met
        wie diegene zegt te zijn. Zonder verificatie doe je niet mee aan de dagelijkse
        matchronde.
      </p>
      <p className="muted">
        In de demo keurt de check je direct goed; in productie doe je hier een ID- en
        fotoverificatie.
      </p>
      {error && <p className="error">{error}</p>}
      <button onClick={handleVerify} disabled={busy}>
        {busy ? 'Verifiëren…' : 'Start verificatie'}
      </button>
    </div>
  );
}
