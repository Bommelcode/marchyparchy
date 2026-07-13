import { BrowserRouter, Routes, Route, Navigate, Link } from 'react-router-dom';
import { AuthProvider, useAuth } from './AuthContext.jsx';
import Signup from './pages/Signup.jsx';
import Login from './pages/Login.jsx';
import Interview from './pages/Interview.jsx';
import Dashboard from './pages/Dashboard.jsx';
import './App.css';

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="card">Loading…</div>;
  if (!user) return <Navigate to="/login" replace />;
  return children;
}

function NavBar() {
  const { user, logout } = useAuth();
  return (
    <nav className="navbar">
      <Link to="/" className="brand">
        ☕ Blind Date
      </Link>
      {user && (
        <div className="nav-links">
          <span className="muted">{user.email}</span>
          <button className="link-button" onClick={logout}>
            Log out
          </button>
        </div>
      )}
    </nav>
  );
}

function Home() {
  const { user } = useAuth();
  if (user) return <Navigate to="/dashboard" replace />;
  return (
    <div className="card">
      <h1>Skip the swiping.</h1>
      <p className="muted">
        Answer a short interview, get matched by compatibility, and go on a real first date —
        coffee, a walk, or something active. No profiles to scroll.
      </p>
      <div className="actions">
        <Link to="/signup">
          <button>Get started</button>
        </Link>
        <Link to="/login">
          <button className="secondary">Log in</button>
        </Link>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <NavBar />
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/signup" element={<Signup />} />
            <Route path="/login" element={<Login />} />
            <Route
              path="/interview"
              element={
                <ProtectedRoute>
                  <Interview />
                </ProtectedRoute>
              }
            />
            <Route
              path="/dashboard"
              element={
                <ProtectedRoute>
                  <Dashboard />
                </ProtectedRoute>
              }
            />
          </Routes>
        </main>
      </AuthProvider>
    </BrowserRouter>
  );
}
