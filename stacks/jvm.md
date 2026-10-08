# Stack pack: JVM (Java, Kotlin)

`project.stack: jvm` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `gradlew` + `gradle/wrapper/gradle-wrapper.properties` | Gradle (wrapper pins the version) |
| `settings.gradle(.kts)` | Gradle build; `include(":a", ":b")` lists subprojects |
| `build.gradle(.kts)` | per-project build; `kotlin("jvm")` / `org.jetbrains.kotlin.jvm` = Kotlin, `java` / `java-library` = Java |
| `gradle/libs.versions.toml` | version catalog — dependencies are added here |
| `buildSrc/`, `build-logic/` | convention plugins (shared config lives there) |
| `pom.xml` (+ `mvnw`, `.mvn/`) | Maven; `<modules>` lists submodules |
| `com.android.application` / `com.android.library` plugin | Android — different test/compile tasks |
| `src/main/kotlin` vs `src/main/java` | language per module (mixed is common) |

Workspace (→ `workspace`): Gradle multi-project / Maven multi-module split by
layer (`:domain`, `:application`, `:adapters:web`, `:app`) is ONE hexagon —
single-package manifest. Split by service (`services/orders`, `services/billing`,
each with its own layers) → workspace form, one package per service.

`project.language`: "Java <n>" from `java { toolchain { languageVersion } }` /
`<maven.compiler.release>`; "Kotlin <n>" from the Kotlin plugin version.
Frameworks: `spring-boot`, `spring-modulith`, `quarkus`, `micronaut`, `ktor`,
`jakarta.*`, `hibernate`, `spring-data-jpa`, `jooq`, `exposed`, `koin`,
`kotlinx.coroutines`, Android/Compose.

## 2. Commands

| Build | `run` | `exec` | `add_dependency` | `test_all` |
|---|---|---|---|---|
| Gradle | `./gradlew` | — | no CLI: add to `gradle/libs.versions.toml` + the module's `dependencies {}` | `./gradlew test` |
| Maven | `./mvnw` (or `mvn` if no wrapper) | — | no CLI: add `<dependency>` to the module `pom.xml` (version in parent `<dependencyManagement>`) | `./mvnw -q test` |

Real commands: CI workflow, `Makefile`/`justfile`, custom Gradle tasks
(`./gradlew tasks --all`), Maven profiles (`-P`). Use the wrapper, never a
system `gradle`/`mvn` when a wrapper exists.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| Gradle (Java and/or Kotlin JVM) | `./gradlew classes testClasses` | `compile-guard` |
| Gradle, one subproject | `./gradlew :<proj>:classes :<proj>:testClasses` | `compile-guard` |
| Maven | `./mvnw -q test-compile` | `compile-guard` |
| Android | the variant's unit-test compile task (find it with `./gradlew :app:tasks --all`, e.g. `compileDebugUnitTestKotlin`) | `compile-guard` |

- `testClasses` depends on `compileTestJava` and `compileTestKotlin`, so it
  compiles test code in both languages; `assemble`/`build` are slower
  (`build` also runs tests).
- Unqualified task names run in every subproject that has them.
- Add `--offline` only if the repo's CI or docs use it; the first run needs
  the network to fetch the wrapper distribution and dependencies.
- kapt/KSP/annotation processors (MapStruct, Dagger, Room) run in this gate.

## 4. Targeted tests

| Build | `test_targeted` | `test_target_hint` |
|---|---|---|
| Gradle | `./gradlew {project}:test --tests '{filter}' --rerun` | "{project} = the Gradle path, e.g. :notes-domain (empty for a single-project build: `:test` is the root project); {filter} = fully qualified class or Class.method, wildcards allowed: '*NoteTest'" |
| Maven | `./mvnw -q test -pl {project} -am -Dtest='{filter}' -Dsurefire.failIfNoSpecifiedTests=false` | "{project} = module dir, e.g. notes-domain; {filter} = ClassName or ClassName#method" |

- Gradle marks an unchanged `test` task UP-TO-DATE / FROM-CACHE and runs
  nothing; `--rerun` (built-in task option, Gradle 7.6+) forces execution.
  Older Gradle: `cleanTest test --tests …`.
- Never `--continuous` / `-t` (watch mode).
- Maven `-pl` without `-am` resolves sibling modules from `~/.m2` (stale);
  `-am` rebuilds them, `failIfNoSpecifiedTests=false` stops the filter failing
  in modules with no match.

## 5. Red stub

A missing class/method is a compile error — not a valid RED. RED means the
test compiles, runs, and fails for the expected reason. Declare it with the
final signature and return a typed placeholder (`null`-safe default, empty
collection, dummy value) so the failure is an assertion. A not-implemented
throw is acceptable only when the test output names that stub as the cause.

| Language | Preferred stub | Acceptable when the failure names it |
|---|---|---|
| Kotlin | return a dummy value of the declared type | body `TODO()` (throws `kotlin.NotImplementedError`) |
| Java | return a dummy value / `Optional.empty()` / `List.of()` | `throw new UnsupportedOperationException("not implemented");` |

`testing.red_stub`: "declare the class and member with the final signature returning a typed placeholder (dummy value / empty); `TODO()` (Kotlin) / `throw new UnsupportedOperationException(\"not implemented\")` (Java) acceptable when the failure names it"

Trap: `assertThrows(RuntimeException.class, …)` / `assertThrows<Exception>`
pass against the Java stub; assert the specific domain exception. (Kotlin's
`NotImplementedError` is an `Error`, so `Exception` assertions do fail.)

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| mirrored source set | `src/test/{java,kotlin}/<same package>/` | `mirrored-tree` | `<module>/src/test/kotlin/<package path>/<Type>Test.kt` |
| extra source sets | `src/integrationTest/`, JVM Test Suites (`testing { suites { … } }`) | `mirrored-tree` (second runner/task) | `<module>/src/integrationTest/...` |
| test fixtures | `java-test-fixtures` plugin, `src/testFixtures/` | — | shared fakes live here |

Frameworks: JUnit 5 (`@Test`, `@Nested`, `@DisplayName` → `user-facing`),
Kotest (`StringSpec`/`FunSpec` names = sentences), AssertJ, Strikt.
Ownership: the layer owns both trees for its package, e.g.
`["notes-domain/src/main/**", "notes-domain/src/test/**"]` in a module-per-layer
build, or `["src/main/kotlin/com/acme/notes/domain/**", "src/test/kotlin/com/acme/notes/domain/**"]`
in a single module. Raise `max_files` to 4 for Java (interface + impl + config + test).

## 7. Doubles & spy technique

- Harness default: hand-written fakes implementing the port interface,
  declared as the port type (`val repo: NoteRepository = InMemoryNoteRepository()`),
  ideally in `src/testFixtures/` so every module's tests share them.
- Stack norms: Mockito (`@Mock`, `when(...)`), MockK (`mockk<T>()`, `every {}`),
  Spring `@MockitoBean` (Boot 3.4+; `@MockBean` before). If ports are mocked
  everywhere, record `doubles.style: mocking-framework` and flag.
- Testcontainers / `@DataJpaTest` / WireMock are adapter-test tools.

`testing.spy_technique`: "`Mockito.spy(real)` (Java) / MockK `spyk(real)` (Kotlin) — calls through to the real object; observe with `verify`"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| unchecked domain exceptions | `extends RuntimeException`, `: RuntimeException(`, `throw ` | `exceptions (DomainException hierarchy)` | `false` | `exception subtype` |
| Kotlin sealed results | `sealed (class\|interface) \w*(Result\|Error)` | `sealed result type` | `true` | `when` over sealed subtypes (exhaustive) |
| Arrow | `arrow.core.Either`, `Raise<`, `either {` | `Either<DomainError, T> (Arrow)` | `true` | `sealed DomainError subtype` |
| kotlin.Result | `Result<`, `runCatching` | `kotlin.Result<T>` (Throwable only) | `false` | `exception type` |
| Vavr (Java) | `io.vavr.control.Either`, `Try` | `Either<DomainError, T> (Vavr)` | `true` | `error subtype` |

HTTP edge: Spring `@RestControllerAdvice` + `@ExceptionHandler`,
`ProblemDetail` (Spring 6), `ResponseStatusException` — driving adapter only.

Typical `traps`:

- "`runCatching` in coroutines swallows `CancellationException`"
- "`DataAccessException` / `EmptyResultDataAccessException` / `PersistenceException` escaping the adapter"
- "`ResponseStatusException` thrown from a service"
- "`catch (Exception e)` wrapping everything in a generic RuntimeException"
- "`Optional.get()` / `!!` instead of handling absence"
- "`else ->` branch in a `when` over a sealed error type (defeats exhaustiveness)"

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| Jakarta Bean Validation / Hibernate Validator | `jakarta.validation`, `@NotNull`, `@Valid`, `@Validated` | request DTOs in the driving adapter; on domain types or `@Entity` = leakage |
| Konform (Kotlin) | `Validation<`, `io.konform` | driving adapter, or application input |
| `require(...)` / factory methods | `init { require(` | domain invariants |

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["Kotlin `!!`", "unchecked `as` casts", "`@Suppress(\"UNCHECKED_CAST\")` / `@SuppressWarnings(\"unchecked\")`", "Java raw types and `(T)` casts", "`Optional.get()`", "`Object`/`Any` parameters", "`lateinit` in domain types", "reflection"]

## 11. Hexagon mapping hints

| Role | Typical appearance |
|---|---|
| domain_type | `…/domain/model/`, `:domain` module; records / data classes / value classes |
| domain_error | `…/domain/` exception hierarchy or sealed `DomainError` |
| driving_port | `application/port/in/*UseCase` interfaces + `application/service/` (Hexagonal "Get Your Hands Dirty" layout), or `*Service` classes |
| driving_adapter | `adapter/in/web/` `@RestController`, Ktor routes, messaging listeners (`@KafkaListener`) |
| driven_port | `application/port/out/*Port` interfaces (or `domain/` repositories) |
| driven_adapter | `adapter/out/persistence/` (JPA/jOOQ/Exposed), `client/` |
| test_double | `src/testFixtures/`, `src/test/**/fake/`, `InMemory*` |
| composition_root | `@SpringBootApplication` class + `@Configuration` `@Bean` methods; Ktor `Application.module()`; Koin/Dagger modules |

Component scanning (`@Service`, `@Component`, `@Repository` everywhere) spreads
the composition root across the codebase. Explicit `@Configuration` bean
methods for adapters keep it in one place — record which; scanning annotations
on domain classes are framework imports in the domain.

Typical gaps (→ `conformance.gaps`):

- `@Entity` / `@Table` / `@Id` on domain classes → domain/persistence merge.
- Spring Data `interface NoteRepository : JpaRepository<NoteEntity, UUID>` used
  directly by services → port is the framework's interface (port derived from adapter).
- `@Transactional`, `@Service`, `@Autowired` in domain types.
- Controllers using repositories directly; DTOs = entities (Jackson on `@Entity`).
- `companion object` / static singletons holding clients.

`leakage_examples`: ["@Entity / @Table / @Column", "JpaRepository", "EntityManager", "DataAccessException", "ResponseEntity", "HttpServletRequest", "@JsonProperty on domain types", "jOOQ Record types"]

`modules.unit`: "one Gradle subproject / Maven module per business module", or Spring Modulith application modules (top-level packages).

## 12. Arch tests

Module-per-layer builds already enforce direction through
`dependencies { implementation(project(":domain")) }`; ArchUnit covers
package-level rules and framework leakage. Use `api` vs `implementation`
carefully — `api` leaks transitively.

**ArchUnit** (`com.tngtech.archunit:archunit-junit5`, test scope;
`onionArchitecture()` + `@AnalyzeClasses` / `@ArchTest` verified against
tng/archunit docs). Starting point — replace packages.
`src/test/java/com/acme/notes/ArchitectureTest.java`:

```java
package com.acme.notes;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.Architectures.onionArchitecture;

@AnalyzeClasses(packages = "com.acme.notes", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    @ArchTest
    static final ArchRule dependencies_point_inward = onionArchitecture()
            .domainModels("com.acme.notes.domain.model..")
            .domainServices("com.acme.notes.domain.service..")
            .applicationServices("com.acme.notes.application..")
            .adapter("web", "com.acme.notes.adapter.in.web..")
            .adapter("persistence", "com.acme.notes.adapter.out.persistence..");

    @ArchTest
    static final ArchRule inner_layers_import_no_frameworks = noClasses()
            .that().resideInAnyPackage("com.acme.notes.domain..", "com.acme.notes.application..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("org.springframework..", "jakarta.persistence..", "com.fasterxml.jackson..");
}
```

Kotlin works identically (bytecode); the file goes in `src/test/kotlin` with
`@JvmField val` rules or keep it in Java. In multi-module builds, put it in the
`:app` module whose test classpath sees all layers. Empty layers fail the rule —
remove unused `adapter(...)` lines (ArchUnit's `withOptionalLayers(true)` exists
for this; confirm against the installed version).

Alternatives: Konsist (Kotlin-source based), Spring Modulith `ApplicationModules.of(App::class.java).verify()` for module boundaries.

`commands.arch_test`: `./gradlew test --tests '*ArchitectureTest' --rerun` /
`./mvnw -q test -Dtest=ArchitectureTest -Dsurefire.failIfNoSpecifiedTests=false`.

## 13. Pitfalls

- Gradle UP-TO-DATE / build cache hides test runs — `--rerun` (§4).
- Gradle daemon is fine; `--continuous` is not.
- First run downloads the wrapper and dependencies — wait for exit; never
  switch to a system Gradle to "fix" it.
- Exclude from `owns` and greps: `**/build/**`, `.gradle/**`, `**/target/**`
  (Maven), `out/**`, `**/build/generated/**` (kapt/KSP/annotation processors,
  OpenAPI generator, jOOQ codegen, protobuf), MapStruct `*Impl` sources if
  checked in, Android `R`/`BuildConfig`.
- DB migrations (`src/main/resources/db/migration/**` Flyway, Liquibase
  changelogs) belong to the persistence layer only.
- Spring context tests (`@SpringBootTest`) are slow and need config/DB; unit
  tests for domain/application must not start a context.
- Kotlin + Spring needs the `kotlin-spring`/`allopen` plugin for proxies;
  `final` classes break Mockito without `mockito-inline` (default since Mockito 5).

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths, drop checks for roles the repo
does not have, and run each once against the exemplar slice before committing
it — a check that hits the conforming exemplar is wrong. The comment above each
command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps
`grep` from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.(java|kt)$|build\.gradle(\.kts)?$' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# framework / persistence annotations or imports in domain
sel '<domain-dir>/' | xargs grep -nE '^import (org\.springframework|jakarta\.persistence|javax\.persistence|com\.fasterxml\.jackson)|@(Entity|Table|Column|Id|Service|Component|Autowired|Transactional|JsonProperty)\b' /dev/null
# Spring Data repository used as the port
sel '<application-dir>/|<domain-dir>/' | xargs grep -nE '(JpaRepository|CrudRepository)<' /dev/null
# web types in services
sel '<application-dir>/' | xargs grep -nE 'ResponseEntity|ResponseStatusException|HttpServletRequest' /dev/null
# persistence exceptions escaping the adapter
skip '<adapter-out-dir>/|/test/' | xargs grep -nE '\b(DataAccessException|EmptyResultDataAccessException|PersistenceException)\b' /dev/null
# catch-all / string-matched error
printf '%s\n' "$F" | xargs grep -nE 'catch \((Exception|Throwable) |\.message *(==|!=)|getMessage\(\)\.(equals|contains)\(' /dev/null
# else branch over a sealed error type (read each hit)
sel '\.kt$' | xargs grep -nE '^\s*else\s*->' /dev/null
# runCatching in coroutine code
sel '\.kt$' | xargs grep -n 'runCatching' /dev/null
# escape hatches / absence handling
printf '%s\n' "$F" | xargs grep -nE '!!|Optional\.get\(\)|\.get\(\)\s*;|@Suppress\("UNCHECKED_CAST"\)' /dev/null
# clock / ids in inner layers
sel '<domain-dir>/|<application-dir>/' | xargs grep -nE '(Instant|LocalDateTime|LocalDate)\.now\(\)|UUID\.randomUUID\(\)|System\.currentTimeMillis' /dev/null
```

Repo scope:

```bash
# component scanning on domain / application classes (composition spread out)
rg -n '@(Service|Component|Repository)\b' <domain-dir> <application-dir>
# test fixtures referenced from main
rg -n 'testFixtures|\.fake\.' --glob 'src/main/**'
```

## 15. Platform UI rules

n/a for Spring / Ktor services. Android (Jetpack Compose):

- `@Composable` functions are `kind: view`: state hoisted, parameters in and
  lambdas out; no `ViewModel` construction, repository or `Context`-driven I/O
  inside them; `remember` only for ephemeral UI state (expanded, focus).
- `ViewModel`s exposing `StateFlow<UiState>` are `kind: presentation`; they call
  use cases, never DAOs / Retrofit services; collect with
  `collectAsStateWithLifecycle()`.
- `LazyColumn` for lists, never `Column` + `forEach` over unbounded data.
- Touch targets ≥ 48dp (`Modifier.minimumInteractiveComponentSize()`);
  `contentDescription` from string resources, never literals.
- Navigation (`NavController`) in the presentation / route layer, never in use
  cases. Platform APIs (`Context`, permissions, `WorkManager`) behind ports.
