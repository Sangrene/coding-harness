# Stack pack: Go

`project.stack: go` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `go.mod` | a module; `module` line = import path prefix, `go` / `toolchain` line = version |
| `go.sum` | dependencies resolved (absent in a dependency-free module — not a negative signal) |
| `go.work` (+ `go.work.sum`) | multi-module workspace; `use (...)` lists the modules |
| `vendor/modules.txt` | vendored deps — builds use `-mod=vendor` implicitly |
| `.golangci.yml` / `.golangci.yaml` / `.golangci.toml` | golangci-lint; `version: "2"` = v2 config format |
| `Makefile`, `Taskfile.yml`, `magefile.go`, `justfile` | real command entry points |

Workspace (→ `workspace`):

- `go.work` → one package per `use` entry, or one package total if the modules
  are one hexagon. Several `go.mod` files without `go.work` → independent modules.
- One module with `cmd/<app>/` × N binaries sharing `internal/` → usually ONE
  package with several composition roots, not a workspace.
- `go list -m` lists modules in the main module / workspace.

`project.language`: "Go 1.x" from the `go` directive. Frameworks: grep `go.mod`
for `net/http` routers (`chi`, `echo`, `gin`, `fiber`, `gorilla/mux`), gRPC
(`google.golang.org/grpc`, `connectrpc.com`), DB (`pgx`, `sqlx`, `sqlc`, `gorm`, `ent`).

## 2. Commands

| Field | Value |
|---|---|
| `run` | `go` |
| `exec` | `go run <module>@<version>` for tools; Go 1.24+: `go tool <name>` when the tool is declared with `tool` in `go.mod` |
| `add_dependency` | `go get <module>@<version>` (then `go mod tidy`) |
| `test_all` | `go test -count=1 ./...` |
| `lint` | `golangci-lint run` if configured; else `go vet ./...` is already the gate |

Real scripts: Makefile targets (`make test`, `make lint`), Taskfile, CI
`.github/workflows/*.yml` (look for `-race`, `-tags`, `-short`, build tags). If
CI passes `-tags integration` or similar, record it — untagged files are skipped
silently.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| default | `go vet ./...` | `compile-guard` |
| build tags in use | `go vet -tags <tags> ./...` | `compile-guard` |

- `go build ./...` does **not** compile `_test.go` files. `go vet ./...`
  type-checks package + test files (verified: a type error in a `_test.go`
  passes `go build`, fails `go vet`).
- `go vet` also runs its analyzers; a vet finding fails the gate. That is
  intended.
- Generated code (`sqlc`, `mockgen`, `protoc`, `templ`) must be regenerated
  before the gate if inputs changed: record `go generate ./...` (or the repo's
  target) as a first gate step only if the repo does not commit generated files.

## 4. Targeted tests

| Runner | `test_targeted` | `test_target_hint` |
|---|---|---|
| go test | `go test -count=1 {package} -run '{filter}'` | "{package} = the package dir, e.g. ./internal/note/... ; {filter} = an anchored regex of the top-level test, e.g. ^TestCreateNote$ (subtest: ^TestCreateNote$/^empty_title$)" |
| gotestsum (if repo uses it) | `gotestsum -- -count=1 {package} -run '{filter}'` | same |

- `-count=1` is mandatory: it disables the test result cache. Without it a
  green "(cached)" run proves nothing.
- `go test` is never interactive; there is no watch mode to disable.
- `-run` is unanchored regex — always anchor with `^...$`.

## 5. Red stub

A missing function is a compile error, so the whole package's tests fail to
build — not a valid RED. Declare the function/method with its real signature
and return zero values, so RED is an assertion failure. A
`panic("not implemented")` is acceptable only when the test output names that
stub as the cause, but it aborts the test binary and hides the other tests'
results — prefer zero values.

`testing.red_stub`: "declare the func/method with its final signature and return zero values (`return Note{}, nil`) so the failure is an assertion; `panic(\"not implemented\")` acceptable only when the failure names it; never leave it undeclared"

Trap: if the test only checks `err == nil`, the zero-value stub passes — the
RED run exposes the weak test; fix the test, not the stub.

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| same dir, same package (white-box) | `package note` in `note_test.go` | `colocated` | `<pkg dir>/<file>_test.go` |
| same dir, external test package (black-box) | `package note_test` | `colocated` | `<pkg dir>/<file>_test.go (package <pkg>_test)` |
| integration tests in `test/` or `tests/` | top-level dir with `_test.go` + build tags | `mirrored-tree` (second runner) | `test/<area>/<x>_test.go` |

- Both package styles may coexist; record which one the exemplar uses.
- `testdata/` dirs are ignored by the toolchain — fixtures go there.
- Naming: `TestType_Method` / `TestFunction` + table-driven `t.Run(tc.name, …)`.
  Subtest names with spaces become underscores in `-run`.

Ownership: tests sit beside code, so the layer that owns `internal/note/domain/**`
owns its `*_test.go` too — no `excludes` needed. A separate test-author layer
would need `excludes: ["**/*_test.go"]` on every layer; don't, builder-owns-tests
is the default. Shared fakes in `internal/<module>/fake/` or `…/memory/` belong
to the test_double owner (often the driven-adapter layer).

## 7. Doubles & spy technique

- Harness default: hand-written fakes / in-memory adapters, with a compile-time
  assertion that they satisfy the port: `var _ app.NoteRepository = (*Memory)(nil)`.
- Stack norms: `go.uber.org/mock` (gomock, `mockgen`), `mockery` (testify mocks),
  `testify/mock`. If the repo uses them for driven ports, record
  `doubles.style: mocking-framework` and flag the divergence; don't rewrite.
- `testify/assert` / `require` are assertion libs, not doubles — fine anywhere.

`testing.spy_technique`: "wrap the real implementation in a small recording decorator that implements the same port interface, appends each call to a slice, and delegates to the wrapped value"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| idiomatic | `errors.New`, `fmt.Errorf(".*%w`, `errors.Is`, `errors.As`, `var Err` | `(T, error) with sentinel + typed errors, errors.Is/As` | `true` (no panic for expected failures) | `errors.Is on a sentinel / errors.As on a typed error` |
| typed domain error | `type .*Error struct`, `func (e \*.*Error) Error() string` | same | `true` | `errors.As(err, &target)` then a `Kind` field |

- Sentinels: `var ErrNotFound = errors.New("note: not found")` in the domain package.
- Wrap with `%w` to keep the chain; `%v` breaks `errors.Is`.
- `panic` only for programmer errors (impossible states, init failure in `main`).
- Classification: driven adapters translate `sql.ErrNoRows` / `pgx.ErrNoRows` /
  HTTP status into domain sentinels; driving adapters map sentinels to status codes.

Typical `traps`:

- "`fmt.Errorf(\"...: %v\", err)` drops the chain — use %w"
- "returning `sql.ErrNoRows`/`*pgconn.PgError` past the adapter"
- "`err == ErrX` instead of `errors.Is(err, ErrX)` once wrapping exists"
- "typed nil: returning a nil `*MyError` as `error` is non-nil"
- "`_ = repo.Save(...)` — discarded error"
- "exhaustive switch does not exist — a new sentinel compiles silently; review the mapper"

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| go-playground/validator | `validate:"` struct tags, `validator.New()` | driving adapter, on request DTOs only |
| ozzo-validation | `validation.ValidateStruct` | driving adapter |
| hand-written constructors | `func NewEmail(s string) (Email, error)` | domain — invariants |

Struct tags (`validate:`, `json:`, `db:`) on a domain type are a leakage gap.

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["`any` / `interface{}` in signatures", "unchecked type assertion `x.(T)` without `, ok`", "`reflect`", "`unsafe`", "`//nolint` without a reason", "`_ =` discarding an error", "`panic` for expected failures"]

## 11. Hexagon mapping hints

| Role | Typical appearance |
|---|---|
| domain_type | `internal/<module>/domain/*.go` or `internal/<module>/<module>.go` (flat package named after the module) |
| domain_error | `var Err… = errors.New` + `type …Error struct` in the domain package |
| driving_port | service struct methods in `internal/<module>/app/` (or `service/`, `usecase/`); sometimes an interface consumed by the handler |
| driving_adapter | `internal/<module>/adapter/http/`, `transport/`, `handler/`, `grpc/`, `cmd/<app>/` CLIs |
| driven_port | **interface declared by the consumer** — in `app/` (or `domain/`), next to the service that uses it. Idiomatic Go and exactly the hexagon |
| driven_adapter | `internal/<module>/adapter/postgres/`, `store/`, `repository/`, `client/` |
| test_double | `internal/<module>/adapter/memory/`, `fake/`, `…test/` package, `mocks/` (generated) |
| composition_root | `cmd/<app>/main.go` (+ `wire.go` / `fx` modules if Wire/Fx is used) |

Typical gaps (→ `conformance.gaps`):

- Interface declared in the adapter package (`postgres.Repository` interface +
  impl) and imported by `app` → port derived from adapter.
- Package-level vars as hidden globals: `var db *sql.DB`, `init()` that opens
  connections, `http.DefaultClient` used inside `app` — adapter constructed
  outside the composition root.
- `sqlc`/`gorm` model structs used as domain types (tags `db:"…"`, `gorm:"…"`).
- Handlers calling the repository directly, skipping the service.
- `models/` package shared by every layer — no translation boundary.
- Layer-by-kind at the top (`handlers/`, `services/`, `repositories/`) with all
  modules mixed — record as `modules` gap, not a hexagon gap.

`leakage_examples`: ["*sql.Rows", "sql.ErrNoRows", "pgx.Row / pgconn.PgError", "gorm.Model", "`db:` / `json:` / `gorm:` struct tags", "*http.Request", "echo.Context / gin.Context", "protobuf generated types"]

`modules.unit`: "one package tree under internal/<module>".

## 12. Arch tests

Starting points; adapt module path, role segment names and roots.

**A. Plain Go test (no dependency)** — verified with Go 1.27: passes on a
conforming tree, fails on `app → adapter` and `domain → adapter`. Put it in
`internal/archtest/arch_test.go` (or `archtest/`).

```go
package archtest

import (
	"encoding/json"
	"io"
	"os/exec"
	"strings"
	"testing"
)

const mod = "example.com/svc" // module path from go.mod

// role maps a package to its hexagon role by path segment; "" = not governed.
func role(pkg string) string {
	for _, seg := range strings.Split(pkg, "/") {
		switch seg {
		case "domain", "app", "adapter":
			return seg
		}
	}
	return ""
}

// allowed[from] = roles it may import (same role always allowed).
var allowed = map[string][]string{
	"domain":  {},
	"app":     {"domain"},
	"adapter": {"domain", "app"},
}

func TestDependenciesPointInward(t *testing.T) {
	// -e: keep going on broken packages (an import cycle must still report).
	out, err := exec.Command("go", "list", "-e", "-json", mod+"/internal/...").Output()
	if err != nil {
		t.Fatalf("go list: %v", err)
	}
	dec := json.NewDecoder(strings.NewReader(string(out)))
	for {
		var p struct {
			ImportPath string
			Imports    []string // non-test imports only
		}
		if err := dec.Decode(&p); err == io.EOF {
			break
		} else if err != nil {
			t.Fatal(err)
		}
		from := role(p.ImportPath)
		for _, imp := range p.Imports {
			to := role(imp)
			if from == "" || to == "" || to == from || !strings.HasPrefix(imp, mod+"/") {
				continue
			}
			ok := false
			for _, a := range allowed[from] {
				ok = ok || a == to
			}
			if !ok {
				t.Errorf("%s (%s) imports %s (%s)", p.ImportPath, from, imp, to)
			}
		}
	}
}
```

Add a second loop over `p.Imports` for domain → third-party (first path segment
contains a `.`) if the domain must be stdlib-only.

**B. depguard in golangci-lint v2** (`.golangci.yml`; keys verified against
the v2 reference config — `rules.<name>.files|allow|deny[{pkg,desc}]|list-mode`,
`$test` file variable). `pkg` is a prefix match with no wildcards, so list each
module's inner paths:

```yaml
version: "2"
linters:
  enable: [depguard]
  settings:
    depguard:
      rules:
        domain:
          files: ["**/internal/*/domain/**", "!$test"]
          deny:
            - { pkg: "example.com/svc/internal/note/app", desc: "domain depends on nothing outward" }
            - { pkg: "example.com/svc/internal/note/adapter", desc: "domain depends on nothing outward" }
            - { pkg: "database/sql", desc: "persistence belongs in a driven adapter" }
            - { pkg: "net/http", desc: "transport belongs in a driving adapter" }
        app:
          files: ["**/internal/*/app/**", "!$test"]
          deny:
            - { pkg: "example.com/svc/internal/note/adapter", desc: "app depends on ports, not adapters" }
```

Glob matching of `files` is relative to where golangci-lint runs; confirm by
introducing a violation and running the repo's lint command (red-then-green).

**C. go-arch-lint** (`.go-arch-lint.yml`, component/deps model) — use only if
the repo already has it.

`commands.arch_test`: `go test -count=1 ./internal/archtest/...` (A) or
`golangci-lint run` (B).

## 13. Pitfalls

- Test cache: always `-count=1`. `GOFLAGS=-count=1` in env is an alternative
  only if the repo sets it.
- `go build ./...` is not a gate (skips tests).
- Build tags: files under `//go:build integration` are invisible without
  `-tags`; the gate and the arch test do not see them either.
- `go mod tidy` / `go get` hit the network; agents run them only in the
  dependency step, never in the gate.
- `t.Parallel()` + shared fakes → data races; CI with `-race` catches it, local
  targeted runs don't.
- Generated code — exclude from every layer's `owns` and from greps:
  `**/*_gen.go`, `**/*.pb.go`, `**/*_grpc.pb.go`, `**/zz_generated*.go`,
  `**/mock_*.go` / `mocks/**` (mockgen/mockery), `**/*_templ.go`, sqlc output dir
  (read `sqlc.yaml` `out:`), `vendor/**`.
- Files with `// Code generated … DO NOT EDIT.` on the first line are generated
  regardless of name.
- `internal/` visibility restricts importers by subtree, not by layer — it is
  not an arch test.

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths, drop checks for roles the repo
does not have, and run each once against the exemplar slice before committing
it — a check that hits the conforming exemplar is wrong. The comment above each
command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps
`grep` from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.go$' | grep -v '_gen\.go$\|\.pb\.go$' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# driver / transport imports in domain or app packages
sel '<domain-pkg>/|<app-pkg>/' | grep -v '_test\.go$' | xargs grep -nE '"(database/sql|net/http|github\.com/(jackc/pgx|lib/pq|labstack/echo|gin-gonic/gin)|gorm\.io)' /dev/null
# struct tags on domain types (leakage)
sel '<domain-pkg>/' | grep -v '_test\.go$' | xargs grep -nE '`(json|db|gorm|validate):"' /dev/null
# interface declared beside its implementation in an adapter package (port derived from adapter)
sel '<adapter-pkgs>/' | grep -v '_test\.go$' | xargs grep -nE '^type \w+ interface' /dev/null
# driver errors escaping the adapter
skip '<adapter-pkgs>/' | xargs grep -nE 'sql\.ErrNoRows|pgx\.ErrNoRows|\*pgconn\.PgError' /dev/null
# %v breaks the error chain
printf '%s\n' "$F" | xargs grep -nE 'fmt\.Errorf\([^)]*%v[^)]*\berr\b' /dev/null
# == on errors once wrapping exists
printf '%s\n' "$F" | xargs grep -nE 'err (==|!=) Err[A-Z]' /dev/null
# string-matched error
printf '%s\n' "$F" | xargs grep -nE '\.Error\(\) *(==|!=)|strings\.Contains\(err\.Error\(\)' /dev/null
# discarded error
printf '%s\n' "$F" | grep -v '_test\.go$' | xargs grep -nE '^\s*_ = \w+.*\(' /dev/null
# panic / log.Fatal in inner packages
sel '<domain-pkg>/|<app-pkg>/' | grep -v '_test\.go$' | xargs grep -nE '\bpanic\(|log\.Fatal' /dev/null
# clock / ids in inner packages
sel '<domain-pkg>/|<app-pkg>/' | grep -v '_test\.go$' | xargs grep -nE 'time\.Now\(\)|uuid\.New|rand\.' /dev/null
```

Repo scope:

```bash
# package-level adapter state / init wiring
rg -n '^var \w+ (\*sql\.DB|\*pgxpool\.Pool|=\s*http\.DefaultClient)|^func init\(\)' --glob '*.go' --glob '!cmd/**' --glob '!*_test.go'
# test helpers imported by production code
rg -n '"[^"]*/(testutil|fakes?|mocks)"' --glob '*.go' --glob '!*_test.go'
```

## 15. Platform UI rules

n/a — Go packages here are services, workers, CLIs or libraries. Server-rendered
templates (`html/template`, `templ`) are `kind: view`: they receive a
presentation struct and contain no queries or business conditions.
