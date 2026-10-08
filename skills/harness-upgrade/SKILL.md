---
name: harness-upgrade
description: "Upgrade an installed coding harness to the current templates. Use when asked to 'upgrade the harness', 're-render .claude from harness.yml', 'pull the new harness version', or after the coding-harness plugin was updated. Migrates a v1 .claude/harness.yml to v2, re-renders every file, and preserves local hand-edits by asking per file — never overwrites silently."
---

# harness-upgrade

You re-render an installed harness from its committed `.claude/harness.yml`
against newer templates, without losing what the team changed by hand.

## Where the harness lives

HARNESS_ROOT = `${CLAUDE_PLUGIN_ROOT}`

If the value above still reads as a dollar-brace variable rather than an
absolute path, you are standalone: HARNESS_ROOT is the repository two
directories above this file, or — if this file was copied out of it — a
coding-harness checkout the user points you at. Confirm
`HARNESS_ROOT/harness.schema.yml` exists.

Use `HARNESS_ROOT/skills/harness-init/SKILL.md` for the render rules,
`HARNESS_ROOT/templates/PLACEHOLDERS.md` for the placeholder map, and
`HARNESS_ROOT/skills/harness-init/CHECKLIST.md` to verify. This skill only adds
what is different about upgrading.

## Rules

- **Never overwrite silently.** Every file whose current content differs from
  what the old templates would have produced is a hand-edit until proven
  otherwise.
- **The manifest is the source of truth**, the templates are the mechanism, and
  the hand-edits are evidence. A hand-edit that encodes a fact belongs in the
  manifest; one that softens an invariant does not survive.
- **Read-only until confirmed.** Plan the whole upgrade, show it, then write.
- Same security rules as `harness-init`: show and wait before any command that
  installs, restores or fetches.
- **Settings survive.** `.claude/settings.json` and `.claude/settings.local.json`
  are never re-rendered: every existing key (`enabledPlugins`, `permissions`,
  `hooks`, `env`, `model`) is kept. The only change allowed is the receipt-hook
  merge. `settings.local.json` is never edited.
- **No rule disappears silently.** Before writing, run the lost-rules check
  (step 4b). A rule the installed harness carries that the re-render does not
  is moved into the manifest or dropped with the user's consent — never lost
  as a side effect of taking NEW.

## Procedure

### 1. Read the install

- `.claude/harness.yml` missing → this harness was not installed by
  `harness-init` or the manifest was not committed. Stop and offer
  `harness-init`; it can read the existing `.claude/` as a strong hint.
- Read `harness_version` (absent = 1), every rendered file, and
  `git log --oneline -- .claude/ <memory_file>` to see which files were edited
  after the install commit.

### 2. Migrate the manifest (v1 → v2)

Apply mechanically, then list every inferred value for confirmation:

| v1 | v2 |
|---|---|
| absent `harness_version` | `harness_version: 2` |
| `project.kind: backend` | `service` (ask if it is a `worker`, `cli` or `library`) |
| `project.kind: frontend` | `web-app` or `mobile-app` from frameworks (Expo / React Native → mobile) — ask |
| absent `project.stack` | from `language` / lockfiles; must name a `stacks/` pack or `<other>` |
| `commands.gate: "<string>"` | `commands.gate: ["<string>"]` |
| `architecture.error_type` | `architecture.errors.type` |
| `architecture.never_throw` | `architecture.errors.never_throw` |
| error discrimination described in layer rules / error-handling skill | `architecture.errors.discriminate_by`, `classification`, `traps` — extract, do not invent |
| validation library in layer rules | `architecture.validation` |
| absent `architecture.shape` | by kind: `service, web-app, mobile-app, worker, fullstack` → `full`; `cli` → `minimal`; `library` → `library` |
| `layers[]` without `kind` | infer from role and owns with the harness-init DETECTION **kind-mapping table** (domain types / rules → `domain`; use cases / cores → `application`; repositories, clients → `driven-adapter`; HTTP handlers, CLI commands, consumers → `driving-adapter`; view-models / presenters → `presentation`; UI components → `view`; stores → `state`; composition → `wiring`) and **ask** for each |
| a component / UI layer with `kind: presentation` or `driving-adapter` (v1 had no `view` kind) | `kind: view`; tell the user the rule pack changes (no behavioural UI state, render props) |
| a view-model / presenter layer with `kind: driving-adapter` | `kind: presentation` |
| `state` ∥ `driven-adapter` with the state port in the adapter layer's `owns` | move the state-port glob to the state layer's `owns`, add it to the adapter layer's `forbidden` with the state agent as owner |
| `testing.red_stub` one string, layers of different return shapes | the stack pack's §5 map form, only the shapes present; show which key each layer renders |
| absent `emit.always_on_skills` | the skills the installed memory file `@`-imports, minus invariants and `architecture`; else propose per DETECTION Sweep 6 with the context cost |
| absent `emit.runner_model` | the `model:` on the installed gate / test-runner agents, if not `inherit` |
| `emit.cursor_compat: true` with no `.cursor/rules/**` / `.cursor/agents/**` | propose `false`; ask |
| `carry_forward` entries copied from a file the memory file `@`-imports | remove them; keep the import |
| `verify.mechanical_checks` diff checks that grep the whole tree | rewrite over `$F` (changed files); add the stack pack's §14 checks the manifest lacks, run once against the exemplar |
| no `kind: domain` layer | the user picks which layer is the domain, or adds one; it moves first in the chain with `owns_tests: true` |
| absent `excludes`, `max_files` | `[]`, `3` |
| absent `testing.red_stub`, `spy_technique`, `doubles.typed_as_port` | from the stack pack; `typed_as_port: true` |
| absent `verify.arch_tests` | run harness-init DETECTION Sweep 5; propose `existing`, `generate` or `none` |
| absent `emit.hooks.receipt_check` | `false` — offer it, opt-in, exactly as harness-init step 2.11 |
| workspace with one root `implement-foundation`, prefixed `test-runner` / `layer-reviewer` | re-render per harness-init "Workspace rendering": `<prefix>-implement-foundation` per package; shared agents unprefixed with every package's skills in `skills:`; delete the old files only after confirmation |
| `plan.spec.sync_agent` / `plan.spec.commit_format` (the spec-sync step was removed: the harness reads the spec only and never writes, commits or pushes it) | drop both fields. List an installed `.claude/agents/verify/spec-sync*` or `prd-sync*` agent for deletion and delete it only after the user confirms. The workflow graph, `parallel.md` and the memory file (dispatch row, standing-authorization sentence) re-render without the spec-sync step |
| single package that is now a monorepo | offer workspace form; this is a re-detection, not a migration — run harness-init DETECTION Sweep 0–2 for the new packages |

Validate the migrated manifest against `harness.schema.yml`: every required
field present, exactly one domain layer, ownership disjoint after excludes
(CHECKLIST mechanical item). Show the migrated manifest as a diff against the
committed one and get confirmation before rendering anything.

### 3. Render to a staging area

Render the full harness from the confirmed manifest into a scratch directory,
not into `.claude/`. Also render the **base**: the old manifest against the
templates of the installed version, if you can obtain them (the plugin's
previous version, or `git show <tag>:templates/...` in a checkout). No base
available → treat the committed file itself as the base and say every
difference will be shown as a possible hand-edit.

### 4. Three-way compare, per file

For each target file, with BASE (old render), LOCAL (committed), NEW (staged):

| Case | Action |
|---|---|
| LOCAL = BASE | template change only → take NEW |
| LOCAL = NEW | nothing to do |
| LOCAL ≠ BASE, NEW = BASE | hand-edit only → keep LOCAL |
| all three differ | **conflict** → ask |
| file only in NEW | new file → list, take after confirmation |
| file only in LOCAL, was rendered before | removed by templates → ask (delete or keep as project-local) |
| file only in LOCAL, never rendered | project-local addition → keep, never touch |

For each conflict, show a short summary — not a full diff unless asked:

```text
.claude/agents/implement/domain-builder.md
  template:  + red-stub rule; max_files now from manifest
  local:     + rule "never import pkg/legacy"; tightened description
  proposal:  take NEW, move the local rule into layers[domain-builder].rules
```

Options per file: take NEW, keep LOCAL, merge (show the merged result first),
or move the local edit into the manifest and take NEW. Prefer the last — it is
what makes the next upgrade clean.

**Invariant files are not negotiable.** `receipt.md`,
`hexagonal-architecture`, `tdd`, `separation-of-concerns`, and the
non-placeholder text of `extract-til-you-drop` take NEW. `tdd` has no
placeholders any more: a v1 `tdd` that carried commands takes NEW whole; the
commands now reach agents through `implement-foundation`. A local edit there is reported as
drift: if it encodes a real repo fact, it goes into the manifest or
`conformance`; if it softens a rule, it is dropped and the user is told why.

**Settings.** `settings.json` and `settings.local.json` are not part of the
three-way compare: they are kept as LOCAL. If the hook is enabled, merge it into
`settings.json` exactly as harness-init does (append / replace the receipt-check
group, never clobber; every other key kept). Update
`.claude/hooks/receipt-check.sh` to the new template; it is invariant.

### 4b. Lost-rules check (installed → re-rendered)

For every file in LOCAL, split it into rules (bullet, table row, checklist
item, trap, grep line). For each rule find the NEW file that still carries it
— same file, or another one (a slot, a rule pack, the manifest's
`layers[].rules`, `verify.mechanical_checks`, `carry_forward`). Show the
unmapped ones as a table:

```text
LOST  .claude/agents/verify/layer-reviewer.md:118  rg 'reaction\(' src/shared/app
      proposal: add to verify.mechanical_checks (scope: repo)
LOST  .claude/skills/component-design/SKILL.md:88  "Touch targets are at least 44x44"
      proposal: pack §15 rule → PLATFORM_UI_RULES (already rendered? no — enable platform: react-native)
```

Each LOST rule: move it into the manifest (preferred — the next upgrade is then
clean), keep the LOCAL file / hunk, or drop it with the user's explicit
consent. A dropped rule that softened an invariant is reported as such. The
upgrade does not write until every LOST line is resolved.

### 5. Write, verify, report

1. Write the agreed files and the migrated `.claude/harness.yml`.
2. Run harness-init's CHECKLIST, including "Settings preserved" and the "Lost
   rules" section with LOCAL as the old harness (show-and-wait for commands that
   run project code).
3. Report: manifest fields migrated, files updated / kept / merged / added /
   removed, hand-edits moved into the manifest, LOST rules and how each was
   resolved, drift dropped from invariant files, checklist results. Suggest one commit for the whole upgrade.

## What not to do

- Do not re-detect from scratch unless the user asks or the repo shape changed
  (single → workspace). The manifest was confirmed once; respect it.
- Do not resolve a conflict by picking the newer file because it is newer.
- Do not carry a softened invariant forward to avoid an awkward question.
- Do not drop a settings key, or a rule, because the new templates do not
  mention it.
