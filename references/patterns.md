# Design Patterns — Repository, UseCase, Either, Freezed, DI, Mapper

Read this when implementing data flow, error handling, DI wiring, or choosing a
pattern for a piece of logic.

## 1. Result / Either monad — error handling without exceptions

Do not throw across layers. The domain boundary returns `Either<Failure, T>`
(left = failure, right = success) or a sealed `Result`. This makes failure part
of the type signature, so callers cannot forget to handle it.

```dart
typedef Either<L, R> = _Either<L, R>;      // your custom monad

sealed class Failure {
  final String message;
  const Failure(this.message);
}
class ServerFailure    extends Failure { const ServerFailure(super.m); }
class NetworkFailure   extends Failure { const NetworkFailure(super.m); }
class CacheFailure     extends Failure { const CacheFailure(super.m); }
class ValidationFailure extends Failure { const ValidationFailure(super.m); }
```

Consuming an `Either` in a bloc — exhaustively, no unhandled path:

```dart
final result = await _getTrips(params);
result.fold(
  (failure) => emit(TripsState.error(failure.toMessage())),
  (trips)   => emit(TripsState.loaded(trips)),
);
```

Map exceptions to failures **only in the data layer**:

```dart
Future<Either<Failure, List<Trip>>> getTrips(...) async {
  try {
    final dtos = await _remote.fetchTrips(...);
    return Right(dtos.map(_mapper.toDomain).toList());
  } on DioException catch (e) {
    return Left(_mapDioError(e));            // typed failure
  } on CacheException {
    return const Left(CacheFailure('No cached trips'));
  }
}
```

## 2. Repository pattern

The repository is the seam between domain and data. Domain defines the
*interface*; data provides the *implementation*. This lets you swap remote for
cache, or mock in tests, with zero UI changes.

```dart
// domain/repositories/trip_repository.dart  (pure abstraction)
abstract interface class TripRepository {
  Future<Either<Failure, List<Trip>>> getTrips({TripStatus? status, int page});
  Future<Either<Failure, Trip>> getTripById(String id);
}

// data/repositories/trip_repository_impl.dart
@LazySingleton(as: TripRepository)
class TripRepositoryImpl implements TripRepository {
  final TripRemoteDataSource _remote;
  final TripLocalDataSource _local;
  final NetworkInfo _network;
  final TripMapper _mapper;

  const TripRepositoryImpl(this._remote, this._local, this._network, this._mapper);

  @override
  Future<Either<Failure, List<Trip>>> getTrips({TripStatus? status, int page = 1}) async {
    if (await _network.isConnected) {
      try {
        final dtos = await _remote.getTrips(status: status, page: page);
        await _local.cacheTrips(dtos);              // offline-first write-through
        return Right(dtos.map(_mapper.toDomain).toList());
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }
    final cached = await _local.getCachedTrips();
    return Right(cached.map(_mapper.toDomain).toList());
  }
}
```

## 3. Mapper pattern — DTO ⇄ Entity

DTOs (`fromJson`/`toJson`) live in `data/`. Entities live in `domain/`. A mapper
translates between them so JSON shape changes never ripple into the UI.

```dart
class TripMapper {
  const TripMapper();

  Trip toDomain(TripDto dto) => Trip(
        id: dto.id,
        origin: dto.origin,
        destination: dto.destination,
        status: TripStatus.fromCode(dto.statusCode),   // string → enum here, not in UI
        price: Money.fromMinorUnits(dto.priceMinor, dto.currency),
      );

  TripDto toDto(Trip trip) => TripDto(/* ... */);
}
```

A **sealed/typed mapper** is useful when a DTO maps to a union of domain types
(e.g. a `notification` DTO whose `type` field selects a Freezed variant). Switch
exhaustively on the discriminator inside the mapper.

## 4. UseCase base + callable pattern

A tiny base makes use cases uniform and easy to invoke like functions.

```dart
abstract interface class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

// For parameterless use cases:
final class NoParams {
  const NoParams();
}
```

## 5. Freezed — immutable models, unions, states

Freezed gives immutability, value equality, `copyWith`, and — most valuably —
**sealed unions** for exhaustive state handling.

```dart
@freezed
sealed class TripsState with _$TripsState {
  const factory TripsState.initial() = _Initial;
  const factory TripsState.loading() = _Loading;
  const factory TripsState.loaded(List<Trip> trips) = _Loaded;
  const factory TripsState.error(String message) = _Error;
}
```

Exhaustive UI switch — the compiler forces every state to be handled:

```dart
switch (state) {
  _Initial() || _Loading() => const _LoadingView(),
  _Loaded(:final trips)    => TripList(trips: trips),
  _Error(:final message)   => ErrorView(message: message),
}
```

Prefer this over a single mutable state class with nullable fields
(`isLoading`, `error`, `data` all present at once) — that shape allows
contradictory states like "loading AND error".

## 6. Dependency Injection — get_it + injectable

Constructor injection everywhere. Widgets receive their bloc via
`BlocProvider(create: (_) => getIt<TripsBloc>())`; they never call `getIt`
inside `build`.

```dart
@LazySingleton(as: TripRepository)
class TripRepositoryImpl implements TripRepository { /* ... */ }

@injectable
class GetTrips implements UseCase<List<Trip>, GetTripsParams> { /* ... */ }

@injectable
class TripsBloc extends Bloc<TripsEvent, TripsState> { /* ... */ }
```

Registration guidance:
- `@lazySingleton` for stateless services, repositories, data sources, Dio.
- `@injectable` (factory) for blocs/cubits so each page gets a fresh instance.
- Never register `BuildContext`, navigation, or anything with UI lifetime.

## 7. Other patterns worth reaching for

- **Strategy** — swap an algorithm at runtime (e.g. pricing strategies,
  sort orders). Replaces growing `if/switch` chains; supports Open/Closed.
- **Factory** — centralize creation when construction is non-trivial or picks a
  subtype (e.g. `PaymentProcessorFactory.forMethod(method)`).
- **Adapter** — wrap a third-party SDK behind your own interface so the app
  depends on *your* contract, not the vendor's. Keeps SDK swaps localized.
- **Decorator** — layer behavior (e.g. `LoggingRepository` wrapping a real
  repository) without touching the wrapped class.
- **Observer** — already idiomatic in Flutter via `Stream`/`BLoC`; don't
  reinvent it with manual listener lists.

Pick the simplest pattern that removes the coupling or duplication at hand. A
pattern applied where a plain function would do is over-engineering (YAGNI).
