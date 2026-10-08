# Detection — reading a codebase into `harness.yml`

Read-only. Never run install, restore, build, codegen or test commands here —
reading files is enough. Sweep 0 first; then Sweeps 1–7 in parallel, per
package. Each fills a section of the manifest. Where detection is ambiguous,
record both candidates and ask at the confirm step rather than guessing.

The stack pack (`stacks/<stack>.md`) holds the per-language signals, idioms and
recipes. This file holds the procedure and the cross-stack signals; where the
pack is more specific, the pack wins.

---

## Sweep 0 — inventory, stack, workspace

Fills `project`, `workspace`.

1. **List manifests**, skipping `node_modules`, `vendor`, `bin`, `obj`,
   `target`, `dist`, `build`, `.venv`, `.git`:

   | Stack id | Markers |
   |---|---|
   | `typescript` | `package.json` + `tsconfig*.json`; workspaces in `package.json` `workspaces`, `pnpm-workspace.yaml`, `nx.json`, `turbo.json` |
   | `rust` | `Cargo.toml`; `[workspace] members` |
   | `go` | `go.mod`; `go.work` (multi-module) |
   | `dotnet` | `*.sln` / `*.slnx`, `*.csproj` / `*.fsproj`, `Directory.Build.props`, `Directory.Packages.props`, `global.json` |
   | `python` | `pyproject.toml`, `uv.lock`, `poetry.lock`, `requirements*.txt`, `setup.cfg`; `[tool.uv.workspace]` |
   | `jvm` | `build.gradle(.kts)` + `settings.gradle(.kts)` `include(...)`, `pom.xml` `<modules>` |
   | IaC | `*.tf`, `Chart.yaml`, `Pulumi.yaml`, `*.bicep`, `kustomization.yaml`, CloudFormation templates |

   Anything else → `<other>`, filled from `stacks/_template.md`.

2. **Pure IaC → stop** (see SKILL step 0). IaC beside app code → add its paths
   to every layer's `excludes` and note it.
3. **Packages.** A package is a unit that builds and tests on its own and holds
   application code: a workspace member, a Go module, a .NET solution folder of
   projects forming one service, a Gradle subproject that is an app. Several →
   workspace mode. Within one package, several projects/crates/modules that
   are *layers of the same hexagon* (a .NET `Domain`/`Application`/
   `Infrastructure`/`Api` set, a cargo workspace split by layer) are **one**
   package with module boundaries, not a workspace.
4. **Prefix** per package: short, unique, lowercase, from the directory name
   (`api`, `web`, `billing`). No prefix may be a prefix of another followed by
   `-` (`api` and `api-admin` collide in agent names like `api-admin-builder`).
5. **Kind** per package: `service` (HTTP/gRPC/queue server), `web-app`,
   `mobile-app`, `cli`, `worker`, `library` (published or consumed, no entry
   point), `fullstack` (one package serving UI and API). From entry points:
   `main`, `Program.cs`, `cmd/`, `bin` in `package.json`, `app/` routes, Expo
   config, `[lib]` only.
6. **Shape** from kind: `service | web-app | mobile-app | worker | fullstack` →
   `full`; `cli` → `minimal`; a worker with one handler and no use-case layer →
   propose `minimal` and ask; `library` → `library`. Mark the roles the shape
   removes `absent: by-shape` — `minimal` keeps the driving port explicit even
   when use cases are plain functions; `library` has no driving adapter and no
   composition root.

---

## Sweep 1 — commands, hygiene, carried rules

Fills `commands`, `carry_forward`, `dev_run`, `emit.memory_file`.

| Signal | Where |
|---|---|
| Package manager / runner | the lockfile wins over any README: `yarn.lock`, `bun.lock(b)`, `pnpm-lock.yaml`, `package-lock.json`, `Cargo.lock`, `uv.lock`, `poetry.lock`, `go.sum`, `packages.lock.json`, `gradle/wrapper/` |
| Scripts | `package.json` `scripts`, `Makefile`, `justfile`, `Taskfile.yml`, `Cargo.toml` aliases (`.cargo/config.toml`), `pyproject.toml` scripts, `Directory.Build.targets` |
| CI | `.github/workflows/*`, `.gitlab-ci.yml`, `azure-pipelines.yml` — the commands CI runs are the commands that must pass, with the flags CI uses |

**Gate.** The fastest *total* correctness check, and it **must compile test
code**. Use the pack's gate; typical:

| Stack | Gate | Why not the obvious one |
|---|---|---|
| typescript | the repo's `typecheck` script / `tsc --noEmit -p <tsconfig incl. tests>` | a build config that excludes `*.test.ts` misses test type errors |
| rust | `cargo check --all-targets` | plain `cargo check` skips `#[cfg(test)]` and `tests/` |
| go | `go vet ./...` | `go build ./...` does not compile `_test.go` |
| dotnet | `dotnet build <sln> --no-restore -warnaserror` (if the repo builds warning-clean) | the solution must include the test projects; `--no-restore` keeps the gate offline |
| python | the repo's type checker (`mypy`, `pyright`) over src **and** tests | no compile step; without a checker the gate is the test run — say so |
| jvm | `./gradlew compileTestJava` / `compileTestKotlin`, `mvn -q test-compile` | `compileJava` skips tests |

Several checks → `gate` is a list, run in order (e.g. typecheck, then lint if
CI blocks on it).

**Targeted tests.** Non-interactive and **uncached**, with exactly the target
token(s) the schema defines:

| Stack | Example | Watch for |
|---|---|---|
| jest | `yarn jest --watchAll=false --no-coverage {path}` | watch mode in a TTY |
| vitest | `pnpm vitest run {path}` | `vitest` alone watches |
| cargo | `cargo test {filter}` | — |
| go | `go test -count=1 {package} -run '{filter}'` | without `-count=1` a cached pass is reported as a run |
| dotnet | `dotnet test {project} --no-restore --filter '{filter}'` | — |
| pytest | `uv run pytest {path} -q` | `-p no:cacheprovider` only if `--lf`/`--ff` is configured |
| gradle | `./gradlew test --tests '{filter}'` | up-to-date check skips tests: add `--rerun` (Gradle ≥ 7.6) or `cleanTest` |

**Hygiene.** Keep the `2>&1` rule. Add the pinned-manager rule. Add a wait-for-
exit rule for anything slow. Add the working directory per package in workspace
mode.

**Carry forward.** Read `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/**`,
`.cursorrules`, `.github/copilot-instructions.md`, `.github/instructions/**`,
`CONTRIBUTING.md`, README dev sections. Quote every rule that tells an agent or
contributor what to do; do not paraphrase; drop only rules the harness itself
supersedes (and list those at confirm).

**Imported files are not carried, they are imported.** If the memory file
`@`-imports a file (`@AGENTS.md`, `@docs/agents.md`), its rules already load
every turn: do **not** copy them into `carry_forward` — the copy doubles the
context cost and drifts (a v1 trial copied `eas build` while the imported file
said `bunx eas-cli`). Keep the `@`-import line in the rendered memory file
instead. When `AGENTS.md` exists and is not imported, prefer adding the
`@AGENTS.md` import over copying its rules; ask at confirm. Only rules from
files that are **not** imported go into `carry_forward`.

**Cache rule (→ `CACHE_RULE`).** From the pack's §4 / §13: the flag that makes
the targeted run uncached (`go test -count=1`, Gradle `--rerun`), or "none of
this stack's runners cache results" when the pack says so.

**Generated memory file.** If a root `CLAUDE.md` / `AGENTS.md` is rewritten by a
framework or dev server, set `emit.memory_file: .claude/CLAUDE.md` and leave the
generated file alone.

**Dev run.** The documented local-run command, a fakes / in-memory flag if one
exists, and seeded fake logins only if the repo already documents them. Never
copy a real credential, token or connection string — reference the env var name
instead.

Never invent a command. If no gate exists, say so — the test run becomes the only
gate, and the user should know.

---

## Sweep 2 — the hexagon, the layers, ownership

Fills `architecture.hexagon`, `architecture.dependency_rule`,
`architecture.modules`, `conformance`, `layers[]`. This is the sweep that
matters; spend the time here.

**You are not detecting the architecture — it is hexagonal, fixed. You are
detecting what this repo calls each part, and how far the code is from it.**

1. **Find the seams.** List the top two or three levels of source. Then use the
   stack's seam signals:

   | Stack | Where the boundaries are |
   |---|---|
   | typescript | directories (`domain/`, `application/`, `adapters/`, `ports/`), filename suffixes (`.repository.ts`, `.use-case.ts`, `.core.ts`, `.store.ts`), path aliases in `tsconfig` |
   | rust | crates in the workspace and their `[dependencies]` on each other; `mod` trees; traits under `ports/` |
   | go | package directories; `internal/` (compiler-enforced visibility); `cmd/<app>/main.go` (composition root). **Interfaces are declared consumer-side** — the driven port is the interface in the package that *uses* it, not beside the implementation. An interface declared next to its only implementation is a port derived from its adapter |
   | dotnet | one `.csproj` per layer; **read the `<ProjectReference>` graph** — it is the compiler-enforced dependency rule. `Domain` referencing `Infrastructure`, or an `I*Repository` declared in the Infrastructure project, are gaps. `Program.cs` / `AddInfrastructure()` extension methods = composition root |
   | python | packages under `src/<pkg>/`; `Protocol` / `ABC` classes as ports; `import-linter` contracts in `pyproject.toml` / `.importlinter` if present |
   | jvm | Gradle/Maven modules and their dependencies; packages `domain`, `application`, `adapter`/`infrastructure`; Spring `@Configuration` classes = composition root |

2. **Fill the role table** for the roles the shape keeps:

   | Role | Look for |
   |---|---|
   | domain type | the type a rule is written about, free of framework / ORM / serialization annotations |
   | domain error | the failure enum / union / sentinel set / exception hierarchy the inside returns |
   | driving port | the use-case entry point the outside calls (interface, function, handler type) |
   | driving adapter | HTTP handler / controller, UI component or hook, CLI command, queue consumer |
   | driven port | the interface the inside declares for a capability it needs |
   | driven adapter | the implementation with a real technology (DB, HTTP client, filesystem, queue) — **including an in-memory adapter that production config can select** (a fakes / demo mode flag) |
   | test double | a test-only fake / stub / spy of a driven port, never reachable from production config |
   | composition root | the one place concrete adapters are constructed |

   A role you cannot find is a **gap**, not a blank.

   **In-memory adapters are not test doubles.** An in-memory implementation that
   the composition root selects under a production config switch (fakes mode,
   `*_IN_MEMORY_*=true`, a demo profile) is a driven adapter: it lives with the
   adapters, follows adapter rules, and the composition root may construct it.
   `testing.doubles.location` points only at test-only fakes. The composition
   root may reference in-memory adapters but never the test-doubles folder; an
   import from that folder into production code is a `conformance` gap.

3. **Assess conformance.** Check each `hexagonal-architecture` anti-pattern and
   record every hit with its paths:

   - framework / ORM / serialization type or annotation in a domain type
     (`[JsonPropertyName]`, `[Table]`, `sqlx::FromRow`, `json:"..."` struct tags
     on a domain struct, `@Entity`, `__typename`);
   - infrastructure error crossing a port (`*pq.Error`, `DbUpdateException`,
     `AxiosError`, `sqlx::Error`);
   - **port derived from its adapter** — `ReturnType<typeof createRepo>`, an
     interface declared beside its only implementation, an `IRepo` in the
     Infrastructure project;
   - **no translation** — the wire / row schema used directly as the domain type;
   - business rule in a driving adapter;
   - driving adapter calling a driven port directly, skipping the use case;
   - adapter constructed outside the composition root — including Go
     package-level vars / `init()` wiring and .NET static service locators;
   - **anemic domain** — types with no behaviour, use cases that only forward.

   Set `conformance.level`: `conforming`, `partial`, `greenfield`,
   `non-conforming`. The last three anti-patterns look like clean code; check
   them explicitly rather than concluding "looks hexagonal" from directory names.

4. **Pick the exemplar slice** — the feature that best conforms and is
   representative. Read it end to end and verify it against the same list.
5. **Derive the layers.** For each layer record:
   - `kind` — from the **kind mapping** table below. **Exactly one
     `kind: domain` layer, first in the chain, `owns_tests: true`.** It owns the
     types, the rule functions and the domain error. If the repo spreads those
     across directories, the domain layer owns all of them; if it has none, it
     owns the path where they will live. Infer every other kind and mark
     inferred ones for confirmation;
   - `owns` globs and `excludes` — see ownership below;
   - what it may and may not import, read from the exemplar's actual imports
     (→ `IMPORT_TABLE`, see "Architecture slots" below);
   - the contract it exposes (exported type, factory / constructor signature,
     return shape);
   - `max_files` — count it, don't assume it. In the exemplar slice, count the
     files one unit of work in this layer touches together: the file, its
     test, its registration, and one file **per locale** or per platform
     variant. A screen + view-model test + `en` and `fr` locale files is 4;
     .NET interface + class + DI registration + test file is 4–5. Use that
     count (minimum 3). A cap below the real unit of work forces split
     dispatches that each leave the layer half-built;
   - `optional`, `depends_on`, `parallel_with` (only for genuinely disjoint
     layers whose shared names the orchestrator can fix up-front; when in
     doubt, none).
   **Kind mapping.** The kind selects the rule pack the agent receives; a wrong
   kind gives the agent the opposite rules (a component layer given
   `presentation` was told to hold form state; a view-model given
   `driving-adapter` got HTTP retry and dead-letter rules). Check every layer
   against this table before the confirm step and list any layer whose kind
   you inferred:

   | Layer does | `kind` | Never |
   |---|---|---|
   | entities, value objects, rule functions, the domain error | `domain` | — |
   | use cases / cores / application services / command handlers | `application` | — |
   | repositories, API clients, storage, queues, mappers from wire to domain | `driven-adapter` | — |
   | receives outside input over a transport: HTTP handler / controller, route loader / action, CLI command, queue consumer, scheduled job, deep-link / push handler | `driving-adapter` | for view-models or components |
   | holds shared app state behind a state port (MobX / Zustand / Redux stores, observable caches) | `state` | — |
   | view-model / presenter / UI-state hook: UI state, calls use cases, maps errors to messages | `presentation` | `driving-adapter` |
   | UI components / pages / templates that render props and forward events | `view` | `presentation` |
   | composition root, DI, providers, app bootstrap | `wiring` | — |
   | none of the above (scripts, codegen glue) | `other` | — |

   A frontend's component layer is always `view`. A harness without a
   presentation layer (components call use cases through hooks directly)
   still uses `view` for the components and records the missing presentation
   model as a gap, or maps the hooks as `presentation` if they are separate
   files.

   **State port ownership.** When a `state` layer runs `parallel_with` a
   `driven-adapter` layer, each parallel half owns the port **it implements**:
   the state agent owns the state port (`ports/<domain>State.port.ts` or the
   repo's equivalent), the adapter agent owns the repository / client port. A
   port owned by the other half of a parallel pair is edited by an agent that
   is not running when its implementer needs it. Put the port glob in the
   implementer's `owns` and in the other's `forbidden` with that owner. If the
   two run sequentially, the port may stay with whichever runs first.

6. **Derive the dependency rule** as one sentence in the repo's vocabulary,
   a specialisation of "dependencies point inward". If the sentence would
   weaken it, that is a gap, not the rule.
7. **Modules.** One hexagon per business module (a crate, a `.csproj`, an
   `internal/<module>/` tree, a workspace package per area) →
   `architecture.modules.enabled: true` with the unit.

### Architecture slots (from the exemplar, not the pack)

Fill these from what the exemplar slice and the shared directories actually
contain; the pack's §11 says where to look. Each is rendered into the
`architecture` skill.

- **`IMPORT_TABLE`** — per layer: may import / must never import, read from the
  exemplar's real import lines (e.g. "use cases: domain, ports, `neverthrow`;
  never `react-native`, `expo-*`, `AppState`, `Platform`, `Linking`, `File`,
  `setTimeout`"). One row per layer kind present.
- **`SHARED_PORTS_TABLE`** — capability ports shared across features: clock,
  id generator, scheduler / timer, alerter / notifier, logger, token provider.
  Grep the ports and shared directories for them; for each record the port,
  the real implementation, the test fake, and their paths (e.g. `Clock` →
  `systemClock` / `fixedClock`; `IdGenerator` → `uuidV7IdGenerator` /
  `sequentialIds`; `Scheduler` → `timeoutScheduler` / `manualScheduler`;
  `Alerter` → `createFakeAlerter`). Inner-layer calls that bypass an existing
  shared port (`new Date()`, `Date.now()`, `crypto.randomUUID()`,
  `setTimeout`) are gaps. None found → the row says so and new code adds the
  port before first use.
- **`PORT_RULES`** — what a port may contain in this repo: declared as an
  interface / trait, never derived from an implementation
  (`ReturnType<typeof create…>`); no infrastructure types in signatures
  (`FormData`, picker assets, validator schema types, DTOs, transport errors,
  observable collections); named after the capability, not the technology;
  which cross-cutting providers are ports and not use cases (e.g. an access-
  token provider).
- **`STATE_RULES`** (when a `state` layer exists) — stores implement a state
  port and hold getters / setters only (no dedupe, ordering, cascade or derived
  rule); the operation-status shape the repo uses (`OperationState`,
  `error: <Domain>Error | null`); whether the context exposes setters to the UI
  (it should not); one minimal store template from the exemplar.
- **`REFERENCE_SLICES`** — plural. The exemplar plus any other slice that
  exemplifies something the exemplar lacks (a native-module adapter, a
  polling scheduler, auth); each with one line on **what it exemplifies**.
  Every path must exist and conform, or carry its deviations inline.

### Ownership (mechanical, required)

Compute, for every layer, `files(owns) − files(excludes)` against the real tree.
No file may be in two layers' sets. Resolve by narrowing globs or adding
`excludes`, never by a precedence rule. Typical carve-outs:

- tests beside code owned by the same layer (Go `*_test.go`, colocated
  `*.test.ts`) need nothing; tests owned by a *different* agent need an exclude;
- a sibling layer's subdirectory (`internal/note/postgres/**` under
  `internal/note/**`);
- generated code (`*.g.cs`, `*_gen.go`, `__generated__/`, `Migrations/`) — owned
  by nobody; exclude it and say who regenerates it;
- IaC, docs, fixtures.

### If there is no hexagon

Set `conformance.level: non-conforming`, map each role to the path where it
*will* live, record the whole current structure as gaps. Say plainly at confirm
that the user is agreeing to a migration. If they do not want one, stop.

---

## Sweep 3 — testing

Fills `testing`, `layers[].owns_tests`.

| Question | How to answer |
|---|---|
| Where do tests live? | Glob the pack's test patterns (`*.test.ts`, `*_test.go`, `tests/*.rs` + `mod tests`, `*.Tests.csproj`, `test_*.py`, `src/test/java`). Set `placement` and a literal `path_formula` |
| Which layers are tested? | Cross-reference test paths with layer globs. Do not promote an untested layer without asking |
| Are tests written first? | Do tests assert behaviour or mirror implementation? Check history on the exemplar if cheap (`git log` is read-only) |
| Doubles | Glob `*fake*`, `*stub*`, `*mock*`, `InMemory*`, `mocks/`, `testdata/`. Record style and location. Drop any hit the composition root selects under production config (fakes mode): that is a driven adapter, not a double. `doubles.location` must name test-only fakes |
| Mocking framework? | Moq, NSubstitute, FakeItEasy, gomock / mockery, testify/mock, unittest.mock, Mockito, jest.mock / vi.mock. If used for ports, set `doubles.style: mocking-framework` and record it as a **divergence** for the confirm step — hand-written fakes typed as the port are the harness default for new ports; never silently change existing tests |
| Spy technique | From the pack: how to observe a call without replacing the collaborator (call-through spy, recording decorator over the port, hand-written recording fake) |
| Red stub | From the pack: the test compiles, runs and fails for the expected reason. Preferred stub returns a typed placeholder (zero value / `default`) so the failure is an assertion; a not-implemented throw/panic (`NotImplementedException`, `todo!()`, `TODO()`) only when the test output names that stub as the cause. **Choose per return shape:** when the pack's §5 gives a map (sync Result / plain value, async, hook, component, state), write `testing.red_stub` as a map with only the shapes the repo's layers return, and note which key each layer renders (`domain` → `sync`, `application` / `driven-adapter` → `async`, `presentation` → `hook`, `view` → `component`, `state` → `state`). One sentence for every layer is wrong whenever the layers return different shapes |
| Naming | Read ten test names: user-facing or technical |

At least one layer — the domain layer — has `owns_tests: true`. If the repo has
no tests at all, raise it at confirm.

---

## Sweep 4 — errors and validation

Fills `architecture.errors`, `architecture.validation`,
`architecture.type_escape_hatches`.

Grep the inner layers (domain, application) — not the edges — for:

| Stack | Failure as value | Failure as throw | Validation |
|---|---|---|---|
| typescript | `neverthrow`, `Result`, `Either`, `effect`, `{ ok: false }` unions | `throw`, `Promise.reject` | zod, ArkType, valibot, yup, class-validator |
| rust | `Result<_, DomainError>`, `thiserror` enums | `panic!`, `unwrap()`, `expect()` outside tests; `anyhow` in inner layers | `validator`, newtype constructors, `serde` at the edge |
| go | `(T, error)`, sentinel `var ErrX = errors.New`, typed errors, `errors.Is/As`, `%w` wrapping | `panic`, `log.Fatal` in inner packages | go-playground/validator struct tags, hand-written `Validate() error` |
| dotnet | ErrorOr, OneOf, FluentResults, `Result<T>` records | `throw`, custom exception hierarchies, `ProblemDetails` mapping | FluentValidation, DataAnnotations, MediatR pipeline behaviours |
| python | `returns`, result dataclasses | `raise`, exception hierarchies | pydantic, attrs validators, marshmallow |
| jvm | `Either` (Vavr, Arrow), sealed result types | exceptions, `@ControllerAdvice` | Bean Validation (`@Valid`, `@NotNull`), Konform |

- Decide **values or exceptions in the layers that matter**. A repo may throw at
  the edge and return values inside; record that precisely — it is the rule the
  reviewer enforces. Set `never_throw`.
- `discriminate_by`: kind field, enum variant, `errors.Is / errors.As`,
  exception subtype, `switch` on `ErrorOr` type.
- `classification`: where each infrastructure failure becomes a domain error
  (`sql.ErrNoRows → ErrNotFound` in the postgres adapter; HTTP 404 → `NotFound`
  in the client adapter).
- `traps`: library footguns the reviewer greps for (`.map(() => ok())` nesting a
  Result; Go `err` shadowing in `if err := ...`; comparing errors with `==`
  after wrapping; `ErrorOr` implicit conversions hiding a missed case).
- Validation `placement` is a boundary rule: where parsing happens vs where
  invariants are enforced.
- `type_escape_hatches` from the pack (`as`, `any`, `!`, `dynamic`, unchecked
  type assertions, `unwrap()`).
- **Idioms and traps with examples** from the pack's §8 (→
  `ERROR_COMPOSITION_IDIOMS`, `ERROR_BOUNDARY_RULES`, `TRAPS_WITH_EXAMPLES`):
  keep the combinators / helpers the repo uses or will need, rewritten with the
  repo's own types; the boundary rule saying where conversion helpers
  (`fromPromise`, `fromThrowable`, `try`/`catch`) may appear; the before/after
  trap examples, adding any trap the repo's own code shows. If the repo
  declares errors both as plain unions and as `Error` subclasses with a `kind`,
  ask which one new code uses per domain — never both in one domain.

---

## Sweep 5 — arch tests

Fills `verify.arch_tests`, `commands.arch_test`.

- **Existing:** NetArchTest / ArchUnitNET test projects; `.go-arch-lint.yml`,
  depguard in `.golangci.yml`; `.dependency-cruiser.*`, `eslint-plugin-boundaries`
  / `import/no-restricted-paths` config; `import-linter` contracts; ArchUnit tests;
  Rust deny tests or `cargo-deny` bans on internal crates. → `status: existing`,
  record tool, path, the rules it encodes, and the command.
- **None:** propose `status: generate` with the pack's recipe: tool, path, the
  exact files, and one rule per dependency-rule specialisation. Note any package
  it must add — that is an install and needs confirmation. Gaps with
  disposition `migrate` become named exceptions.
- The user may decline → `status: none`; the reviewer's greps remain.

**Reviewer greps** (→ `verify.mechanical_checks`, `STACK_REVIEW_GREPS`). Take
the pack's §14, substitute the repo's real paths, suffixes and wire-format
markers, drop checks for roles the repo lacks, and add the repo's own (an old
harness's reviewer greps — see Sweep 7 — come first). Run each **read-only**
against the exemplar slice: a hit on conforming code means the pattern is
wrong; fix it before it ships. Record each with `scope: diff` (it runs over
`$F`, the changed files — never over the whole source tree) or `scope: repo`
(whole tree, compared against "Known deviations"). Every check has a
`description` saying what it catches.

---

## Sweep 6 — optional features (cheap, last)

| Flag | Detect by |
|---|---|
| `skills.optional.i18n` | an i18n library + locale files; record the namespace rule and the missing-translation marker (→ `I18N_MISSING_MARKER`): what the repo puts in a locale it cannot translate yet (`"TODO: translate"`, the source string, an empty string). Every key exists in every locale; the marker, never an absent key, signals the gap |
| `skills.optional.component_design` | atoms/molecules tree, Storybook stories; `preview` = `storybook` only if `*.stories.*` and a Storybook config exist, else `none`; `platform` = `react-native` for Expo / RN, else `web` (selects pack §15) |
| `skills.optional.presentation_model` | view-models / presenters between UI and use cases |
| `architecture.modules.enabled` | see Sweep 2 step 7 |
| `plan.impact_scout` | a `.codegraph/` directory |
| `plan.spec.*` | a PRD / spec file, especially a submodule; its path. The spec is read-only to the harness — nothing emitted writes, commits or pushes it. **Enable only when the file exists in the working tree.** A submodule that is declared in `.gitmodules` but not initialised (empty directory) means `enabled: false` by default: say so at confirm, show the init command, and never run it during detection. An agent whose file is absent is a trap |
| `plan.depth` | `full` over ~30k LOC or with a spec; else `single` |
| `emit.cursor_compat` | **default `false`.** Propose `true` only when `.cursor/` is actually used for agents — `.cursor/rules/**` or `.cursor/agents/**` present — **and** the user confirms they run these agents in Cursor. A bare `.cursor/` (settings, MCP config) is not enough: `true` adds a Startup section to every agent that re-reads preloaded skills |
| `emit.always_on_skills` | propose `error-handling` plus every enabled optional skill the main agent edits inline: `i18n`, `presentation-model`, and `component-design` for frontends. An old harness's `@`-imports (Sweep 7) are a strong signal. Show the context cost at confirm: line count of each rendered skill, summed, loaded on every turn |
| `emit.runner_model` | an existing harness's gate / test-runner (runner) agents with a `model:` override other than `inherit` → carry it. Else empty |

---

## Sweep 7 — an existing harness (when target `.claude/` exists)

Fills `emit.runner_model`, `emit.always_on_skills`
hints, extra `verify.mechanical_checks`, and the **lost-rules inventory** the
confirm step needs. Read-only.

1. **Inventory.** List every file under `.claude/` (agents, skills, hooks,
   commands, `settings.json`, `settings.local.json`) and the memory file.
2. **Settings.** Record `settings.json` and `settings.local.json` verbatim
   (`enabledPlugins`, `permissions`, `hooks`, `env`, `model`). They are carried
   forward unchanged; the receipt hook, if opted in, is merged into them.
3. **Runner model.** A `model:` other than `inherit` on the old gate /
   test-runner / typecheck agents → `emit.runner_model`.
4. **Spec writers.** An old agent that writes, commits or pushes the spec / PRD
   is not carried: list it in the lost-rules inventory as **dropped** (the
   harness reads the spec only) and remove it only with the user's consent.
5. **Always-on.** Skills the old memory file `@`-imports → proposed
   `emit.always_on_skills` (minus invariants and `architecture`, which are
   always included).
6. **Reviewer greps.** Every grep / rg line in the old reviewer → a
   `verify.mechanical_checks` entry (generalised to the repo's real paths), so
   no mechanical check is lost.
7. **Lost-rules inventory.** Split every old agent and skill into its rules
   (one bullet, table row, checklist item or code-block trap each). For each
   rule record where it lands in v2: an invariant skill, a rule pack, a filled
   slot (`IMPORT_TABLE`, `PORT_RULES`, `SHARED_PORTS_TABLE`, `STATE_RULES`,
   `TRAPS_WITH_EXAMPLES`, `PLATFORM_UI_RULES` …), a `layers[].rules` line, a
   mechanical check, or `carry_forward`. A rule with no home is **lost**: give
   it a home in the manifest, or list it for explicit drop at confirm. Rules
   that soften an invariant are listed as dropped, with the reason.

---

## Output of detection

A filled `harness.yml` (`harness_version: 2`), plus a short prose summary:

- workspace map (if any), stack pack per package, kind and shape;
- the role table, role by role, with local name and path;
- conformance level and every gap, file counts, proposed disposition;
- the exemplar slice, and whether it fully conforms;
- the layer chain with kinds, and the ownership check result;
- recorded divergences (mocking framework, throw-based errors) and the default
  the harness proposes for new code;
- arch-test status and, for `generate`, the files to write;
- every command that will be run later and whether it may fetch;
- with an existing harness: settings carried, runner model, commit prefix, and
  the lost-rules inventory (rule → v2 home, or "drop?");
- anything you could not determine.
