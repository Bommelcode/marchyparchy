import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE = path.join(__dirname, '..', 'data', 'db.json');

function load() {
  if (!fs.existsSync(DATA_FILE)) {
    return { users: [], matches: [] };
  }
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'));
}

let state = load();

function persist() {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2));
}

export const db = {
  get users() {
    return state.users;
  },
  get matches() {
    return state.matches;
  },
  save() {
    persist();
  },
  reset() {
    state = { users: [], matches: [] };
    persist();
  },
};
