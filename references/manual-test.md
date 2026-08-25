# Manual Self-Test — Run What You Wrote

Read this after producing or changing any code that affects runtime behavior.
Unit tests (see `testing.md`) prove the logic; this file is about proving the
*actual app* — the assistant launches its own change, pokes it like a QA
engineer, and reports evidence. "It compiles" and "the tests pass" are not the
same claim as "I watched it work".

## The Honesty Rule

> **Never claim a change works unless you ran it and saw it work.**
>
> If no device/emulator is available, or the flow needs a second party (a real
> call, a push from the backend), say exactly that: *"code-complete, not
> device-tested — verify X on a device"*. A false "tested ✓" is worse than an
> honest "untested" because it cancels the user's own verification.

## 1. Gate order — cheapest signal first

Run these in order; stop and fix at the first failure. Don't launch an emulator
to discover a syntax error.

```bash
dart format --set-exit-if-changed lib test        # or omit if project format differs
flutter analyze                                    # zero errors; treat new warnings as failures
dart run build_runner build --delete-conflicting-outputs   # only if codegen inputs changed
flutter test                                       # unit/widget suite still green
```

Only when all four are green does manual runtime testing begin.

## 2. Write the test plan BEFORE launching

Three lines minimum, derived from the change itself — not a generic smoke test.
For every change list:

```
Manual Test Plan
  Feature/fix : <what changed, one line>
  Preconditions: <login state, seed data, locale, flags>
  Steps        : 1) … 2) … 3) …
  Expect       : <observable outcome — text, navigation, log line, no crash>
  Edge pokes   : <the 2-3 unhappy paths this change could break>
```

Edge pokes to always consider: loading/empty/error states, no network, rapid
double-tap, back navigation mid-operation, locale switch (e.g. en/es/fr), dark mode,
small screen, app backgrounded mid-flow.

## 3. Launch and drive

```bash
flutter devices                       # pick a target; prefer an already-booted one
flutter run -d <device_id>            # run in background, capture output
```

- Prefer a **running session + hot reload** over cold restarts while iterating;
  cold-start once at the end because init paths (DI, routing redirects, deep
  links) only execute there.
- Drive the UI yourself where possible; where interaction is needed on Android,
  `adb shell input tap/text/swipe/keyevent` works and keeps the loop scriptable.
- For flows too complex to drive by hand, write a throwaway
  `integration_test/manual_probe_test.dart` that walks the steps, run it once
  with `flutter test integration_test/... -d <device>`, then delete it — it is
  a probe, not a suite member.

## 4. Collect evidence — don't just watch

A manual test that leaves no artifact is a claim, not a result. Capture at
least one of:

```bash
# Screenshot
adb exec-out screencap -p > shot.png              # Android
xcrun simctl io booted screenshot shot.png        # iOS simulator

# Logs, filtered to the change
flutter logs | grep -E "MYTAG|Exception|ERROR"
adb logcat -s flutter                              # Android alternative
```

- Add temporary `debugPrint('MYTAG: …')` markers at the decision points of your
  change, assert their order in the log output, then **remove them before
  finishing** — a leftover marker is a review defect.
- Read the log for *unexpected* lines too: a feature can "work" while spamming
  exceptions from a listener you forgot to guard.

## 5. Report — evidence in, adjectives out

End the response with the executed plan, not a vibe:

```
Manual Test Result
  ✓ Step 1-3 pass on <device/emulator, OS version>
  ✓ Log shows MYTAG:start → MYTAG:done, no exceptions
  ✓ Error path: airplane mode → error view + retry works
  ✗ NOT tested: push-tap path (needs real FCM) — verify on device
```

Every `✗ NOT tested` must name what remains and how the user can verify it.
Failed steps are reported with the exact output, then fixed — never silently
re-run until green without saying what changed.

## 6. When runtime testing is impossible

No emulator, platform channel needs real hardware, flow needs a second user or
backend event:

1. Still run all of §1 (static gates + unit tests always work).
2. Cover the logic with a widget/bloc test that simulates the runtime path as
   closely as possible.
3. Declare the gap explicitly using the Honesty Rule wording, and hand the user
   a copy-pasteable test plan (§2) so *they* can run it in one minute.

## What NOT to do

- Don't substitute `flutter analyze` passing for a runtime check on UI changes.
- Don't test only the happy path — the plan's "edge pokes" line exists because
  regressions live there.
- Don't leave probe files, debug markers, or `--dart-define` hacks in the diff.
- Don't run the full manual loop for a comment typo or pure-refactor with green
  tests — scale the ceremony to the blast radius of the change.
