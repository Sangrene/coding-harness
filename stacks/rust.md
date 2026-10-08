# Stack pack: Rust

`project.stack: rust` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `Cargo.toml` | crate; `[package] edition`, `rust-version` |
| `Cargo.lock` | resolved deps (binaries/apps commit it) |
| `Cargo.toml` `[workspace] members = [...]` | cargo workspace; `cargo metadata --no-deps --format-version 1` lists members |
| `rust-toolchain.toml` / `rust-toolchain` | pinned toolchain |
| `.config/nextest.toml` / `cargo nextest` in CI | nextest runner |
| `deny.toml` | cargo-deny |
| `.sqlx/` / `sqlx-data.json` | sqlx offline query metadata (needed to compile `query!` without a DB) |
| `build.rs`, `*.proto` + `tonic-build`/`prost-build` | generated code at build time |

Workspace (→ `workspace`): a cargo workspace whose crates are layers of ONE
service (`domain`, `app`, `infra`, `api`) is a single-package manifest with
`modules`/crate-per-layer; a workspace of independent binaries/services is the
workspace form. A `lib` crate published for others → `shape: library`.

`project.language`: "Rust <edition>" plus `rust-version` if set. Frameworks:
`axum`, `actix-web`, `rocket`, `poem`, `tonic`, `tokio`, `sqlx`, `diesel`,
`sea-orm`, `reqwest`, `tauri`, `leptos`, `bevy`.

## 2. Commands

| Field | Value |
|---|---|
| `run` | `cargo` |
| `exec` | — (installed subcommands run as `cargo <sub>`) |
| `add_dependency` | `cargo add <crate>` (in a workspace: `cargo add -p <member> <crate>`; dev: `--dev`) |
| `test_all` | `cargo test --workspace` (or `cargo nextest run --workspace` + `cargo test --doc`) |
| `lint` | `cargo clippy --all-targets -- -D warnings` if CI uses it |

Real commands: `Makefile`/`justfile`/`cargo-make` (`Makefile.toml`),
`.cargo/config.toml` `[alias]`, CI workflow (features flags: `--all-features`,
`--features x`).

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| single crate | `cargo check --all-targets` | `compile-guard` |
| workspace | `cargo check --workspace --all-targets` | `compile-guard` |
| sqlx `query!` macros, no DB in agent env | `SQLX_OFFLINE=true cargo check --workspace --all-targets` | `compile-guard` |
| CI checks feature combos | add the CI's `--features …` / `--all-features` | `compile-guard` |

- Plain `cargo check` skips `#[cfg(test)]` code, `tests/`, benches and
  examples. `--all-targets` checks them (flag verified on cargo 1.98).
- Clippy is slower and can be the gate instead when CI denies warnings:
  `cargo clippy --workspace --all-targets -- -D warnings`.

## 4. Targeted tests

| Runner | `test_targeted` | `test_target_hint` |
|---|---|---|
| cargo test | `cargo test {filter}` (workspace: `cargo test -p <crate> {filter}`) | "{filter} = a substring of the test path, e.g. note::tests::rejects_empty_title; add `-- --exact` for one test" |
| nextest | `cargo nextest run {filter}` | "{filter} = a substring of the test name" |

- Never interactive, no result cache (only build artifacts are cached).
- nextest does not run doctests — `test_all` must add `cargo test --doc` if the
  repo has them.
- A filter that matches nothing reports `0 passed` and exits 0 — the receipt
  must show the test ran.

## 5. Red stub

A missing fn is a compile error — not a valid RED. RED means the test
compiles, runs, and fails for the expected reason. Declare it with the real
signature returning `Default::default()` or a dummy value, so the failure is an
assertion. `todo!()` is acceptable only when the test output names that stub as
the cause (the panic message `not yet implemented` at the stub's location
does); it fails that test only.

`testing.red_stub`: "declare the fn/method with its final signature returning `Default::default()`/a dummy value; `todo!()` acceptable when the failure names it"

Trap: `#[should_panic]` without `expected = "…"` passes against `todo!()`.
Async trait methods: `todo!()` works inside `async fn`.

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| inline module | `#[cfg(test)] mod tests { use super::*; … }` at file end | `colocated` | `<file>.rs (#[cfg(test)] mod tests)` |
| sibling file | `#[cfg(test)] mod tests;` + `<module>/tests.rs` | `sibling-file` | `<module>/tests.rs next to the code, declared as #[cfg(test)] mod tests;` |
| integration tests | `tests/*.rs` per crate (public API only) | `mirrored-tree` | `<crate>/tests/<feature>.rs` |

Naming: snake_case fn names (`rejects_empty_title`) → `technical` unless the
repo writes sentence-like names. Ownership: inline and sibling-file tests
belong to the layer owning the module. Integration `tests/` dirs need an owner
(usually the layer whose crate they exercise).

## 7. Doubles & spy technique

- Harness default: hand-written fakes / `InMemory*` adapters implementing the
  port trait, used as `Arc<dyn NoteRepository>` or a generic `R: NoteRepository`.
- Stack norms: `mockall` (`#[automock]` / `mock!`). `#[automock]` on a port
  trait in the domain puts a test dependency in the domain; if present, prefer
  `#[cfg_attr(test, mockall::automock)]` and record the divergence.
  `wiremock` / `httpmock` are for HTTP adapter tests.

`testing.spy_technique`: "wrap the real or in-memory implementation in a recording struct that implements the same trait, pushes each call into a `Mutex<Vec<_>>`, and delegates to the inner value"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| thiserror domain enum | `#[derive(.*Error`, `#[error(`, `enum \w*Error` | `Result<T, DomainError>` (thiserror) | `true` | `enum variant` |
| anyhow at edges | `anyhow::Result`, `anyhow!`, `.context(` | edge only (main, bins, tests) | — | — |
| per-module error enums | `pub enum NoteError` | `Result<T, NoteError>` | `true` | `enum variant` |

- `anyhow`/`eyre` only in binaries, `main`, CLI glue and tests — never in
  domain/application signatures (callers cannot match on it).
- Panic (`unwrap`, `expect`, `panic!`) only for invariants a test proves cannot fail.
- Classification: driven adapter maps `sqlx::Error::RowNotFound` →
  `DomainError::NotFound`; driving adapter implements `IntoResponse` for the
  domain error → status code.

Typical `traps`:

- "`#[from] sqlx::Error` on a domain error variant — `?` silently leaks the driver error inward"
- "`impl From<sqlx::Error> for DomainError` inside the domain crate (domain now depends on sqlx)"
- "`.map_err(|_| …)` dropping the source"
- "`Box<dyn Error>` / `anyhow::Error` in inner-layer signatures"
- "`unwrap()` / `expect()` on adapter results outside tests"
- "non-exhaustive `_ =>` arm hiding a new variant in the error mapper"

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| serde (+ `#[serde(deny_unknown_fields)]`) | `#[derive(Deserialize)]` | driving/driven adapter DTOs only — never on domain types |
| validator | `#[derive(Validate)]`, `#[validate(` | driving adapter DTOs |
| garde | `#[derive(Validate)]`, `#[garde(` | driving adapter DTOs |
| newtypes / `TryFrom` / `nutype` | `impl TryFrom<String> for Email` | domain — invariants by construction |

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["`unwrap()` / `expect()` outside tests", "`unsafe`", "`as` numeric casts (use `try_from`)", "`panic!` / `unreachable!` / `todo!` left in code", "`#[allow(...)]` without a reason", "`Box<dyn Any>` + downcast", "`std::mem::transmute`"]

## 11. Hexagon mapping hints

| Role | Single crate (modules) | Workspace (crate per layer/module) |
|---|---|---|
| domain_type | `src/domain/{entities,value_objects}/` | `crates/<module>-domain/` or `crates/domain/` |
| domain_error | `src/domain/errors.rs` | `domain/src/error.rs` |
| driving_port | `src/application/services/` (service structs/traits) | `crates/<module>-app/` |
| driving_adapter | `src/infrastructure/http/` (axum handlers), `src/cli/` | `crates/api/`, `crates/cli/` |
| driven_port | traits in `src/domain/ports/` (or `application/ports/`) | in the domain/app crate |
| driven_adapter | `src/infrastructure/adapters/persistence/` | `crates/<module>-infra/`, `crates/infra-postgres/` |
| test_double | `…/persistence/in_memory/`, `#[cfg(test)]` fakes | `crates/<module>-testing/` or feature-gated `fakes` module |
| composition_root | `src/main.rs` (builds `AppState`, router) | the bin crate's `main.rs` |

Async ports: `async fn` in traits is stable (1.75) but not object-safe for
`dyn`; repos use `#[async_trait]` or return `impl Future + Send`. Record which.

Typical gaps (→ `conformance.gaps`):

- `#[derive(sqlx::FromRow, Serialize, Deserialize)]` on domain entities.
- Handlers taking `State<PgPool>` and running queries — no use case, no port.
- Global pools/clients in `static`/`OnceLock`/`lazy_static` used from inner layers.
- Services returning `axum::Json`/`StatusCode` or `anyhow::Result`.
- Port trait defined in the infra module and imported by the service.

`leakage_examples`: ["sqlx::FromRow", "sqlx::Error", "PgPool", "serde::Serialize/Deserialize on domain types", "axum::Json / StatusCode", "reqwest::Error", "tonic::Status"]

`modules.unit`: "one library crate per business module + shared kernel" or "one `src/<module>/` tree per module".

## 12. Arch tests

Crate-per-layer makes the rule structural: a domain crate whose `Cargo.toml`
lists no inner-workspace deps cannot import outward. Lock it with a test so a
new `[dependencies]` line fails the gate.

**`cargo metadata` test** — verified on cargo 1.98: passes on a conforming
workspace, fails with `inward rule broken: ["domain -> pg"]` when the domain
crate gains a dependency. Starting point; replace crate names.
`crates/arch/tests/dependency_rule.rs` (dev-dependency `serde_json = "1"`):

```rust
use std::collections::HashMap;
use std::process::Command;

// crate name -> workspace crates it may depend on (normal + dev + build).
fn allowed() -> HashMap<&'static str, &'static [&'static str]> {
    HashMap::from([
        ("domain", &[][..]),
        ("app", &["domain"][..]),
        ("adapters", &["domain", "app"][..]),
    ])
}

#[test]
fn dependencies_point_inward() {
    let out = Command::new(env!("CARGO"))
        .args(["metadata", "--format-version", "1", "--no-deps"])
        .output()
        .expect("cargo metadata");
    assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
    let meta: serde_json::Value = serde_json::from_slice(&out.stdout).unwrap();
    let packages = meta["packages"].as_array().unwrap();
    let members: Vec<&str> = packages.iter().map(|p| p["name"].as_str().unwrap()).collect();
    let rules = allowed();
    let mut violations = Vec::new();
    for p in packages {
        let name = p["name"].as_str().unwrap();
        let Some(ok) = rules.get(name) else { continue };
        for d in p["dependencies"].as_array().unwrap() {
            let dep = d["name"].as_str().unwrap();
            if members.contains(&dep) && !ok.contains(&dep) {
                violations.push(format!("{name} -> {dep}"));
            }
        }
    }
    assert!(violations.is_empty(), "inward rule broken: {violations:?}");
}
```

Cycles (`domain → app` when `app → domain`) are already rejected by cargo itself.

**cargo-deny bans** for third-party crates (`deny.toml`, `crate`/`wrappers`
keys verified against cargo-deny docs) — only the listed crates may depend
directly on the banned one:

```toml
[bans]
deny = [
  { crate = "sqlx", wrappers = ["infra-postgres"] },
  { crate = "axum", wrappers = ["api"] },
]
```

Run `cargo deny check bans`. Single-crate repos (modules, not crates): no
structural check — use `verify.mechanical_checks` greps such as
`grep -rnE 'use (crate::)?(infrastructure|sqlx|axum)' src/domain`.

`commands.arch_test`: `cargo test -p arch` (+ `cargo deny check bans`).

## 13. Pitfalls

- `cargo check` without `--all-targets` misses test code.
- sqlx `query!` needs `DATABASE_URL` or `SQLX_OFFLINE=true` + committed `.sqlx/`;
  after changing a query, `cargo sqlx prepare` must run (needs a DB) — report
  BLOCKED rather than switching to unchecked `query()`.
- First build after a dependency change downloads crates (network) and can take
  minutes — wait for exit.
- Feature-gated code is invisible unless the gate enables the features CI uses.
- Exclude from `owns` and greps: `target/**`, `**/*.rs` emitted under `OUT_DIR`
  (in `target/`), checked-in generated code (`src/generated/**`, `*_pb.rs`,
  `schema.rs` from diesel — owned by the persistence layer, regenerated not
  hand-edited), `migrations/**` (owned by the persistence layer).
- Tests sharing a DB/global state run in parallel threads by default; repos use
  `--test-threads=1` or `serial_test` — copy the CI invocation.

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths, drop checks for roles the repo
does not have, and run each once against the exemplar slice before committing
it — a check that hits the conforming exemplar is wrong. The comment above each
command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps
`grep` from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.rs$|Cargo\.toml$' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# driver / framework crates in domain or application
sel '<domain-crate-or-dir>/|<app-crate-or-dir>/' | xargs grep -nE 'use (sqlx|axum|reqwest|tonic|diesel|sea_orm)::|^(sqlx|axum|reqwest|tonic) *=' /dev/null
# serde / ORM derives on domain types
sel '<domain-crate-or-dir>/' | xargs grep -nE 'derive\(.*(Serialize|Deserialize|FromRow|Queryable)' /dev/null
# driver error converted into the domain error (leaks inward via ?)
sel '<domain-crate-or-dir>/' | xargs grep -nE '#\[from\] *(sqlx|reqwest|tonic)::|impl From<(sqlx|reqwest)::' /dev/null
# anyhow / boxed errors in inner signatures
sel '<domain-crate-or-dir>/|<app-crate-or-dir>/' | xargs grep -nE 'anyhow::(Result|Error)|Box<dyn (std::error::)?Error' /dev/null
# unwrap / expect / panic outside tests (read hits inside #[cfg(test)] modules as fine)
skip '/tests/|_test\.rs$' | xargs grep -nE '\.unwrap\(\)|\.expect\(|panic!\(|todo!\(|unimplemented!\(' /dev/null
# map_err dropping the source
printf '%s\n' "$F" | xargs grep -nE 'map_err\(\|_\|' /dev/null
# clock / ids in inner layers
sel '<domain-crate-or-dir>/|<app-crate-or-dir>/' | xargs grep -nE '(Utc|Local)::now\(\)|SystemTime::now|Uuid::new_v[47]' /dev/null
```

Repo scope:

```bash
# globals holding pools / clients
rg -n '(static|OnceLock|lazy_static!|once_cell).*(Pool|Client)' --glob '*.rs' --glob '!**/main.rs'
# catch-all arm in error mappers
rg -n '_ =>' <error-mapper-files>
```

## 15. Platform UI rules

n/a for services, CLIs and libraries. Tauri / Leptos / Yew / egui frontends:
components are `kind: view` (props in, events out, no `reqwest`/DB calls);
signals/stores holding UI state are `kind: presentation` or `state`; Tauri
`#[tauri::command]` handlers are driving adapters that call use cases.
