# Testing — Unit, Widget, Golden, Integration

Read this when writing tests, deciding what to test, or wiring test
infrastructure. The point of the clean architecture in `architect.md` is that it
makes this layer cheap: pure domain code is trivial to test.

## 1. The pyramid

Many fast unit tests, fewer widget tests, few integration tests.

```
        /\      integration  — real device/app, slow, few
       /  \     golden       — pixel snapshots of UI
      /----\    widget       — a widget/page in a test harness
     /------\   unit         — use cases, blocs, mappers, value objects (most)
```

**Target: >90% coverage of business logic** (domain + data + bloc). Do not chase
100% overall — trivial getters and generated code aren't worth it. Coverage is a
tool to find untested logic, not a scoreboard.

## 2. Mock everything external

Anything crossing a boundary — network, disk, platform, clock, randomness — is
mocked so tests are deterministic and fast. Use `mocktail` (no codegen) or
`mockito`.

```dart
class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late GetTrips useCase;
  late MockTripRepository repo;

  setUp(() {
    repo = MockTripRepository();
    useCase = GetTrips(repo);
  });

  test('returns trips on success', () async {
    when(() => repo.getTrips(status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => const Right([_tTrip]));

    final result = await useCase(const GetTripsParams(page: 1));

    expect(result, const Right<Failure, List<Trip>>([_tTrip]));
    verify(() => repo.getTrips(status: null, page: 1)).called(1);
  });

  test('propagates failure', () async {
    when(() => repo.getTrips(status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(const GetTripsParams(page: 1));

    expect(result, const Left<Failure, List<Trip>>(ServerFailure('boom')));
  });
}
```

Structure tests as **Arrange / Act / Assert**. One behavior per test. Name tests
as sentences: `emits [Loading, Loaded] when fetch succeeds`.

## 3. Bloc tests

Use `bloc_test` — it handles the async emission sequence cleanly.

```dart
blocTest<TripsBloc, TripsState>(
  'emits [loading, loaded] when TripsFetched succeeds',
  build: () {
    when(() => getTrips(any())).thenAnswer((_) async => const Right([_tTrip]));
    return TripsBloc(getTrips);
  },
  act: (bloc) => bloc.add(const TripsFetched()),
  expect: () => const [TripsState.loading(), TripsState.loaded([_tTrip])],
  verify: (_) => verify(() => getTrips(any())).called(1),
);
```

Test the *sequence and content* of states, and that the use case was called with
the right params. Don't test framework internals.

## 4. Widget tests

Test a widget/page in isolation with a fake bloc (or a real bloc + mocked use
cases). Assert on what the user sees and can do.

```dart
testWidgets('shows error view and retries', (tester) async {
  final bloc = MockTripsBloc();
  whenListen(
    bloc,
    Stream.value(const TripsState.error('Network')),
    initialState: const TripsState.initial(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<TripsBloc>.value(value: bloc, child: const TripsPage()),
    ),
  );
  await tester.pump();

  expect(find.text('Network'), findsOneWidget);
  await tester.tap(find.byKey(const Key('retry_button')));
  verify(() => bloc.add(const TripsFetched())).called(1);
});
```

Tips: use `Key`s for elements you interact with. Use `pump` for a single frame,
`pumpAndSettle` to run animations to completion. Wrap in the same theme/l10n the
real app uses when it affects output.

### 4.1 One harness for every widget test

Wrap once, reuse everywhere — a widget that renders under the real theme and
l10n is the only one whose test proves anything about the UI.

```dart
Widget wrap(Widget child, {Size size = const Size(360, 690), double textScale = 1.0}) =>
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    );
```

Two cheap assertions worth adding to any non-trivial screen test — they catch the
regressions that reviewers miss:

```dart
testWidgets('does not overflow on a narrow screen at large text', (tester) async {
  await tester.pumpWidget(wrap(const OfferCard(offer: _tOffer), textScale: 1.3));
  expect(tester.takeException(), isNull);   // a RenderFlex overflow throws here
});
```

Test the **four states** of a screen (loading / empty / error / success) by
driving the fake bloc, not just the success path.

## 5. Golden tests

Golden tests snapshot the *rendered pixels* of a widget and fail on visual
regressions — great for design-system components and locking in layouts.

```dart
testWidgets('TripCard matches golden', (tester) async {
  await tester.pumpWidget(_wrap(const TripCard(trip: _tTrip)));
  await expectLater(
    find.byType(TripCard),
    matchesGoldenFile('goldens/trip_card.png'),
  );
});
```

- Generate/update with `flutter test --update-goldens`; review the diff before
  committing.
- Pin fonts and disable animations so goldens are stable across machines
  (`golden_toolkit` helps, and load real fonts in `flutter_test_config.dart`).
- Font rendering differs across OSes; run goldens in one canonical environment
  (usually CI) to avoid false diffs.

## 6. Integration tests

Full-app flows on a real device/emulator via `integration_test`. Reserve these
for critical end-to-end journeys (login → create trip → see it in list), because
they're slow and flakier.

```dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();
testWidgets('login flow', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('phone_field')), '+15551234567');
  await tester.tap(find.byKey(const Key('send_otp')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('otp_field')), findsOneWidget);
});
```

Keep the count small and the flows high-value. Stub the backend (or point at a
sandbox) so they're repeatable.

## 7. Test data & TDD

- Centralize fixtures/builders (`_tTrip`, `tripBuilder()`) so tests read cleanly
  and one schema change updates one place.
- Prefer **TDD for domain logic and bug fixes**: write the failing test that
  reproduces the bug, then fix until green — it becomes a permanent regression
  guard.
- Make tests independent (no shared mutable state, no ordering dependence). Reset
  in `setUp`.

## What to test vs. skip

**Test:** use cases, blocs/cubits, mappers, value-object validation, repository
logic (caching/offline branching), failure mapping, critical widgets & flows.

**Skip:** generated code (Freezed/injectable output), trivial pass-through
getters, third-party library internals, pure layout with no logic (a golden
covers that better than an assertion-heavy widget test).
