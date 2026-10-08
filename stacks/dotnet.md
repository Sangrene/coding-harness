# Stack pack: .NET (C#)

`project.stack: dotnet` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `*.sln` / `*.slnx` | solution; lists projects (`dotnet sln <sln> list`) |
| `*.csproj` (`*.fsproj`) | SDK-style project; `<TargetFramework>` = runtime, `<LangVersion>` if pinned |
| `Directory.Build.props` / `.targets` | repo-wide MSBuild settings (`TreatWarningsAsErrors`, `Nullable`, analyzers) |
| `Directory.Packages.props` | Central Package Management — versions live here, not in `.csproj` |
| `global.json` | pinned SDK; `"test": { "runner": "Microsoft.Testing.Platform" }` switches `dotnet test` to MTP mode (.NET 10+) |
| `packages.lock.json` | NuGet lock files — restore with `--locked-mode` in CI |
| `.config/dotnet-tools.json` | local tools (`dotnet ef`, `csharpier`, …) |
| `NuGet.config` | private feeds — restore may need credentials/network |

Workspace (→ `workspace`): a `.sln` is usually ONE hexagon split across
projects (Domain/Application/Infrastructure/Api) — single-package manifest.
Use the workspace form only for several independent services in one repo
(several `src/<Service>/*.sln` or a solution with disjoint project groups).
Read the `<ProjectReference>` graph: it is the dependency rule, mechanically.

`project.language`: "C# <n>" — `<LangVersion>`, else the default for the TFM
(net8 → C# 12, net9 → 13, net10 → 14). Frameworks: `Microsoft.NET.Sdk.Web`
(ASP.NET Core), `MediatR`, `Wolverine`, `EntityFrameworkCore`, `Dapper`,
`MassTransit`, `Orleans`, `Blazor`, `MAUI`.

## 2. Commands

| Field | Value |
|---|---|
| `run` | `dotnet` |
| `exec` | `dotnet tool run <tool>` (local tools manifest); `dotnet <tool>` also works for local tools |
| `add_dependency` | `dotnet add <proj> package <Id>` (.NET 10 also: `dotnet package add <Id> --project <proj>`). With CPM, check the version landed in `Directory.Packages.props` |
| `test_all` | `dotnet test <sln> --no-restore` |
| `lint` | `dotnet format --verify-no-changes` if the repo uses it; `csharpier check .` if CSharpier |

Real scripts: CI workflow (`dotnet build -c Release`, `--collect`, filters),
`build.cake`, `build.ps1`/`build.sh`, Nuke `build/Build.cs`, Makefile/justfile.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| default | `dotnet build <sln> --no-restore -warnaserror` | `build-guard` |
| repo has existing warnings and no `TreatWarningsAsErrors` | `dotnet build <sln> --no-restore` | `build-guard` |

- Building the solution compiles test projects too — that is why the gate is
  `build`, not a per-project build.
- `--no-restore` requires `obj/project.assets.json` up to date. Restore is
  needed after: fresh clone, any `PackageReference`/`ProjectReference` change,
  new project, `Directory.Packages.props` edit, SDK change. The dependency step
  (or the wiring agent) runs `dotnet restore <sln>` — never the gate, so the
  gate stays offline and fast. Error `NETSDK1004` = assets file missing → restore.
- `-warnaserror` fails a repo that tolerates warnings today: check
  `Directory.Build.props`/CI first; do not introduce it unasked.

## 4. Targeted tests

| Mode | `test_targeted` | `test_target_hint` |
|---|---|---|
| VSTest (default ≤ .NET 9, or no `test.runner` in `global.json`) | `dotnet test {project} --no-restore --filter "FullyQualifiedName~{filter}"` | "{project} = the test project dir or .csproj, e.g. tests/Notes.Domain.Tests; {filter} = Namespace.ClassName or ClassName.MethodName" |
| MTP (`global.json` test.runner = Microsoft.Testing.Platform) | `dotnet test --project {project} --no-restore <framework filter> {filter}` | same; filter flag depends on the framework |

- MTP filter options come from the test framework, not the SDK. MSTest/NUnit on
  MTP accept `--filter`; xUnit v3 uses its own (`--filter-class`,
  `--filter-method`, …). Read `dotnet test --project <p> --help` in the repo
  and record the exact flag — do not guess.
- `dotnet test` has no result cache and no watch (that is `dotnet watch test` —
  never use it).
- `--no-build` is faster but runs stale binaries if the gate didn't build; use
  it only right after a successful gate.

## 5. Red stub

A missing type/member is a compile error (whole test project fails to build) —
not a valid RED. RED means the test compiles, runs, and fails for the expected
reason. Declare the member with its real signature returning `default` or a
dummy value, so the failure is an assertion. `throw new
NotImplementedException()` is acceptable only when the test output names that
stub as the cause.

`testing.red_stub`: "declare the type and member with the final signature returning `default`/a dummy value; `throw new NotImplementedException()` acceptable when the failure names it"

Trap: `Assert.ThrowsAny<Exception>`, `Should().Throw<Exception>()`, or
`Assert.ThrowsAsync<Exception>` pass against the stub. Assert the specific
exception type (or the Result's error code) so RED is a real failure.

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| one test project per production project | `tests/<Proj>.Tests/*.csproj` with `<ProjectReference>` to `src/<Proj>` | `separate-project` | `tests/<Proj>.Tests/<Folder>/<Type>Tests.cs` |
| one test project per kind | `UnitTests`, `IntegrationTests`, `FunctionalTests` | `separate-project` | `tests/<Kind>Tests/<Proj>/<Type>Tests.cs` |
| tests inside the project (rare) | `*Tests.cs` beside code, test packages in the main csproj | `colocated` | `<Folder>/<Type>Tests.cs` |

Frameworks: xUnit (`[Fact]`/`[Theory]`), NUnit (`[Test]`), MSTest
(`[TestMethod]`), TUnit. Naming: `Method_State_Expected` (technical) or
sentence-style display names (user-facing).

Ownership: each layer owns its production project AND its slice of the test
tree: `owns: ["src/Notes.Domain/**", "tests/Notes.Domain.Tests/**"]`, with
`excludes: ["**/bin/**", "**/obj/**"]`. The `.csproj` belongs to the layer whose
project it is; `*.sln` and `Directory.*.props` to the wiring layer. Raise
`max_files` to 4–5: interface + class + DI registration + test is one unit of work.

## 7. Doubles & spy technique

- Harness default: hand-written fakes (`InMemoryNoteRepository : INoteRepository`)
  in the test project or a shared `tests/<X>.TestDoubles` project; declared as the
  interface (`INoteRepository repo = new InMemoryNoteRepository();`).
- Stack norms: Moq, NSubstitute, FakeItEasy are ubiquitous. If the repo mocks
  driven ports with them, record `doubles.style: mocking-framework` and flag;
  don't rewrite existing tests. `WebApplicationFactory<Program>` +
  `ConfigureTestServices` swaps adapters for driving-adapter tests.
- `Testcontainers` / EF InMemory / SQLite in-memory are adapter-test tools, not
  doubles for application tests.

`testing.spy_technique`: "write a recording fake that implements the port interface, records each call in a list, and delegates to an inner real or in-memory implementation (Moq `CallBase` only works on virtual members of classes, not on interfaces)"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| exceptions | `class \w+Exception : `, `throw new`, `catch (` | `exceptions (DomainException hierarchy)` | `false` | `exception subtype` |
| ErrorOr | `ErrorOr<`, `Error.NotFound(`, `.Match(` | `ErrorOr<T>` | `true` | `Error.Type (ErrorType enum) + Code` |
| OneOf | `OneOf<`, `.Match(`, `.Switch(` | `OneOf<T, NotFound, …>` | `true` | `union case type` |
| FluentResults | `Result.Fail(`, `Result.Ok(`, `IError` | `Result<T> (FluentResults)` | `true` | `error subtype / metadata` |
| LanguageExt | `Fin<`, `Either<`, `Option<` | `Fin<T> / Either<Error, T>` | `true` | `Error code / case` |
| hand-rolled | `record Result<`, `abstract record .*Error` | `Result<T, DomainError>` | `true` | `record subtype pattern match` |

HTTP edge: ProblemDetails (`AddProblemDetails()`, `IExceptionHandler`,
`Results.Problem`, `TypedResults.Problem`, `ValidationProblem`) — mapping from
domain error/exception to status belongs in the driving adapter only.

Typical `traps`:

- "`catch (Exception)` that swallows or rethrows as a generic error"
- "`DbUpdateException` / `SqlException` / `HttpRequestException` escaping the adapter"
- "ErrorOr `.Value` / FluentResults `.Value` / OneOf `.AsT0` read without checking the failure case"
- "`throw ex;` instead of `throw;` (loses stack)"
- "`.Result` / `.Wait()` on tasks; `async void` outside event handlers"
- "domain throwing for an expected failure when `never_throw: true`"

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| FluentValidation | `AbstractValidator<`, `RuleFor(` | driving adapter or application pipeline behaviour (MediatR `IPipelineBehavior`) — on commands/requests, never on entities |
| DataAnnotations | `[Required]`, `[StringLength]`, `[Range]` | request DTOs only; on a domain type = leakage |
| Minimal API / MVC validation | `AddValidation()`, `[ApiController]` auto-400 | driving adapter |
| constructors / factory methods | `static Result<Email> Create(` | domain invariants |

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["`!` null-forgiving operator", "`default!` / `null!`", "`dynamic`", "`object` in signatures", "explicit casts `(T)x`", "`#nullable disable`", "`#pragma warning disable`", "`[SuppressMessage]` without justification", "reflection (`GetType().GetProperty`, `Activator.CreateInstance`)"]

## 11. Hexagon mapping hints

| Role | Typical appearance |
|---|---|
| domain_type | `src/<App>.Domain/` — entities, value objects, aggregates (`Entities/`, `ValueObjects/`, `Aggregates/`) |
| domain_error | `Domain/Errors/*Errors.cs` (ErrorOr static error catalogues) or `Domain/Exceptions/` |
| driving_port | `src/<App>.Application/` — MediatR `IRequestHandler<,>` / command+handler pairs, `*Service` interfaces, `UseCases/` |
| driving_adapter | `src/<App>.Api/` (`Controllers/`, `Endpoints/`, minimal API `Map*`), `Worker` (`BackgroundService`), gRPC services |
| driven_port | `I*Repository`, `I*Gateway`, `IClock` in `Application/Abstractions/` or `Domain/` |
| driven_adapter | `src/<App>.Infrastructure/` — `Persistence/`, EF `DbContext`, `*Repository`, HTTP clients |
| test_double | `tests/*/Fakes/`, `InMemory*`, `Fake*` |
| composition_root | `Program.cs` + `DependencyInjection.cs` / `ServiceCollectionExtensions` (`AddApplication()`, `AddInfrastructure()`) |

Templates seen in the wild: Jason Taylor `CleanArchitecture`, Ardalis
`CleanArchitecture` (Core/UseCases/Infrastructure/Web), Milan Jovanović
style (Domain/Application/Infrastructure/Presentation), vertical slice
(`Features/<Feature>/` with endpoint + handler + validator in one folder — map
handler → driving_port, endpoint → driving_adapter; the dependency rule then
applies *within* the slice, so per-layer `owns` globs become per-suffix globs).

Typical gaps (→ `conformance.gaps`):

- `IRepository` declared in the Infrastructure project → port derived from adapter.
- `DbContext` / `IApplicationDbContext` exposing `DbSet<T>` used in Application
  handlers → persistence leaks inward (common in the Jason Taylor template).
- EF entities with `[Table]`, `[Key]`, `[Column]`, navigation-property-driven
  design used as domain types → domain/persistence merge.
- Generic `Repository<T>` over EF with `IQueryable<T>` returned → leakage.
- Controllers containing logic / calling `DbContext` directly.
- Static service locator (`ServiceLocator.Current`, `IServiceProvider` injected
  into domain/application), `HttpContext.Current`-style statics.
- Application project referencing `Microsoft.EntityFrameworkCore` or
  `Microsoft.AspNetCore.*` (check its `.csproj`).

`leakage_examples`: ["DbContext", "DbSet<T>", "IQueryable<T> past the repository", "DbUpdateException", "[JsonPropertyName]", "[Column] / [Key] / [Table]", "IActionResult / IResult", "HttpContext", "ProblemDetails outside the API project"]

`modules.unit`: "one .csproj (or Domain/Application/Infrastructure trio) per module".

## 12. Arch tests

`<ProjectReference>` already enforces cross-project direction (a Domain
project without references cannot import Infrastructure). Check with
`dotnet list <proj> reference`. Two holes remain: package references
(EF Core in Application) and transitive references (Api → Infrastructure →
Application exposes Application everywhere unless
`<DisableTransitiveProjectReferences>true</DisableTransitiveProjectReferences>`).
Arch tests close them, and are required for single-project / vertical-slice repos.

**NetArchTest.Rules** (API verified against benmorris/NetArchTest docs:
`Types.InAssembly`, `ShouldNot().HaveDependencyOnAny(params string[])`,
`GetResult()`, `IsSuccessful`, `FailingTypeNames`). Starting point — replace
namespaces and marker types. `tests/Architecture.Tests/DependencyRuleTests.cs`:

```csharp
using NetArchTest.Rules;
using Xunit;

public class DependencyRuleTests
{
    private const string Application = "Notes.Application";
    private const string Infrastructure = "Notes.Infrastructure";
    private const string Api = "Notes.Api";

    [Fact]
    public void Domain_depends_on_nothing_outward() =>
        AssertNoDependency(typeof(Notes.Domain.Note).Assembly,
            Application, Infrastructure, Api,
            "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore", "System.Text.Json.Serialization");

    [Fact]
    public void Application_depends_on_domain_only() =>
        AssertNoDependency(typeof(Notes.Application.CreateNote).Assembly,
            Infrastructure, Api, "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore");

    [Fact]
    public void Infrastructure_does_not_depend_on_driving_adapters() =>
        AssertNoDependency(typeof(Notes.Infrastructure.NotesDbContext).Assembly, Api);

    private static void AssertNoDependency(System.Reflection.Assembly assembly, params string[] forbidden)
    {
        var result = Types.InAssembly(assembly)
            .ShouldNot()
            .HaveDependencyOnAny(forbidden)
            .GetResult();
        Assert.True(result.IsSuccessful,
            "Violations: " + string.Join(", ", result.FailingTypeNames ?? System.Array.Empty<string>()));
    }
}
```

Single-project / vertical slice: use `Types.InAssembly(...).That().ResideInNamespace("Notes.Domain")`
before `.ShouldNot()`.

**ArchUnitNET** alternative (`ArchUnitNET.xUnit`): `new ArchLoader().LoadAssemblies(...).Build()`,
`Types().That().ResideInNamespace("Notes.Domain").Should().NotDependOnAny(Types().That().ResideInNamespace("Notes.Infrastructure")).Check(Architecture)`.
Check the `ResideInNamespace` overloads against the installed version.

`commands.arch_test`: `dotnet test tests/Architecture.Tests --no-restore`.

## 13. Pitfalls

- Restore needs network (and maybe feed credentials); keep it out of the gate.
  `--locked-mode` fails if `packages.lock.json` is stale — that is a dependency
  step problem, not a code problem.
- `dotnet watch` / `dotnet test --watch`-style loops never end — forbid.
- Exclude from every layer's `owns` and from greps: `**/bin/**`, `**/obj/**`,
  `**/*.g.cs`, `**/*.g.i.cs`, `**/*.Designer.cs`, `**/*.generated.cs`,
  `**/Migrations/**` (EF; owned by the persistence layer only if the repo edits
  them by hand — normally generated by `dotnet ef migrations add`),
  `**/Properties/launchSettings.json`, `**/TestResults/**`.
- Source generators emit into `obj/` — never edit; change the input.
- `Nullable` disabled in a project makes `!`/null checks meaningless; read
  `<Nullable>` before writing nullability rules.
- `InternalsVisibleTo` lets tests reach internals — fine; it is not a layer
  permission.
- A running app (`dotnet run`) can lock `bin/` on Windows → build fails with
  MSB3026/MSB3027; stop the app, don't retry blindly.
- Terminal logger (.NET 9+ default) redraws lines; for agent-readable output
  add `-tl:off` only if the logs are unreadable.

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths, drop checks for roles the repo
does not have, and run each once against the exemplar slice before committing
it — a check that hits the conforming exemplar is wrong. The comment above each
command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps
`grep` from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.(cs|csproj)$' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# persistence / web framework in Domain or Application
sel '<Domain>/|<Application>/' | xargs grep -nE 'using Microsoft\.(EntityFrameworkCore|AspNetCore)|DbContext|DbSet<|IQueryable<|HttpContext|IActionResult|IResult\b' /dev/null
# project reference pointing outward (Domain/Application referencing Infrastructure or Api)
sel '<Domain>/.*\.csproj$|<Application>/.*\.csproj$' | xargs grep -nE 'ProjectReference.*(Infrastructure|Api|Web)' /dev/null
# port declared in the adapter project
sel '<Infrastructure>/' | xargs grep -nE '^\s*(public|internal) interface I[A-Z]\w*(Repository|Gateway|Client|Store)\b' /dev/null
# serialization / ORM attributes on domain types
sel '<Domain>/' | xargs grep -nE '\[(JsonPropertyName|Table|Column|Key|Required|StringLength)' /dev/null
# infrastructure exception escaping the adapter
skip '<Infrastructure>/|\.Tests/' | xargs grep -nwE 'DbUpdateException|SqlException|HttpRequestException' /dev/null
# string-matched error
printf '%s\n' "$F" | xargs grep -nE '\.Message *(==|!=)|\.Message\.(Contains|StartsWith)\(' /dev/null
# catch-all swallow / rethrow losing stack
printf '%s\n' "$F" | xargs grep -nE 'catch *\((System\.)?Exception\b|throw ex;' /dev/null
# reading .Value without checking the failure case (ErrorOr / FluentResults)
sel '<Application>/|<Api>/' | xargs grep -nE '\.Value\b' /dev/null   # read each hit: guarded by IsError / IsFailed?
# clock / ids / randomness in inner layers
sel '<Domain>/|<Application>/' | xargs grep -nE 'DateTime(Offset)?\.(Now|UtcNow)|Guid\.NewGuid\(\)|new Random\(' /dev/null
# sync-over-async
printf '%s\n' "$F" | xargs grep -nE '\.Result\b|\.Wait\(\)|async void' /dev/null
# escape hatches
printf '%s\n' "$F" | xargs grep -nE 'null!|default!|\bdynamic\b|#nullable disable|#pragma warning disable' /dev/null
```

Repo scope (reported as new-vs-baseline against "Known deviations"):

```bash
# adapters constructed outside the composition root
rg -n 'new \w+(Repository|Client|Gateway)\(' --glob '*.cs' --glob '!**/Program.cs' --glob '!**/DependencyInjection*.cs' --glob '!**/*.Tests/**'
# static service locator
rg -n 'ServiceLocator|IServiceProvider' <Domain> <Application>
# test projects referenced by production projects
rg -n 'ProjectReference.*\.Tests' --glob '*.csproj' --glob '!**/*.Tests/**'
```

## 15. Platform UI rules

n/a for API / worker / library services. When the package is a UI app:

- **MAUI**: pages and XAML are `kind: view` (bindings only, no logic in
  code-behind beyond `InitializeComponent`); `ViewModel`s (CommunityToolkit.Mvvm
  `[ObservableProperty]`, `[RelayCommand]`) are `kind: presentation` and call
  application handlers, never `DbContext` or HTTP clients. Navigation
  (`Shell.Current.GoToAsync`) behind an `INavigationService` port or in the
  view-model, never in a handler. Platform code under `Platforms/<os>/`, not
  `#if ANDROID` inside view-models.
- **Blazor**: `.razor` components are `kind: view` (render parameters, raise
  `EventCallback`s); a code-behind/state class or presenter is
  `kind: presentation`. No `HttpClient` / `DbContext` injected into components;
  `NavigationManager` only in presentation, never in application handlers.
  JS interop behind a port.
