# Security — Secrets, Tokens, Storage, Transport, Auth

Read this when handling credentials, tokens, API keys, secure storage, network
transport, or authentication/authorization flows. Review every code change
against these — a leaked token or hardcoded key is a production incident.

## 1. Secrets & API keys — never hardcode

- No secrets in source, ever. Not in Dart, not in a committed `.env`, not in
  version control history.
- Inject build-time config via `--dart-define` / `--dart-define-from-file` and
  keep the values file out of git (`.gitignore`).

```dart
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const analyticsKey = String.fromEnvironment('ANALYTICS_KEY');
```

- Remember that **anything shipped in the app binary is extractable.** A
  "secret" compiled into the client is not secret. Truly sensitive operations
  (signing, third-party secret keys) belong on your backend, with the client
  calling your API. Client keys should be scoped/restricted and rotatable.
- Scan for accidental leaks: no keys in log output, error messages, analytics
  events, or crash reports.

## 2. Token storage — use the keychain/keystore

- Store access/refresh tokens, PINs, and credentials in
  `flutter_secure_storage` (iOS Keychain / Android Keystore/EncryptedShared
  Preferences). **Never** in `SharedPreferences`, a plain file, or Hive/Isar
  without encryption — those are readable on a rooted/jailbroken device.

```dart
final storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
await storage.write(key: 'refresh_token', value: token);
```

- Keep tokens in memory only as long as needed; don't stash them in global
  mutable singletons that outlive the session.
- On logout, wipe secure storage and any in-memory caches.

## 3. Token lifecycle in the network layer

- Attach the access token via a Dio interceptor, not by hand at each call site.
- Handle `401` centrally: attempt a single refresh, queue in-flight requests,
  retry once, and force logout if refresh fails. Guard against refresh storms
  (multiple 401s triggering parallel refreshes).
- Never log the `Authorization` header or request/response bodies containing
  tokens or PII.

```dart
class AuthInterceptor extends QueuedInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStore.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
```

## 4. Transport security & certificate pinning

- HTTPS only. Reject cleartext: on Android set
  `android:usesCleartextTraffic="false"`; on iOS keep ATS enabled.
- For high-value apps, add **certificate/public-key pinning** so a compromised
  or rogue CA cannot MITM traffic. Pin the SPKI hash, keep a backup pin, and
  have a rotation plan (an expired pin with no backup bricks the app).
- Never disable certificate verification
  (`badCertificateCallback => true`) outside a local dev flavor — and never ship
  it.

## 5. Authentication & authorization

- **Authentication** (who you are) and **authorization** (what you may do) are
  distinct. Enforce both on the **server**. Client-side checks are UX only — a
  hidden button is not a security control.
- Prefer platform biometrics (`local_auth`) for local re-auth; store nothing
  reusable from the biometric result itself.
- Implement session timeout and re-authentication for sensitive actions
  (payments, profile changes).
- Use OAuth2/OIDC with PKCE for third-party login; never embed client secrets in
  the app for the auth flow.

## 6. Input handling & injection

- Treat all server and user input as untrusted. Validate/normalize at the
  boundary (value objects help — see `patterns.md`).
- Parameterize any local SQL (sqflite/Drift) — never string-concatenate user
  input into queries.
- Sanitize anything rendered in a `WebView`; disable JS unless required, and
  restrict navigation. Never inject unescaped user content into a WebView.
- Validate deep-link / App Link / Universal Link parameters before acting on
  them; a malicious link should not be able to drive privileged navigation.

## 7. Logging & data exposure

- No sensitive data in logs (tokens, passwords, full card/PAN, precise
  location, national IDs). Strip or mask before logging.
- Disable verbose network logging in release builds. Gate it behind
  `kDebugMode`.
- Configure crash/analytics tooling to scrub PII; don't attach raw request
  bodies.
- Be careful with clipboard, screenshots, and app-switcher previews for screens
  showing secrets (mask the app preview on iOS/Android for such screens).

## 8. Platform hardening (high-assurance apps)

- Consider root/jailbreak detection and emulator detection for fraud-sensitive
  flows — as *defense in depth*, not a guarantee.
- Enable code obfuscation for release (`flutter build --obfuscate
  --split-debug-info=...`) to raise the reverse-engineering bar. Keep the
  symbol files to de-obfuscate crash traces.
- Keep dependencies patched; run `flutter pub outdated` and audit transitive
  packages. A vulnerable package is your vulnerability.

## Review checklist

```
[ ] No hardcoded secrets / keys / tokens anywhere
[ ] Tokens & credentials only in secure storage
[ ] 401/refresh handled centrally, no refresh storms
[ ] HTTPS enforced; pinning where warranted; verification never disabled
[ ] Authn & authz enforced server-side, not just hidden in UI
[ ] Inputs validated; SQL parameterized; WebView locked down
[ ] No sensitive data in logs / crash reports / analytics
[ ] Release build obfuscated; verbose logging gated to debug
```
