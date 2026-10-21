---
name: harness-doctor
description: "Read-only health check of an installed coding harness. Use when asked to 'check the harness', 'is the harness still valid', 'harness doctor', or when agents start failing on stale paths or commands. Runs the acceptance checklist's mechanical and contract items, detects drift between .claude/harness.yml and the rendered .claude/ files, finds stale owns globs and commands that no longer run, and reports pass/fail. Changes nothing."
---

# harness-doctor

You check an installed harness and report. You never edit, render or fix — the
fix is `harness-upgrade` (template or manifest drift) or a manifest edit plus
re-render. Your value is being read-only and exact.

## Where the harness lives

HARNESS_ROOT = `${CLAUDE_PLUGIN_ROOT}`

If the value above still reads as a dollar-brace variable rather than an
absolute path, you are standalone: HARNESS_ROOT is the repository two
directories above this file, or — if copied out of it — a coding-harness
checkout the user points you at. Confirm `HARNESS_ROOT/harness.schema.yml`
exists. The checklist is `HARNESS_ROOT/skills/harness-init/CHECKLIST.md`.

## Procedure

### 1. Load

Read target `.claude/harness.yml`. Missing → report `FAIL: no manifest` and
stop; offer `harness-init`. `harness_version` below 2 → report it and continue
with the checks that do not depend on v2 fields; recommend `harness-upgrade`.

### 2. Checks that need no command execution

Run each; record pass / fail with the evidence (path, line, glob).

1. **CHECKLIST Mechanical**, every item that is a read: placeholder regex,
   frontmatter on line 1, names equal file names minus `emit.agent_suffix`,
   `skills:` resolve, `NEXT:` and
   forbidden owners resolve, ownership disjoint after excludes, referenced
   paths exist, workspace prefixes unique.
2. **CHECKLIST Contract integrity**: invariant files byte-identical to
   `HARNESS_ROOT/templates` (`cmp`) — `receipt.md`, `hexagonal-architecture`,
   `tdd`, `separation-of-concerns`; `extract-til-you-drop` differs only at
   `LOGIC_LAYERS` / `EXTRACT_LOCATION`; one domain layer, first; reviewer and gate read-only.
   A template newer than the install is **template drift**, not a failure —
   report it separately with the file list.
3. **Manifest ↔ files drift**:
   - every `layers[]` entry has its agent file, and every implement agent file
     has a `layers[]` entry;
   - each agent's owned-files block equals its manifest `owns` / `excludes`;
   - the gate agent's commands equal `commands.gate` (+ `commands.arch_test`);
   - the targeted-test command in skills and agents equals
     `commands.test_targeted` (or the layer override);
   - the memory file's dispatch table covers exactly the manifest's layers;
   - `emit.hooks.receipt_check` agrees with `.claude/settings.json` and the
     presence of `.claude/hooks/receipt-check.sh`; the matcher regex lists
     exactly the emitted agents; `--tdd` lists exactly the `owns_tests: true`
     agents. A stale regex silently stops checking a new agent.
   - workspace: every package has its prefixed layer and gate agents, its
     `<prefix>-architecture`, `-testing`, `-error-handling` and
     `-implement-foundation` skills, and its `<path>/CLAUDE.md`; invariant
     skills and `orchestrator` exist once at the root; shared agents (scout,
     planner, architecture-gate, layer-reviewer) are unprefixed
     and their `skills:` list names every package's skills;
   - optional skills and optional agents exist exactly when their flags /
     emit-table conditions (`templates/agents/optional-agents.md`) hold.
4. **Stale globs**: every `owns` glob, `excludes` glob, mechanical-check path,
   hexagon path and `exemplar_slice` matches at least one existing file
   (`git ls-files -co --exclude-standard -- ':(glob)<glob>'`). A glob matching
   nothing means the code moved and the agent now owns nothing — or something
   else now owns its files.
5. **Unowned code**: source files (per the stack pack's source patterns, minus
   generated / IaC / docs) matched by no layer. New directories that no agent
   owns are where the next feature will go wrong.
6. **Manifest sanity** (the losses a real dry run found):
   - every layer's `kind` agrees with the harness-init DETECTION kind-mapping
     table — UI components `view`, view-models `presentation`, transports
     `driving-adapter`; a `view` agent body carrying "holds UI state" or a
     `presentation` body carrying HTTP retry / dead-letter rules is a fail;
   - each test-owning agent's red stub matches its return shape
     (`testing.red_stub` map key for its kind) and appears once in the file;
   - for each `parallel_with` pair, the port each agent implements is in its
     own `owns` (state port with the state agent);
   - `layer-reviewer` diff-scoped checks run over `$F`, not the whole tree;
   - `carry_forward` holds no rule from a file the memory file `@`-imports;
     the memory files (root and per-package) contain no `@` import of a skill
     (`@...skills/...SKILL.md`) → fail: remove it, link instead;
   - a leftover `.claude/agents/**/spec-sync*` or `prd-sync*` agent, a
     `plan.spec.sync_agent` / `commit_format` field, or a graph / dispatch row
     naming spec-sync → fail: the harness never writes the spec; run
     harness-upgrade to remove it (deletion needs the user's confirmation);
   - `plan.spec.enabled: true` while `plan.spec.path` is missing from the
     working tree (uninitialised submodule) → fail: `spec-mapper` has nothing
     to read;
   - `emit.cursor_compat: true` without `.cursor/rules/**` / `.cursor/agents/**`
     → warn;
   - `.claude/settings.json` / `settings.local.json` parse (`jq .`). Lost
     keys cannot be detected without a pre-install copy; if `git log` shows
     the install commit changed them, report the removed keys
     (`git show <install-commit>^:.claude/settings.json`).
7. **Conformance freshness**: for each gap with `disposition: migrate`, whether
   its paths still exist and still show the finding. A fixed gap should be
   removed from the manifest; report it.

### 3. Checks that run project code — ask first

List the exact commands — every `commands.gate` entry, `commands.test_targeted`
with one real substituted target, `commands.arch_test`, `commands.lint` — and
which may fetch dependencies. Wait for confirmation. Then run them read-only
(no `--fix`, no formatters that write) and record exit code and the decisive
failure line. If the user declines, mark them `skipped`, not `pass`.

The hook self-test from CHECKLIST (piping sample JSON into
`.claude/hooks/receipt-check.sh`) only reads stdin and prints; run it without
asking, if the hook is enabled.

### 4. Report

```text
harness-doctor — <repo> — harness_version <n> — <N pass / M fail / K skipped>

FAIL  ownership       internal/note/**: also matched by api-store-builder (12 files)
FAIL  stale-glob      application-builder owns src/usecases/** — matches nothing
FAIL  hook-drift      matcher omits api-billing-builder (added to manifest, not settings)
DRIFT template        tdd/SKILL.md — newer template available (harness-upgrade)
PASS  placeholders, frontmatter, skills resolve, gate (go vet ./...), arch tests
SKIP  test_targeted   declined by user
```

Then one line per fail with the fix and the tool for it: manifest edit +
`harness-upgrade`, or `harness-init` re-detection when the repo's shape changed.
Nothing else. Do not fix anything yourself.
