import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';

// SecureStore bestaat niet op web; daar valt de Expo-webbuild terug op
// localStorage zodat dezelfde code overal draait.
export const storage = {
  async getToken() {
    if (Platform.OS === 'web') return globalThis.localStorage?.getItem('token') ?? null;
    return SecureStore.getItemAsync('token');
  },
  async setToken(token) {
    if (Platform.OS === 'web') return void globalThis.localStorage?.setItem('token', token);
    return SecureStore.setItemAsync('token', token);
  },
  async clearToken() {
    if (Platform.OS === 'web') return void globalThis.localStorage?.removeItem('token');
    return SecureStore.deleteItemAsync('token');
  },
};
