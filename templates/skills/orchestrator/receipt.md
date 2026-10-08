# Subagent Receipt Schema

Every subagent's **final message ends** with this block — the last six lines,
nothing after it:

```text
STATUS: done | blocked | needs-orchestrator
SCOPE: <subagent-name>
FILES: <comma-separated paths changed or read>
OUTCOME: <1-3 sentences, on one line>
BLOCKERS: <empty, or one line — several joined with "; ">
NEXT: <suggested next subagent>
```

**Every field is exactly one line.** No line breaks inside a field, no bullet
lists, no fenced output. Several blockers or findings go on the one line,
separated by `; ` — e.g.
`BLOCKERS: src/a.ts:12 — rule in use case; src/b.ts:40 — port declared beside adapter`.

## What may come before the receipt

- **Plan agents** (scouts, planner, architecture gate, spec and impact
  mappers) write a structured report first, under the headings their agent
  file names — rules found, existing code, target files with hexagon role and
  owner, contracts to fix, gaps in scope. `OUTCOME` summarises it in one line.
- **Verify agents** may put their findings list first (one line per finding,
  `file:line — what — owner`). `BLOCKERS` still carries a single-line summary.
- **Implement agents** write nothing but the receipt. Their `OUTCOME` carries
  the contract the next layer fits — exact type, error, port, field, setter,
  signature and prop names — because the orchestrator never opens their files.

No file dumps and no full logs anywhere in the message.

## Semantics

- `done` — the work is finished **and verified**. For an agent that owns tests,
  `done` means its targeted test run was executed and green, not that the files
  exist. Its `OUTCOME` states both halves of the loop and must contain the
  literal words `red` and `green` — the test was seen to fail first, then pass
  (e.g. "3 tests: red on the expected-value assertion against the stub, then
  3/3 green"). An `OUTCOME`
  that reports only a passing run means the loop was skipped; the orchestrator
  should treat it as `needs-orchestrator` and re-dispatch.
- Red = the test compiles, runs, and fails for the expected reason. A run that
  fails because a symbol does not exist yet — a compile, import or resolution
  error — has not reached the test. Stub the signature first: preferably with a
  typed placeholder (zero value / default) so the failure is an assertion; a
  not-implemented throw or panic (`NotImplementedException`, `todo!()`,
  `TODO()`) counts only when the test output names that stub as the cause.
- `blocked` — the agent could not finish. `BLOCKERS` carries the decisive failure
  output on one line (shortest useful form: `file:line: message`, several
  joined with `; `, never a full log dump), and
  `NEXT` names the agent that owns the missing piece.
- `needs-orchestrator` — the work is done but a decision is needed, or a
  read-only agent found violations someone else must fix.

## Orchestrator contract

The orchestrator stores receipts (and plan reports) only. It does not re-read
subagent-edited files unless a verify agent reported `blocked`/`needs-orchestrator`,
or the user asks. The contract in a receipt's `OUTCOME` — and a plan report's
"Contracts to fix" — is what goes, verbatim, into the next dispatch prompt.

The orchestrator must never advance the dependency chain on a receipt that is
not `done`.
