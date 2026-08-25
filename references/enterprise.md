# Enterprise — CI/CD, Monorepo, Flavors, Release, ADRs

Read this when setting up project infrastructure, scaling a codebase across a
team, or defining release/versioning process. These are the practices that keep
a large app shippable by many people over years.

## 1. CI/CD — the automated gate

Every PR must pass, before merge, in this order (fail fast on the cheap steps):

```yaml
# Conceptual pipeline
1. format-check   flutter format --set-exit-if-changed .
2. analyze        flutter analyze          # zero warnings
3. test           flutter test --coverage  # + coverage threshold gate
4. build          flutter build (apk/ipa/web) per flavor
5. (main only)    upload to distribution (Firebase App Distribution / TestFlight)
```

- **Gate on coverage** for business logic so it can't silently rot.
- Cache pub + build artifacts to keep CI fast; slow CI gets bypassed.
- Sign builds with secrets from the CI secret store, never from the repo.
- Protect `main`: required checks + review approval, no direct pushes.

## 2. Flavors / build environments

Separate `dev`, `staging`, `prod` with distinct bundle IDs, names, icons, and
config so they can coexist on one device and can't cross-talk.

```bash
flutter run --flavor dev  --dart-define-from-file=env/dev.json
flutter build apk --flavor prod --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols/prod
```

- Config in per-flavor `--dart-define-from-file` JSON, kept out of git.
- Never point a debug/dev flavor at production data, and never ship a
  cert-verification bypass that exists for the dev flavor.

## 3. Monorepo (melos) — enforcing boundaries by compiler

When features grow, split them into packages so layer boundaries are enforced by
the build system rather than by discipline. A `feature_trips` package that
doesn't depend on `feature_payments` *cannot* import it.

```
packages/
├── app/                 # thin shell: routing, DI wiring, main.dart per flavor
├── core/                # error, network, utils, design-system
├── feature_trips/
├── feature_payments/
└── ...
```

- `melos` runs analyze/test/build across all packages with one command.
- The `app` package composes features; features never depend on each other
  directly — shared contracts live in `core`.
- Enforce dependency rules in each package's `pubspec.yaml`; a forbidden import
  fails to resolve.

Don't start here for a small app (YAGNI) — migrate when a single `lib/` becomes
painful to reason about or multiple squads step on each other.

## 4. Architecture Decision Records (ADRs)

Record significant, hard-to-reverse decisions so the *why* survives team
turnover. One short markdown file per decision in `docs/adr/`.

```markdown
# ADR-0007: Adopt Freezed for domain models
Status: Accepted — 2025-01-15
Context: We need immutability, value equality, and exhaustive state unions.
Decision: Use Freezed for models and BLoC states across all features.
Consequences: + compile-time exhaustiveness, less boilerplate;
              − codegen step in CI, longer build. Revisit if build time hurts.
Alternatives considered: hand-written data classes; built_value.
```

Write an ADR for: state-management choice, error-handling strategy, DI approach,
navigation stack, monorepo split, backend/transport (REST vs gRPC), and any
choice you'd be annoyed to see silently reversed.

## 5. Versioning & releases

- **Semantic versioning** for the app and shared packages: `MAJOR.MINOR.PATCH`.
  Breaking public API of a shared package → MAJOR.
- Keep `pubspec.yaml` `version:` as `x.y.z+build`; automate the build number in
  CI (e.g. from the run number) so it always increases.
- Maintain a **CHANGELOG** (Keep a Changelog format); "Unreleased" section
  updated per PR.
- Consider Conventional Commits (`feat:`, `fix:`, `refactor:`…) — it enables
  automated changelog + version bumping and makes history greppable.
- Tag releases; keep the de-obfuscation symbol files for each release so you can
  read production crash traces.

## 6. Observability in production

- Crash reporting (Crashlytics/Sentry) wired from day one, PII scrubbed.
- Structured, leveled logging behind a logger interface — off/minimal in
  release. No `print`.
- Feature flags / remote config for risky rollouts and kill-switches.
- Analytics events defined centrally (typed), not sprinkled as raw strings.

## 7. Dependency hygiene

- Pin versions; review `flutter pub outdated` regularly and update deliberately,
  not reactively during an incident.
- Audit new dependencies: maintenance, popularity, transitive weight, license,
  and platform support. Every dependency is attack surface and future
  migration cost.
- Prefer a thin adapter around volatile third-party SDKs (see Adapter in
  `patterns.md`) so a swap touches one file.

## 8. Definition of Done (team contract)

A change is "done" when:
```
[ ] flutter analyze — zero warnings
[ ] flutter format — clean
[ ] Tests written & passing; business-logic coverage gate met
[ ] Self-review checklist (review.md) passed
[ ] Docs/ADR/CHANGELOG updated if the change warrants it
[ ] Builds for all flavors in CI
[ ] Reviewed & approved by a peer
```

Infrastructure scales a team the same way clean architecture scales a codebase:
by making the right thing the easy thing and the wrong thing hard.
