# Code Review — PR Review & AI Self-Review

Read this when reviewing a PR / auditing existing code, and use the self-review
protocol at the end of *every* code-producing response. This is where the Staff
Engineer mindset actually shows up: catch problems before they merge.

## 1. Review order — cheapest signal first

Don't start at line 1. Triage in this order so you spend attention where it
matters:

1. **Does it belong?** Right layer, right feature, right level of abstraction?
   A file in the wrong layer (see `architect.md`) is a bigger problem than a
   naming nit.
2. **Correctness & edge cases.** Null/empty/error/loading states, boundary
   values, concurrency, the unhappy path.
3. **Architecture & coupling.** SOLID, layer boundaries, dependency direction,
   testability.
4. **Performance.** Rebuild scope, leaks/dispose, list building, async.
5. **Security.** Secrets, tokens, storage, transport (see `security.md`).
6. **Tests.** Do they exist, do they test behavior (not implementation), do they
   cover the failure paths?
7. **Style & readability.** Naming, `const`, magic values, docs. Real, but
   lowest priority — and largely automatable via lints.

## 2. Full review checklist

**Architecture & design**
```
[ ] Layer boundaries respected (domain pure; UI doesn't import data/)
[ ] SOLID — esp. single responsibility & dependency inversion
[ ] No cyclic or cross-feature coupling
[ ] Abstractions justified (not speculative — YAGNI)
[ ] Business logic out of widgets (in use cases / blocs)
```

**Correctness**
```
[ ] Loading / empty / error / success all handled
[ ] Failures typed and mapped (no exceptions crossing layers)
[ ] Null safety sound (no unjustified `!`, no risky `late`)
[ ] Edge cases: empty lists, pagination end, timeouts, retries
[ ] No race conditions on async emits (isClosed / mounted guards)
```

**Performance**
```
[ ] Rebuilds scoped (BlocSelector/select, extracted widgets, const)
[ ] All controllers/streams/timers disposed/cancelled
[ ] Lists use builders + itemExtent where fixed
[ ] Heavy work off the UI isolate
[ ] Images sized for their display box
```

**UI & layout** (see `ui-layout.md`, `ui-from-design.md`)
```
[ ] Values from tokens/l10n — no raw hex, inline TextStyle, EdgeInsets, or strings
[ ] No overflow at 360 dp width or textScale 1.3; API/l10n text has maxLines+ellipsis
[ ] Loading / empty / error / success states all drawn and reachable
[ ] Tappable surfaces have press feedback + haptic and are ≥ 48 dp
[ ] Icon-only controls have a semantic label; decorative images excluded
[ ] Dark theme verified, not assumed
[ ] Nothing duplicates an existing shared/common widget
```

**Security**
```
[ ] No hardcoded secrets/keys/tokens
[ ] Tokens in secure storage; not logged
[ ] HTTPS; verification not disabled; pinning where warranted
[ ] Inputs validated; no injection; WebView locked down
```

**Testing**
```
[ ] Tests exist for new logic (>90% of business logic)
[ ] Tests assert behavior, not implementation details
[ ] Failure paths covered, not just the happy path
[ ] Deterministic (externals mocked, no time/order dependence)
```

**Readability & maintainability**
```
[ ] Names reveal intent
[ ] No magic numbers/strings
[ ] No god classes / 200-line build methods
[ ] Effective Dart + flutter_lints clean
[ ] Public APIs documented where non-obvious
```

## 3. Smell detectors — quick "stop and look" triggers

- A `build` method you have to scroll to read.
- A `switch`/`if-else` on a `type`/`status` that keeps growing → polymorphism.
- `catch (_) {}` or `catch (e) { print(e); }` → swallowed error.
- A `StatefulWidget` with `initState` creating controllers but no `dispose`.
- A DTO name (`...Dto`, `...Response`) appearing in `presentation/`.
- `getIt<...>()` called inside `build`.
- Nested `FutureBuilder`/`BlocBuilder`.
- Copy-pasted blocks with one value changed.
- A test that mocks the thing it's supposedly testing, or has no assertions.
- A `Row` containing a `Text` that isn't wrapped in `Expanded`/`Flexible`.
- `MediaQuery.of(context).size.width * 0.42` standing in for a flex ratio.
- A `BlocBuilder` whose builder handles only the success case.
- A hex literal, an inline `TextStyle`, or a quoted user-facing string in a widget.

## 4. How to deliver review feedback

- **Separate blocking from non-blocking.** Prefix nits with `nit:` and
  must-fixes clearly. Don't drown a real bug under ten style comments.
- **Explain the why**, not just the what: "extract this widget so it can be
  `const` and rebuild independently" beats "extract this".
- **Offer the fix** when it's small — show the corrected snippet.
- **Praise good choices** briefly; review isn't only fault-finding.
- Be direct and kind. The goal is better code and a better engineer, not a
  scorecard.

## 5. AI Self-Review protocol (run before finishing any code answer)

Before returning code, silently run this and fix or flag anything that fails.
Surface only the items where you made a judgment call or a trade-off — don't
paste the whole list every time.

```
Self-Review
  [ ] Clean Architecture — layers & dependency direction correct
  [ ] SOLID
  [ ] DRY / KISS / YAGNI
  [ ] Effective Dart + flutter_lints clean
  [ ] Null safety (no unsafe ! / late)
  [ ] Error handling — typed failures, nothing swallowed
  [ ] Testability — dependencies injected, no hidden statics
  [ ] Scalability — will hold up as the feature grows
  [ ] Performance — rebuilds scoped, const, no leaks
  [ ] Readability & naming
  [ ] Maintainability
  [ ] Disposal — controllers/streams closed
  [ ] Documentation on non-obvious public APIs
```

If the user's request forces a rule violation (e.g. "just hardcode the key for
now"), don't silently comply and don't silently refuse — name the rule, explain
the risk in one line, and offer the correct approach. That transparency is the
whole point of the Golden Rule.
