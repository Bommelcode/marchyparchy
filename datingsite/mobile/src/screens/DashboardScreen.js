import { useCallback, useEffect, useState } from 'react';
import { View } from 'react-native';
import { api } from '../api.js';
import { Button, Card, Chip, ChipRow, H1, H2, P } from '../ui.js';
import { colors } from '../theme.js';

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
  if (ms <= 0) return <P>nu</P>;
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  return (
    <P>
      Volgende matchronde: elke dag om 19:00 — nog {h > 0 ? `${h} uur ` : ''}
      {m} min {s} sec.
    </P>
  );
}

export default function DashboardScreen({ user, onUserChanged }) {
  const [match, setMatch] = useState(undefined);
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
    loadStatus();
    const t = setInterval(loadStatus, 20000); // pollt de matchronde
    return () => clearInterval(t);
  }, [loadStatus]);

  async function act(fn, after) {
    setBusy(true);
    setError(null);
    try {
      const result = await fn();
      if (after) await after(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function accept() {
    act(
      () => api.respondToMatch(match.id, 'accept', pickedSlots),
      async (result) => {
        if (result.user) onUserChanged(result.user);
        if (result.match.status === 'no_overlap') {
          setMatch(null);
          setMessage('Geen gedeeld moment geprikt. Morgen om 19:00 sta je weer in de ronde.');
        } else {
          setMatch(result.match);
        }
      }
    );
  }

  function decline() {
    act(
      () => api.respondToMatch(match.id, 'decline'),
      async (result) => {
        if (result.user) onUserChanged(result.user);
        setMatch(null);
        setMessage('Datumprikker afgewezen.');
      }
    );
  }

  function pay() {
    act(() => api.payForMatch(match.id), (result) => setMatch(result.match));
  }

  function sendFeedback() {
    act(
      () =>
        api.submitFeedback(match.id, {
          partnerShowedUp: showedUp,
          wantsSecondDate: showedUp ? !!secondDate : false,
        }),
      async (result) => {
        setMatch(result.match.status === 'closed' ? null : result.match);
        if (result.match.status === 'closed') setLastResult(result.match);
        setShowedUp(null);
        setSecondDate(null);
      }
    );
  }

  if (user.paused) {
    return (
      <Card>
        <H1>Account gepauzeerd</H1>
        <P>
          Je account staat op pauze — door twee afgewezen datumprikkers of een gemelde no-show.
          Met is voor mensen die écht op date willen.
        </P>
      </Card>
    );
  }

  if (match === undefined) {
    return (
      <Card>
        <P>Laden…</P>
      </Card>
    );
  }

  return (
    <Card>
      <H1>Hoi {user.firstName} 👋</H1>

      {user.strikes === 1 && !match && (
        <P error>
          Let op: je hebt één strike. Bij een tweede (afgewezen prikker of no-show) pauzeren we
          je account.
        </P>
      )}

      {!match && (
        <View>
          <P muted>{message || 'Je hebt op dit moment geen actieve match.'}</P>
          {nextDrop && <Countdown until={nextDrop} />}
          {lastResult && (
            <View style={{ backgroundColor: colors.accentBg, borderRadius: 10, padding: 14 }}>
              <H2>Je vorige date met {lastResult.partner.firstName}</H2>
              {lastResult.feedback.outcome === 'second_date' && (
                <P success>
                  Jullie willen elkaar allebei terugzien! Neem contact op via{' '}
                  {lastResult.feedback.partnerEmail}. 💌
                </P>
              )}
              {lastResult.feedback.outcome === 'ended' && (
                <P muted>Geen wederzijdse klik deze keer. Morgen sta je weer in de ronde.</P>
              )}
              {lastResult.feedback.outcome === 'no_show' && (
                <P muted>Deze date is als no-show afgesloten. Het bedrag wordt teruggestort.</P>
              )}
            </View>
          )}
        </View>
      )}

      {match && (
        <View>
          <P style={{ fontWeight: '700', color: colors.heading, fontSize: 17 }}>
            {match.score}% match met {match.partner.firstName} ({match.partner.age},{' '}
            {match.partner.education.toUpperCase()})
          </P>
          <P>{match.rationale}</P>

          <View style={{ backgroundColor: colors.accentBg, borderRadius: 10, padding: 14 }}>
            <H2>
              {match.datePicker.activityLabel} bij {match.datePicker.venue}
            </H2>
            <P muted>
              {match.datePicker.city} · {euro(match.price)} p.p. vooraf, eerste drankje
              inbegrepen
            </P>

            {match.status === 'proposed' && !match.yourResponse && (
              <View>
                <P>Prik de momenten waarop jij kunt:</P>
                <ChipRow>
                  {match.datePicker.slots.map((slot) => (
                    <Chip
                      key={slot.id}
                      label={slotLabel(slot)}
                      selected={pickedSlots.includes(slot.id)}
                      onPress={() => setPickedSlots(toggle(pickedSlots, slot.id))}
                    />
                  ))}
                </ChipRow>
                <Button
                  title="Prik deze momenten"
                  onPress={accept}
                  disabled={busy || pickedSlots.length === 0}
                />
                <Button title="Afwijzen" onPress={decline} disabled={busy} secondary />
              </View>
            )}

            {match.status === 'proposed' && match.yourResponse && (
              <P muted>
                Jij hebt geprikt — nu {match.partner.firstName} nog. We laten het weten zodra
                jullie een gedeeld moment hebben.
              </P>
            )}

            {match.status === 'awaiting_payment' && (
              <View>
                <P>
                  Gedeeld moment gevonden: {slotLabel(match.confirmedSlot)}. Leg de date vast
                  door vooraf te betalen.
                </P>
                {match.payment.youPaid ? (
                  <P muted>
                    Jij hebt betaald.{' '}
                    {match.payment.partnerPaid
                      ? ''
                      : `Zodra ${match.partner.firstName} ook betaalt, staat de date vast.`}
                  </P>
                ) : (
                  <Button title={`Betaal ${euro(match.price)} (demo)`} onPress={pay} disabled={busy} />
                )}
              </View>
            )}

            {match.status === 'booked' && (
              <P success>
                De date staat: {slotLabel(match.confirmedSlot)}. Beiden betaald — je hoeft
                alleen maar te komen opdagen. 🎉
              </P>
            )}

            {match.status === 'completed' && !match.feedback.youSubmitted && (
              <View>
                <P style={{ fontWeight: '600', color: colors.heading }}>
                  Hoe was je date van {slotLabel(match.confirmedSlot)}?
                </P>
                <P>Kwam {match.partner.firstName} opdagen?</P>
                <ChipRow>
                  <Chip label="Ja" selected={showedUp === true} onPress={() => setShowedUp(true)} />
                  <Chip
                    label="Nee (no-show)"
                    selected={showedUp === false}
                    onPress={() => setShowedUp(false)}
                  />
                </ChipRow>
                {showedUp && (
                  <View>
                    <P>Wil je {match.partner.firstName} nog eens zien?</P>
                    <ChipRow>
                      <Chip
                        label="Ja, graag"
                        selected={secondDate === true}
                        onPress={() => setSecondDate(true)}
                      />
                      <Chip
                        label="Nee"
                        selected={secondDate === false}
                        onPress={() => setSecondDate(false)}
                      />
                    </ChipRow>
                  </View>
                )}
                <Button
                  title="Verstuur feedback"
                  onPress={sendFeedback}
                  disabled={busy || showedUp === null || (showedUp && secondDate === null)}
                />
              </View>
            )}

            {match.status === 'completed' && match.feedback.youSubmitted && (
              <P muted>
                Bedankt voor je feedback! Zodra {match.partner.firstName} ook reageert, hoor je
                of er een tweede date in zit.
              </P>
            )}
          </View>
        </View>
      )}

      {error && <P error>{error}</P>}
    </Card>
  );
}
