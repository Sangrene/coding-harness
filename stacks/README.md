# Stack packs

A stack pack is a reference for the **installer agent** (`skills/harness-init/SKILL.md`),
not user documentation. It tells the installer how to recognise a stack, which
idioms that stack uses for each manifest field, and which traps an agent in
that stack falls into. `project.stack` in `harness.yml` names the pack used.

| Pack | Covers |
|---|---|
| `typescript.md` | TypeScript / JavaScript — Node backends, web and React Native frontends; npm, yarn, pnpm, bun |
| `rust.md` | Rust — cargo, cargo workspaces, nextest |
| `go.md` | Go — modules, `go.work` workspaces |
| `dotnet.md` | C# / F# on .NET — solutions, SDK-style projects, VSTest and Microsoft.Testing.Platform |
| `python.md` | Python — uv, poetry, pip; pytest |
| `jvm.md` | Java and Kotlin — Gradle (Groovy/Kotlin DSL) and Maven |
| `_template.md` | Empty pack. Copy it for an unlisted language |

## The rule above every pack

**A pack supplies defaults and signals. The repo's actual code always wins.**

- A command in a pack is a default. If `package.json` scripts, a Makefile,
  justfile, Taskfile or CI workflow runs something else, the repo's command goes
  in the manifest.
- A layout in a pack is a hint for where to look. The hexagon mapping comes from
  reading the repo's exemplar slice, not from the pack's table.
- An arch-test recipe is a starting point. The installer rewrites names, paths
  and namespaces to the repo's real ones, and runs it red-then-green before it
  is committed.
- Where the pack and the repo disagree, record the repo's choice. Where the repo
  breaks the hexagon, record a `conformance.gaps` entry — never weaken the rule
  to match the pack or the repo.

## Fixed section list

Every pack has exactly these sections, in this order. The installer reads them
by heading, so do not rename, merge or reorder them.

| # | Section | Feeds manifest fields |
|---|---|---|
| 1 | Detection signals | `project.stack`, `project.language`, `project.frameworks`, `workspace` |
| 2 | Commands | `commands.run`, `exec`, `add_dependency`, `test_all`, `lint`, `hygiene` |
| 3 | Gate | `commands.gate`, `gate_name` |
| 4 | Targeted tests | `commands.test_targeted`, `test_target_hint`, `testing.runners` |
| 5 | Red stub | `testing.red_stub` (string, or map by return shape → per-layer `RED_STUB`) |
| 6 | Test placement & naming conventions | `testing.placement`, `path_formula`, `naming`; `layers[].owns` / `excludes` |
| 7 | Doubles & spy technique | `testing.doubles`, `testing.spy_technique` |
| 8 | Errors | `architecture.errors.*`; idioms and before/after traps → `ERROR_COMPOSITION_IDIOMS`, `ERROR_BOUNDARY_RULES`, `TRAPS_WITH_EXAMPLES` |
| 9 | Validation | `architecture.validation.*` |
| 10 | Type escape hatches | `architecture.type_escape_hatches` |
| 11 | Hexagon mapping hints | `architecture.hexagon`, `leakage_examples`, `modules`, `conformance.gaps`, `layers[]` (incl. `kind`), `SHARED_PORTS_TABLE` |
| 12 | Arch tests | `verify.arch_tests`, `commands.arch_test` |
| 13 | Pitfalls | `commands.hygiene`, `layers[].excludes`, `verify.mechanical_checks` |
| 14 | Reviewer greps | `verify.mechanical_checks` (diff scope against `$F` = changed files, repo scope against the tree), `STACK_REVIEW_GREPS` |
| 15 | Platform UI rules | `PLATFORM_UI_RULES` (component-design, view builders), `PRESENTATION_PLATFORM_RULES` (presentation-model); "n/a" when the stack has no UI |

## How the installer uses a pack

1. **Pick.** Match section 1 of each pack against the repo root (and each
   workspace package). The lockfile/manifest that exists decides; a README
   never does. Polyglot repo → workspace form, one pack per package.
2. **Read the repo through the pack.** Sections 2–4 say where the real
   commands live and which flags make them non-interactive and uncached;
   sections 6–11 say what to grep for and what each hexagon role usually looks
   like in this stack.
3. **Fill fields.** Take the pack's default only when the repo is silent, and
   say so at the confirm step ("defaulted from stacks/go.md").
4. **Gaps.** Section 11 lists the stack's typical gaps (port declared in the
   adapter project, ORM entity used as domain type …). Each hit becomes a
   `conformance.gaps` entry.
5. **Arch tests.** If the repo has none and the user agrees,
   `verify.arch_tests.status: generate` and section 12's recipe is adapted and
   written red-then-green during render.
6. **Ownership.** Section 6 and 13 give the `excludes` and generated-code globs
   the mechanical disjointness check needs.
7. **Reviewer greps.** Section 14's patterns are rewritten with the repo's real
   paths, run once against the exemplar slice (a hit on conforming code means
   the pattern is wrong), and become `verify.mechanical_checks` with
   `scope: diff` (commands over `$F`) or `scope: repo`. Diff-scoped checks never
   grep the whole source tree. Patterns are POSIX ERE (`grep -E`, GNU and BSD);
   repo-scope checks use `rg`.
8. **Platform UI.** Section 15's subsection for
   `skills.optional.component_design.platform` fills the view and presentation
   platform rules; only rules the repo already follows or the user confirms.

## Adding a pack for an unlisted language

1. Copy `_template.md` to `stacks/<id>.md`. `<id>` is lowercase, one word; it is
   the value of `project.stack`.
2. Fill every section. "None" is a valid answer (e.g. no arch-test tool exists) —
   say what the installer does instead. An empty section is not.
3. Verify every command and flag against the tool's `--help` or current docs.
   Do not invent flags. Mark anything unverified as such.
4. Section 4 must give a non-interactive, uncached invocation. Section 3 must
   compile test code. Section 5 must make RED a test that compiles, runs and
   fails for the expected reason: preferred stub returns a typed placeholder
   (zero value / default) so the failure is an assertion; a not-implemented
   throw/panic is acceptable only when the test output names that stub. When
   one stub does not fit every return shape (sync rule, async port, UI hook,
   component), give the `red_stub` map form, keyed by shape.
5. Add the pack to the table above and to the `project.stack` enum comment in
   `harness.schema.yml`.

Until a pack exists, the installer can still fill the same fields by hand from
the repo; it says so at the confirm step.

## Style

Terse: tables, bullets, exact commands. Every recipe is marked as a starting
point. ~150–350 lines per pack.
