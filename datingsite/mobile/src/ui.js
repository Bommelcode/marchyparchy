import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { colors } from './theme.js';

export function Button({ title, onPress, disabled, secondary }) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.button,
        secondary && styles.buttonSecondary,
        (disabled || pressed) && { opacity: 0.6 },
      ]}
    >
      <Text style={[styles.buttonText, secondary && styles.buttonTextSecondary]}>{title}</Text>
    </Pressable>
  );
}

export function Chip({ label, selected, onPress }) {
  return (
    <Pressable onPress={onPress} style={[styles.chip, selected && styles.chipSelected]}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

export function ChipRow({ children }) {
  return <View style={styles.chipRow}>{children}</View>;
}

export function Field({ label, ...props }) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        style={styles.input}
        placeholderTextColor={colors.text}
        autoCapitalize="none"
        {...props}
      />
    </View>
  );
}

export function Card({ children }) {
  return <View style={styles.card}>{children}</View>;
}

export function H1({ children }) {
  return <Text style={styles.h1}>{children}</Text>;
}

export function H2({ children }) {
  return <Text style={styles.h2}>{children}</Text>;
}

export function P({ children, muted, error, success, style }) {
  return (
    <Text
      style={[
        styles.p,
        muted && { opacity: 0.8 },
        error && { color: colors.error },
        success && { color: colors.success, fontWeight: '600' },
        style,
      ]}
    >
      {children}
    </Text>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: colors.accent,
    borderRadius: 10,
    paddingVertical: 12,
    paddingHorizontal: 20,
    alignItems: 'center',
    marginTop: 8,
  },
  buttonSecondary: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: colors.accent,
  },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  buttonTextSecondary: { color: colors.accent },
  chip: {
    backgroundColor: colors.accentBg,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 999,
    paddingVertical: 7,
    paddingHorizontal: 14,
  },
  chipSelected: { backgroundColor: colors.accent, borderColor: colors.accent },
  chipText: { color: colors.heading, fontSize: 14, fontWeight: '500' },
  chipTextSelected: { color: '#fff' },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 10 },
  field: { marginBottom: 14 },
  fieldLabel: { color: colors.heading, fontSize: 14, marginBottom: 4 },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 12,
    backgroundColor: colors.bg,
    color: colors.heading,
    fontSize: 15,
  },
  card: {
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 14,
    padding: 22,
    marginBottom: 16,
  },
  h1: { fontSize: 26, fontWeight: '600', color: colors.heading, marginBottom: 8 },
  h2: { fontSize: 17, fontWeight: '600', color: colors.heading, marginBottom: 6 },
  p: { color: colors.text, fontSize: 15, lineHeight: 21, marginBottom: 10 },
});
