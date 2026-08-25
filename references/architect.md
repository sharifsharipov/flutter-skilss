# Architecture — Clean Architecture, Feature-First, SOLID, DDD

Read this when structuring a new project or feature, deciding where a file
lives, or auditing layer boundaries.

## 1. Layer model

Three layers, one dependency direction. **The domain layer is the center and
depends on nothing.**

```
presentation  ──depends on──▶  domain  ◀──depends on──  data
   (UI, BLoC)                  (pure)                 (Dio, DB, DTOs)
```

- **domain** — entities, value objects, repository *interfaces*, use cases,
  failures. Pure Dart. No Flutter imports, no Dio, no JSON, no `BuildContext`.
  If you `import 'package:flutter/...'` here, it's wrong.
- **data** — repository *implementations*, remote/local data sources, DTOs,
  mappers. Depends on domain (implements its interfaces). Knows about Dio, Isar,
  SharedPreferences, etc.
- **presentation** — widgets, BLoC/Cubit, page routing. Depends on domain use
  cases. Never imports from `data/`.

**The Dependency Rule:** source code dependencies point inward only. Inner
layers know nothing about outer layers. The UI can change from Flutter to
anything and the domain never notices.

## 2. Feature-first folder structure

Organize by feature, not by technical type. A new engineer should read the
folder tree and understand *what the app does*, not just *what patterns it uses*.

```
lib/
├── core/                      # shared, cross-feature
│   ├── error/                 # Failure, Exception types
│   ├── network/               # Dio client, interceptors
│   ├── usecase/               # UseCase<Type, Params> base
│   ├── utils/                 # Either, typedefs, extensions
│   └── di/                    # injectable config
├── features/
│   └── trips/
│       ├── domain/
│       │   ├── entities/          trip.dart
│       │   ├── repositories/      trip_repository.dart   (abstract)
│       │   └── usecases/          get_trips.dart
│       ├── data/
│       │   ├── models/            trip_dto.dart          (fromJson/toJson)
│       │   ├── datasources/       trip_remote_data_source.dart
│       │   ├── mappers/           trip_mapper.dart
│       │   └── repositories/      trip_repository_impl.dart
│       └── presentation/
│           ├── bloc/              trips_bloc.dart
│           ├── pages/             trips_page.dart
│           └── widgets/           trip_card.dart
└── main.dart
```

Rules:
- One feature never imports another feature's `data/` or `presentation/`. Shared
  needs go to `core/` or a shared feature exposing a domain interface.
- `core/` holds only genuinely cross-cutting code. Resist the urge to dump
  feature logic there — it becomes a god package.

## 3. SOLID in Flutter terms

**S — Single Responsibility.** A class has one reason to change. A `TripsBloc`
that also parses JSON and formats dates has three reasons. Split them: parsing →
mapper, formatting → extension/formatter, orchestration → bloc.

**O — Open/Closed.** Extend behavior without editing existing code. Add a new
`PaymentMethod` by adding a class implementing the interface, not by adding a
`case` to a growing `switch` in the checkout logic. Use polymorphism / the
Strategy pattern.

**L — Liskov Substitution.** A subtype must be usable wherever its supertype is
expected without surprises. A `CachedTripRepository` implementing
`TripRepository` must honor the same contract — same failure types, no throwing
where the interface promised `Either`.

**I — Interface Segregation.** Prefer small, focused interfaces. A data source
that only reads shouldn't be forced to implement `delete`/`update`. Split
`ReadableSource` and `WritableSource` if consumers differ.

**D — Dependency Inversion.** Depend on abstractions. The bloc depends on a
`GetTrips` use case and the use case on a `TripRepository` interface — never on
`Dio` or `TripRepositoryImpl` directly. Concrete classes are wired only in the
DI container.

```dart
// GOOD — presentation depends on the abstraction
class TripsBloc extends Bloc<TripsEvent, TripsState> {
  final GetTrips _getTrips;            // use case, from domain
  TripsBloc(this._getTrips) : super(const TripsState.initial());
}

// BAD — presentation reaches into data + network
class TripsBloc {
  final Dio dio;                       // ❌ layer + framework leak
}
```

## 4. Domain-Driven Design essentials

- **Entities** have identity (an `id`) and equality by that identity.
- **Value objects** are immutable, equal by value, and enforce their own
  invariants at construction. Use them to make illegal states unrepresentable.

```dart
// A phone number that cannot be constructed in an invalid state.
class PhoneNumber {
  final String value;
  const PhoneNumber._(this.value);

  static Either<ValidationFailure, PhoneNumber> create(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
      return const Left(ValidationFailure('Invalid phone number'));
    }
    return Right(PhoneNumber._(normalized));
  }
}
```

Prefer value objects over primitive `String`/`int` for domain concepts (money,
IDs, coordinates, phone numbers). "Primitive obsession" is a real smell — it
scatters validation across the codebase.

- **Aggregates** — a cluster of entities/value objects with one root. Outside
  code talks only to the root, keeping invariants in one place.

## 5. Use cases

One use case = one business operation. It orchestrates repositories and encodes
a single intent. Keep them thin; they are *not* a dumping ground.

```dart
class GetTrips implements UseCase<List<Trip>, GetTripsParams> {
  final TripRepository _repository;
  const GetTrips(this._repository);

  @override
  Future<Either<Failure, List<Trip>>> call(GetTripsParams params) {
    return _repository.getTrips(status: params.status, page: params.page);
  }
}
```

If a use case grows conditionals and coordinates five repositories, that logic
probably belongs in a domain service or should be split.

## 6. Common layer-boundary violations to reject

- DTO (`TripDto`) used directly in a widget → map to `Trip` entity first.
- `BuildContext` passed into the domain or data layer → never.
- Repository implementation returning raw `DioException` → catch in the data
  layer, map to a typed `Failure`.
- Business rules living in `onPressed` callbacks → move into a use case.
- A feature importing another feature's internals → invert via a domain
  interface placed in `core/` or the owning feature's public API.

## 7. Package boundaries & cohesion

- **High cohesion:** things that change together live together (a feature's
  bloc, page, and widgets).
- **Low coupling:** features communicate through domain contracts, not shared
  mutable singletons.
- Watch for **cyclic dependencies** between features — they signal a missing
  shared abstraction. Extract it to `core/` or a `shared` feature.
- For large apps, consider splitting features into separate packages (melos
  monorepo) so boundaries are enforced by the compiler, not by discipline. See
  `enterprise.md`.
