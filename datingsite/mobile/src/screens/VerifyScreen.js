import { useState } from 'react';
import { api } from '../api.js';
import { Button, Card, H1, P } from '../ui.js';

export default function VerifyScreen({ onDone }) {
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function verify() {
    setBusy(true);
    setError(null);
    try {
      const { user } = await api.verify();
      onDone(user);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <H1>Verifieer je profiel</H1>
      <P muted>
        Iedereen op Met is gescreend en geverifieerd, zodat je veilig op date gaat met wie
        diegene zegt te zijn. Zonder verificatie doe je niet mee aan de dagelijkse matchronde.
      </P>
      <P muted>
        In de demo keurt de check je direct goed; in productie doe je hier een ID- en
        fotoverificatie.
      </P>
      {error && <P error>{error}</P>}
      <Button title={busy ? 'Verifiëren…' : 'Start verificatie'} onPress={verify} disabled={busy} />
    </Card>
  );
}
