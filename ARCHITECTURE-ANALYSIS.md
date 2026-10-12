# Cross-repo analysis — what actually generalizes

Source material: three working harnesses — a Next.js/Apollo web app
(Next.js/React + Apollo + Zustand + Jest), a React Router web app
(React Router + MobX + ArkType + neverthrow + Vitest), and a Rust/Axum modular
monolith (Rust + Axum + sqlx). Below they are called the *Next.js app*, the
*React Router app* and the *Rust service*.

The three `.claude/` directories are the **same machine with different labels**.
This document separates the machine (invariant) from the labels (per-repo).

---

## 1. The invariant core

These hold identically across frontend and backend, and are copied verbatim into
every generated harness.

### 1.1 Phase-folder layout

```
.claude/agents/
  plan/       read-only: scope, audit, blast radius, checklist, boundary gate
  implement/  one agent per architectural layer, each owning a disjoint file set
  verify/     read-only: gate (compile/typecheck + targeted tests), boundary reviewer
```

The folder is the phase. An agent's phase determines whether it may write, whether
it may run in parallel, and what it is allowed to conclude.

### 1.2 The receipt schema

Byte-identical in all three repos. This is the single most portable artifact.

```text
STATUS: done | blocked | needs-orchestrator
SCOPE: <subagent-name>
FILES: <comma-separated paths changed or read>
OUTCOME: <1-3 sentences>
BLOCKERS: <empty or list>
NEXT: <suggested next subagent>
```

Two rules give it its value:
- A subagent's **final message is only the receipt** — no prose, no file dumps.
- The orchestrator **stores receipts only** and never re-reads subagent-edited
  files unless a verify agent reported `blocked`/`needs-orchestrator`, or the
  user asked.

That is the whole context-economy argument for the pattern: the root agent's
context grows by ~6 lines per layer instead of by the diff.

### 1.3 The dispatch graph shape

Every repo's graph reduces to:

```
scout (read-only, alone, first)
  → [ independent foundation layers in parallel ]
    → dependent layer chain (strictly sequential, each self-tested green)
      → wiring / composition root
        → compile-or-typecheck + targeted-test gate (sequential, blocking)
          → boundary-reviewer  (read-only)
```

Only one parallel group is ever safe: the foundation pair that writes disjoint
files whose shared names the orchestrator fixes up-front in both dispatch
prompts. Verify is sequential: one gate agent (gate + targeted tests), then the
reviewer.

Everything else is sequential because a downstream layer reads the
**finished, verified** shape of the layer above — not its planned shape.

### 1.4 The green-receipt gate (TDD, enforced structurally)

`STATUS: done` from a test-owning builder means *tests ran and passed*, not
*files exist*. The builder self-tests with a targeted run before reporting.
The orchestrator's only TDD job is to **refuse to advance the chain on a receipt
that isn't `done`** — never to write or fix a subagent's tests itself.

This is what makes TDD survive delegation. A prose instruction "please do TDD"
does not; a receipt that cannot say `done` without a green run does.

### 1.5 Orchestrator discipline rules

Present in all three (most explicit in the React Router app), all stack-agnostic:

- **Dispatch means an Agent tool call.** Reading an agent's `.md` and doing the
  work inline is not dispatch — it skips the isolated context and the receipt
  boundary the pattern depends on.
- **No meta-orchestrator subagent.** A subagent that dispatches subagents
  collapses turn-level parallelism and collapses N receipts into one opaque
  summary. The root walks the graph itself, turn by turn.
- **Visibility.** A subagent's final message is invisible to the user unless the
  orchestrator posts it. One line before each dispatch, the receipt after each.
- **Say what, not how.** Give a subagent the goal, the contracts it must fit
  (exported schema name, call signature, state field names, hook return shape),
  and constraints it cannot discover. Never prescribe the internals of the file
  it owns — you do not have its context, and prescribing silently overrides
  rules you never read.
- **Never pre-clear anything to a verify agent.** Give scope and context, never
  verdicts. Telling the reviewer "that deviation is fine" disables it exactly
  where it was needed. Overrule findings in the open instead.
- **Scope cap.** ≤3 files per implement invocation; ask the orchestrator to split.

### 1.6 The skill tiers

Skills split into two tiers, and the split is load-bearing.

**Invariant** (`hexagonal-architecture`, `tdd`, `separation-of-concerns`,
`extract-til-you-drop`, `orchestrator`) are byte-identical everywhere. They
describe a practice, not a codebase, so adapting them to a repo is always a
mistake — a repo that does not practise TDD, or does not respect the hexagon,
needs the unmodified skill plus a recorded gap, not a softened one.

**Filled** (`architecture`, `testing`, `error-handling`) have the same structure
everywhere and are rendered from the manifest.

The pairing is deliberate: each filled skill has an invariant counterpart that
holds the reasoning, so the project-specific file stays short and factual.

| Filled (this repo) | Invariant counterpart (the practice) |
|---|---|
| `architecture` — role→path mapping, slice layout, naming, exemplar | `hexagonal-architecture` — the boundary; `separation-of-concerns` — which side |
| `testing` — where files go, doubles, assertions | `tdd` — red-green-refactor, watch it fail |
| `error-handling` — the repo's failure type | `hexagonal-architecture` — errors are classified at the adapter |

Neither restates the other; they cross-reference. Two copies of the same rule
drift, and then contradict.

#### Architecture is not an axis

The first draft of this harness treated architecture style as a manifest field.
It is not: **every harness is hexagonal (ports & adapters) with clean layering**,
and `hexagonal-architecture` is emitted verbatim. Only the naming varies.

The reason is visible in the source repos. Both correct implementations —
the Rust service and the Next.js app — converge on the same structure despite
sharing no language, framework or vocabulary:

| | Rust service | Next.js app |
|---|---|---|
| Domain type free of framework | pure Rust struct, no `sqlx::FromRow`/`serde` | `<domain>.model.type.ts`, no `__typename` |
| Driven port owned by the inside | trait in `src/domain/ports/` | `<domain>.repository.interface.ts` |
| Driven adapter translates | `DbAuthor::from(author)` | Apollo adapter maps GraphQL → model |
| Errors classified at the adapter | `sqlx::Error` → `DomainError` | `ApolloError` → typed result |
| Composition root only | `main.rs` wires, no logic | `StoreProvider` + `use<Domain>Repository` |
| Doubles per port | `FakeAuthorRepository` | `<domain>.repository.fake.ts` |

That convergence is the evidence the model is stack-independent. Making it
configurable would have let each new repo re-litigate a settled question.

#### The counter-example: the React Router app

Kept in `examples/` deliberately (`react-router-web.harness.yml`). It uses hexagonal vocabulary — cores, ports,
adapters, fakes, injection — while breaking the structure in four places. All
four are evidenced in its own skills, and all four are the kind that look like
*less* code rather than worse code:

1. **Port derived from its adapter.**
   `type UserRepository = ReturnType<typeof createUserRepository>`, with the
   factory taking an `HTTPClient`, and port and adapter in the same file. The
   implementation defines the contract, so the dependency is inverted back.
2. **No translation boundary.** The repository parses the HTTP response straight
   into the domain schema (`responseType: EntitySchema`). The wire shape *is* the
   domain model; every API change is a domain change. The anti-corruption layer
   is exactly the code that was skipped.
3. **Anemic domain.** Models are ArkType schemas with no behaviour; feature cores
   are CRUD pass-throughs (set loading → validate → call repository → set state).
   The inner layer holds no decisions, so there is nothing for the hexagon to
   protect.
4. **Infrastructure owns an application type.** `<Domain>StoreInterface` is
   declared in the MobX store file and imported by the core.

One of its slices is the exception and does it properly — real ports,
adapters, typed error kinds — which is why it is nominated as the exemplar rather
than one of the CRUD slices.

The harness's answer is `conformance`: unmodified rules, the gaps recorded with a
disposition (`enforce-now` for new code, `migrate` for existing), and the
`architecture` skill's "Known deviations" section generated from them.

#### Why `tdd` is its own skill

In all three source repos the loop was either fused into a conventions skill
(the Next.js app's and the Rust service's `testing`) or stated once as steps
among many (the React Router app's `tdd`, `new-feature`). An agent could load the
conventions and skip the discipline, and nothing downstream noticed — a test
written after the code passes on the first run and looks identical in the diff.

The harness makes the loop structural instead:

1. `tdd` is preloaded on every implement agent, via `implement-foundation`.
2. The receipt must report **both** halves — the red run and the green one. An
   `OUTCOME` that only mentions passing tests is sent back.
3. `layer-reviewer`'s first invariant check is that behaviour changes in a tested
   layer arrive with their tests in the same diff.
4. The orchestrator cannot advance on a non-`done` receipt, so skipping the loop
   does not save a turn — it costs one later.

### 1.7 Where the source repos' skills map to

Same ideas in all three repos, different vocabulary:

| Idea | Next.js app | React Router app | Rust service |
|---|---|---|---|
| Layering / ports & adapters | `create-vertical-slice`, `create-repository`, `create-use-case`, `create-view-model`, `create-store` | `clean-architecture`, `new-feature`, `view-model`, `components-design` | `hexagonal-architecture`, `modular-monolith` |
| Decomposition | (implicit) | (implicit) | `extract-til-you-drop` |
| Testing | `testing`, `test-naming-pattern` | `tdd` | `testing` |
| Typed error flow | `neverthrow` | `fp` | `Result<T, DomainError>` inside hexagonal |

Generalization: these collapse into the seven always-present skills of §1.6 —
four invariant, three filled. Two observations drove the split:

- `extract-til-you-drop` exists only in the Rust repo, yet nothing in it is
  Rust-specific. It is invariant, and its absence is the largest single gap in
  both frontend harnesses.
- The "separation of concerns" reasoning is scattered across five
  stack-specific skills per frontend repo (`create-use-case`,
  `create-view-model`, `clean-architecture`, `view-model`, `components-design`).
  Each restates the dependency rule in its own layer's vocabulary. Hoisting it
  into one invariant skill removes four copies and leaves the stack skills
  describing only paths and naming.

### 1.8 Command hygiene

Repeated in every repo, in different words: pin the package manager
(`yarn` / `bun run` / `cargo`), never append `2>&1`, always use the
non-interactive/targeted test invocation, always wait for exit.

---

## 2. The variable axes

Everything below is what the installer must detect or ask about. These are the
placeholders in `templates/` and the fields in `harness.yml`.

| Axis | Next.js app | React Router app | Rust service |
|---|---|---|---|
| Layer chain | model/repository → use-case ∥ store → view-model → component | repository ∥ store → core → view-model → component → wiring | domain → application → infrastructure(http/persistence/integration) → wiring |
| Foundation parallel pair | use-case ∥ store | repository ∥ store | none (layer order is strict) |
| Test-owning layers | use-case, view-model | core, view-model | test-author (separate agent) |
| Gate command | `yarn typecheck` | `bun run typecheck` | `cargo check` |
| Targeted test | `yarn jest --no-coverage --watchAll=false <path>` | `bun run test <path>` | `cargo test <filter>` |
| Error type | `ResultAsync<T,E>` (neverthrow) | `ResultAsync<T,E>` (neverthrow) | `Result<T, DomainError>` |
| Test doubles | `test/*.repository.fake.ts` | `src/<d>/tests/*.fake.ts` | `InMemory*` persistence adapters |
| Test placement | colocated `.use-case.test.ts` | colocated `<feature>.core.test.ts` | sibling `tests.rs` submodule |
| Validation | (types) | ArkType schemas | domain types |
| State | Zustand | MobX | none (stateless services) |
| Optional agents | — | `wiring-agent` | `spec-mapper`, `impact-scout` (CodeGraph) |
| Optional skills | — | `i18n`, `components-design` | `modular-monolith` |

### 2.1 Divergences worth flagging (not just naming)

- **Plan phase depth.** The Rust service has four plan agents
  (`impact-scout` ∥ `spec-mapper` → `feature-planner` → `architecture-gate`); the
  frontends have one scout. The four-agent version is the better default for any
  codebase over ~30k LOC or with an external spec; the single scout is right for
  a small one. Make it a manifest switch, not a fork.
- **Who owns tests.** Frontends: the builder owns and self-tests its own tests
  (stronger TDD). Backend: a separate `test-author` runs after the implementer
  (weaker — the green gate moves off the builder's receipt). The harness default
  should be **builder-owns-tests**; `test-author` becomes an optional extra for
  languages where test bodies live in a separate file, and even then the builder
  still reports green.
- **`impact-scout` depends on CodeGraph.** Gate it on `.codegraph/` existing.
- **Cursor compatibility.** The Rust service carries both `is_background` and
  `background`, plus `## Startup (Cursor — read before review)` blocks that
  re-list skills as explicit reads, because Cursor does not honor the `skills:`
  frontmatter. Keep as an optional emit flag.
- **Agent filename suffix.** The Next.js app uses `*.agent.md`, the others `*.md`.
  Cosmetic; the harness emits `*.md`.

---

## 3. What the installer produces

Given a target repo, `skills/harness-init/SKILL.md` runs detection
(`DETECTION.md`, guided by the matching `stacks/<id>.md` pack), writes a
`harness.yml` for the user to confirm, then renders `templates/` into the repo's
`.claude/` per `templates/PLACEHOLDERS.md`, and verifies the result against
`CHECKLIST.md`.

The generated harness is **not** a copy of any source repo. It is the invariant
core plus the detected labels. Every stack-specific rule comes from the target
codebase's own code, not from these examples.

---

## 4. v2 — from three repos to any repo

Two more source harnesses fed v2: an Expo mobile port of the React Router app,
and the rebuilt React Router app itself. Three more stacks were added as targets: Go, .NET and the JVM.
Each change below fixes something that was implicitly TypeScript- or
Rust-shaped, or ports a practice the web/mobile harnesses proved.

### 4.1 What the Expo port proved

The mobile app (`expo-mobile.harness.yml`) is an Expo port of the React Router app. Almost every difference
between the two harnesses is relabelling: paths, import alias, browser APIs vs
`expo-*` adapters, and env prefix. The machine survived a platform change
untouched. Only seven practices changed:

- no Storybook;
- two test runners;
- React Native UI rules;
- versioned-docs lookup;
- navigation as UI plumbing;
- plain descriptors in ports;
- a migration doc instead of a deviation table.

All seven are schema fields or optional skills now:

- per-layer `test_targeted` and `testing.runners`;
- `component_design.platform` and `.preview`;
- `carry_forward`;
- `conformance.migration_doc`.

None of them is a template fork.

### 4.2 What the evolved web/mobile harnesses added (now invariant)

- **Domain first.** The scout extracts every business rule ("only if", "must",
  "at most"). A `kind: domain` layer then runs alone, before every other builder.
  A rule with no domain home always ends up in a use case, a store or a
  view-model.
- **Scope gaps explicitly.** For each gap in the touched area, the orchestrator
  decides "fix now" or "record". It never forwards a gap as "fine for now", which
  is pre-clearing by another name.
- **Rule precedence.** An agent's own rules outrank the dispatch prompt. A
  `blocked` receipt naming the missing piece costs one round, while silently
  complying costs a refactor.
- **Rule packs per layer kind.** Examples: use cases never decide from state
  reads and never self-start; state adapters are setters only; the composition
  root passes ports and never imports test code.
- **Reviewer depth.** Mechanical greps, diff-scoped and repo-wide, plus a
  case-by-case comparison between adapter tests and use-case tests.
- **Mappers are tested.** "Adapters are not unit-tested" had one exception:
  translation code is pure and full of decisions.

The React Router app (`react-router-web.harness.yml`) remains the `partial` example. Its harness now carries all of
the above, but legacy files still deviate, and its manifest records them.

### 4.3 What was implicitly TS/Rust-shaped

| Assumption | Broke on | v2 fix |
|---|---|---|
| "A missing function" is a valid red | Go, C#, Java: missing symbol = compile error for the whole package | `testing.red_stub` per stack: zero-value func, `NotImplementedException`, `todo!()`, `TODO()` |
| Gate = one typecheck command | `go build` skips `_test.go`; .NET needs restore semantics | `commands.gate` is a list, must compile tests |
| Test target = a file path | Go targets packages, .NET targets projects | `{path}` `{package}` `{project}` `{filter}` tokens + `test_target_hint` |
| Test results are fresh | `go test` caches passes | uncached command required; "a cached pass is not a run" in `tdd` |
| Tests colocated | .NET: separate test projects | `placement: separate-project`; layers own globs in test projects |
| Disjoint globs | Go `*_test.go` beside code | `layers[].excludes` |
| Errors told apart by `kind` | Go: `errors.Is/As` on sentinel and typed errors | `errors.discriminate_by`; "never compare message text" (sentinel values are fine) |
| Spy = `vi.spyOn` | no runtime patching in Go; Moq needs virtual members | `testing.spy_technique` |
| ≤3 files per invocation | .NET adapter = interface + class + DI + test files | `layers[].max_files` |
| `{{` = unrendered placeholder | Go templates (`{{.Imports}}`) | regex `\{\{[A-Z][A-Z0-9_]*\}\}` |
| Frontmatter after HTML comment | every agent file (parse failure) | templates start with `---`; render notes are `<!-- harness: -->` after it, stripped |

### 4.4 Why the hexagon still holds in Go and .NET

Both stacks make the hexagon *cheaper* than TypeScript does:

- **Go.** Interfaces are satisfied implicitly and declared where they are
  consumed. A driven port in `app/` with its adapter in `adapter/postgres/` is
  idiomatic Go, not ceremony.
- **.NET.** The `<ProjectReference>` graph is a compiler-enforced dependency
  rule: Domain references nothing, and Infrastructure references Application.
  Arch tests only need to cover what project boundaries do not, such as
  namespaces inside one project and attribute leakage.

The common .NET gap is `IRepository` declared in the Infrastructure project.
That is the "port derived from its adapter" anti-pattern in another costume, and
detection checks for it explicitly.

### 4.5 Shapes, workspaces, enforcement

- **Shapes** (`full | minimal | library`) let a CLI or library install the
  harness without fake layers. They remove roles, never rules.
- **Workspaces** render one manifest into prefixed per-package agents and
  skills, with shared invariants. A cross-package change becomes two chains
  ordered by the contract, never one chain spanning two stacks.
- **Arch tests** move the dependency rule from reviewer judgment into the gate.
  The **receipt-check hook** moves the receipt format from orchestrator
  vigilance into the runtime. Both are opt-in, because both write files the user
  owns.
