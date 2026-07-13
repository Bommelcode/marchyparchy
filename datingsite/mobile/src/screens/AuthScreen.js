import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { api } from '../api.js';
import { storage } from '../storage.js';
import { Button, Card, Chip, ChipRow, Field, H1, P } from '../ui.js';
import { colors } from '../theme.js';

export default function AuthScreen({ onAuthed }) {
  const [mode, setMode] = useState('signup');
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
    api.profileSchema().then(setSchema).catch((e) => setError(e.message));
  }, []);

  const set = (key) => (value) => setForm((f) => ({ ...f, [key]: value }));

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const payload =
        mode === 'signup'
          ? { ...form, birthYear: Number(form.birthYear) }
          : { email: form.email, password: form.password };
      const { token, user } = await (mode === 'signup' ? api.signup(payload) : api.login(payload));
      await storage.setToken(token);
      onAuthed(user);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <H1>{mode === 'signup' ? 'Maak je account' : 'Welkom terug'}</H1>
      {mode === 'signup' && (
        <P muted>
          Geen foto's om te swipen, geen eindeloos gechat. Een kort interview en je staat op de
          datelijst.
        </P>
      )}

      {mode === 'signup' && (
        <Field label="Voornaam" value={form.firstName} onChangeText={set('firstName')} />
      )}
      <Field
        label="E-mailadres"
        value={form.email}
        onChangeText={set('email')}
        keyboardType="email-address"
      />
      <Field
        label="Wachtwoord"
        value={form.password}
        onChangeText={set('password')}
        secureTextEntry
      />

      {mode === 'signup' && (
        <>
          <Field
            label="Geboortejaar (bijv. 1998)"
            value={form.birthYear}
            onChangeText={set('birthYear')}
            keyboardType="number-pad"
          />
          <P style={{ color: colors.heading, marginBottom: 4 }}>Stad</P>
          <ChipRow>
            {schema?.cities.map((city) => (
              <Chip
                key={city}
                label={city}
                selected={form.city === city}
                onPress={() => set('city')(city)}
              />
            ))}
          </ChipRow>
          <P style={{ color: colors.heading, marginBottom: 4 }}>Opleidingsniveau</P>
          <ChipRow>
            {schema?.educationLevels.map((level) => (
              <Chip
                key={level}
                label={level.toUpperCase()}
                selected={form.education === level}
                onPress={() => set('education')(level)}
              />
            ))}
          </ChipRow>
        </>
      )}

      {error && <P error>{error}</P>}
      <Button
        title={busy ? 'Bezig…' : mode === 'signup' ? 'Aan de slag' : 'Log in'}
        onPress={submit}
        disabled={busy}
      />

      <Pressable onPress={() => setMode(mode === 'signup' ? 'login' : 'signup')}>
        <Text style={{ color: colors.accent, marginTop: 14, fontSize: 14 }}>
          {mode === 'signup' ? 'Al een account? Log in' : 'Nieuw hier? Maak een account'}
        </Text>
      </Pressable>
    </Card>
  );
}
