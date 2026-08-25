# Feature Scaffolding — Clean Architecture, end to end

Read this when the task is **"create a feature"**, "add an endpoint/usecase",
"wire a new bloc", or "how should this new piece be structured". It is the
concrete build order and file layout that `architect.md` describes abstractly
and `patterns.md` justifies pattern-by-pattern.

Pairs with `refactor.md` (§8 Widget composition) for the UI half — this file
deliberately stops **before** custom UI.

---

## 0. Calibrate to the repository FIRST

This skill is repo-agnostic; every project names things slightly differently.
Before writing a single file, open the **canonical reference feature** — the most
complete, already-working feature in the codebase (usually `auth` or the oldest
shipped flow) — and record its actual conventions:

| Thing to confirm | Typical variants seen in the wild |
| --- | --- |
| `Either` implementation | project-local `core/either/…` vs `core/models/either/…`; **never** `dartz`/`fpdart` if a local one exists |
| Failure base + factory | `core/error/failure.dart` vs `core/errors/failure.dart`; `ErrorHandler.toFailure(e)` vs `ServerError.withDioError(...)` |
| Folder plurality | `repository/` vs `repositories/`, `bloc/` vs `blocs/` |
| Model layout | one freezed model per own folder vs flat files in `models/` |
| Mapping style | dedicated `mappers/` sealed class vs `Model.toEntity()` extension |
| Status enum | `Status` (`core/enums/status.dart`) vs `ApiStatus` (`services/api_status.dart`) |
| State classes | Freezed union vs Equatable + hand-written `copyWith` |
| Error propagation | data source returns `Either` vs data source **throws** and the repo catches |
| Localization | `intl_*.arb` + `intl_utils` vs a custom `AppLocalizations` over `assets/locale/*.json` |
| Codegen command | `dart run build_runner build --delete-conflicting-outputs` vs a project alias/Makefile |

**Match the reference feature. Do not import conventions from another repo.**
If the reference feature itself violates the standard, say so and propose the
fix — but do not silently introduce a third style.

Never hand-edit generated files: `*.g.dart`, `*.freezed.dart`,
`injection.config.dart`, `lib/generated/`.

---

## 1. Hard boundary — scaffold stops before custom UI

Scaffold everything **up to and including an empty page skeleton**, then STOP.

- Do NOT design widgets, layouts, colors, charts, or cards on a fresh scaffold.
- The page skeleton is a `StatefulWidget` + mixin with a near-empty `Scaffold`
  (at most an app bar). Nothing more.
- Do NOT copy UI patterns from unrelated presentation files or mock-data files —
  they are not necessarily representative.
- An empty `widgets/` folder is created next to the page. It gets filled later,
  under `refactor.md` §8 rules.

Exception: if the user explicitly asks for the UI in the same request, build it
— but build it in **UI mode**: `ui-from-design.md` (pipeline + tokens + recipes),
`ui-layout.md` (page shape, overflow, states, a11y), `refactor.md` §8 (file
structure). Never ad hoc.

---

## 2. Dependency rules (enforce strictly)

Allowed import direction — violations are architecture bugs, not style nits:

| Layer | May import | Must NOT import |
| --- | --- | --- |
| `domain/entities` | core, freezed | data, presentation, Dio, Supabase, Hive |
| `domain/repository` | core, own entities, own usecase Params | data, presentation |
| `domain/usecases` | core, own entities + repo interface | data, presentation |
| `data/models` | core, freezed/json | domain, presentation |
| `data/data_source` | core, own models, Dio/Supabase/local storage | domain entities, presentation |
| `data/mappers` | own models + domain entities/Params | presentation |
| `data/repository` | own data_source + mappers + domain interface | presentation |
| `presentation/bloc` | core, domain (usecase, entity, Params) | data layer, Dio, Supabase |
| `presentation/pages` | core, own bloc, router | data layer, usecases directly |

Key consequences:

- Bloc talks ONLY to usecases. Never inject a repository or data source into a bloc.
- UI reads ONLY entities from bloc state. Request/response models never cross
  into presentation.
- **Data source is transport + error wrapping only.** It does not decide
  business-level failures.
- **Repository impl owns model→entity mapping and the failure classification** —
  whichever of the two shapes the repo uses (`fold` over an `Either` from the
  data source, or `try/catch` → `ErrorHandler.toFailure`), that decision lives
  here, not in the data source and not in the bloc.
- Offline check (`NetworkInfo`) belongs in the repository impl, before touching
  the data source.

---

## 3. Planning order (domain-first)

Each step fixes the contract for the next. Keep this order even when only some
layers are needed:

1. **Entity** — what the UI ultimately needs. No json, no API field names.
2. **Repository interface** (domain) — operations in business terms, `Either<Failure, Entity>`.
3. **Usecase(s) + Params** — one class per operation.
4. **Data models** — mirror the actual API/DB payload exactly (request + response).
5. **Mapper** — Params→Request, Response→Entity.
6. **Data source** (abstract + impl) — transport + error handling only.
7. **Repository impl** — glue: mapping + failure classification + `NetworkInfo`.
8. **Bloc** — events mirror user intents, single immutable state object.
9. **Page skeleton + mixin + route + DI check.** STOP.
10. **Tests** — see `testing.md`; a scaffold is not done because it compiles.

---

## 4. Decision guide

- **No backend call yet?** Create the abstract data source + an empty impl
  (`@LazySingleton(as: XDataSource) class XDataSourceImpl implements XDataSource {}`).
  Contract first, transport later.
- **Operation returns nothing?** Use the project's `Unit`
  (`Future<Either<Failure, Unit>>`, `return Right(unit)`). Never `void` inside
  `Either`.
- **Usecase without input?** `NoParams`.
- **Local persistence (tokens, flags, small prefs)?** Do NOT create a new storage
  box. Add a key + typed getter/setter to the existing local-source wrapper and
  inject it into the data source impl. For complex cached objects, add a separate
  `<feature>_local_data_source.dart` beside the remote one — same
  abstract + impl + `@LazySingleton(as:)` shape, `CacheFailure` on error.
- **Offline check needed?** Inject `NetworkInfo` into the repository impl; on
  `!isConnected` return `Left(NoInternetFailure(...))` before calling the data
  source.
- **New error case?** Add a `Failure` subclass in the project's failure file with
  its localized message. Do not sprinkle raw message strings through layers.
- **Several operations in one feature?** One usecase class per operation, ONE
  repository interface holding all methods, ONE bloc per screen with one event
  per user intent — inject multiple usecases into that bloc. Never two blocs for
  one screen.
- **Extending an existing feature?** Same order, additive only: repo interface
  method → impl → usecase → event + handler on the existing bloc → codegen.

---

## 5. Anti-patterns — reject on sight

- `dartz`/`fpdart` when the project has its own `Either`.
- `throw` crossing a layer boundary the project doesn't expect it to cross —
  pick the repo's one convention and hold it.
- Bloc injecting Dio / Supabase / data source / repository.
- Entity with `fromJson`, or a model leaking into state/page.
- Manual edits to `injection.config.dart`; manual `sl.registerX` for feature
  classes (annotations + codegen own that file).
- Business logic in the `State` body — controllers/listeners/helpers go in the mixin.
- New storage boxes; raw box access outside the local-source wrapper.
- Building custom UI beyond the skeleton on a fresh scaffold.
- Hardcoded UI strings — add the key to **every** locale file the project ships.

---

## 6. Layer templates

Shapes, not gospel — bend the names to the reference feature (§0).

### 6.1 Data source (abstract + impl)

Shape A — data source returns `Either` (error classification wrapped here):

```dart
abstract class XDataSource {
  Future<Either<Failure, XResponse>> doThing({required XRequest request});
}

@LazySingleton(as: XDataSource)
class XDataSourceImpl implements XDataSource {
  final Dio _dio;
  const XDataSourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<Either<Failure, XResponse>> doThing({required XRequest request}) async {
    try {
      final response = await _dio.post('/endpoint', data: request.toJson());
      return Right(XResponse.fromJson(response.data));
    } on DioException catch (error, stackTrace) {
      log('Exception occurred: $error stacktrace: $stackTrace');
      return Left(ServerError.withDioError(error: error).failure);
    } on Exception catch (error, stackTrace) {
      log('Exception occurred: $error stacktrace: $stackTrace');
      return Left(ServerError.withError(message: error.toString()).failure);
    }
  }
}
```

Shape B — data source throws, repository catches:

```dart
abstract class XDataSource {
  Future<XResponse> doThing({required XRequest request});
}

@LazySingleton(as: XDataSource)
class XDataSourceImpl implements XDataSource {
  final Dio dio;
  const XDataSourceImpl({required this.dio});

  @override
  Future<XResponse> doThing({required XRequest request}) async {
    final response = await dio.post('/endpoint', data: request.toJson());
    return XResponse.fromJson(response.data);
  }
}
```

Use whichever shape the reference feature uses. Do not mix both in one repo.

### 6.2 Models (freezed + json)

```dart
@freezed
abstract class XRequest with _$XRequest {
  const factory XRequest({required String field}) = _XRequest;
  factory XRequest.fromJson(Map<String, dynamic> json) => _$XRequestFromJson(json);
}
```

### 6.3 Entity (freezed, no json)

```dart
@freezed
abstract class XEntity with _$XEntity {
  const factory XEntity({required String field}) = _XEntity;
}
```

### 6.4 Mapper — sealed class, private ctor, statics only

```dart
sealed class XMapper {
  XMapper._();
  static XEntity toEntity(XResponse response) => XEntity(field: response.field);
  static XRequest toRequest(XParams params) => XRequest(field: params.field);
}
```

(Projects that use `extension XResponseX on XResponse { XEntity toEntity() => … }`
keep that instead — same rule: mapping lives in `data/`, never in `domain/` or
`presentation/`.)

### 6.5 Repository — abstract in domain, impl in data

```dart
abstract class XRepository {
  Future<Either<Failure, XEntity>> doThing({required XParams params});
}
```

Impl, Shape A (fold):

```dart
@LazySingleton(as: XRepository)
class XRepositoryImpl implements XRepository {
  final XDataSource _dataSource;
  const XRepositoryImpl({required XDataSource dataSource}) : _dataSource = dataSource;

  @override
  Future<Either<Failure, XEntity>> doThing({required XParams params}) async {
    final result = await _dataSource.doThing(request: XMapper.toRequest(params));
    return result.fold(
      (failure) => Left(failure),
      (response) => Right(XMapper.toEntity(response)),
    );
  }
}
```

Impl, Shape B (network guard + try/catch):

```dart
@LazySingleton(as: XRepository)
class XRepositoryImpl implements XRepository {
  final XDataSource dataSource;
  final NetworkInfo networkInfo;
  const XRepositoryImpl({required this.dataSource, required this.networkInfo});

  @override
  Future<Either<Failure, XEntity>> doThing({required XParams params}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NoInternetFailure(message: 'No Internet Connection'));
    }
    try {
      final response = await dataSource.doThing(request: XMapper.toRequest(params));
      return Right(response.toEntity());
    } catch (e) {
      return Left(ErrorHandler.toFailure(e));
    }
  }
}
```

### 6.6 Usecase — extends the core `UseCase<Type, Params>`, Params in the same file

```dart
@lazySingleton
class XUsecase extends UseCase<XEntity, XParams> {
  const XUsecase({required this.repository});
  final XRepository repository;

  @override
  Future<Either<Failure, XEntity>> call(XParams params) => repository.doThing(params: params);
}

@freezed
abstract class XParams with _$XParams {
  const factory XParams({required String field}) = _XParams;
}
```

### 6.7 Bloc — `@injectable`, event/state as `part` files, a status enum

```dart
part 'x_event.dart';
part 'x_state.dart';
part 'x_bloc.freezed.dart';

@injectable
class XBloc extends Bloc<XEvent, XState> {
  final XUsecase usecase;
  XBloc({required this.usecase}) : super(const XState()) {
    on<DoThingEvent>(_onDoThing);
  }

  Future<void> _onDoThing(DoThingEvent event, Emitter<XState> emit) async {
    emit(state.copyWith(status: Status.loading));
    final result = await usecase(event.params);
    result.fold(
      (failure) => emit(state.copyWith(status: Status.failed, failure: failure)),
      (entity) => emit(state.copyWith(status: Status.success, entity: entity)),
    );
  }
}
```

State rules:

- ONE state object per bloc, immutable, with `copyWith`.
- Status comes from the project's status enum with its `isLoading`/`isSuccess`/…
  extensions — never loose `bool isLoading, hasError` pairs.
- `Failure` field defaults to the project's unknown failure; payload fields nullable.
- Multi-operation screens: one shared `status` if operations are sequential, or
  one status field per independent operation (`loadStatus`, `saveStatus`).
- Freezed union vs Equatable is the repo's call (§0) — but the *rules* above hold
  either way.

### 6.8 Page skeleton + mixin (STOP here on a fresh scaffold)

```dart
// x_mixin.dart
mixin XMixin on State<XPage> {}
```

```dart
// x_page.dart
class XPage extends StatefulWidget {
  const XPage({super.key});

  @override
  State<XPage> createState() => _XPageState();
}

class _XPageState extends State<XPage> with XMixin {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: CustomAppBar(title: context.locale.someKey),
      );
}
```

Controllers, listeners, and helper logic go in the mixin, not the `State` body.
New l10n keys go into **every** locale file the project ships, then the locale
codegen runs (if the project has one).

### 6.9 Route

1. Add the route name/path constant.
2. Register it — root-level flows get their own navigator key if the router uses
   nested navigators; tab screens go inside the matching shell branch.
3. Provide the bloc at route level:

```dart
GoRoute(
  path: Routes.x,
  name: Routes.x,
  builder: (_, __) => BlocProvider(
    create: (_) => sl<XBloc>(),
    child: const XPage(),
  ),
),
```

Navigate with `context.pushNamed(Routes.x)`; pass data via `state.extra`.

Routing details that are easy to get wrong:

- **Never construct a path string at a call site.** `Routes.*` constants only —
  a stringly-typed route is the same defect as a magic number.
- **Typed arguments.** `extra` is `Object?`; pass one entity/params object and
  cast it once in the route builder, not scattered casts in the page.
- **Returning a result** (a picked value, a confirmed sheet): `await
  context.pushNamed<T>(...)`, then `if (!context.mounted) return;` before using
  the result.
- **Auth/onboarding guards** live in the router's `redirect`, not in a page's
  `initState`. One place decides who may see what.
- **Deep links** validate their parameters before acting (`security.md` §6) —
  a link must not be able to drive privileged navigation with an unchecked id.
- **Bloc lifetime follows the route.** Provide it at the route (as above) so it
  is disposed with the page; hoist it to a shell branch only when the state must
  genuinely outlive the screen.

### 6.10 DI

No manual registration. `@LazySingleton(as: ...)` for interface impls,
`@lazySingleton` for usecases, `@injectable` for blocs, then run codegen.

---

## 7. Directory layout (per feature)

```
lib/features/<feature>/
  data/
    data_source/
      <feature>_data_source.dart          # abstract + impl (or split)
    mappers/
      <feature>_mapper.dart
    models/
      <name>_request.dart
      <name>_response.dart
    repository/
      <feature>_repository_impl.dart
  domain/
    entities/
      <name>_entity.dart
    repository/
      <feature>_repository.dart           # abstract
    usecases/
      <name>_usecase.dart                 # usecase + Params together
  presentation/
    bloc/
      <name>_bloc/
        <name>_bloc.dart
        <name>_event.dart                 # part of bloc
        <name>_state.dart                 # part of bloc
    pages/
      <name>_page/
        <name>_page.dart
        <name>_mixin.dart
        widgets/                          # created empty — filled per refactor.md §8
```

Folder plurality and per-model subfolders follow the reference feature (§0).

---

## 8. Finish checklist

1. Dependency table (§2) holds — no forbidden imports.
2. Codegen ran; generated files compile.
3. Locale codegen ran — only if locale files were touched.
4. `flutter analyze` — zero new issues.
5. Tests exist for the usecase + bloc at minimum (`testing.md`). A scaffold with
   no tests is not finished, it is started.
6. If any runtime behavior changed, the `Manual Test Result` block from
   `manual-test.md` is filled in — or the response says plainly
   "code-complete, NOT device-tested" with exact steps.
7. Report to the user: files created, which usecases/events exist, and that the
   page body + `widgets/` are intentionally left for them to draw.
