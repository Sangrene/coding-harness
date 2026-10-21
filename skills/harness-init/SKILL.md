---
name: harness-init
description: "Install the orchestrator / receipt-enforced TDD / hexagonal-architecture coding harness into a target repository, any stack, single package or monorepo. Use when asked to 'set up the harness', 'install the orchestrator pattern', 'add the agents and skills to this repo', 'generate .claude for this codebase', or to adapt this harness to a new project. Detects the codebase's real layers, commands and conventions (read-only), writes .claude/harness.yml for confirmation, then renders the agents, skills, memory files and optional arch tests and receipt hook."
---

# harness-init

You install a coding harness into a target repository: an orchestrator pattern
with phase-scoped subagents, receipt-enforced TDD, an architecture skill set, a
boundary reviewer, and — on request — language-native arch tests and a receipt
hook.

The harness is **derived from the target codebase**, never copied from an
example. Your job is 80% detection and 20% rendering.

## Where the harness lives

HARNESS_ROOT = `${CLAUDE_PLUGIN_ROOT}`

If the value above still reads as a dollar-brace variable rather than an
absolute path, you are running **standalone**, not as a plugin:

- read directly from a checkout → HARNESS_ROOT is the repository containing this
  file, two directories above it (`<root>/skills/harness-init/SKILL.md`);
- copied out of the repo (e.g. `~/.claude/skills/harness-init/`) → there is no
  root above it. Ask the user for the path to a coding-harness checkout.

Either way, confirm `HARNESS_ROOT/harness.schema.yml` exists before going on.
Every path below is relative to HARNESS_ROOT unless it says *target*:

| What | Path |
|---|---|
| Manifest schema — the contract | `harness.schema.yml` |
| Templates | `templates/` |
| Placeholder → manifest field map — the authority | `templates/PLACEHOLDERS.md` |
| Kind rule packs for implement agents | `templates/agents/implement/rule-packs.md` |
| Per-package memory template | `templates/PACKAGE-CLAUDE.md.tmpl` |
| Receipt hook + settings snippet | `templates/hooks/` |
| Stack packs | `stacks/<stack>.md`; `stacks/_template.md` for an unlisted language |
| Detection procedure | `DETECTION.md`, beside this file |
| Acceptance checklist | `CHECKLIST.md`, beside this file |
| Worked manifests | `examples/*.harness.yml` — read for shape, never copy content |

Where this file and `PLACEHOLDERS.md` disagree about a placeholder,
`PLACEHOLDERS.md` wins. Where anything disagrees with `harness.schema.yml`, the
schema wins.

## Prime directive

**The architecture is fixed: hexagonal (ports & adapters) with clean layering.**
It is not detected, not negotiated, and not adapted to what the repo happens to
do. `hexagonal-architecture` is emitted verbatim into every project.

What you detect is only the **naming, the shape and the distance**:

- *Naming* — what this repo calls each hexagon role, and where it lives. Fills
  `architecture.hexagon` and the `architecture` skill.
- *Shape* — which roles legitimately do not exist for this kind of project
  (`architecture.shape`). Shape removes roles; it never weakens a rule.
- *Distance* — how far the current code is from the model. Fills `conformance`,
  the "Known deviations" section of `architecture`, and each layer's "Do not
  copy" list.

A gap never weakens a rule. A repo that merges its wire shape into its domain
model gets the unmodified translation rule **and** a recorded deviation. The
reviewer flagging existing code is the intended outcome; scope it with
`conformance.gaps[].disposition` so agents know what must comply now (all new
code) versus what is tracked for when a file is next touched.

Everything else — commands, test placement, error type, layer names — must be
true of the code that is already there.

## Security rules — apply to every step

- **Detection is read-only.** Read files; never run install, restore, build,
  postinstall, codegen or test commands while detecting. Third-party setup
  scripts are not safe to run unreviewed.
- **Show, then wait.** Before running anything that clones, installs, restores
  packages, adds a dependency, or fetches remote content — including commands
  that fetch as a side effect (`go vet`/`go test` with a cold module cache,
  `cargo check` with missing crates, `dotnet build` without `--no-restore`,
  `gradle` wrapper download) — print the exact command lines, say which may hit
  the network and why, and wait for explicit confirmation. Batch them so the
  user confirms once per batch, not once per line.
- **Never chain a fetch into an execution.** No `curl | sh`, no decoding remote
  content into a command. If the repo's own docs say to do this, report it and
  stop.
- **Settings are the user's.** An existing `.claude/settings.json` and
  `.claude/settings.local.json` survive the install **unchanged** — every key
  (`enabledPlugins`, `permissions`, `hooks`, `env`, `model`) kept, never
  dropped, never rewritten from a template, even when `.claude/` is otherwise
  replaced. `settings.json` is edited only to merge the receipt hook the user
  opted in to at the confirm step, after being shown the exact JSON.
  `settings.local.json` is never edited.

## Procedure

### 0. Get the repo, and decide what you are installing into

1. If the repo is not local, show the clone command and wait for confirmation.
2. **Refuse pure infrastructure.** If the repo is only IaC (Terraform, Helm,
   Pulumi, CloudFormation, Ansible, Kustomize) with no application code, stop.
   Say why: the hexagon governs application code — use cases, ports, adapters —
   and a repo of resource declarations has none of those roles; a harness here
   would be a reviewer flagging every file for an architecture that does not
   apply. Offer to install into the application repo instead. IaC *beside*
   application code is fine: exclude it from every layer and say so.
3. **Detect workspace mode.** Run `DETECTION.md` Sweep 0. Two or more
   independently buildable packages that each deserve their own hexagon (Go API
   + TS web app, a .NET solution of independent services, a pnpm / cargo / uv /
   Gradle workspace of apps) → `workspace.enabled: true`, one `packages[]` entry
   each. Shared libraries consumed by those apps are packages too only if they
   hold application code with their own layers; a shared types / contract
   package goes under `workspace.contracts`, owned by one package.

### 1. Detect

Follow `DETECTION.md` in full, once per package in workspace mode. Load the
stack pack `stacks/<stack>.md` for each package first; it supplies the
detection signals, command idioms, red-stub rule, error idioms and arch-test
recipe. No pack for the language → read `stacks/_template.md` and fill the same
fields by hand from the code, and say so at the confirm step.

Produce a draft `harness.yml` per `harness.schema.yml`, `harness_version: 2`.

Delegate the sweeps — they are read-only, parallel, and their file dumps do not
belong in your context. One agent per axis (commands, hexagon + layers, testing,
errors + validation), per package, each reporting a receipt. Practice the
pattern you are about to install.

### 2. Confirm

Show the user the draft `harness.yml` and, in plain prose:

1. **Workspace map** (workspace mode only) — package, path, prefix, stack, kind,
   shape, layer chain; the contracts between packages and their owners; and the
   rule that a cross-package change is two chains sequenced by the contract.
2. **Stack pack used** per package — `stacks/<id>.md`, or "no pack — filled by
   hand from the code" with the fields that were hardest to settle.
3. **Shape** — `full | minimal | library`, why (from `project.kind`), and each
   role marked `absent: by-shape`.
4. **The hexagon mapping** — which file is which role, role by role. Getting
   this wrong makes every downstream rule point at the wrong file.
5. **The conformance report.** Level, then each gap: what the code does instead,
   how many files, proposed disposition. A `partial` repo will see
   `layer-reviewer` findings on day one; say so.
6. The layer chain, its `kind`s, and who owns which files — `owns` minus
   `excludes`.
7. Which layers own tests, and that `done` requires a red run then a green one.
   If the repo has no tests at all, the user chooses: adopt TDD going forward
   (default) or do not install.
8. The commands the agents will run, and which of them may fetch dependencies.
9. **Divergences recorded, not changed** — e.g. a mocking framework where the
   harness defaults to hand-written fakes. The harness keeps the repo's norm for
   existing tests and states the default for new ports; the user picks.
10. **Arch tests.** `existing` → the command found. `generate` → the tool, any
    package it must add (exact command, via `commands.add_dependency` when the
    tool belongs to the stack's dependency manager, plus the manifest and
    lockfile changes it will cause — e.g. a new `devDependencies` entry, a new
    `arch` script, a lockfile update), and the **exact files to write** with
    their full content and the rules each encodes; gaps with disposition
    `migrate` appear as named exceptions, never as a weakened rule. `none` →
    reviewer greps only.
11. **Receipt hook (opt-in, default off).** Explain it in two sentences: a
    SubagentStop hook that sends a harness agent back when its final message is
    not a valid receipt (six one-line fields at the very end; several BLOCKERS
    joined with "; "), or when a test-owning builder reports `done` with an
    OUTCOME lacking the words "red" and "green". Show the exact script path
    it will write and the exact JSON it will merge into `.claude/settings.json` — rendered, with the real
    agent regex and TDD agent list, not the placeholders. Ask yes/no.

12. **Existing harness** (target `.claude/` already present — DETECTION
    Sweep 7):
    - settings files kept as they are (name the keys, e.g. `enabledPlugins`),
      and the receipt-hook merge, if any, shown as a diff against them;
    - **lost-rules check**: a table of every rule in the old harness → the v2
      file (and slot or manifest field) that now carries it. Every rule maps to
      a v2 file or is listed as **dropped**, and nothing is dropped without the
      user saying so; a softened invariant is listed as dropped with the reason.
      Then diff the old and the draft new file sets: every old agent / skill
      file is either re-rendered, absorbed (name where), or removed with
      consent;
    - carried values: `emit.runner_model` (ask if two old files disagree).
13. **Kinds checked** against the DETECTION kind-mapping table: components are
    `view`, view-models `presentation`, transports `driving-adapter`; and, for
    parallel `state` ∥ `driven-adapter` layers, the state port owned by the
    state agent.
14. **Memory-file context cost**: `@`-imports kept (e.g. `@AGENTS.md`, not
    copied into `carry_forward`; never a skill), and `emit.cursor_compat` (default `false`; `true` only if the
    user confirms they run the agents from Cursor).

Ask about anything detection could not settle — in particular which pattern is
the intended exemplar when two conflict, the disposition per gap, and the
`kind` of any layer you inferred. Do **not** ask whether to enforce hexagonal
architecture; that is settled.

Do not render until the user confirms. This is the one blocking question in the
whole procedure; everything after it is mechanical, except the command batches
the security rules require you to show.

### 3. Render

Fill every template from the confirmed manifest using `templates/PLACEHOLDERS.md`.
Which optional agents and which agent template per layer to emit is decided by
the emit table in `templates/agents/optional-agents.md` ("What is emitted, and
when"). Agent files take the manifest's `emit.agent_suffix` (`.md` or
`.agent.md`), written `<sfx>` below; the frontmatter `name` is the file name
minus `<sfx>`. Target layout, single package (paths in the *target* repo):

```text
<emit.memory_file>                                    CLAUDE.md.tmpl
.claude/harness.yml                                   the confirmed manifest
.claude/skills/orchestrator/SKILL.md                  SKILL.md.tmpl
.claude/skills/orchestrator/receipt.md                verbatim
.claude/skills/orchestrator/parallel.md               parallel.md.tmpl
.claude/skills/implement-foundation/SKILL.md          orchestrator/implement-foundation/SKILL.md.tmpl
                                                      --- invariant ---
.claude/skills/hexagonal-architecture/SKILL.md        verbatim
.claude/skills/tdd/SKILL.md                           verbatim (no placeholders)
.claude/skills/separation-of-concerns/SKILL.md        verbatim
.claude/skills/extract-til-you-drop/SKILL.md          LOGIC_LAYERS, EXTRACT_LOCATION only
                                                      --- filled ---
.claude/skills/architecture/SKILL.md
.claude/skills/testing/SKILL.md
.claude/skills/error-handling/SKILL.md
                                                      --- optional (templates/skills/optional/<name>/) ---
.claude/skills/i18n/SKILL.md                          skills.optional.i18n.enabled
.claude/skills/component-design/SKILL.md              skills.optional.component_design.enabled
.claude/skills/presentation-model/SKILL.md            skills.optional.presentation_model
.claude/skills/modular-monolith/SKILL.md              skills.optional.modules
.claude/skills/spec-implement/SKILL.md                skills.optional.spec_implement
.claude/skills/test-naming/SKILL.md                   testing.naming: user-facing
                                                      --- agents ---
.claude/agents/plan/<scout><sfx>                      scout.md.tmpl
.claude/agents/plan/<planner, architecture-gate><sfx> only when plan.depth: full
.claude/agents/implement/<agent><sfx>                 _layer-builder.md.tmpl + rule pack for its kind (every layer not kind: wiring)
.claude/agents/implement/<wiring agent><sfx>          wiring-agent.md.tmpl (the kind: wiring layer; never for shape: library)
.claude/agents/verify/<gate_name><sfx>                gate.md.tmpl (gate + targeted tests)
.claude/agents/verify/layer-reviewer<sfx>
.claude/agents/<optional><sfx>                        per the emit table in templates/agents/optional-agents.md
<verify.arch_tests.path>                              when arch_tests.status: generate
.claude/hooks/receipt-check.sh                        when emit.hooks.receipt_check
.claude/settings.json                                 kept as found; receipt hook merged in when emit.hooks.receipt_check
.claude/settings.local.json                           kept as found, never edited
```

Per-layer values the layer-builder template needs:

- **`RED_STUB`** — when `testing.red_stub` is a string, every layer gets it.
  When it is a map, each layer gets the entry for **its** return shape:
  `domain` → `sync` (plus `async` if its rules return async results),
  `application` / `driven-adapter` → `async`, `presentation` → `hook`,
  `view` → `component`, `state` → `state` (fall back to `sync`). Where
  `RED_STUB` appears in a shared file (the foundation skill), render the whole
  map as a shape → stub table. The same stub sentence never appears twice in
  one agent file.
- **Rule pack by `kind`** — `view` layers get the `view` pack (humble
  component: no `useState` / `useEffect` / `useMemo` / `useCallback` holding
  behavioural state, the narrow `useRef` exception) plus `PLATFORM_UI_RULES`
  from the pack's §15; `presentation` layers get the `presentation` pack plus
  `PRESENTATION_PLATFORM_RULES`. A layer whose kind contradicts the DETECTION
  kind-mapping table is fixed in the manifest before rendering.
- **`STACK_REVIEW_GREPS` / `MECHANICAL_CHECKS`** — `scope: diff` checks render
  over `$F` (the changed-file list the reviewer computes first), never over
  the whole source tree; `scope: repo` checks render as repo-wide.

`implement-foundation` goes at `.claude/skills/implement-foundation/`, not
nested under `orchestrator/`: agents preload it by name, and only top-level
skill directories are discovered. If `templates/` gains or renames a file,
`PLACEHOLDERS.md` is the list; this table is the expected shape.

#### Workspace rendering

Per the schema's `workspace` section:

- **Once, at the root:** invariant skills (`hexagonal-architecture`, `tdd`,
  `separation-of-concerns`, `extract-til-you-drop`), `orchestrator` (with
  `receipt.md` and `parallel.md`), `.claude/harness.yml`, the hook.
- **Per package, prefixed:** filled skills and the foundation skill as
  `.claude/skills/<prefix>-architecture/`, `<prefix>-testing/`,
  `<prefix>-error-handling/`, `<prefix>-implement-foundation/` (it carries the
  package's commands), plus that package's enabled optional skills as
  `<prefix>-<name>/`; layer agents (builders and the wiring agent) as
  `.claude/agents/implement/<prefix>-<agent><sfx>` with
  `name: <prefix>-<agent>`; the gate as `<prefix>-<gate_name>`. Every
  cross-reference inside a package's files — `skills:` lists, `NEXT:`,
  forbidden-owner names, dispatch rows — uses the prefixed names.
- **Shared, unprefixed:** `scout`, `feature-planner`, `architecture-gate`,
  and `layer-reviewer` (`{{LAYER_REVIEWER}}` renders
  unprefixed). Their `skills:` frontmatter is one comma
  list holding every package's skill names (`api-architecture,
  web-architecture, …`); each reads the `<prefix>-*` skills of the package whose
  paths it is working on.
- **Root memory file:** workspace map, routing table (path glob → package →
  its chain), contracts and owners, and the cross-package rule.
- **`<package.path>/CLAUDE.md`** from `PACKAGE-CLAUDE.md.tmpl`: that package's
  commands, graph and dispatch table. If the package already has a `CLAUDE.md`,
  do not overwrite it — show the diff and ask, or append a delimited harness
  section.
- **Ownership globs are rendered from the repo root** (`services/api/internal/**`),
  so disjointness can be checked across the whole workspace.
- **Commands run from `{{WORKDIR}}`.** `{{WORKDIR}}` renders as `.` outside
  workspace mode and as the package path inside it. Render the package's
  `commands.*` verbatim; the gate and test commands run from `{{WORKDIR}}`,
  which the templates state in the package's memory file, foundation skill and
  gate agent.

#### Rendering rules

- **No placeholder survives.** Check with the regex `\{\{[A-Z][A-Z0-9_]*\}\}` —
  plain `{{` false-positives on Go templates, Handlebars and Jinja in the target.
- **Strip render instructions.** Templates carry `<!-- harness: ... -->`
  comments addressed to you. Follow them, then delete them; none may reach the
  output.
- **Frontmatter is the first line.** Every agent and skill file starts with
  `---` on line 1. Any comment above the frontmatter is dropped, not rendered.
- **Invariant skills are never rewritten per project.** `hexagonal-architecture`,
  `tdd`, `separation-of-concerns` and `receipt.md` are byte-identical to their
  templates; `extract-til-you-drop` takes only `LOGIC_LAYERS` and
  `EXTRACT_LOCATION`. Project commands reach the loop through
  `implement-foundation`, never through `tdd`. A repo that does not
  practise the rule gets the rule plus a `conformance` gap, never a softer rule.
- **Do not duplicate an invariant skill into a filled one.** `architecture` maps
  roles to paths; it does not restate the dependency rule. `testing` says where
  files go; the loop lives in `tdd`.
- **Rule packs, not repetition.** Each implement agent gets the rule pack for
  its `kind` from `rule-packs.md`, then its own `rules:`. Do not copy pack rules
  into `rules:`.
- **Per-layer `skills:` lists extras only.** The base set comes through
  `implement-foundation`.
- **Every example is from the target repo.** One borrowed path, type or command
  teaches the agent the wrong vocabulary.
- **Disjoint ownership after excludes.** Verify mechanically (CHECKLIST); fix
  the manifest, never the templates.
- **The exemplar slice must actually conform**, or have its deviations named
  inline. Agents pattern-match the exemplar harder than any prose.
- **Keep the invariants verbatim** — receipt schema, dispatch-is-a-tool-call,
  no meta-orchestrator, never-pre-clear, visibility protocol, green-receipt gate.

#### Arch tests (when `verify.arch_tests.status: generate`)

Follow the stack pack's "Arch tests" recipe. Treat them as tests, so TDD-style:

1. Run the confirmed dependency-add command, if any (shown at confirm).
2. Write exactly the files shown at confirm. One rule per test, named for the
   dependency rule it encodes. `migrate` gaps are explicit, named exceptions
   that cite the gap; `enforce-now` gaps have none.
3. Run them. They must pass on the current code with the exceptions in place.
   A failure is either a gap detection missed (record it, go back to the user)
   or a wrong rule (fix the test) — never a reason to widen an exception.
4. If cheap — one scratch file, one run — seed a violation (e.g. a domain file
   importing an adapter), watch the relevant test fail, delete the scratch file,
   re-run green. If not cheap, skip and say so.
5. Record the command in `commands.arch_test`, add it to the gate agent's
   command list after the compile gate, and add the test paths to the owning
   layer's `owns` (normally the composition root / wiring layer, or a dedicated
   architecture path excluded from every builder).

#### Receipt hook (when `emit.hooks.receipt_check: true`)

1. Copy `templates/hooks/receipt-check.sh` to target
   `.claude/hooks/receipt-check.sh`, unchanged, and make it executable.
2. Render `templates/hooks/settings.snippet.json`:
   - `{{HARNESS_AGENTS_REGEX}}` → `^(<every emitted agent name, |-joined>)$` —
     plan, implement and verify agents, prefixed layer and gate agents in
     workspace mode, shared agents unprefixed. Names are the frontmatter `name`
     (file name minus `emit.agent_suffix`), never the file name, so
     `.agent.md` does not leak into the regex. Only harness agents: built-in
     agents (Explore, general-purpose) do not emit receipts.
   - `{{TDD_AGENTS}}` → comma-joined names of agents with `owns_tests: true`,
     no spaces. None → drop the `--tdd {{TDD_AGENTS}}` argument entirely.
3. Merge into target `.claude/settings.json` — **never clobber**:
   - absent → write the rendered snippet;
   - present → parse it, keep every existing key, append the rendered matcher
     group to `hooks.SubagentStop` (create the arrays if missing). If a group
     already runs `.claude/hooks/receipt-check.sh`, replace that group only.
   - Write it back, then parse it again (`jq . .claude/settings.json` or
     `python3 -m json.tool`) to prove it is valid JSON.
4. The JSON written must be the JSON shown at confirm. If it differs, show the
   new version and ask again.

#### Existing `.claude/` (re-install over a hand-made or older harness)

1. Before writing, copy the old `.claude/` and memory file to a scratch
   directory — the lost-rules check (confirm item 12) and CHECKLIST compare
   against it.
2. Write the new files. Keep `settings.json` and `settings.local.json` byte-for-
   byte, except the confirmed receipt-hook merge into `settings.json`.
3. Files from the old harness that the confirmed plan marks *absorbed* or
   *removed* are deleted only now, and only those. Anything else not
   re-rendered is project-local: keep it.

### 4. Verify

Run `CHECKLIST.md` against the rendered output. Report each item pass / fail.
Fix every fail before reporting done. Commands the checklist runs follow the
security rules: show the batch, wait, then run.

### 5. Prove it

Offer a dry run: the user names a small real feature; walk the graph for it —
scout, one implement layer, gate — posting dispatch lines and receipts. Nothing
proves a harness like one green receipt from it.

Then tell the user to commit `.claude/harness.yml` with the rest: it is what
`harness-upgrade` re-renders from and what `harness-doctor` checks against.

## What not to do

- Do not copy another project's skills because the stack matches. Conventions
  differ between two repos in the same language.
- Do not emit an agent with no distinct file ownership.
- Do not emit `impact-scout` without `.codegraph/`, or a spec agent without a
  spec file. An agent whose tool is absent is a trap.
- Do not soften the receipt contract to make an agent "more helpful".
- Do not add an ownership hook, a permission rule, or any settings change other
  than the opted-in receipt hook. Do not drop an existing settings key.
- Do not replace an existing harness without the lost-rules check: a rule the
  team relied on that silently disappears is the most expensive regression an
  install can cause.
- Do not silently replace the repo's test-double norm. Record the divergence.
