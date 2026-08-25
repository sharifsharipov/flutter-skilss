# Layout & Constraints — how not to break the screen

Read this **together with `ui-from-design.md`** whenever you draw UI. That file
answers *what values and widgets to reach for*; this one answers *how the layout
survives real devices* — long text, small screens, big system fonts, a keyboard,
a notch, dark mode, and an empty API response.

Most AI-drawn Flutter UI fails here, not in the tokens. A screen that looks right
on the reviewer's simulator and overflows on a 360×640 phone with `textScale 1.3`
is a defect, not a near miss.

> **On the names in the code samples.** `AppDimens.kGap12`, `context.colors.*`,
> `context.textStyles.*`, `AppTopBar`, `AppButton`, `ShimmerLoading` are
> illustrative token and widget names — substitute your project's equivalents
> (see the *Calibrate* section of `ui-from-design.md`). Every layout rule here is
> framework-level and applies unchanged.

---

## 1. The constraints model — the one rule everything follows

> **Constraints go down. Sizes go up. The parent sets the position.**

Consequences you must hold in your head while drawing:

- A widget **cannot** be bigger than its incoming constraints, and cannot decide
  its own position.
- `Row` gives its children **unbounded width**; `Column` gives them **unbounded
  height**. Anything greedy in that axis (`Text`, `ListView`, `Image`,
  `TextField`) must be flexed or bounded, or you get an overflow / infinite-size
  crash.
- `SingleChildScrollView` gives its child **unbounded** extent in the scroll
  axis. `Expanded`/`Spacer`/`Flexible` inside it in that same axis is an error.
- `Expanded` / `Flexible` / `Spacer` are **only** legal as direct children of
  `Row`, `Column`, or `Flex`. Anywhere else it throws at runtime.
- `Stack` sizes to its **non-positioned** children. A `Stack` whose children are
  all `Positioned` collapses to the parent's constraints (or to zero if
  unbounded).

When unsure what constraints a widget is getting, don't guess — see §9.

## 2. Choosing the layout widget

| The design shows | Use | Notes |
| --- | --- | --- |
| Items side by side | `Row` | Long text child → `Expanded` + `maxLines`/`ellipsis` |
| Items stacked vertically | `Column` | `mainAxisSize: MainAxisSize.min` inside a scroll/sheet/card |
| One item fills the leftover space | `Expanded` | Ratio split → `flex:` on each |
| Item takes *at most* what it needs | `Flexible` | `Expanded` = `Flexible(fit: tight)` |
| Push apart / fixed empty space | `MainAxisAlignment.spaceBetween` or `Spacer()` | Fixed gap → `AppDimens.kGap<N>` |
| Overlap (badge, avatar ring, gradient scrim) | `Stack` + `Positioned`/`Align` | Give the `Stack` a bounded size |
| Chips that wrap to the next line | `Wrap(spacing:, runSpacing:)` | Never a `Row` that can overflow |
| Equal-height siblings whose height is content-driven | `IntrinsicHeight` | Expensive — last resort, never inside a list item |
| Fixed aspect box (video, map, banner) | `AspectRatio` | Better than magic heights |
| Centering one child | `Center` / `Align` | Not a `Row` with two `Spacer`s |
| Size relative to parent | `FractionallySizedBox` / `LayoutBuilder` | Not `MediaQuery.size.width * 0.42` |
| Scrollable list | `ListView.builder` / `CustomScrollView` | Never `Column` + `SingleChildScrollView` for N items |
| Grid | `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount` | `childAspectRatio` from the design, not guessed |
| A box that only has a shape | `SizedBox` + `DecoratedBox` | See `ui-from-design.md` Recipe A/B |

`Container` is not on this list on purpose. It is the fallback when padding +
margin + decoration + alignment are genuinely all needed at once.

## 3. Overflow — the eight failures and their fixes

These are the actual runtime errors. Learn the fix, not the error text.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `A RenderFlex overflowed by N pixels on the right` | Long `Text` in a `Row` | Wrap the text in `Expanded`, add `maxLines: 1, overflow: TextOverflow.ellipsis` |
| `…overflowed on the bottom` | `Column` taller than the screen | Make the page scrollable (§4) — do **not** shrink paddings to make it fit |
| `Vertical viewport was given unbounded height` | `ListView`/`GridView` inside a `Column` | `Expanded(child: ListView…)`; if it must not scroll: `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()` |
| `Incorrect use of ParentDataWidget` | `Expanded`/`Positioned` under a non-`Flex`/non-`Stack` parent | Remove it, or add the right parent |
| `BoxConstraints forces an infinite width` | `Image`/`TextField`/`Row` greedy inside a `Row` | `Expanded`, or a `SizedBox(width:)` from the design |
| Nested scroll fights / list not scrolling | Two scrollables on the same axis | One scrollable: `CustomScrollView` + slivers, or inner `shrinkWrap` + `NeverScrollableScrollPhysics` |
| `Stack` renders nothing | Every child `Positioned`, parent unbounded | Give the `Stack` a bounded size (`SizedBox`, `AspectRatio`) or one non-positioned child |
| Bottom button hidden behind keyboard | Fixed-position button, no inset handling | §5 |

**Text is the usual culprit.** Any `Text` whose content comes from the API or
from l10n gets a deliberate overflow policy:

```dart
Expanded(
  child: Text(
    user.fullName,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.textStyles.bodySubheadline,
  ),
)
```

Never "fix" an overflow by hardcoding a smaller font size, shrinking the design's
padding, or wrapping the whole screen in `FittedBox`. Fix the flex model.

## 4. The five canonical page shapes

Pick one deliberately before writing the page body. Almost every screen is one of
these.

**A. Short static content, may overflow on small phones**

```dart
Scaffold(
  appBar: const AppTopBar(title: '…'),
  body: SafeArea(
    child: SingleChildScrollView(
      padding: AppDimens.kPaddingAll16,
      child: Column(children: [ /* sections */ ]),
    ),
  ),
)
```

**B. Content that must fill the screen but still scroll when it can't**

```dart
LayoutBuilder(
  builder: (context, constraints) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: IntrinsicHeight(
        child: Column(
          children: [
            const HeaderSection(),
            const Spacer(),            // legal: IntrinsicHeight bounds the column
            const FooterActions(),
          ],
        ),
      ),
    ),
  ),
)
```

**C. A list (the default for any repeating row)**

```dart
ListView.separated(
  padding: AppDimens.kPaddingAll16,
  itemCount: items.length,
  separatorBuilder: (_, __) => AppDimens.kGap12,
  itemBuilder: (_, index) => OfferCard(offer: items[index]),
)
```

**D. Header + list scrolling as one surface → slivers, never nested scrollables**

```dart
CustomScrollView(
  slivers: [
    const SliverToBoxAdapter(child: ProfileHeader()),
    AppDimens.kSliverGap16,
    SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => AppDimens.kGap12,
      itemBuilder: (_, i) => OfferCard(offer: items[i]),
    ),
  ],
)
```

**E. Form / flow with a pinned bottom action**

```dart
Scaffold(
  appBar: const AppTopBar(title: '…'),
  body: SafeArea(
    child: SingleChildScrollView(
      padding: AppDimens.kPaddingAll16,
      child: Column(children: [ /* fields */ ]),
    ),
  ),
  bottomNavigationBar: SafeArea(
    child: Padding(
      padding: AppDimens.kPaddingAll16,
      child: AppButton(text: context.locale.next, onTap: onNext),
    ),
  ),
)
```

Use `bottomNavigationBar` (or `persistentFooterButtons`) for a pinned action —
not a `Stack` with a `Positioned` button. The `Scaffold` slot already handles
insets and keeps the scroll view's usable height correct.

## 5. Safe areas, notches, and the keyboard

- `SafeArea` wraps the **body**, not the whole `Scaffold`, and not every widget.
  Double-wrapping adds phantom padding.
- A `Scaffold` with an `appBar` already handles the top inset; you usually need
  `SafeArea(top: false)` in that case, or nothing at all.
- Edge-to-edge / gradient-behind-status-bar screens: `extendBodyBehindAppBar` +
  a `SafeArea` inside, not manual `MediaQuery.padding.top` arithmetic.
- **Keyboard:** `Scaffold.resizeToAvoidBottomInset` defaults to `true` — keep it.
  If a fixed bottom button must rise with the keyboard, put it in
  `bottomNavigationBar` and let the inset do the work; only reach for
  `MediaQuery.of(context).viewInsets.bottom` when the design genuinely needs a
  custom offset.
- Dismiss the keyboard on background tap with the project's `KeyboardDismiss`
  wrapper, not a bare `GestureDetector` on the page root.
- After an `await`, guard `context` use: `if (!context.mounted) return;`.

## 6. Responsive & scalable — the three things that actually break

1. **Narrow phones (320–360 dp).** A `Row` of three fixed-width cards will
   overflow. Use `Expanded` with `flex`, or `Wrap`. Never hardcode a width the
   design measured on a 430 dp frame.
2. **System font scale.** `MediaQuery.textScalerOf(context)` can be 1.3–2.0. Any
   fixed-height box containing text must either grow (`IntrinsicHeight`, no fixed
   height) or clamp text (`maxLines` + `ellipsis`). Test one screen at
   `textScale 1.3` before calling UI done.
3. **Long translations.** A label that is 6 characters in English can be 18 in
   German or Finnish. Every static label gets the same overflow policy as API text.

Sizing guidance:

- Read `MediaQuery` for **screen-level** decisions; read `LayoutBuilder` for
  **widget-level** ones (a card doesn't care about the screen, it cares about its
  slot).
- `MediaQuery.of(context).size.width * 0.42` is a smell — it hardcodes a ratio
  the designer expressed as "two equal columns with a 12 gap". Model it as
  `Expanded` + a gap.
- Breakpoints only when the design actually has a tablet layout. Don't invent
  responsive behavior nobody asked for (YAGNI).

## 7. Directionality (only if the app ships an RTL locale)

- `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional` and
  `start`/`end` instead of `left`/`right`.
- Directional icons (back arrows, chevrons) mirror; brand marks do not.
- If the app ships only LTR locales, skip this — but say so rather than silently
  ignoring it.

## 8. Every screen has four states

A screen that only draws the happy path is half-drawn. Before the UI task is
done, all four exist and are reachable from the bloc's status:

| State | What to draw |
| --- | --- |
| Loading | The project's shimmer/skeleton widgets, shaped like the real content — not a centered spinner on a full page, unless the design says so |
| Empty | The design's empty view (the project's shared one, or the feature's own) with the l10n message |
| Error | Error view + a retry that re-dispatches the bloc event; transient errors → the project's snackbar/toast |
| Success | The real content |

```dart
BlocBuilder<XBloc, XState>(
  builder: (context, state) => switch (state.status) {
    Status.loading => const XLoadingView(),
    Status.failed  => XErrorView(onRetry: () => context.read<XBloc>().add(const XFetched())),
    _ when state.items.isEmpty => const XEmptyView(),
    _ => XContent(items: state.items),
  },
)
```

Each of these is its own public widget file under `widgets/` — same rule as any
other extracted widget.

## 9. Accessibility — the minimum bar, not an extra

- **Tap targets ≥ 48×48 dp.** A 20 dp icon needs padding or a `SizedBox` around
  it. `CircleActionButton(size: 40)` at the edge of the bar is the floor, not the
  target.
- **Icon-only buttons get a label:** `Semantics(label: context.locale.close, button: true, child: …)`, or the widget's own `tooltip`.
- **Decorative images are excluded:** `ExcludeSemantics` / `excludeFromSemantics: true` so a screen reader doesn't announce a background flourish.
- **Don't encode meaning in color alone** — a red border needs an error text too.
- **Contrast** comes from the token pair; if the design puts muted text on a
  colored surface, that's a question for the designer, not a value to eyeball.

## 10. Debugging a layout instead of guessing

- Flutter DevTools **Widget Inspector → Layout Explorer** shows the actual
  constraints, flex factors, and overflow on the selected widget. Use it before
  changing numbers at random.
- `debugPaintSizeEnabled = true` (temporarily, in `main`) paints every box.
- Read the **first** frame of the exception, not the last — the offending widget
  is named in "The relevant error-causing widget was …".
- Reproduce at the failing configuration: small screen, `textScale`, long string,
  keyboard open — not on the one device where it looked fine.

## 11. Layout checklist (run before calling UI done)

- [ ] No overflow at 360 dp width and at `textScale 1.3`
- [ ] Every API/l10n `Text` in a `Row` has `Expanded` + `maxLines` + `ellipsis`
- [ ] Page shape chosen from §4 — no nested same-axis scrollables
- [ ] Lists use `.builder`/`.separated`, never a `Column` of N items
- [ ] Pinned actions in `bottomNavigationBar`, keyboard-safe
- [ ] `SafeArea` applied once, in the right place
- [ ] Loading / empty / error / success all drawn and reachable
- [ ] Tap targets ≥ 48 dp; icon-only buttons labelled
- [ ] Dark theme checked, not assumed
- [ ] No `MediaQuery.size * 0.xx` standing in for a flex ratio
