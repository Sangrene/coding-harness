# Stack pack: <Language>

`project.stack: <id>` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| <manifest / lockfile> | <stack, package manager, runner> |

Workspace / monorepo structure (→ `workspace`):

- <how packages are declared and how to list them>

Language version (→ `project.language`): <where to read it>.
Frameworks (→ `project.frameworks`): <dependency names to look for>.

## 2. Commands

| Variant | `run` | `exec` | `add_dependency` | `test_all` |
|---|---|---|---|---|
| <tool> | | | | |

Where the real commands live: <scripts, Makefile, CI workflow …>.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| <default> | <command that compiles/typechecks production AND test code> | <typecheck-guard / compile-guard / build-guard> |

Pitfalls: <what the obvious command misses>.

## 4. Targeted tests

| Runner | `test_targeted` | `test_target_hint` |
|---|---|---|
| <runner> | <non-interactive, uncached, one target token> | <one sentence> |

## 5. Red stub

<How to make RED a runtime/assertion failure instead of a compile error: the
test compiles, runs, and fails for the expected reason. Preferred stub returns a
typed placeholder (zero value / default) so the failure is an assertion; a
not-implemented throw/panic is acceptable only when the test output names that
stub as the cause.>

`testing.red_stub`: "<exact string>"

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| | | | |

Ownership implications: <which layer owns test files; `excludes` needed>.

## 7. Doubles & spy technique

- Harness default: hand-written fakes typed as the driven port.
- Stack norms: <mocking libraries; how to record a divergence>.

`testing.spy_technique`: "<one sentence>"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| | | | | |

Typical `traps`:

- <...>

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| | | |

## 10. Type escape hatches

`architecture.type_escape_hatches`: [<...>]

## 11. Hexagon mapping hints

| Role | Typical appearance |
|---|---|
| domain_type | |
| domain_error | |
| driving_port | |
| driving_adapter | |
| driven_port | |
| driven_adapter | |
| test_double | |
| composition_root | |

Typical gaps (→ `conformance.gaps`):

- <...>

`leakage_examples`: [<...>]

## 12. Arch tests

Tool: <name, or "none — reviewer greps only">. Starting point; adapt names and
paths to the repo.

```text
<recipe>
```

`commands.arch_test`: <command>

## 13. Pitfalls

- <caching, watch modes, network/restore, generated dirs to exclude>

## 14. Reviewer greps

Diff-scoped checks run against `$F` (changed files) and repo-wide checks
against the tree. One comment line per command saying what it catches. Each
must print nothing on the exemplar slice.

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '<source-ext-regex>' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# <framework / driver import in inner layers>
sel '<domain-dir>/|<application-dir>/' | xargs grep -nE '<pattern>' /dev/null
# <infrastructure error escaping the adapter>
skip '<adapters-dir>/' | xargs grep -nE '<pattern>' /dev/null
# <string-matched error>, <swallowed error>, <clock / ids in inner layers>, <escape hatches>
```

Repo scope:

```bash
# <adapter constructed outside the composition root>
rg -n '<pattern>' <paths>
```

## 15. Platform UI rules

"n/a" when the stack has no UI framework. Otherwise, per UI framework: which
files are `kind: view` vs `kind: presentation`, list / touch-target /
accessibility / platform-file rules, and where navigation may be called
(presentation, never use cases).
