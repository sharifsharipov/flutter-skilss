# Building UI from a design / screenshot

Read this **before writing the first widget** whenever the input is a screenshot,
a Figma frame, or a described layout. It is the drawing procedure + the token
contract + the shape recipes + the reusable-widget inventory.

Pairs with two files:

- **`ui-layout.md`** — constraints, flex, overflow, page shapes, responsive,
  screen states, accessibility. *How the layout survives real devices.*
- **`refactor.md` §8** — how to split what you build into files.

---

## Calibrate to the project — do this once, before anything else

**The API names in this file are illustrative placeholders, not a specification.**
Your project names the same concepts differently. The
*rules* are universal — "every color comes from a token, a missing token is a
question" holds everywhere. The *identifiers* are not.

So before drawing anything in a repo you haven't calibrated to, spend two minutes
finding the project's real equivalents:

| Concept | Find it by | Example in this file |
| --- | --- | --- |
| Text style set | search the theme folder for a `TextStyle` collection or `ThemeExtension` | `AppTextStyles` → `context.textStyles.<name>` |
| Color set | the same, for colors | `AppColors` → `context.colors.<name>` |
| How the UI reaches them | the `BuildContext` extension file | `core/extension/build_context_extension.dart` |
| Spacing / radius / padding constants | grep an existing widget for `EdgeInsets`/`BorderRadius` and see what it uses instead | `AppDimens.kGap8`, `kPaddingAll16`, `kBorderRadius12` |
| Generated asset references | `flutter_gen` output, or however assets are referenced | `Assets.icons.*`, `Assets.images.*` |
| Asset codegen command | `pubspec.yaml` / `Makefile` / project scripts | `<your-asset-codegen-command>` |
| Shared widget folder | where `AppButton`-style widgets live | `core/widgets/` |
| Tap primitive | grep for the project's wrapper around `InkWell` | `AppInkWell` |
| Localized strings | the l10n accessor | `context.locale.<key>` |
| Loading / empty / error views | grep for shimmer/skeleton/empty-state widgets | `ShimmerLoading`, `SkeletonBoxWidget` |

Record what you find, then **read the rest of this file substituting your
project's names**. If the project genuinely has no token layer, no spacing
constants, or no tap primitive, say so and ask whether to introduce one — do not
silently fall back to raw hex values and `EdgeInsets.all(16)`, and do not invent a
token file unasked.

`scaffold.md` §0 does the same thing for the data/domain layers; this is its UI
counterpart. Once calibrated, everything below applies as written.

> Maintaining a fork? Replace the example column with your own names, and this
> becomes a precise, project-specific contract instead of a general one.

---

## 0. Read the design before you draw it

Drawing UI is a **five-step pipeline**. Skipping step 0–2 is why generated UI
looks approximately right and is structurally wrong.

### 0.1 Decompose — top-down, out loud

Before any code, write the widget tree as a short outline in the response:

```
ProfilePage (Scaffold)
├── AppTopBar(title, actions: [notification icon])
└── body: SingleChildScrollView          ← page shape B (ui-layout §4)
    ├── ProfileHeader        avatar 64 + name + phone, Row
    ├── kGap24
    ├── ProfileStatsRow      3 × Expanded(StatTile)
    ├── kGap24
    └── ProfileMenuList      6 × ProfileMenuTile (icon + label + chevron)
```

Rules for the outline:
- Name every section the way the widget class will be named.
- Mark which sections repeat → those become one widget with parameters.
- Mark which sections already exist in `core/widgets/` (§4) → reuse, don't rebuild.
- Pick the page shape from `ui-layout.md` §4 **here**, not after the overflow.

### 0.2 Measure, don't eyeball

From the screenshot, read off and write down:

| Read | Then |
| --- | --- |
| Outer page padding | match to an `AppDimens.kPadding*` constant |
| Vertical rhythm between sections | match to `AppDimens.kGap*` (designs are on a 4/8 grid — 13 px means you misread 12) |
| Corner radii | match to `AppDimens.kBorderRadius*` |
| Font size + weight per text role | match to a `context.textStyles.*` token |
| Fill / border / text colors by **role** | match to a `context.colors.*` token |
| Icon sizes | usually 16/20/24 — confirm against existing usage |
| Which elements stretch vs stay fixed | drives `Expanded` vs fixed `SizedBox` |

Match by **role**, never by hex. "Muted secondary label" → the muted token, even
if the token is two shades off the screenshot. A pixel-perfect literal that breaks
dark mode is worse than a one-shade-off token that doesn't.

### 0.3 If the input is a Figma link, read it — don't guess from the PNG

The Figma MCP tools give exact values instead of eyeballed ones. When a
`figma.com` URL is provided:

1. `get_screenshot` — see the frame.
2. `get_variable_defs` — the **real** tokens (colors, spacing, radii, type). Map
   these to the project's tokens; a Figma variable name is not a Dart token name.
3. `get_design_context` / `get_metadata` — structure, auto-layout direction,
   constraints (this tells you `Row` vs `Column` and what stretches).
4. `download_assets` — export icons/images rather than recreating them as
   widgets.

If the Figma connector isn't authorized in this session, say so and fall back to
the screenshot procedure (§0.1–0.2) — don't silently invent values.

### 0.4 Batch every unknown into ONE question

Collect all missing tokens, ambiguous behaviors, and unexported assets from the
whole screen, then ask once, then build. Five interruptions mid-build is the
failure mode.

Also ask (once) about behavior the image can't show: what does tapping this do,
what shows while loading, what shows when the list is empty, is this text from the
API or l10n, is there a dark-theme frame.

### 0.5 Then build → then verify

Build in the file structure of `refactor.md` §8, then run the verification loop
in §7 of this file. UI is not done when it compiles.

---

## 1. The token contract — never invent a value

The rule is absolute: **every visual value resolves to a token, or it is a
question for the user.** The names below are the calibration example — substitute
the ones you found above.

| You need | You use *(example names — see Calibrate)* | Source |
| --- | --- | --- |
| Text style | `context.textStyles.<name>` | `core/theme/app_text_styles.dart` (`AppTextStyles`) |
| Color | `context.colors.<name>` | `core/theme/colors/app_colors.dart` (`AppColors`) |
| Gradient | `Theme.of(context).extension<AppGradients>()!.<name>` (no `context.` getter exists yet) | `core/theme/colors/app_gradients.dart` |
| Corner radius | `AppDimens.kBorderRadius<N>` | `core/theme/app_dimens.dart` |
| Padding | `AppDimens.kPadding<...>` | `core/theme/app_dimens.dart` |
| Gap between children | `AppDimens.kGap<N>` / `kSliverGap<N>` | `core/theme/app_dimens.dart` |
| SVG icon | `Assets.icons.<name>` | `lib/gen/assets.gen.dart` |
| PNG / raster | `Assets.images.<name>` | `lib/gen/assets.gen.dart` |
| Remote image | `AppNetworkImage` | `core/widgets/app_network_image.dart` |
| User-facing string | the project's l10n key (`context.locale.<key>`) | never a literal in the widget |

`context.textStyles` and `context.colors` come from
`core/extension/build_context_extension.dart`.

**Banned on sight while drawing UI** — these hold in every project, whatever the
token layer is called:

- an inline `TextStyle(fontSize: …, fontWeight: …)` instead of a style token
- a raw `Color(0xFF…)` / `Colors.blue` / `.withOpacity()` used to fake a missing token
- a hand-written `BorderRadius.circular(12)` instead of the radius constant
  (here: `AppDimens.kBorderRadius12`)
- a raw `EdgeInsets.all(16)` instead of the padding constant
  (here: `AppDimens.kPaddingAll16`)
- an asset path string instead of the generated asset reference (here: `Assets.*`)
- a hardcoded user-facing string instead of an l10n key
- `MediaQuery.of(context).size.width * 0.42` where the design means "two equal
  columns" (see `ui-layout.md` §6)

### 1.1 When a token is missing — STOP and ask

Do not improvise. Ask the user, in one short question, and wait.

- **Missing text style** → ask for the exact size/weight/color/line-height. Then
  add it **universally**: field + constructor param + `light` + `dark` +
  `copyWith` + `lerp` in `AppTextStyles`. A style that exists in only one theme
  is a bug. Name it semantically where possible.
- **Missing color** → ask for the hex **and** the dark-theme counterpart. Never
  invent a hex, never fake it with opacity, never add a token unasked.
- **Gradient** → always ask. `AppGradients` currently carries only
  `primaryAction`; a new one needs the user's stops and direction.
- **Border color** → same rule as color: `AppColors` first, otherwise ask.
- **Missing asset** → ask whether it comes from Figma (they export it) or from
  the API (then it is a network image, not an asset). After new files land in
  `assets/`, ask the user to run the project's asset-codegen command — the `Assets.*` reference does not
  exist until codegen runs.
- **Missing l10n key** → add it to **every** locale file the project ships, then
  run the locale codegen. A key in one locale is a crash in another.

One batched question at the start beats five interruptions mid-build (§0.4).

---

## 2. Recipe A — a pressable shape

Any tappable card, chip, icon button, or row. `AppInkWell` already provides
the scale animation, the ink highlight, and the light haptic — do not hand-roll
`GestureDetector` + `Material` + `InkWell`.

```dart
SizedBox(
  height: 48,                       // only if the design fixes it
  width: 48,                        // only if the design fixes it
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.cardBackground,        // AppColors, never a hex
      borderRadius: AppDimens.kBorderRadius12,     // AppDimens, never .circular()
      // shape: BoxShape.circle,                  // only for a circle; then drop borderRadius
      // gradient: AppGradients.light.primaryAction, // only after asking the user
      border: Border.all(color: context.colors.border),
    ),
    child: AppInkWell(
      onTap: onTap,
      borderRadius: AppDimens.kBorderRadius12,     // MUST match the decoration radius
      child: Padding(
        padding: AppDimens.kPaddingAll12,          // AppDimens; add there if missing
        child: Row(                               // or Column — follow the design
          children: [
            SvgPicture.asset(Assets.icons.example),
            AppDimens.kGap8,
            Text('label', style: context.textStyles.bodySubheadline),
          ],
        ),
      ),
    ),
  ),
)
```

Rules for this recipe:

- The `AppInkWell.borderRadius` and the `BoxDecoration.borderRadius` are the
  **same token**. A mismatch makes the ripple bleed outside the corners.
- `shape: BoxShape.circle` and `borderRadius` are mutually exclusive — pick one.
- No fixed `SizedBox` when the shape must stretch (inside `Expanded`/`Flexible`
  or a flexed `Row`/`Column`) — let the parent's constraints drive it.
- Padding lives **inside** `AppInkWell`, so the ripple covers the full
  surface, not just the content box.
- Missing padding value → add the constant to `AppDimens`, then use it. Never a
  one-off `EdgeInsets`.
- Total tap area ≥ 48×48 dp (`ui-layout.md` §9). A 24 dp icon needs padding.
- `onTap: null` is the disabled state — pair it with the design's disabled
  colors, don't just leave the button looking enabled.

## 3. Recipe B — a static shape

Same skeleton, no ink layer:

```dart
SizedBox(
  height: 40,                       // only if the design fixes it
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: AppDimens.kBorderRadius16,
      border: Border.all(color: context.colors.border),
    ),
    child: Row(
      children: [
        SvgPicture.asset(Assets.icons.tag),
        AppDimens.kGap6,
        Text(title, style: context.textStyles.regularFootnote),
      ],
    ),
  ),
)
```

`Container` is allowed only when padding + margin + decoration + alignment are
genuinely all needed at once. Anything that is "a box with a shape" is
`SizedBox` + `DecoratedBox`.

## 3.1 Recipe C — a list row (icon + text block + trailing)

The single most repeated shape in an app. Note the `Expanded`: without it, a long
name overflows the moment the API returns a real value.

```dart
AppInkWell(
  onTap: onTap,
  borderRadius: AppDimens.kBorderRadius16,
  child: Padding(
    padding: AppDimens.kPaddingAll12,
    child: Row(
      children: [
        SvgPicture.asset(Assets.icons.box, width: 24, height: 24),
        AppDimens.kGap12,
        Expanded(                                   // ← the whole point
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySubheadline,
              ),
              AppDimens.kGap4,
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.regularFootnote
                    .copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        AppDimens.kGap8,
        SvgPicture.asset(Assets.icons.chevronRight),
      ],
    ),
  ),
)
```

`.copyWith(color: …)` is the **only** acceptable edit to a text token, and only
when the token differs from the design solely by color.

## 3.2 Recipe D — an SVG icon

```dart
SvgPicture.asset(
  Assets.icons.filter,
  width: 24,
  height: 24,
  colorFilter: ColorFilter.mode(context.colors.iconPrimary, BlendMode.srcIn),
)
```

- Tint through `colorFilter` + a token — never ship two color variants of the
  same icon file, and never leave a themed icon untinted (it will be invisible in
  one of the two themes).
- Always give an explicit `width`/`height`; an untinted, unsized SVG expands to
  its parent and silently wrecks a `Row`.
- Multi-color/brand illustrations are the exception: no `colorFilter`.

## 3.3 Recipe E — a shadow

```dart
DecoratedBox(
  decoration: BoxDecoration(
    color: context.colors.cardBackground,
    borderRadius: AppDimens.kBorderRadius16,
    boxShadow: [
      BoxShadow(
        color: context.colors.shadow,   // token, not Colors.black.withOpacity(0.08)
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: child,
)
```

If there is no shadow token, that is a §1.1 question — shadows are theme-specific
and a light-mode shadow on a dark surface looks like dirt. Inner shadows use the
existing `InnerShadowBox`.

---

## 4. Reuse before you build — the shared-widget inventory

Check the project's shared-widget folder **before** building anything. A second
app bar / button / text field is a defect, not a preference.

The inventory below is the calibration example (`core/widgets/` is the
illustrative folder name used here). In a fresh repo, spend five minutes listing your own
equivalents once and paste them here — a fork with an accurate inventory is worth
far more than a generic instruction to "check for existing widgets", because the
assistant cannot reuse what it doesn't know exists.

### 4.1 The four you will reach for constantly

| Widget | File | Key params |
| --- | --- | --- |
| `AppTopBar` | `app_top_bar.dart` | `title`, `titleWidget`, `actions`, `bottom`, `showBackButton` (def. true), `centerTitle` (def. true), `bgColor` |
| `AppButton` | `app_button.dart` | `text`, `onTap`, `borderRadius` (def. `kBorderRadius48`), `bgColor`, `textColor`, `icon`/`iconR`, `pngIcon`/`pngIconR`, `isLoading`, `isEnabled`, `fontSize`/`fontWeight`, `isBorder`+`borderColor`, `verticalPad`/`horizontalPad`, `blurSigma`/`blurColor`, `innerShadows` |
| `AppTextField` | `app_text_field.dart` | `hintText` (required) + controller/validator/focus, `prefix`/`prefixIcon`/`prefixText`, `suffix`/`suffixIcon`/`suffixText`, `labelText`+`labelInTextField`, `showError`+`errorText`, `showSuccess`, `showBorder`/`showEnabledBorder`/`enabledBorder`/`focusedBorderColor`, `borderRadius`, `maxLines`/`minLines`/`maxLength`, `inputFormatters`, `obscure`, `readOnly`, `onTap` |
| `SegmentedTabBarWidget` | `tabbar_witget/segmented_tab_bar_widget.dart` | `tabs`, `controller`, `height` (def. 40) — labels via `SegmentedTabLabel(title:)` |

### 4.2 Everything else already in the shared folder

| Need | Widget / helper |
| --- | --- |
| Tap wrapper (scale + ink + haptic) | `AppInkWell(borderRadius, onTap, child, highlightColor?, bound?, enableFeedback?)` |
| Round icon button | `CircleActionButton(onTap, icon, color?/gradient?, iconColor?, size=40, iconSize=20)` |
| Call / share / favorite action buttons | `CallActionButton`, `ShareActionButton`, `FavoriteActionButton` (`onTap`, `size`, `iconSize`) |
| Checkbox row | `CheckBoxWidgetLeft` / `CheckBoxWidgetRight` (`onTap`, `title`, `value`) |
| Dropdown | `DropDownWidget(list, label, hintText?, selectedItem?, onChanged?)` |
| Remote image | `AppNetworkImage(imageUrl, width/height/fit, per-corner radius, placeholder/errorWidget)` |
| Pull to refresh | `AppRefreshIndicator(child, onRefresh, …)` |
| Bottom sheet | `showAppBottomSheet<T>(context: …, builder: …)`; image picker: `showImagePickerSheet(...)` |
| Snackbar | `AppSnackBar.showSuccessSnackBar(...)` / `showErrorSnackBar(...)` |
| Toast (liquid glass) | `AppToastMixin` on a `State` → `showToast` / `showErrorToast` |
| Full-screen blocking loader | `ModalProgressHUD(inAsyncCall, child, …)` |
| List-bottom loader | `BottomLoadingIndicatorWidget()` |
| Skeleton / shimmer | `ShimmerLoading(isLoading, child)` + `SkeletonBoxWidget(width, height, borderRadius, shape)` |
| OTP input / resend timer / hint | `OtpDigitsField`, `OtpResendTimer(seconds)`, `OtpSentHint(identifier)` |
| Identifier (phone/email) form | `IdentifierFormLayout(title, subtitle, field, actions, …)`, `CenteredIdentifierField(...)` |
| Rating | `RatingBarWidget(rating, iconsSize, onRatingChanged?, isAnimate?)` |
| Inner shadow box | `InnerShadowBox(borderRadius, shadows, child)` |
| Scrolling marquee row | `MarqueeRow(children, gap, pixelsPerSecond)` |
| Keep tab alive in a `PageView` | `KeepAliveWidget(child)` |
| Dismiss keyboard on tap | `KeyboardDismiss(child, …)` |
| Fade with keyboard | `KeyboardVisibilityFade(child, duration)` |
| Selection tick | `SelectIcon(isSelected)` |
| Empty/unavailable state | `EmptyStateView()` |

If the design needs something close to one of these but not identical, **extend
the existing widget with a new optional param** — do not fork a near-copy.

### 4.3 Drawing the four screen states

Never leave a screen with only its success state. Full rule + the `switch`
skeleton: `ui-layout.md` §8.

| State | Reach for |
| --- | --- |
| Loading | `ShimmerLoading` + `SkeletonBoxWidget` shaped like the real content |
| Empty | `EmptyStateView` or the feature's own empty widget + l10n text |
| Error | Error view + retry event; transient → `AppSnackBar` / `AppToastMixin` |
| Inline/blocking action | `AppButton(isLoading: true)` or `ModalProgressHUD` |

---

## 5. Structure rules while drawing

These are enforced, not advisory (full set: `refactor.md` §8):

1. **No `Widget _buildX()` functions.** Ever. A widget-returning function
   rebuilds with the parent, can't be `const`, and gets no build boundary — it is
   a performance defect, not a style choice. Extract a widget class.
2. **No underscore-private widget classes.** Every extracted widget is public
   and lives in its own file under the page's `widgets/` folder.
3. **File length: 300 lines is a hard cap.** Split well before that — as soon as
   a widget has more than one visual section (~150 lines is the usual trigger).
4. `StatelessWidget` unless it genuinely owns state, a controller, or an
   animation.
5. `const` wherever the analyzer allows it.
6. `build()` reads like a table of contents of child widgets.
7. Naming says what it shows: `OfferPriceCard`, not `ItemWidget`.
8. Widgets take **data + callbacks**, not blocs. A leaf widget that reaches for
   `context.read<XBloc>()` to render is fine for dispatching, but it should not
   need the bloc to know what to draw — pass the values in.

---

## 6. Performance while drawing (the parts that apply to UI, not to lists)

- Repeating rows come from `ListView.builder`/`.separated`, never a `Column` of
  N children (`ui-layout.md` §4C).
- Scope rebuilds: `BlocSelector` / `context.select` around the piece that
  changes, so typing in a field doesn't rebuild the whole page.
- `const` every static subtree — that's the cheapest rebuild win available.
- Remote images: `AppNetworkImage` with an explicit size; raster assets
  get `cacheWidth`/`cacheHeight` so a 4000 px photo isn't decoded into a 40 px
  avatar.
- Controllers created in the widget (`TextEditingController`, `ScrollController`,
  `AnimationController`, `TabController`, `PageController`) are disposed. In this
  project they live in the page's mixin, not in the `State` body.

Deeper: `performance.md`.

---

## 7. Verify against the design — the loop that makes UI actually match

Compiling is not matching. After the build:

1. `flutter analyze` — zero new issues.
2. Run the app, navigate to the screen, screenshot it
   (`adb exec-out screencap -p > shot.png` / `xcrun simctl io booted screenshot shot.png`).
3. **Put your screenshot next to the design and compare in this order:**
   overall structure → section spacing → alignment → radii → typography →
   colors → icon sizes. Structure errors first; nobody cares about a 2 px radius
   on a screen whose sections are in the wrong order.
4. Write the delta list, fix, hot-reload, screenshot again. Repeat until the list
   is empty or the remaining items are questions for the user.
5. Re-check in the **other theme**, at **`textScale 1.3`**, and on a **narrow
   screen** — see `ui-layout.md` §6.
6. Poke the four states (§4.3): loading, empty, error, success.

Then the `manual-test.md` protocol closes it out with a `Manual Test Result`
block — or, if no device is available, the honest
"code-complete, NOT device-tested" line plus the exact steps for the user.

---

## 8. Finish gates for a UI task

1. Every color / text style / radius / padding / asset / string traced to a token
   or l10n key — grep your own diff for `Color(0x`, `TextStyle(`, `EdgeInsets.`,
   `BorderRadius.circular`, and quoted user-facing strings.
2. Every tappable surface goes through `AppInkWell` (or a common button) —
   press feedback + haptic — and is ≥ 48 dp.
3. Nothing duplicates a `core/widgets/` widget.
4. No file over 300 lines; no `_build*` widget functions; no private widget
   classes.
5. Layout checklist in `ui-layout.md` §11 passes — no overflow at 360 dp /
   `textScale 1.3`, long strings ellipsised, correct page shape.
6. All four screen states drawn.
7. Light **and** dark checked on device, not assumed.
8. `flutter analyze` clean.
9. New assets → the user ran the asset-codegen command; new tokens → both `light` and `dark`
   updated; new strings → every locale file.
10. Design-comparison loop (§7) done, then `manual-test.md` — evidence, or an
    explicit "NOT device-tested" with steps.
