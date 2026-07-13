import { useEffect, useState } from 'react';
import { View } from 'react-native';
import Slider from './LikertRow.js';
import { api } from '../api.js';
import { Button, Card, Chip, ChipRow, H1, H2, P } from '../ui.js';

function toggle(list, value) {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

export default function InterviewScreen({ onDone }) {
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

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const { user } = await api.submitInterview({
        interests,
        personality,
        preferredActivities,
        availability: { days, timesOfDay },
      });
      onDone(user);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (!schema) {
    return (
      <Card>
        <P>Interview laden…</P>
      </Card>
    );
  }

  return (
    <Card>
      <H1>Een paar korte vragen</H1>
      <P muted>
        Hiermee zoeken we iemand die bij je past en plannen we meteen een echte eerste date —
        geen geswipe, geen gechat.
      </P>

      <H2>Waar word je blij van?</H2>
      <ChipRow>
        {schema.interests.map((interest) => (
          <Chip
            key={interest}
            label={interest}
            selected={interests.includes(interest)}
            onPress={() => setInterests(toggle(interests, interest))}
          />
        ))}
      </ChipRow>

      <H2>Hoe zou je jezelf omschrijven?</H2>
      {schema.personalityTraits.map((trait) => (
        <Slider
          key={trait.id}
          trait={trait}
          value={personality[trait.id] ?? 3}
          onChange={(v) => setPersonality({ ...personality, [trait.id]: v })}
        />
      ))}

      <H2>Wat voor eerste date zie je zitten?</H2>
      <ChipRow>
        {schema.dateActivities.map((activity) => (
          <Chip
            key={activity.id}
            label={activity.label}
            selected={preferredActivities.includes(activity.id)}
            onPress={() => setPreferredActivities(toggle(preferredActivities, activity.id))}
          />
        ))}
      </ChipRow>

      <H2>Wanneer kun je meestal?</H2>
      <ChipRow>
        {schema.days.map((day) => (
          <Chip
            key={day}
            label={day}
            selected={days.includes(day)}
            onPress={() => setDays(toggle(days, day))}
          />
        ))}
      </ChipRow>
      <ChipRow>
        {schema.timesOfDay.map((t) => (
          <Chip
            key={t}
            label={t}
            selected={timesOfDay.includes(t)}
            onPress={() => setTimesOfDay(toggle(timesOfDay, t))}
          />
        ))}
      </ChipRow>

      {error && <P error>{error}</P>}
      <Button title={busy ? 'Opslaan…' : 'Opslaan en verder'} onPress={submit} disabled={busy} />
    </Card>
  );
}
