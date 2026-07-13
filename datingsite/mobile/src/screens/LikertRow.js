import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors } from '../theme.js';

// Vijfpuntsschaal als tikbare stippen — geen native slider-dependency nodig.
export default function LikertRow({ trait, value, onChange }) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{trait.left}</Text>
      <View style={styles.dots}>
        {[1, 2, 3, 4, 5].map((n) => (
          <Pressable key={n} onPress={() => onChange(n)} hitSlop={6}>
            <View style={[styles.dot, value === n && styles.dotActive]} />
          </Pressable>
        ))}
      </View>
      <Text style={[styles.label, styles.labelRight]}>{trait.right}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  label: { color: colors.text, fontSize: 13, width: 80 },
  labelRight: { textAlign: 'right' },
  dots: { flex: 1, flexDirection: 'row', justifyContent: 'space-evenly', alignItems: 'center' },
  dot: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.accentBg,
  },
  dotActive: { backgroundColor: colors.accent, borderColor: colors.accent },
});
