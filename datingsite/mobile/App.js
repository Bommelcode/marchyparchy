import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';

import { api } from './src/api.js';
import { storage } from './src/storage.js';
import { colors } from './src/theme.js';
import AuthScreen from './src/screens/AuthScreen.js';
import InterviewScreen from './src/screens/InterviewScreen.js';
import VerifyScreen from './src/screens/VerifyScreen.js';
import DashboardScreen from './src/screens/DashboardScreen.js';

export default function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const token = await storage.getToken();
      if (token) {
        try {
          const { user } = await api.me();
          setUser(user);
        } catch {
          await storage.clearToken();
        }
      }
      setLoading(false);
    })();
  }, []);

  async function logout() {
    await storage.clearToken();
    setUser(null);
  }

  // Simpele fasegestuurde navigatie: auth → interview → verificatie → dashboard.
  let screen = null;
  if (loading) {
    screen = <Text style={styles.loading}>Laden…</Text>;
  } else if (!user) {
    screen = <AuthScreen onAuthed={setUser} />;
  } else if (!user.hasInterview) {
    screen = <InterviewScreen onDone={setUser} />;
  } else if (!user.verified) {
    screen = <VerifyScreen onDone={setUser} />;
  } else {
    screen = <DashboardScreen user={user} onUserChanged={setUser} />;
  }

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar style="dark" />
      <View style={styles.navbar}>
        <Text style={styles.brand}>
          met<Text style={styles.brandDot}>.</Text>
        </Text>
        {user && (
          <Pressable onPress={logout}>
            <Text style={styles.logout}>Uitloggen</Text>
          </Pressable>
        )}
      </View>
      <ScrollView contentContainerStyle={styles.content}>{screen}</ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  navbar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  brand: { fontSize: 24, fontWeight: '700', color: colors.heading, letterSpacing: -0.5 },
  brandDot: { color: colors.accent },
  logout: { color: colors.text, textDecorationLine: 'underline', fontSize: 14 },
  content: { padding: 16, maxWidth: 560, width: '100%', alignSelf: 'center' },
  loading: { color: colors.text, padding: 24 },
});
