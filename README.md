# coding-harness

A stack-agnostic coding harness for Claude Code. It provides an orchestrator
pattern, receipt-enforced TDD, hexagonal architecture, real separation of
concerns and extract-til-you-drop. An agent generates it into any target
repository and adapts it to that codebase.

It works with any language. Stack packs ship for TypeScript, Rust, Go, .NET (C#),
Python and the JVM (Java/Kotlin). A language without a pack is still
installable; the installer fills the same fields by hand.

The harness was generalized from five working harnesses:

- a Next.js/Apollo web app (Zustand/Jest)
- a React Router web app (MobX/ArkType/neverthrow/Vitest)
- an Expo mobile port of that web app (React Native, Vitest + jest-expo)
- a Rust/Axum modular monolith (sqlx)
- the evolved web/mobile harnesses: domain-first chain, rule packs per
  layer kind, stronger reviewer

## Install

### As a plugin (recommended)

```text
/plugin marketplace add <path-or-git-url-of-this-repo>
/plugin install coding-harness@coding-harness
```

Then, in the target repository:

| Command | What it does |
|---|---|
| `/coding-harness:harness-init` | Detect the repo, draft `.claude/harness.yml`, ask you to confirm, render `.claude/`, verify |
| `/coding-harness:harness-upgrade` | Re-render an installed harness against newer templates. Migrates v1 manifests and asks per hand-edited file |
| `/coding-harness:harness-doctor` | Read-only health check: drift, stale globs, unowned code, broken commands |

### Standalone

Point an agent at `skills/harness-init/SKILL.md` in this repo. When the plugin
root variable is not substituted, the skill resolves templates relative to its
own location. See `install/README.md`.

## The idea

The source harnesses are the same machine with different labels. The machine is:

```text
scout (read-only, alone)
  → domain layer (rules, types, errors — alone, self-tested red→green)
    → [ independent layers ‖ ]
      → sequential layer chain, each self-tested red→green
        → wiring
          → gate (compile/typecheck + boundary tests — blocking, sequential)
            → [ test-runner ‖ layer-reviewer ]
```

Everything that varies is a label in `harness.yml`: layer names, commands, error
types, test placement, language.

### Two tiers of skill

**Invariant**: byte-identical in every generated harness and never adapted to a
codebase.

| Skill | Always answers |
|---|---|
| `hexagonal-architecture` | where the boundary is. **Not a style choice** |
| `tdd` | red → green → refactor. Watch it fail. In compiled languages, stub the signature first so red is an assertion failure, not a compile error |
| `separation-of-concerns` | which side of the boundary this logic goes on |
| `extract-til-you-drop` | decompose until every name earns itself |
| `orchestrator` | how the root delegates, and the receipt contract |

**Filled**: same structure everywhere, contents rendered from the manifest.

- `architecture`: this repo's roles, paths and known deviations.
- `testing`: placement, runners, doubles and spy technique.
- `error-handling`: the repo's failure type, where errors are classified, and
  traps.

### Layer kinds and rule packs

Every implement agent has a `kind`: `domain`, `application`, `driven-adapter`,
`driving-adapter`, `state`, `presentation`, `wiring` or `other`. The kind pulls
in a stack-agnostic rule pack (`templates/agents/implement/rule-packs.md`). One
example is "the use case decides from the entity it loaded, never from a state
read". Repo-specific rules sit on top.

Exactly one layer is `kind: domain`, and it goes first. Business rules are
routed to it before anything else.

### Scaled hexagon

The architecture is fixed, but its size is not. `architecture.shape` declares
which roles legitimately do not exist:

| Shape | For | Removes |
|---|---|---|
| `full` | services, web/mobile apps, workers | nothing |
| `minimal` | CLIs, small workers | separate application layer (use cases may sit beside the domain) |
| `library` | libraries | driving adapter and composition root (the consumer is the root) |

Scaling removes roles. It never weakens rules. Pure IaC repos (Terraform, Helm)
are out of scope, and the installer says so.

### Monorepos and polyglot repos

Workspace mode puts one manifest at the root, with one `packages[]` entry per
package. Each package has its own stack, commands, layers and conformance.

- Invariant skills are rendered once.
- Filled skills and agents are rendered per package, with a prefix (`api-domain-builder`, `web-architecture`).
- The root memory file routes by path. Each package directory gets its own `CLAUDE.md`.

A change that crosses packages becomes two chains, sequenced by the shared
contract.

### Enforcement

TDD and boundaries are enforced structurally, not by exhortation:

1. **Receipts.** Every subagent ends with six lines. A test-owning builder
   cannot report `done` without both a red run and a green run.
2. **Arch tests (opt-in, recommended).** Language-native boundary tests run in
   the gate: NetArchTest/ArchUnitNET, go-arch-lint/depguard,
   dependency-cruiser/eslint-plugin-boundaries, import-linter, ArchUnit, or the
   crate graph. The dependency rule then fails the build instead of waiting for
   a reviewer.
3. **Receipt-check hook (opt-in).** This is a `SubagentStop` hook
   (`templates/hooks/receipt-check.sh`). It bounces any malformed receipt back to
   the subagent, including a `done` with no red run. Installing it edits
   `.claude/settings.json`, so the installer shows the JSON and asks first.
4. **`layer-reviewer`** catches what neither can: misplaced rules, decisions made
   from state, anemic domains, and fakes not typed as the port.

### Four load-bearing invariants

1. **One receipt schema.** The orchestrator stores receipts only and never
   re-reads edited files. Root context grows per *layer*, not per *diff*.
2. **`done` means red-then-green.** The orchestrator refuses to advance on a
   non-`done` receipt.
3. **Disjoint file ownership.** One layer, one agent, one glob set (with
   `excludes` for carve-outs).
4. **Verify agents are never pre-cleared.**

## Layout

```text
.claude-plugin/            plugin.json + marketplace.json (repo is its own marketplace)
skills/
  harness-init/            the installer: SKILL.md, DETECTION.md, CHECKLIST.md
  harness-upgrade/         re-render + v1→v2 manifest migration
  harness-doctor/          read-only health check
stacks/                    per-language packs: detection, commands, red stub, errors, arch tests
templates/                 every emitted file, with {{PLACEHOLDERS}}
  PLACEHOLDERS.md          placeholder → manifest field (the renderer's authority)
  hooks/                   receipt-check.sh + settings snippet
harness.schema.yml         the manifest schema (v2), annotated
examples/                  real and illustrative manifests (see examples/README.md)
ARCHITECTURE-ANALYSIS.md   what generalizes, what varies, and why
install/README.md          pointer for standalone use
```

## Design decisions worth knowing

- **Builder-owns-tests is the default.** A separate `test-author` is emitted only
  when test bodies cannot live with the builder, and the builder still reports
  green.
- **No meta-orchestrator subagent, ever.** The root walks the graph itself.
- **The architecture is enforced, everything else is described.** A repo that
  deviates gets the unmodified rules plus recorded `conformance` gaps, each with
  a disposition (`enforce-now` / `migrate`). Agreeing to a non-conforming repo
  means agreeing to a migration, and the installer says so.
- **Stack packs supply defaults, the repo wins.** Every command and path in a
  rendered harness must be true of the target code.
- **Hooks only on opt-in.** The installer edits settings only for the
  receipt-check hook, and only after you confirm the exact JSON.

## Limits

- The renderer is an agent, not a template engine. Most of the work is judgment
  about the target codebase. `templates/PLACEHOLDERS.md` keeps the substitution
  half honest.
- `harness.yml` is committed to the target repo. `harness-upgrade` re-renders
  from it and asks before overwriting hand edits. `harness-doctor` reports drift.
- The Go, .NET, library and workspace examples are illustrative. They are not
  reverse-engineered from production repos, so the first real install on each
  stack is the real test.
