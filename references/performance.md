# Performance — Rebuilds, Memory, Lists, Async, Images

Read this when building UI that renders lists, animates, holds controllers/
streams, loads images, or shows jank / high memory. Optimize by measurement,
not by superstition — but these defaults prevent the common regressions.

## 1. Minimize widget rebuilds

The single biggest source of jank is rebuilding too much, too often.

- **Use `const` aggressively.** A `const` widget is canonicalized and skipped on
  rebuild. Any widget with no dynamic inputs should be `const`. Turn on the
  `prefer_const_constructors` lint.
- **Extract subtrees into their own widgets** so a `setState` / state change
  rebuilds only the smallest necessary subtree, not the whole page.
- **Scope state reads.** With BLoC, use `BlocSelector` (or `context.select`) so
  a widget rebuilds only when the *specific slice* it reads changes:

```dart
// Rebuilds only when the trip count changes, not on every state emission.
BlocSelector<TripsBloc, TripsState, int>(
  selector: (state) => state.mapOrNull(loaded: (s) => s.trips.length) ?? 0,
  builder: (context, count) => Text('$count trips'),
);
```

- Pass `const` children *into* animated/rebuilding parents so the child is built
  once. `AnimatedBuilder`'s `child` parameter exists for exactly this.
- Don't create closures, lists, or objects inside `build` if they can be fields
  or `const`. `build` can run at 60–120 fps.

## 2. RepaintBoundary — isolate expensive paints

Wrap a subtree that repaints frequently (animations, progress spinners, a
constantly-updating chart) in `RepaintBoundary` so its repaints don't dirty the
rest of the layer tree.

```dart
RepaintBoundary(child: LiveRouteMap(controller: _mapController));
```

Use it deliberately — every boundary is a separate layer with its own cost.
Profit shows up when an animated element sits inside an otherwise static page.

## 3. Lists & slivers

- Always use the **builder** constructors (`ListView.builder`,
  `GridView.builder`, `SliverList` with a builder delegate). Never build a huge
  list eagerly with `ListView(children: [...])` — it constructs every item up
  front.
- Provide `itemExtent` (or `prototypeItem`) when item height is fixed. It lets
  Flutter skip layout math and scroll instantly to any offset.
- Give list items stable `ValueKey`s when they can reorder, so element state is
  preserved correctly.
- For mixed scrolling content (header + list + footer), use `CustomScrollView`
  with slivers instead of nesting scrollables.
- **Pagination:** load pages on demand; don't fetch 5,000 rows to show 20.
  Trigger the next page from a scroll listener near the end, and keep the page
  cursor in the bloc, not the widget.

## 4. Memory leaks & disposal — the top mobile bug class

Every subscription, controller, and listener you create, you must dispose.
Leaks manifest as growing memory, "setState called after dispose", and ghost
callbacks firing on dead widgets.

```dart
class _MapPageState extends State<MapPage> {
  late final AnimationController _anim;
  StreamSubscription<Position>? _positionSub;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _positionSub = _locationStream.listen(_onPosition);
  }

  @override
  void dispose() {
    _anim.dispose();
    _positionSub?.cancel();      // ❗ cancel stream subscriptions
    _scrollController.dispose();
    super.dispose();             // last
  }
}
```

Checklist of things that MUST be disposed/cancelled:
`AnimationController`, `TextEditingController`, `ScrollController`,
`FocusNode`, `PageController`, `TabController`, `StreamSubscription`,
`Timer`, platform channel listeners, `ChangeNotifier` you own, and any
`Ticker`.

In blocs, close streams and cancel subscriptions in `close()` /
`await super.close()`. Guard async completions with `if (isClosed) return;`
before `emit`.

## 5. Async optimization

- Never do heavy CPU work (large JSON parse, image decode, crypto) on the UI
  isolate. Use `compute()` or a spawned isolate. A parse that blocks 40 ms drops
  frames.
- Don't `await` sequentially when calls are independent — use
  `Future.wait([...])` to run them concurrently.
- Debounce high-frequency inputs (search fields, scroll-driven fetches) so you
  don't fire a request per keystroke.
- Avoid nested `FutureBuilder`/`StreamBuilder`. They rebuild on every emission
  and re-trigger futures on rebuild. Prefer a bloc that owns the async lifecycle
  and emits discrete states.

## 6. Images

- Set `cacheWidth`/`cacheHeight` (or use `ResizeImage`) so a 4000px photo isn't
  decoded at full size into a 100px avatar. This is the biggest image-memory
  win.
- Use `cached_network_image` (or equivalent) for remote images: disk + memory
  cache, placeholders, and fade-in for free.
- Prefer appropriately-sized assets and modern formats. Provide density buckets
  (`2.0x`, `3.0x`) for raster assets.
- Precache above-the-fold images with `precacheImage` to avoid first-frame pop.

## 7. Other wins

- `ListView`/`Column` inside `Column` → wrap correctly (`Expanded`, `Flexible`)
  rather than shrink-wrapping expensive lists.
- Avoid `Opacity`/`ClipRRect` on large or animated subtrees when a cheaper
  option exists (e.g. `FadeTransition`, `AnimatedOpacity`, or a decorated
  container with `borderRadius`). Saveable-layer clips/opacity are expensive.
- Battery/CPU: stop location/sensor streams when the screen is backgrounded;
  reduce update frequency when high precision isn't needed.

## 8. Measure, don't guess

- DevTools **Performance** view for jank (look for >16 ms frames / red bars).
- **Memory** view + heap snapshots to find leaks (retained objects growing
  across navigation).
- Run performance profiling in **profile mode**, never debug — debug builds are
  intentionally slow and misleading.
- Turn on the "Track Widget Rebuilds" tool to find widgets rebuilding needlessly.

Optimize the thing the profiler points at. Premature micro-optimization that
hurts readability violates the Golden Rule.
