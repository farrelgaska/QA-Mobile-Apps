# Mobile — Environment Configuration

## How the API URL is resolved

`ApiService` resolves the backend URL at runtime using the compile-time
`--dart-define=API_BASE_URL=<url>` flag, via `resolveApiBaseUrl` in
`lib/core/services/api_service.dart`.

Priority order:

1. **Explicit `API_BASE_URL`** — if provided and is a valid absolute URL:
   - HTTPS URL → always used, including for web release builds
   - HTTP URL → used for all targets **except** web+release (blocked; only HTTPS is safe for production web)
2. **Fallback by platform** (when `API_BASE_URL` is absent or blank):
   - Web + release → `https://qa-mobile-api.vercel.app` (hardcoded production fallback)
   - Web + debug → `http://127.0.0.1:3002`
   - Android emulator → `http://10.0.2.2:3002`
   - Other (iOS simulator, desktop) → `http://127.0.0.1:3002`

---

## Local — development

### Android emulator (auto, no `--dart-define` needed)
```sh
flutter run -d <android-emulator>
# Uses http://10.0.2.2:3002 automatically
```

### Flutter Web / Desktop debug
```sh
flutter run -d chrome
# OR
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3002
# Uses http://127.0.0.1:3002 by default; explicit dart-define also works
```

### Physical device on LAN
```sh
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<LAN-IP>:3002
```

---

## Staging

Staging requires a deployed HTTPS backend (see `mock-api/docs/STAGING.md`).
An explicit HTTPS `API_BASE_URL` is used for **all** build modes and platforms,
including web+release. This is verified by the existing unit test:
`test/core/services/api_service_test.dart` — "production Web uses and normalizes
configured HTTPS URL".

### Android / iOS — debug or release
```sh
flutter run -d <device> --dart-define=API_BASE_URL=https://<staging-backend>.vercel.app
```

### Flutter Web — debug
```sh
flutter run -d chrome --dart-define=API_BASE_URL=https://<staging-backend>.vercel.app
```

### Flutter Web — release build
```sh
flutter build web --release --dart-define=API_BASE_URL=https://<staging-backend>.vercel.app
```

---

## Production

### Release build (explicit, recommended)
```sh
flutter build web --release --dart-define=API_BASE_URL=https://qa-mobile-api.vercel.app
```

### Release build (omit `--dart-define`)
The production URL `https://qa-mobile-api.vercel.app` is the hardcoded fallback
when no `API_BASE_URL` is supplied to a web+release build. This means a build
without `--dart-define` will target production. **Always supply `--dart-define`
explicitly to staging builds to prevent accidental production targeting.**

---

## Summary table

| Target | Environment | Command fragment |
|--------|-------------|-----------------|
| Android emulator | Local | _(no dart-define needed)_ |
| Web/Desktop debug | Local | `--dart-define=API_BASE_URL=http://localhost:3002` |
| Physical device | Local | `--dart-define=API_BASE_URL=http://<LAN-IP>:3002` |
| Any target | Staging | `--dart-define=API_BASE_URL=https://<staging-api>` |
| Web release | Production (explicit) | `--dart-define=API_BASE_URL=https://qa-mobile-api.vercel.app` |
| Web release | Production (fallback) | _(omit dart-define — uses hardcoded fallback)_ |
