# Acceptance checklist for a rendered harness

Run every item. Report pass / fail per item. Fix all fails before reporting
done. `harness-doctor` runs the Mechanical and Contract sections against an
installed harness, read-only.

Commands below are read-only except where marked **runs project code**. Those
follow the security rules: show the exact batch, say which may fetch, wait for
confirmation, then run.

In workspace mode, run each per-package item once per package, with prefixed
names and the package's commands from its `{{WORKDIR}}` (the package path).

## Mechanical

- [ ] **No placeholder survived.** Plain `{{` false-positives on Go templates,
      Handlebars and Jinja, so match the harness's placeholder form only:

      ```sh
      grep -rnE '\{\{[A-Z][A-Z0-9_]*\}\}' .agents/ <memory_file> <package>/AGENTS.md
      ```

      Expect no output.
- [ ] **No render instruction survived.** Templates carry `<!-- harness: ... -->`
      comments for the renderer; none belong in the output:

      ```sh
      grep -rn '<!-- harness:' .agents/ <memory_file> <package>/AGENTS.md CLAUDE.md
      ```

      Expect no output.
- [ ] **Frontmatter is line 1.** Every agent and skill file starts with `---`:

      ```sh
      find .agents/agents .agents/skills -name '*.md' \( -path '*/agents/*' -o -name SKILL.md \) \
        -exec sh -c 'head -n 1 "$1" | grep -qx -- "---" || echo "$1"' _ {} \;
      ```

      Expect no output. A comment or blank line above `---` breaks parsing.
- [ ] Every agent has a unique `name` equal to its file name minus
      `emit.agent_suffix` (`.md` or `.agent.md`); every agent file ends in that
      suffix. In workspace mode layer and gate agents are `<prefix>-<agent>`;
      `scout`, `feature-planner`, `architecture-gate` and `layer-reviewer` are
      unprefixed.
- [ ] Every `skills:` entry in an agent's frontmatter names a directory under
      `.agents/skills/` with a `SKILL.md`. `implement-foundation` resolves at
      `.agents/skills/implement-foundation/` — in workspace mode
      `.agents/skills/<prefix>-implement-foundation/`, one per package, beside
      `<prefix>-architecture`, `<prefix>-testing`, `<prefix>-error-handling`.
- [ ] **Workspace shared agents list every package.** Each shared agent's
      `skills:` frontmatter is a single comma list naming every package's
      skills it needs (`api-architecture, web-architecture, …`), not one
      package's set. Invariant skills and `orchestrator` exist once, at the root.
- [ ] **Optional skills match their flags.** Each enabled flag
      (`skills.optional.i18n`, `component_design`, `presentation_model`,
      `modules`, `spec_implement`; `testing.naming: user-facing`) has its skill
      (`i18n`, `component-design`, `presentation-model`, `modular-monolith`,
      `spec-implement`, `test-naming`) rendered from
      `templates/skills/optional/<name>/`; no skill exists for a disabled flag.
- [ ] **Emitted agents match the emit table** in
      `templates/agents/optional-agents.md`: the `kind: wiring` layer is rendered
      from `wiring-agent.md.tmpl`, every other layer from `_layer-builder.md.tmpl`,
      and each optional agent exists exactly when its condition holds.
- [ ] Every `NEXT:` value and every forbidden-path owner names an agent that
      exists.
- [ ] **Ownership is disjoint after excludes.** Per implement agent, list its
      files with git pathspecs (tracked and untracked-not-ignored):

      ```sh
      git ls-files -co --exclude-standard -- ':(glob)<owns-1>' ':(glob)<owns-2>' \
        ':(glob,exclude)<excludes-1>' | sort > "$TMP/<agent>.files"
      cat "$TMP"/*.files | sort | uniq -d
      ```

      Expect no output. Each line printed is a file two agents can edit.
- [ ] Every `owns` glob matches at least one path, or is documented as a path
      the harness will create (greenfield / non-conforming roles).
- [ ] Every path in `architecture.hexagon`, `exemplar_slice`, `layers[].reference`,
      `testing.doubles.location` and `verify.arch_tests.path` exists.
- [ ] **Workspace prefixes are unique**, and no prefix followed by `-` is the
      start of another (`api` vs `api-admin`). Every package path exists and no
      two package paths nest unless the outer one excludes the inner.
- [ ] **The gate runs.** *Runs project code.* Run each `commands.gate` entry in
      order; all exit 0. Confirm it compiles test code: the pack's gate is used,
      or a deliberately broken test file (scratch, deleted after) fails it — only
      if cheap.
- [ ] **The targeted test runs.** *Runs project code.* Substitute one real
      target per `test_target_hint` and run `commands.test_targeted` once. It
      exits without prompting and does not report a cached result.
- [ ] **Arch tests run** when `verify.arch_tests.status` is `existing` or
      `generate`. *Runs project code.* `commands.arch_test` exits 0, and the gate
      agent's body runs it after the compile gate.
- [ ] **Adapters are pointers.** *(per enabled adapter)* `claude`: `CLAUDE.md`
      (root and per package) is exactly one `@<memory file>` line; `.claude/skills`
      and `.claude/agents` are relative symlinks that resolve into `.agents/`
      (`test -L`, `readlink`); no file under `.claude/` other than `settings*.json`
      is a regular file with harness content. Expect no second copy of any rule.
- [ ] **Receipt hook works** when `emit.hooks.receipt_check: true`:
      - `.agents/hooks/receipt-check.sh` is byte-identical to the template and
        executable (`test -x`);
      - *(adapter `claude`)* `.claude/settings.json` parses (`jq . .claude/settings.json`), still has
        every key it had before, and has exactly one `SubagentStop` group running
        the script;
      - the matcher regex matches every emitted agent `name` (not file name, so
        no `.agent.md`) and nothing else;
      - piping a sample receipt allows, and a broken one blocks:

      ```sh
      H=.agents/hooks/receipt-check.sh
      ok='{"agent_type":"<tdd-agent>","stop_hook_active":false,"last_assistant_message":"STATUS: done\nSCOPE: <tdd-agent>\nFILES: a\nOUTCOME: red: 1 failing; green: 1 passing\nBLOCKERS:\nNEXT: <gate>"}'
      printf '%s' "$ok" | "$H" --tdd <tdd-agents>                         # expect no output
      printf '%s' "$ok" | sed 's/red: 1 failing; //' | "$H" --tdd <tdd-agents>  # expect {"decision":"block",...}
      printf '%s' "$ok" | sed 's/red: 1 failing; green: 1 passing/3 passed, 0 failed/' | "$H" --tdd <tdd-agents>  # expect block: no "red"/"green" words
      ```

- [ ] **Settings preserved.** When `.claude/settings.json` or
      `.claude/settings.local.json` existed before the install / upgrade, every
      key it had is still present with the same value (`enabledPlugins`,
      `permissions`, `hooks`, `env`, `model`); the only change allowed is the
      opted-in receipt-hook group. Compare against the pre-install copy:

      ```sh
      jq -S . "$OLD/.claude/settings.json" > "$TMP/old.json"
      jq -S . .claude/settings.json        > "$TMP/new.json"
      diff "$TMP/old.json" "$TMP/new.json"   # only the receipt-check group may appear
      cmp "$OLD/.claude/settings.local.json" .claude/settings.local.json
      ```
- [ ] **Diff-scoped greps are diff-scoped.** In `layer-reviewer`, every
      `scope: diff` check runs over `$F` (the changed-file list), never over
      `src` / the whole tree; every `scope: repo` check is labelled repo-wide.

## Lost rules (only when a harness or memory file existed before)

- [ ] **Every old rule has a home.** For each rule in the pre-install
      `.agents/` and `.claude/` (agents, skills, memory files — one bullet, table row,
      checklist item or trap each), name the v3 file that carries it, or show
      the user's explicit consent to drop it. Report as a table:
      `old file:line → v3 file (slot / manifest field) | dropped (consented)`.
      An unmapped rule is a fail.
- [ ] **Every old mechanical check survives.** Each grep / rg line in the old
      reviewer appears in `verify.mechanical_checks` (path-generalised) or is
      in the consented drop list.
- [ ] **Old files are accounted for.** Every old agent / skill file is
      re-rendered, absorbed (named target), or removed with consent; nothing
      else under `.agents/` was deleted.
- [ ] Carried values match the old harness: runner agents' `model:` →
      `emit.runner_model`.
- [ ] Nothing emitted writes, commits or pushes the spec: no agent other
      than the read-only `plan/spec-mapper` names `plan.spec.path`, and an old
      agent that wrote the spec is listed as dropped in the lost-rules check.

## Contract integrity

- [ ] `receipt.md`, `hexagonal-architecture/SKILL.md`, `tdd/SKILL.md` and
      `separation-of-concerns/SKILL.md` are byte-identical to their templates
      (`cmp`). No project-local softening, however pre-existing the violation.
- [ ] `extract-til-you-drop/SKILL.md` differs from its template **only** at
      `LOGIC_LAYERS` and `EXTRACT_LOCATION` and by the stripped
      `<!-- harness: -->` comments. Every rule is intact.
- [ ] `architecture` maps roles to paths (role rows, known-deviation rows and
      the arch-tests section all filled from the manifest) and does **not** restate the dependency
      rule, ports, translation or anti-patterns.
- [ ] Every hexagon role is mapped to a real path, marked `absent: by-shape`
      (only roles the shape removes), or recorded as a gap. None is blank.
- [ ] Exactly one implement agent has `kind: domain`; it is first in the chain
      and owns tests.
- [ ] Each implement agent carries the rule pack for its `kind`, and its
      `rules:` do not repeat the pack.
- [ ] **Kinds match the kind-mapping table** (DETECTION Sweep 2): UI
      components are `view` (never `presentation`), view-models / presenters
      `presentation` (never `driving-adapter`), transports `driving-adapter`.
      A `view` agent's body carries no "holds UI state" rule; a
      `presentation` agent's carries no HTTP / retry / dead-letter rule.
- [ ] **Red stub fits the return shape.** Each test-owning agent's red stub is
      the `testing.red_stub` entry for its kind (sync for domain, async for
      application / adapters, hook for presentation, component for views) and
      appears once in that agent.
- [ ] **Parallel ownership.** For every `parallel_with` pair, each port is
      owned by the agent that implements it (the state port by the state
      agent).
- [ ] The exemplar slice exists, and its deviations are stated inline.
- [ ] `tdd` and `testing` do not both describe the loop; `separation-of-concerns`
      and `architecture` do not both describe the dependency rule at length.
- [ ] Every implement agent — layer builders **and** the wiring agent — names
      `tdd`, `separation-of-concerns` and `extract-til-you-drop` both in its
      `skills:` frontmatter **and** in its body, as applying regardless of
      layer.
- [ ] `layer-reviewer` carries the invariant checklist ahead of the
      project-specific list.
- [ ] Every agent's final-message section demands the receipt and nothing
      after: six fields, each on one line, several BLOCKERS joined with "; ".
      Test-owning builders' `done` OUTCOME must use the words "red" and "green".
- [ ] Every test-owning agent has the self-test gate and cannot report `done`
      on red; its `max_files` matches the manifest.
- [ ] `parallel.md`'s graph, its table, and the workflow in the memory file
      agree.
- [ ] The memory file's touch-area table covers every layer glob. In workspace
      mode the root routing table covers every package path, and each
      `<package>/AGENTS.md` covers that package's layers.
- [ ] Gate (which also runs the targeted tests) and layer-reviewer are read-only in their tool lists and
      say so in their bodies.
- [ ] No settings change other than the opted-in receipt hook; no ownership
      hook; no existing settings key dropped; `settings.local.json` untouched.

## Truthfulness

- [ ] Every example path in every skill exists in this repo.
- [ ] The role and layer tables match the directory structure.
- [ ] The dependency rule is a specialisation of "dependencies point inward".
- [ ] Every conformance gap appears in "Known deviations" with its disposition,
      and in the affected layers' "Do not copy" lists.
- [ ] The error-handling skill matches what inner layers actually return.
- [ ] The testing skill's path formula matches where tests actually live, and
      its red-stub and spy technique are the stack's.
- [ ] Recorded divergences (mocking framework, throw-based errors) are stated,
      not silently changed.
- [ ] `carry_forward` rules are quoted, not paraphrased, and none of them
      comes from a file the memory file `@`-imports.
- [ ] No memory file (root or package) `@`-imports a skill;
      `emit.adapters.cursor: true` only if the user confirmed Cursor use.
- [ ] Architecture slots are filled from the repo: `IMPORT_TABLE` rows match
      the exemplar's imports; every `SHARED_PORTS_TABLE` port, real
      implementation and fake exists at its path; every `REFERENCE_SLICES`
      path exists and says what it exemplifies.
- [ ] Known contradictions between the harness and existing code are listed for
      the user.

## Behavioural smoke test

Dispatch a real, small task and check:

- [ ] The scout runs alone and returns a receipt, not prose.
- [ ] One implement agent edits only files inside its `owns` minus `excludes`.
- [ ] That agent wrote its test first and reported the red run, not just the
      green one.
- [ ] Its `done` receipt reports a green run it actually executed.
- [ ] The gate agent reports `file:line: message`, not a log dump.
- [ ] `layer-reviewer` is dispatched only after the gate agent (gate + targeted
      tests) reports `done`.
- [ ] The orchestrator posted a dispatch line and a receipt for every agent, and
      never re-read an edited file without cause.
- [ ] With the hook on: a deliberately prose-ending reply from one agent is sent
      back once and then corrected.

The orchestrator item fails most often in practice, and it decides whether the
pattern saves context or merely adds ceremony.
