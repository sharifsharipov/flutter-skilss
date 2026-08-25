# Best Practices — Effective Dart & Flutter Idioms

Read this for language-level and idiom-level guidance: naming, null safety,
immutability, lints, and the day-to-day "prefer/avoid" of writing good Dart.

## 1. Enable strict lints — let the machine enforce the boring rules

Start from `flutter_lints` (or the stricter `very_good_analysis`) and turn on
strict analyzer modes. This catches a large class of issues before review.

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore   # e.g. Freezed json_key on fields

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    require_trailing_commas: true
    unawaited_futures: true
```

A clean `flutter analyze` is part of "done". Don't `// ignore:` a lint without a
one-line reason.

## 2. Naming (Effective Dart)

- **Types & extensions:** `UpperCamelCase` — `TripRepository`, `MoneyX`.
- **Members, variables, params:** `lowerCamelCase` — `getTrips`, `isConnected`.
- **Files & directories:** `lowercase_with_underscores` — `trip_repository.dart`.
- **Constants:** `lowerCamelCase` too (not `SCREAMING_CAPS`) — `defaultTimeout`.
- Name booleans as assertions: `isEnabled`, `hasError`, `canSubmit`.
- Name things by *what they mean*, not their type: `elapsed` not `durationInt`.
- Don't abbreviate unless the abbreviation is more common than the full word
  (`id`, `http`, `db` OK; `usrRepo` not OK).

## 3. Null safety — make illegal states unrepresentable

- Avoid force-unwrap `!` unless you can *prove* non-null right there. Prefer
  `?.`, `??`, `??=`, and pattern matching / `case` binding.
- Use `late` only when you truly initialize before use (e.g. in `initState`) —
  a `late` read before assignment is a runtime crash.
- Prefer non-nullable fields with sensible defaults over nullable-everywhere.
- Model "absent" explicitly with a union (Freezed) rather than a soup of
  nullable fields that can contradict each other.

```dart
// Prefer pattern matching over ! and null checks
final name = switch (user) {
  User(:final displayName?) => displayName,
  _ => 'Guest',
};
```

## 4. Immutability by default

- Fields `final` unless they genuinely must mutate. Whole objects immutable
  where possible (Freezed / `@immutable`).
- `const` everything you can — constructors, literals, collections. It's free
  performance and signals "this never changes".
- Never mutate a list/map you were handed; return a new one. Expose
  `List<T>` as unmodifiable (`List.unmodifiable` / `UnmodifiableListView`) from
  domain objects.

## 5. Modern Dart features to use

- **Records** for lightweight multi-value returns instead of ad-hoc classes or
  out-params: `final (double lat, double lng) center = (41.31, 69.24);`.
- **Pattern matching / `switch` expressions** for exhaustive, expression-style
  branching — pairs perfectly with Freezed sealed unions.
- **Enhanced enums** (with fields/methods) instead of `int` codes + helper maps:

```dart
enum TripStatus {
  draft(0), active(1), delivered(2), cancelled(3);
  const TripStatus(this.code);
  final int code;
  static TripStatus fromCode(int c) =>
      values.firstWhere((s) => s.code == c, orElse: () => draft);
}
```

- **Extensions** for cohesive helpers on existing types instead of static util
  classes: `context.colors`, `'2025-01'.toDateOrNull()`, `double.hp`.

## 6. Async idioms

- `async`/`await` over raw `.then()` chains for readability.
- Don't leave futures unawaited by accident; mark intentional fire-and-forget
  with `unawaited(...)`.
- Wrap awaited work that touches `context` after an `await` with a
  `if (!context.mounted) return;` guard.
- Prefer `Stream` transforms (`where`, `map`, `distinct`, `debounceTime` via
  rxdart if used) over manual buffering.

## 7. Widgets & UI idioms

- `StatelessWidget` unless you own mutable state or a controller lifecycle.
- Extract widgets into classes, not `_build...()` methods (see `refactor.md`).
- Use `Theme`, design tokens, and `TextTheme` instead of hardcoded colors/sizes.
- Localize user-facing strings from day one (`intl`/`l10n`) — retrofitting is
  painful.
- Keys: use `ValueKey`/`ObjectKey` for list items that reorder; `GlobalKey`
  sparingly (it's expensive and often a smell).
- Any `Text` whose content comes from the API or l10n gets an explicit overflow
  policy (`maxLines` + `TextOverflow.ellipsis`) — see `ui-layout.md` §3.
- Respect the system font scale: never lock a text box to a fixed height that
  can't grow, and never clamp `textScaler` to 1.0 to "fix" a layout.
- Icon-only controls carry a `Semantics(label:)` or `tooltip`; decorative images
  are wrapped in `ExcludeSemantics`. Minimum tap target is 48×48 dp.
- Localize from day one; a hardcoded user-facing string is a defect, not a TODO.

## 8. Prefer / Avoid quick reference

**Prefer:** `const` · `final` · `StatelessWidget` · composition · extensions ·
records · sealed unions · pattern matching · enhanced enums · immutable
collections · dependency injection · early returns.

**Avoid:** force-unwrap `!` · `dynamic` · `print` · global mutable state ·
`late` without guaranteed init · giant `Constants` buckets · deep inheritance ·
stringly-typed code (raw strings for routes/status) · `// ignore:` without a
reason · swallowing exceptions (`catch (_) {}`).

## 9. Documentation

- `///` doc comments on public APIs where the intent isn't obvious from the
  name. Explain *why*, not *what the code literally does*.
- Keep comments truthful — a stale comment is worse than none. If the code says
  it, don't repeat it in a comment.
- A short `README` per non-trivial feature/package (what it does, how to run its
  tests) pays off in onboarding.
