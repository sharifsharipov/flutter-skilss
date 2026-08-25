# Refactoring — KISS, DRY, YAGNI, Extraction

Read this when cleaning up existing code, breaking down a large widget/class, or
removing duplication. Refactoring changes structure, **not behavior** — so it is
only safe with tests (see `testing.md`). Refactor in small, verifiable steps.

§1–7 are general refactoring. **§8 is the widget-composition rulebook** — read it
whenever you split a page, fill a feature's `widgets/` folder, or review UI code.
For creating a feature from scratch, see `scaffold.md`. For building UI from a
screenshot/Figma (drawing pipeline, tokens, shape recipes, reusable-widget
inventory), read `ui-from-design.md` first, and `ui-layout.md` for constraints,
overflow, page shapes, screen states, and accessibility — §8 only covers how to
structure what you build.

## 1. The three principles that drive most refactors

- **KISS — Keep It Simple.** The simplest solution that fully solves the problem
  wins. Clever one-liners that need a comment to explain are usually a net loss.
  Readability over cleverness (the Golden Rule).
- **DRY — Don't Repeat Yourself.** Duplicated *knowledge* is the enemy, not
  duplicated *lines*. Extract when the same rule appears in multiple places, so a
  change happens once. But don't over-abstract two things that merely look
  similar today (see AHA: "Avoid Hasty Abstractions").
- **YAGNI — You Aren't Gonna Need It.** Don't build for imagined future
  requirements. Delete speculative generality, unused params, and "just in case"
  hooks. The best code is the code you didn't write.

## 2. Widget extraction — break down huge `build` methods

A `build` method longer than a screen, or nested more than ~3–4 levels, is a
refactor target. Extract cohesive subtrees into their own **widget classes**
(not helper methods returning `Widget`).

```dart
// BEFORE — one 200-line build with a deep tree
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(children: [ /* header 40 lines */, /* list 80 lines */, /* footer 60 lines */ ]),
  );
}

// AFTER — cohesive, const-able, independently rebuildable pieces
// each one a PUBLIC class in its own file under widgets/
Widget build(BuildContext context) {
  return const Scaffold(
    body: Column(children: [TripsHeader(), Expanded(child: TripsList()), TripsFooter()]),
  );
}
```

**Prefer extracting to a widget class over a `_buildX()` method.** A widget class
can be `const`, gets its own build boundary (so it rebuilds independently), and
is testable in isolation. A helper method rebuilds with the parent every time and
can't be `const`.

Extracted widgets are **public classes in their own files** — not
underscore-private classes buried in the page file. Full rules: §8.

## 3. God classes & long methods

Symptoms: a class with 15+ methods and mixed concerns, a method over ~30–40
lines, or a name containing "Manager"/"Helper"/"Util" doing five unrelated
things.

Refactor moves:
- **Extract Class** — pull a cohesive cluster of fields+methods into its own
  class (Single Responsibility).
- **Extract Method** — name a block of logic; the name documents intent.
- **Move business logic out of the UI** — a bloc/cubit or use case owns it, the
  widget just renders state and dispatches events.
- **Replace conditional with polymorphism** — a growing `switch` on a `type`
  becomes subclasses / a Strategy (Open/Closed).

## 4. Magic numbers & strings

Named constants make intent explicit and changes safe. Route strings, keys,
durations, and sizes should never be scattered literals.

```dart
// BEFORE
if (status == 3) { ... }
Future.delayed(const Duration(milliseconds: 300));
Navigator.pushNamed(context, '/trip-details');

// AFTER
if (status == TripStatus.delivered) { ... }
Future.delayed(AppDurations.debounce);
Navigator.pushNamed(context, Routes.tripDetails);
```

Group constants meaningfully (`AppSpacing`, `AppDurations`, `Routes`,
`AppColors`) rather than one giant `Constants` bucket.

## 5. Common Flutter smells & their fixes

| Smell | Fix |
| --- | --- |
| Unnecessary `Container` | Use `Padding`/`SizedBox`/`DecoratedBox`/`Align` directly |
| Deeply nested widget tree | Extract widget classes; use `Spacer`/`Gap` |
| Nested `FutureBuilder`/`BlocBuilder` | Move async into a bloc; emit discrete states |
| `setState` in a big `StatefulWidget` | Localize state to the smallest widget, or lift to a bloc |
| Business logic in `onPressed` | Dispatch an event/call a use case |
| `if (x != null) x!.foo()` chains | Null-aware ops `?.`, `??`, pattern matching |
| Repeated padding/margins | Design tokens (`AppSpacing`) + shared widgets |
| `print()` for logging | A logger gated by `kDebugMode` |
| Passing data via global singletons | Constructor injection / bloc / route args |

## 6. Refactoring safely — the loop

1. Ensure there's a test covering the current behavior. If not, write a
   **characterization test** first (assert what it does now, even if ugly).
2. Make **one** small structural change.
3. Run analyzer + tests. Green? Commit. Red? Revert or fix immediately.
4. Repeat. Never mix a refactor and a behavior change in the same commit — it
   makes review and bisecting impossible.

## 7. When NOT to refactor

- No tests and no time to add them for a risky area → add tests first, or leave
  it.
- "It's ugly but isolated and never changes" → low value; spend effort where
  churn is high.
- Refactoring to introduce an abstraction you *might* need → YAGNI; wait for the
  second real use case (Rule of Three) before abstracting.

---

## 8. Widget composition — the UI rulebook

Applies to every widget you write or touch: filling a scaffold's empty
`widgets/` folder, splitting an existing page, or reviewing UI in a PR. Goal is
readability and maintainability; on a pure refactor, **behavior and UI stay
pixel-for-pixel and logic-for-logic identical.**

### 8.1 Rules

1. **Never build UI with methods.** No `Widget _buildHeader()`. Extract a real
   widget class (`HeaderWidget`). A `Widget`-returning function is never an
   acceptable substitute, no matter how small the widget is.
2. **Extracted widgets are public and live in their own file.** No
   underscore-private widget classes, no three widget classes stacked in one
   file. One file per widget, named after what it shows.
3. **Split large widgets. 300 lines per file is a hard cap.** Split well before
   that — several UI sections, multiple widget-building methods, or simply hard
   to read (~150 lines is the usual trigger) → split
   (`HomePage` → `HomeHeader`, `HomeBanner`, `HomeStatistics`, `HomeBody`,
   `HomeBottomBar`). A file over 300 lines is not a judgment call; it gets split.
4. **Extract repeated UI.** Any block appearing more than once becomes its own
   widget (a repeated decorated box → `InfoCard`).
5. **`SizedBox` + `DecoratedBox` over `Container` for shape.** When the widget's
   only job is shape (color, border, radius, shadow, gradient) at a **fixed
   size**:

   ```dart
   SizedBox(
     width: 48,
     height: 48,
     child: DecoratedBox(
       decoration: BoxDecoration(
         color: context.colors.primary,          // theme token, never a hex
         borderRadius: AppDimens.kBorderRadius12, // token, never .circular()
       ),
     ),
   )
   ```

   If it must **expand to fill** (inside `Expanded`/`Flexible`, a flexed
   `Row`/`Column`, or parent-driven constraints), drop the fixed `SizedBox` and
   let `DecoratedBox` take the parent's constraints — don't force a fixed size
   onto something meant to grow:

   ```dart
   Expanded(
     child: DecoratedBox(
       decoration: BoxDecoration(color: context.colors.surface),
       child: child,
     ),
   )
   ```

   Reach for `Container` only when several of its features are genuinely needed
   at once (padding + margin + decoration + alignment together) — not as the
   default for anything with a shape.
6. **`StatelessWidget` by default.** No local mutable state and no animation →
   stateless, always. Promote to `StatefulWidget` only for real local state,
   lifecycle hooks (`initState`/`dispose`/controllers), or an
   `AnimationController` (+ `SingleTickerProviderStateMixin`/
   `TickerProviderStateMixin`). Prefer the dedicated animation widgets
   (`AnimatedBuilder`, `AnimatedContainer`, `AnimatedOpacity`,
   `TweenAnimationBuilder`) over faking state.
7. **One widget = one responsibility.** A single widget does not own app bar +
   content + stats + settings.
8. **Methods are for logic only** — calculations, formatting, validation, state
   manipulation, calls. Never for returning widgets.
9. **`build()` reads like a table of contents**, not like the layout itself:

   ```dart
   @override
   Widget build(BuildContext context) => const Scaffold(
         appBar: HomeAppBar(),
         body: HomeBody(),
         bottomNavigationBar: HomeBottomNavigation(),
       );
   ```
10. **Naming describes responsibility** — `LoginButton`, `ProfileAvatar`,
    `UserInfoCard`, `PaymentSummary`. Never `Widget1`, `ItemWidget`,
    `CustomWidget`, `MyContainer`.
11. **Design tokens, never hardcoded values.** Colors, radii, spacing, and text
    styles come from the project's theme/token layer, reached through its
    `BuildContext` extension — never a raw hex, never an inline
    `TextStyle(fontSize: …, fontWeight: …)`. A literal in a widget is a bug.
    See §8.5 for what to do when the token you need doesn't exist.
12. **Interactive elements get press feedback.** Use the project's tap primitive
    (`AppInkWell` here — scale + ink + light haptic) or a common button;
    `Material` + `InkWell`/`InkResponse` + haptic if the project has none. A bare
    `GestureDetector` on a tappable surface is a defect. The ink's `borderRadius`
    must equal the decoration's, or the ripple bleeds past the corners.
13. **`const` everywhere possible**; extract static subtrees into `const`
    widgets so they don't rebuild.
14. **Keys only when necessary** — don't add them defensively.
15. **Don't thread `BuildContext`** through several layers unless truly required.
16. **Widgets take data + callbacks, not blocs.** A leaf widget may dispatch an
    event, but it should not need a bloc to know what to draw.
17. **Layout is not improvised.** Pick a page shape and a flex model from
    `ui-layout.md` (§2–4); any `Text` fed by the API or l10n inside a `Row` gets
    `Expanded` + `maxLines` + `overflow`. An overflow is a defect, and shrinking
    the design's paddings or font sizes is not the fix.
18. **A screen is not one state.** Loading, empty, error, and success are all
    drawn, each as its own widget file (`ui-layout.md` §8).

### 8.2 File structure

```
<feature>/presentation/pages/<name>_page/
  <name>_page.dart
  <name>_mixin.dart
  widgets/
    <name>_header.dart
    <name>_body.dart
    <name>_card.dart
```

One file per extracted widget, named after what it shows, not after its type.

### 8.3 Do NOT change during a refactor

Business logic · API behavior · state-management flow · navigation · UI
appearance (pixels, spacing, colors, text) · animations.

Only the structure improves. A refactor is invisible to the end user.

### 8.4 Per-file checklist

- [ ] No widget-building methods (`_buildX()`) left
- [ ] Each became a real widget class — stateless unless it genuinely needs state/animation
- [ ] Each extracted widget is public, in its own file
- [ ] Repeated UI extracted into a shared widget
- [ ] `SizedBox` + `DecoratedBox` for fixed-size shape; no fixed `SizedBox` on expanding widgets
- [ ] No file over 300 lines (hard cap); split already at ~150 / multiple sections
- [ ] Theme tokens only — no hardcoded colors/spacing
- [ ] Tappable surfaces have press feedback + haptic
- [ ] `const` applied where possible
- [ ] Names describe responsibility
- [ ] `build()` short and readable
- [ ] Behavior and UI preserved exactly
- [ ] No inline `TextStyle(...)` and no raw hex — token getters only (§8.5)
- [ ] No hardcoded user-facing strings — l10n keys only
- [ ] No overflow at 360 dp / `textScale 1.3`; dynamic text ellipsised
- [ ] Loading / empty / error / success all present (new UI, not pure refactors)
- [ ] Tap targets ≥ 48 dp; icon-only controls have a semantic label
- [ ] `flutter analyze` — zero new issues

### 8.5 Building UI from a screenshot or design

When the user sends a screenshot/mockup and asks for the UI, the design is the
**target**, not the **source of values**. Values come from the token layer.

Summary below; the full contract — the decompose/measure/ask pipeline, the token
table, the shape recipes (`SizedBox`+`DecoratedBox`[+`AppInkWell`]), asset
rules, the shared reusable-widget inventory, and the design-comparison
loop — is in **`ui-from-design.md`**, with layout/overflow/responsive/a11y in
**`ui-layout.md`**. Read those before drawing, not after.

1. **Open the token files before writing the widget.** Find the project's
   text-style set, its color set, and the `BuildContext` extension that exposes
   them. Read the available names — you cannot pick the right token from memory.
2. **Text style → always the token getter.** `context.textStyles.<name>` or the
   project's equivalent. Never construct a `TextStyle` inline in a widget just
   because the screenshot looks like 15/w600. Pick the closest existing token;
   adjust only with `.copyWith(color: …)` when the token differs solely by color.
3. **Color → the token if it exists.** `context.colors.<name>` or equivalent.
   Match by **role** (surface, border, muted text, danger), not by eyeballing the
   hex.
4. **Color missing from the token set → STOP and ask the user.** Do not invent a
   hex. Do not fake it with an opacity of a nearby token. Do not add a new entry
   to the token file on your own initiative. Ask: "the design uses this swatch;
   there's no matching token — should I add one, and under what name?" Then
   continue once answered.
5. **Never sample a color out of the screenshot and paste it as a literal.** That
   is exactly the bug the token layer exists to prevent, and it silently breaks
   the other theme (light/dark).
6. Spacing, radii, and icon sizes follow the same order: existing token → ask.
