const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000/api';

function getToken() {
  return localStorage.getItem('token');
}

async function request(path, { method = 'GET', body, auth = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error || `Er ging iets mis (${res.status})`);
  }
  return data;
}

export const api = {
  signup: (payload) => request('/auth/signup', { method: 'POST', body: payload, auth: false }),
  login: (payload) => request('/auth/login', { method: 'POST', body: payload, auth: false }),
  me: () => request('/me'),
  verify: () => request('/verify', { method: 'POST' }),
  profileSchema: () => request('/profile/schema', { auth: false }),
  interviewSchema: () => request('/interview/schema', { auth: false }),
  submitInterview: (answers) => request('/interview', { method: 'POST', body: answers }),
  matchStatus: () => request('/match/status'),
  lastResult: () => request('/match/last-result'),
  respondToMatch: (id, response, slotIds) =>
    request(`/match/${id}/respond`, { method: 'POST', body: { response, slotIds } }),
  payForMatch: (id) => request(`/match/${id}/pay`, { method: 'POST' }),
  submitFeedback: (id, payload) =>
    request(`/match/${id}/feedback`, { method: 'POST', body: payload }),
  // dev-hulpmiddelen (alleen buiten productie beschikbaar)
  devDrop: () => request('/dev/drop', { method: 'POST' }),
  devFinishDate: (id) => request(`/dev/finish-date/${id}`, { method: 'POST' }),
};
