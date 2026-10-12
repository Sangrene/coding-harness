# Placeholder map

The authority on what every `{{PLACEHOLDER}}` in `templates/` renders from.
`harness-init` and `harness-upgrade` render from this table; a placeholder that
is not listed here is a template bug.

Conventions:

- Placeholders are `{{UPPER_SNAKE}}`. Anything else in braces (`{{.Imports}}`
  in a Go template, `{path}` in a command) is literal text.
- Render instructions live in `<!-- harness: ... -->` comments placed after the
  frontmatter. Apply them, then strip them. None may survive in the output.
- **Workspace mode.** Per-package names render with the package prefix
  (`api-domain-builder`, `api-architecture`): the filled skills, the
  foundation skill, enabled per-package optional skills, every implement agent
  (layer builders, wiring, test-author) and the gate agent. Shared agents stay
  **unprefixed**: the scout, `feature-planner`, `architecture-gate`, the
  optional plan/spec agents, and `layer-reviewer`; their
  frontmatter `skills:` uses the `ALL_*_SKILLS` placeholders (every package's
  names, comma-joined). In `PACKAGE-CLAUDE.md.tmpl` and in every per-package
  file, every field renders from `workspace.packages[i]`. In shared root files
  and shared agents' bodies, a per-package value renders as a slash-joined list.
- **Invariant skills take no placeholders.** `hexagonal-architecture`,
  `separation-of-concerns`, `tdd` and `receipt.md` render byte-identical.
  `tdd` points at the foundation skill for its commands, gate and red stub.
  `extract-til-you-drop` takes only `LOGIC_LAYERS` and `EXTRACT_LOCATION`.
- Values that already carry their own backticks are marked *(formatted)*. Do not
  wrap them in backticks again.

## Project and emit

| Placeholder | Source |
|---|---|
| `PROJECT_NAME`, `PROJECT_SUMMARY` | `project.name`, `project.summary` |
| `DOMAIN_WORD` | what this repo calls a business area (domain, module, bounded context) — from `architecture` vocabulary |
| `MEMORY_FILE` | `emit.memory_file` |
| `SKILLS_IMPORT_PREFIX` | `.claude/skills/` when the memory file is root `CLAUDE.md`; `skills/` when it is `.claude/CLAUDE.md` |
| `CURSOR_FLAGS` | `emit.cursor_compat` — empty when false |
| `CURSOR_STARTUP` | `emit.cursor_compat: true` → one line, then a blank line: ``**Cursor** ignores `skills:` — read first: `<path>`, `<path>` …`` with the `.claude/skills/<name>/SKILL.md` path of every skill in this agent's `skills:`. Nothing else — no restated skill content. Empty (line removed) when false |
| `REPO_IMPORTS` | one `@<path relative to the memory file>` line per repo instruction file the memory file imports (`AGENTS.md` when it exists and is not the memory file); empty otherwise. Rules in these files are never copied into `CARRY_FORWARD` |
| `ALWAYS_ON_IMPORTS` | one `@{{SKILLS_IMPORT_PREFIX}}<name>/SKILL.md` line each: the four invariants (`hexagonal-architecture`, `tdd`, `separation-of-concerns`, `extract-til-you-drop`), `ARCH_SKILL`, then `emit.always_on_skills` by rendered name. Workspace mode: invariants only |
| `PACKAGE_ALWAYS_ON_IMPORTS` | `PACKAGE-CLAUDE.md.tmpl`: one `@{{PACKAGE_SKILLS_PREFIX}}<name>/SKILL.md` line each — the package's `ARCH_SKILL`, then its `emit.always_on_skills` entries, prefixed |
| `RUNNER_MODEL_LINE` | `emit.runner_model` as `model: <x>` plus newline, or empty |
| `SKILL_INDEX` | `skills.filled` + enabled `skills.optional` (names per "Skill names" below), one linked line each — minus every skill already in `ALWAYS_ON_IMPORTS` |
| `CARRY_FORWARD` | `carry_forward`, quoted verbatim, one bullet each — only rules from files the memory file does not import (`REPO_IMPORTS`) and that `COMMAND_RULES` does not already state; section dropped when empty |
| `DEV_RUN` | `dev_run.*`; section dropped when empty |
| `EXTRA_SECTIONS` | spec and optional-skill sections |
| `WORKSPACE_SECTION` | `workspace.packages` (package map, path → package routing) + `workspace.contracts`; empty when not a workspace |

## Workspace package memory file (`PACKAGE-CLAUDE.md.tmpl`)

| Placeholder | Source |
|---|---|
| `PACKAGE_NAME`, `PACKAGE_PATH` | `packages[].name`, `packages[].path` |
| `PACKAGE_SUMMARY`, `PACKAGE_STACK` | `packages[].project.summary`, `packages[].project.stack` |
| `PACKAGE_SKILLS_PREFIX` | relative path from `packages[].path` to `.claude/skills/` |
| `PACKAGE_SKILL_INDEX` | `packages[].skills.optional`, one linked line per enabled skill, prefixed names |
| `PACKAGE_CONTRACTS` | `workspace.contracts` this package owns or consumes |

## Commands

| Placeholder | Source |
|---|---|
| `WORKDIR` | the directory every command is run from: `.` (repo root) when not a workspace; `packages[].path` for a per-package file. Not used in shared agents |
| `GATE` *(formatted)* | `commands.gate` inline: `` `a`, then `b` `` |
| `GATE_STEPS` | `commands.gate` as a numbered list, then `commands.arch_test` if set — the steps that run today, never a "once it exists" step |
| `GATE_AGENT` | `commands.gate_name` |
| `TEST_TARGETED` | `layers[].test_targeted` for the agent being rendered, else `commands.test_targeted` |
| `TEST_TARGET_HINT` | `commands.test_target_hint` |
| `TEST_ALL` | `commands.test_all` |
| `TEST_RUNNERS_TABLE` | `testing.runners` + per-layer `test_targeted` overrides, as `\| Package \| Layers \| Working dir \| Targeted command \| Target hint \| Full suite \|`; one row per **distinct** (package, working dir, targeted command, hint, full suite) — layers sharing one are merged into the Layers cell, so an override equal to the default adds no row (workspace: every package in the shared testing skill, `Working dir` = `packages[].path`; in a per-package gate agent only that package's rows, Package column dropped; otherwise the Package column is dropped and `Working dir` is `.`) |
| `COMMAND_RULES` | `commands.*` (except `gate`/`arch_test`, which render through `GATE_STEPS`) + `commands.hygiene`, as the memory file's command section |
| `HYGIENE_LINES`, `HYGIENE_SHORT` | `commands.hygiene` — full list / one-line form |

## Architecture

| Placeholder | Source |
|---|---|
| `ARCHITECTURE_SHAPE` | `architecture.shape` |
| `ABSENT_ROLES` | roles marked `absent: by-shape`, or `none` |
| `HEXAGON_ROLE_ROWS` | `architecture.hexagon`, one row per role, absent rows say "absent by shape" |
| `HEXAGON_ROLE` | the role(s) of the layer being rendered, from `layers[].kind` |
| `DEPENDENCY_RULE` | `architecture.dependency_rule` |
| `TRANSLATION_RULE` | driven-adapter mapping convention, from the exemplar's adapter |
| `LEAKAGE_EXAMPLES` | `architecture.leakage_examples` |
| `COMPOSITION_ROOT` | `hexagon.composition_root.path` |
| `COMPOSITION_PATTERNS`, `FAKE_WIRING` | how the root builds adapters and swaps in fakes — from the root file's code |
| `OUTER_MAPPING` | how the driving adapter maps domain errors to its transport — from its code |
| `EXEMPLAR_SLICE` | `architecture.exemplar_slice` |
| `SLICE_LAYOUT`, `NAMING_TABLE`, `EXTRA_ROLE_ROWS` | `layers[]` + the exemplar slice's real tree and names |
| `MODULES_SECTION` | `architecture.modules`; empty when disabled |
| `TYPE_ESCAPE_HATCHES` | `architecture.type_escape_hatches` |
| `VALIDATION_LIBRARY`, `VALIDATION_PLACEMENT` | `architecture.validation.*` |
| `ARCH_TESTS_SECTION` | `verify.arch_tests` + `commands.arch_test`; dropped when status is `none` |
| `CONFORMANCE_LEVEL` | `conformance.level` |
| `KNOWN_DEVIATIONS_ROWS` | `conformance.gaps[]` with disposition |
| `MIGRATION_DOC`, `MIGRATION_DOC_LINE`, `MIGRATION_DOC_CLAUSE` | `conformance.migration_doc` — bare path / full sentence / `` and in `<path>` `` ; empty when unset |
| `DOMAIN_ERROR_PATH` | `hexagon.domain_error.path` |

## Errors

| Placeholder | Source |
|---|---|
| `ERROR_TYPE` | `architecture.errors.type` |
| `ERROR_TYPE_DETAIL` | `errors.type` expanded with the stack pack's idiom notes and the repo's own declaration |
| `ERROR_RULE` | `architecture.errors.never_throw` + `type` as one rule sentence |
| `ERROR_DISCRIMINATE_BY` | `architecture.errors.discriminate_by` |
| `ERROR_CLASSIFICATION_TABLE` | `architecture.errors.classification` |

## Testing

| Placeholder | Source |
|---|---|
| `TEST_PLACEMENT` | `testing.placement` |
| `TEST_PLACEMENT_RULE` | the placement variant chosen by `testing.placement` |
| `TEST_PATH_FORMULA` | `testing.path_formula` |
| `DOUBLES_STYLE`, `DOUBLES_LOCATION`, `DOUBLES_RULE` | `testing.doubles.*` |
| `SPY_TECHNIQUE` | `testing.spy_technique` |
| `RED_STUB` | `testing.red_stub`, per layer, rendered **only** in the self-test section (the foundation skill points there; never in `tdd`). A string renders verbatim. A map renders the entry for what the layer returns — `sync` (pure rules, mappers), `async` (ports, use cases, adapters), `hook` (presentation models), or another key the stack pack defines; a layer returning several shapes renders each as `` `<shape>` (<what>): <stub> ``, joined with `; ` |
| `NAMING_RULE` | `testing.naming` — `user-facing`: one sentence pointing at `TEST_NAMING_SKILL`; `technical`: "Name each test after the behaviour, from the caller's point of view (see `tdd`)." |
| `TESTED_LAYERS_PROSE`, `TESTED_LAYERS_TABLE` | `testing.tested_layers` + `layers[]` |
| `TEST_OWNING_AGENTS` | layers with `owns_tests: true` |
| `TEST_OWNERSHIP_RULE`, `NON_TEST_OWNER_RULE` | `owns_tests` + whether `test-author` is emitted |
| `SELF_TEST_SECTION` | `_self-test-section.md.tmpl`, variant chosen by `owns_tests` |
| `LOGIC_LAYERS`, `EXTRACT_LOCATION` | every layer holding logic (all tested layers, plus mappers); where extracted helpers go |

## Layers (rendered once per `layers[]` entry)

| Placeholder | Source |
|---|---|
| `AGENT` | `layers[].agent` (prefixed in workspace mode) |
| `KIND` | `layers[].kind` |
| `KIND_RULES` | the `rule-packs.md` section for `layers[].kind`: `domain`, `application`, `driven-adapter`, `driving-adapter` (transports), `state`, `presentation` (view-model), `view` (humble UI component), `wiring`; none for `other` |
| `RULES` | `layers[].rules` |
| `OWNS` | `layers[].owns` with `layers[].excludes` shown as `!glob` lines |
| `FORBIDDEN_TABLE` | `layers[].forbidden` |
| `REFERENCE` | `layers[].reference` |
| `DO_NOT_COPY` | `conformance.gaps[]` whose `layers` contains this agent |
| `MAX_FILES` | `layers[].max_files`, default 3 |
| `FILE_CAPS` | every agent with its `max_files` |
| `SKILLS` | `FOUNDATION_SKILL`, `hexagonal-architecture`, `tdd`, `separation-of-concerns`, `extract-til-you-drop`, `ARCH_SKILL`; then `TESTING_SKILL` when `owns_tests: true`; `ERRORS_SKILL` for every kind except `state` and `view`; then `layers[].skills` — all comma-joined, prefixed names in workspace mode. The installer fills `layers[].skills` by kind when the optional skill is enabled: `view` → `COMPONENT_SKILL`, `PRESENTATION_SKILL`, `I18N_SKILL`; `presentation` → `PRESENTATION_SKILL`, `I18N_SKILL` |
| `EXTRA_SKILLS` | `, ` + `layers[].skills`, or empty |
| `SKILLS_PROSE`, `LAYER_ROLE`, `DEPENDS_ON_PROSE`, `PARALLEL_PROSE`, `SELF_TEST_PROSE` | `layers[]` role, depends_on, parallel_with, owns_tests |
| `OUTCOME_HINT` | ` — ` + the contract clause for `layers[].kind` (table below), then `owns_tests: true` → `; then red and green: what failed first and on what, then the green count`, otherwise `; then the gate result`. `other`: `what was built and the names a caller uses` |
| `NEXT_AGENT` | the agent's successor in the graph |

`OUTCOME_HINT` contract clause by kind — the names the next dispatch prompt is
written from (the orchestrator never opens the files):

| Kind | Contract clause |
|---|---|
| `domain` | `exported type names and every error kind added` |
| `application` | `the use-case signature and its input schema / type name` |
| `driven-adapter` | `the port name, its method signatures, and the in-memory adapter and fake names` |
| `driving-adapter` | `the entry point (route, command, topic), the use case it calls, and the error → transport mapping` |
| `state` | `the state port name, its field names and setter names` |
| `presentation` | `the presentation model's name and return shape (values, flags, handlers)` |
| `view` | `the component name, its props, and every new i18n key` (drop the key part without i18n) |
| `wiring` | rendered in `wiring-agent.md.tmpl`: what was registered where |

## Graph and agent names

| Placeholder | Source |
|---|---|
| `DOMAIN_AGENT` | the layer with `kind: domain` |
| `SCOUT_NEXT` | the scout's successor in the graph: `feature-planner` when `plan.depth: full`; otherwise `DOMAIN_AGENT` + ` (or <layers depending on it, joined with " ∥ "> if no new type, rule or error kind)` |
| `WIRING_AGENT` | the layer with `kind: wiring` |
| `SCOUT` | `plan.scout_name` — shared, never prefixed |
| `LAYER_REVIEWER` | `layer-reviewer` — shared, never prefixed |
| `TEST_AUTHOR` | `test-author`; `<prefix>-test-author` per package in workspace mode |
| `FOUNDATION_SKILL` | `implement-foundation`, or `<prefix>-implement-foundation` per package |
| `ARCH_SKILL`, `TESTING_SKILL`, `ERRORS_SKILL` | `architecture`, `testing`, `error-handling`; `<prefix>-…` per package in workspace mode |
| `ALL_ARCH_SKILLS`, `ALL_TESTING_SKILLS`, `ALL_ERRORS_SKILLS` | shared agents' frontmatter only: every package's `ARCH_SKILL` / `TESTING_SKILL` / `ERRORS_SKILL`, joined with `, `; equal to the single name when not a workspace |
| `EXTRA_REVIEW_SKILLS` | `, ` + every enabled optional skill's rendered name (all packages, comma-joined), or empty |
| `LAYER_ORDER` | the implement chain on **one line**, `a → (b ∥ c) → d`, conditions omitted — the full graph lives in `GRAPH` |
| `GRAPH`, `GRAPH_TABLE`, `LAYER_CHAIN_PROSE`, `PHASE_FOLDER_TREE`, `GREEN_GATE_SENTENCE` | `layers[]` + `plan.*` |
| `PLAN_AGENTS`, `IMPLEMENT_AGENTS`, `VERIFY_AGENTS` | emitted agent names per phase |
| `PARALLEL_PAIR_RULE` | `layers[].parallel_with` — wording in the harness comment in `parallel.md.tmpl` |
| `DISPATCH_TABLE` | `layers[].owns` → agent; scout and verify rows are static |
| `CONTRACT_EXAMPLES`, `EXAMPLE_DISPATCH_LINE`, `EXAMPLE_RECEIPT_LINE` | built from real names in `layers[]` and the exemplar |

## Verify

| Placeholder | Source |
|---|---|
| `REVIEW_CHECKLIST` | `verify.layer_reviewer_checklist` |
| `REVIEW_BASE` | the branch the diff is taken against (`origin/<default branch>`, from `git symbolic-ref refs/remotes/origin/HEAD`, else `main`) |
| `STACK_REVIEW_GREPS` | the stack pack's `## Reviewer greps` list (`stacks/<id>.md`), each tagged diff or repo; diff-scoped ones rendered to run on `$F`. Empty → the "Stack checks" lines are dropped |
| `MECHANICAL_CHECKS` | `verify.mechanical_checks`, grouped by `scope` under "Diff-scoped (on `$F`)" and "Repo-wide (compare against Known deviations)"; diff-scoped commands rewritten to read `$F`, never `src/`. Empty → the "This project's checks" lines are dropped |
| `I18N_PARITY_CHECK` | i18n enabled: a command that lists keys missing from any locale in `I18N_LOCALES` (built from `I18N_FILES`, e.g. a `jq`/script key diff per namespace); empty and dropped otherwise |

## Spec

| Placeholder | Source |
|---|---|
| `SPEC_PATH` | `plan.spec.path` |
| `SPEC_REFRESH_COMMAND` | read-only staleness check. `plan.spec.submodule`: "run `git -C <submodule dir> fetch --quiet` and `git -C <submodule dir> status -sb`; if it is behind its upstream, say so in the report — never pull, merge, init or `git submodule update` it without the user's confirmation"; else "re-read the file" |
| `SPEC_MAPPER_MENTION` | `` and `spec-mapper` `` when `plan.spec.enabled`; empty otherwise |

The spec is read-only: no template writes, commits or pushes to it.

## Stack-pack and detection slots

Filled from the stack pack (`stacks/<id>.md`, section number in brackets) and
from detection on the repo's real code. A slot with nothing true to say renders
empty, and its heading is dropped.

| Placeholder | Source |
|---|---|
| `IMPORT_TABLE` | per layer, what it may and must never import: the exemplar's real imports, `layers[]`, `verify.arch_tests.rules` |
| `PORT_RULES` | repo-specific port rules from its ports, plus the stack pack [11] |
| `SHARED_PORTS_TABLE` | shared capability ports (clock, ids, scheduler, alerter…) with their real and fake implementations, from detection |
| `STATE_RULES` | the `kind: state` layer's port, shape and exemplar store; empty when there is no state layer |
| `REFERENCE_SLICES` | extra exemplar slices, each with what it exemplifies; empty drops the list |
| `RED_STUB_TABLE` | `testing.red_stub` map rendered as a table (return shape → stub) + stack pack [5] |
| `CACHE_RULE` | stack pack [4] test-caching note; empty when the runner does not cache |
| `FAKE_PORT_TYPING` | stack pack [7] idiom for declaring a fake as the port type |
| `ERROR_COMPOSITION_IDIOMS` | stack pack [8] composition idioms for `architecture.errors.type` |
| `ERROR_BOUNDARY_RULES` | where infrastructure error types may appear (e.g. a transport error only under its adapter), from repo code + stack pack [8] |
| `TRAPS_WITH_EXAMPLES` | `architecture.errors.traps` + stack pack [8] traps, with before/after code |
| `PLATFORM_UI_RULES` | stack pack [15] subsection for `component_design.platform` |
| `PRESENTATION_PLATFORM_RULES` | stack pack [15] presentation-model rules for the platform (navigation, lifecycle) |
| `VIEW_STATE_HOOKS` | stack pack [15] names of state / effect / memo / callback primitives banned in views |
| `VIEW_REF_EXCEPTION` | stack pack [15] the narrow ref exception for imperative platform handles |
| `I18N_MISSING_MARKER` | `skills.optional.i18n.missing_marker`, else the marker already used in the repo's locale files (e.g. `TODO: translate`) |

## Hooks

| Placeholder | Source |
|---|---|
| `HARNESS_AGENTS_REGEX` | `^(` + every emitted agent name joined with `\|` + `)$` |
| `TDD_AGENTS` | layers with `owns_tests: true`, comma-separated |

## Skill names

Every filled and optional skill renders its `name:` from a placeholder, and
every cross-reference to it uses the same placeholder. In workspace mode a
skill enabled per package renders once per package as `<prefix>-<name>`;
`spec-implement` reads top-level `plan.spec` and renders once, unprefixed. A
reference to an optional skill that is not enabled is dropped (each template's
`harness:` comment says which).

| Flag | Template | Name placeholder | Emitted name |
|---|---|---|---|
| always | `skills/architecture/SKILL.md.tmpl` | `ARCH_SKILL` | `architecture` |
| always | `skills/testing/SKILL.md.tmpl` | `TESTING_SKILL` | `testing` |
| always | `skills/error-handling/SKILL.md.tmpl` | `ERRORS_SKILL` | `error-handling` |
| always | `skills/orchestrator/implement-foundation/SKILL.md.tmpl` | `FOUNDATION_SKILL` | `implement-foundation` |
| `skills.optional.i18n.enabled` | `skills/optional/i18n/SKILL.md.tmpl` | `I18N_SKILL` | `i18n` |
| `skills.optional.component_design.enabled` | `skills/optional/component-design/SKILL.md.tmpl` | `COMPONENT_SKILL` | `component-design` |
| `skills.optional.presentation_model` | `skills/optional/presentation-model/SKILL.md.tmpl` | `PRESENTATION_SKILL` | `presentation-model` |
| `skills.optional.modules` (with `architecture.modules.enabled`) | `skills/optional/modular-monolith/SKILL.md.tmpl` | `MODULES_SKILL` | `modular-monolith` |
| `skills.optional.spec_implement` (requires `plan.spec.enabled`) | `skills/optional/spec-implement/SKILL.md.tmpl` | `SPEC_SKILL` | `spec-implement` |
| `testing.naming: user-facing` | `skills/optional/test-naming/SKILL.md.tmpl` | `TEST_NAMING_SKILL` | `test-naming` |

## Optional skills

| Placeholder | Source |
|---|---|
| `I18N_LOCALES` | `skills.optional.i18n.locales`, comma-joined |
| `I18N_RULE` | `skills.optional.i18n.rule` (namespace rule), plus the namespaces found in the locale files |
| `I18N_CALL` | the translation call idiom, from the repo's translated code (e.g. the hook/function and how a namespace is chosen) |
| `I18N_FILES` | locale file path formula, from the repo (e.g. `<root>/<locale>/<namespace>.<ext>`) |
| `COMPONENT_PLATFORM` | `skills.optional.component_design.platform` |
| `COMPONENT_TIERS_TABLE` | the repo's component tiers: `\| Tier \| Path \| What lives here \| Example \|`, from its folders |
| `COMPONENT_PREVIEW_RULE` | `skills.optional.component_design.preview` — wording in the template's `harness:` comment; section dropped when `none` |
| `PRESENTATION_NAME` | what the repo calls a presentation model (view-model, presenter …) |
| `PRESENTATION_PATH` | path formula of a presentation-model file, from the repo |
| `PRESENTATION_ACCESS` | how a presentation model reaches use cases and read-only state, from the repo's code (context, injected facade, constructor) |
| `FORM_BINDING_RULE` | the form library and how it binds the use case's input schema (from `architecture.validation` + repo code); section dropped when there are no forms |
| `MODULE_UNIT` | `architecture.modules.unit` |
| `MODULE_LAYOUT` | the repo's module tree, from its layout |
| `MODULE_PUBLIC_SURFACE` | how a module publishes its contract, from the repo |
| `SHARED_KERNEL_PATH` | path of the shared kernel module |
| `MODULE_ENFORCEMENT` | what makes a cross-module violation fail the build (visibility, references, linter rule), or "review only" |
| `TEST_NAME_SHAPE` | the repo's test-label structure, from its best-named existing tests |
