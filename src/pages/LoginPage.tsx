import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Eye, EyeOff, Lock, User, AlertCircle } from 'lucide-react';
import { PageTransition } from '../components/layout/PageTransition';

export const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    // Simulate slight async for UX feel
    await new Promise((r) => setTimeout(r, 600));

    if (username === 'admin' && password === 'admin123') {
      localStorage.setItem('qa_admin_auth', 'true');
      localStorage.setItem('isAdminLoggedIn', 'true');
      if (rememberMe) {
        localStorage.setItem('qa_admin_remember', 'true');
      }
      navigate('/dashboard');
    } else {
      setError('Username atau password salah. Gunakan admin / admin123.');
      setIsLoading(false);
    }
  };

  return (
    <PageTransition className="min-h-screen w-full bg-gradient-to-br from-[#F0F9F7] via-[#F7FAFA] to-[#EDF4F8] flex items-center justify-center p-4">
      {/* Background decorative circles */}
      <div className="fixed top-[-80px] right-[-80px] h-[320px] w-[320px] rounded-full bg-[#006B5A]/5 pointer-events-none" />
      <div className="fixed bottom-[-60px] left-[-60px] h-[240px] w-[240px] rounded-full bg-[#006B5A]/5 pointer-events-none" />

      <div className="w-full max-w-md relative z-10">
        {/* Logo & Brand */}
        <div className="text-center mb-8">
          <img
            src="/assets/logo_qa.png"
            alt="QA Digitalization Logo"
            className="h-30 w-30 object-contain mx-auto mb-4"
          />
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">QA Digitalization</h1>
          <p className="text-sm text-gray-500 mt-1 font-medium">Admin Dashboard · Quality Control Management</p>
        </div>

        {/* Login Card */}
        <div className="bg-white rounded-2xl border border-gray-200/80 shadow-xl shadow-gray-200/60 overflow-hidden">
          {/* Card top accent */}
          <div className="h-1 w-full bg-gradient-to-r from-[#006B5A] via-[#00A887] to-[#006B5A]" />

          <div className="px-8 py-8">
            <div className="mb-6">
              <h2 className="text-lg font-bold text-gray-800">Masuk ke Panel Admin</h2>
              <p className="text-xs text-gray-400 mt-1">Khusus untuk administrator QC. Akses terbatas.</p>
            </div>

            <form onSubmit={handleLogin} className="space-y-5">
              {/* Error Alert */}
              {error && (
                <div className="flex items-start gap-3 p-3.5 rounded-xl bg-red-50 border border-red-200/60 text-red-700 text-xs font-medium leading-relaxed animate-fadeIn">
                  <AlertCircle className="h-4 w-4 flex-shrink-0 mt-0.5 text-red-500" />
                  <span>{error}</span>
                </div>
              )}

              {/* Username */}
              <div className="space-y-1.5">
                <label htmlFor="username" className="text-xs font-semibold text-gray-700">
                  Username
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none" />
                  <input
                    id="username"
                    type="text"
                    autoComplete="username"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder="Masukkan username"
                    required
                    className="w-full pl-10 pr-4 py-2.5 text-sm border border-gray-300 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#006B5A]/25 focus:border-[#006B5A] transition-all duration-200"
                  />
                </div>
              </div>

              {/* Password */}
              <div className="space-y-1.5">
                <label htmlFor="password" className="text-xs font-semibold text-gray-700">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none" />
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Masukkan password"
                    required
                    className="w-full pl-10 pr-10 py-2.5 text-sm border border-gray-300 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#006B5A]/25 focus:border-[#006B5A] transition-all duration-200"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                    tabIndex={-1}
                    aria-label={showPassword ? 'Sembunyikan password' : 'Tampilkan password'}
                  >
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>

              {/* Remember Me */}
              <div className="flex items-center gap-2.5">
                <input
                  id="remember-me"
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-[#006B5A] focus:ring-[#006B5A] cursor-pointer"
                />
                <label htmlFor="remember-me" className="text-xs font-medium text-gray-600 cursor-pointer select-none">
                  Ingat saya di perangkat ini
                </label>
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={isLoading || !username || !password}
                className="w-full py-3 px-4 rounded-xl bg-[#006B5A] hover:bg-[#005244] disabled:opacity-60 disabled:cursor-not-allowed text-white font-semibold text-sm transition-all duration-200 active:scale-[0.98] shadow-md shadow-[#006B5A]/25 flex items-center justify-center gap-2"
              >
                {isLoading ? (
                  <>
                    <svg className="animate-spin h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
                    </svg>
                    <span>Memverifikasi...</span>
                  </>
                ) : (
                  'Masuk ke Dashboard'
                )}
              </button>
            </form>
          </div>

          {/* Footer hint */}
          <div className="px-8 py-4 bg-gray-50/70 border-t border-gray-100">
            <p className="text-[11px] text-center text-gray-400">
              Sistem QA Digitalization · Telkom Indonesia · v1.0.0 Prototype
            </p>
          </div>
        </div>

        {/* Demo credential hint */}
        <div className="mt-5 p-3.5 bg-amber-50/80 border border-amber-200/60 rounded-xl">
          <p className="text-xs text-amber-700 text-center font-medium">
            🔑 Demo: username <code className="font-mono font-bold">admin</code> · password <code className="font-mono font-bold">admin123</code>
          </p>
        </div>
      </div>
    </PageTransition>
  );
};
