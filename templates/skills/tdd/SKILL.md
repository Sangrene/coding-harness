---
name: tdd
description: "Test-driven development — the red-green-refactor loop, always enforced, in any language. Use when writing ANY new behaviour, fixing ANY bug, or changing ANY logic in a tested layer: write the failing test first, watch it fail for the expected reason, then write the minimum code to pass. Also use when reviewing whether work was test-driven, when a test was written after the code, when asked to 'add tests' to existing code, when a test fails to compile, when a run reports cached results, or when deciding whether a change is done. Do not skip because the change is small, obvious, or urgent. Pairs with the testing skill (where tests live, how to write doubles) and with extract-til-you-drop (what to do in refactor)."
---

# TDD

**Tests drive the code. Not the other way round.**

This skill is always on. It is not a mode you enter for big features, and not a
step you do at the end. Every behaviour change in a tested layer goes through the
loop below.

## The loop

```text
RED → GREEN → REFACTOR → repeat
```

1. **RED — write one failing test.**
   One behaviour, expressed from the caller's point of view. Not the
   implementation's. Not two behaviours.

2. **RED — run it. Watch it fail.**
   Use the targeted test command and its target hint from `implement-foundation`
   (your package's `<prefix>-implement-foundation` in a workspace), verbatim,
   from the working directory it names.

   **This step is not optional and cannot be reasoned about instead of run.**
   Confirm it fails *for the reason you expect* — see "What counts as red"
   below. A test that fails on a typo, a compile error, an import error, or a
   bad fixture is not red, it is broken: fix it and re-run until the failure is
   the real one.

   If it passes before the code exists, the test asserts nothing. Delete it and
   write a real one.

3. **GREEN — write the minimum code to pass.**
   The smallest change that makes this test pass. Not the design you already have
   in your head, not the next three cases. Resist writing code no test asked for.

4. **GREEN — run it. Watch it pass.**
   Then run the gate listed in the same foundation skill.

5. **REFACTOR — improve the code, not its behaviour.**
   Apply `extract-til-you-drop`. Tests stay green throughout; if a test goes red
   during refactor, the change was not a refactor — revert and separate it.

6. **Repeat** for the next behaviour: error path, validation, boundary, edge
   case. One test per loop.

## What counts as red

Red is **the new test failing for the reason you predicted** — a wrong value, a
missing error, an unexpected call. Before running, say what the failure will
be; after running, check that it was.

**Compiled or type-checked code: stub first, so RED is an assertion failure.**
A test referencing a symbol that does not exist fails to compile, often taking
the whole module down with it — no test ran, so that is not red. Declare the
signature (real name, parameters, return type, no behaviour) with your layer's
red stub, stated in your agent file's self-test section; GREEN replaces it. The testing skill
explains the stub per return shape.

**Dynamic languages:** a missing function raising at call time inside the new
test is acceptable red; a load error that stops the whole file is not.

Either way, a red you did not predict is information: read it before writing
code.

**A cached pass is not a run.** If the output says the test was cached, skipped,
up-to-date or that 0 tests ran, it did not run: use the targeted command from
`implement-foundation` verbatim, never a shorter form, and re-run until it
executes.

## Why watching it fail is the whole point

An unverified test is a claim, not evidence. Until you have seen the test fail
and then pass, you do not know:

- that it exercises the code you think it does,
- that its assertion can ever be false,
- that it is wired into the runner at all.

Tests written after the code routinely pass on day one and can never fail again.
They cost maintenance and buy nothing. This is the single most common way a
codebase ends up with high coverage and no safety.

## Writing the test

- **Name it after the behaviour, from the caller's point of view.** "rejects a
  title longer than the limit", "returns NotFound when the note was deleted" —
  not "test validate 2", not "calls repo.save", not the name of the branch in
  the code. A name you can only write by reading the implementation is a test
  of the implementation.
- **One behaviour, one assertion focus.** Several assertions are fine when they
  describe one outcome (the returned value and its fields). Two outcomes are two
  tests. If the description needs "and", split it.
- **Given / When / Then**, in that order. Arrange only what this behaviour needs.
- **Boundaries are behaviours.** Empty input, exactly at the limit, one past it,
  the last item — each is its own test when the code treats it differently.
- **Assert outcomes, not mechanics.** The returned value, the typed error, the
  observable state change. Not which private helper ran.

## Bug fixes are TDD too

A bug means a missing test, always. The fix sequence is fixed:

1. Reproduce the bug in a test at the **innermost layer that owns the wrong
   decision** — usually the domain rule, not the handler where it was noticed.
2. Run it. **It must fail, with the symptom the bug report describes** — that is
   your proof you reproduced the real bug and not an adjacent one.
3. Fix the code. Minimum change.
4. Watch the test pass. Then run the gate.

Never fix first and test after. If you cannot write a failing test for the bug,
you have not understood it yet. If the wrong decision lives in a layer that
should not hold decisions, the fix is a placement fix: move the rule inward
(`separation-of-concerns`) and test it there.

## What drives design

Writing the test first forces the unit to be callable without its infrastructure.
That pressure is the mechanism, not a side effect:

- A unit that is hard to construct in a test has too many dependencies.
- A unit that needs a real database, network, renderer or clock in its test is
  missing a port.
- A test that needs elaborate setup to reach one branch is telling you that
  branch belongs in its own unit.

**When a test is hard to write, fix the design, not the test.** Reaching for a
heavier mock is how the pressure gets vented and the design stays wrong.

## Scope

Applies to every layer holding decisions — business rules, validation,
orchestration, state transitions, error mapping, wire ↔ domain mappers, and
the behaviour of driving adapters and presentation models (input parsing, error
→ transport mapping, which use case is called and when). See the project's
testing skill (`testing`, or `<prefix>-testing` in a workspace) for which layers
this project tests and where the files go.

Does not apply to: a driven adapter's I/O and framework plumbing with no
decisions in them. Those are not unit-tested — integration or contract tests
cover the I/O where the repo has them, and otherwise they are made
*injectable*, so everything above them can be.

## Non-negotiable rules

- Never write production logic with no failing test demanding it.
- Never write a test you have not watched fail for the expected reason.
- Never count a compile error, a load error or a cached result as a run.
- Never edit a test to match code you just wrote. The test is the specification;
  if it is wrong, that is a separate, deliberate change with its own reason.
- Never delete, skip or ignore a failing test to get to green. Red means the
  work is not done.
- Never report work as done off a test run you did not execute in this session.

## Done means green

For any agent that owns tests, `STATUS: done` means *the targeted run was
executed — red first, then green — and passed*, not *the test file exists*. A
non-green run is `STATUS: blocked`, with the decisive failure line.

The orchestrator will not advance the chain on a receipt that is not `done`, so a
skipped loop does not save time — it stalls the whole graph one step later.
