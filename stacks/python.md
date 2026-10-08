# Stack pack: Python

`project.stack: python` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `pyproject.toml` | project; `[project] requires-python`, `[tool.*]` config for every tool |
| `uv.lock` | uv |
| `poetry.lock` (+ `[tool.poetry]`) | Poetry |
| `pdm.lock` / `hatch.toml` | PDM / Hatch |
| `requirements*.txt`, `requirements.in` + pip-tools | pip |
| `setup.py` / `setup.cfg` | legacy packaging |
| `.python-version` | pinned interpreter |
| `manage.py` + `settings.py` | Django |
| `mypy.ini` / `[tool.mypy]`, `pyrightconfig.json` / `[tool.pyright]` | type checker |
| `pytest.ini` / `[tool.pytest.ini_options]` / `conftest.py` | pytest (read `addopts`) |
| `[tool.importlinter]` / `.importlinter` | import-linter |

Workspace (→ `workspace`): `[tool.uv.workspace] members = [...]`, Poetry/PDM
path dependencies (`{ path = "../x", develop = true }`), several
`pyproject.toml` under `packages/` or `services/`. Layout: `src/<pkg>/` (src
layout) vs `<pkg>/` at root — record which; imports and globs differ.

`project.language`: "Python 3.x" from `requires-python` / `.python-version`.
Frameworks: `fastapi`, `django`, `djangorestframework`, `flask`, `litestar`,
`starlette`, `sqlalchemy`, `sqlmodel`, `alembic`, `pydantic`, `celery`,
`dramatiq`, `typer`, `click`.

## 2. Commands

| Tool | `run` | `exec` | `add_dependency` |
|---|---|---|---|
| uv | `uv run` | `uvx` | `uv add <pkg>` (dev: `uv add --dev <pkg>`; workspace: `uv add --package <member> <pkg>`) |
| Poetry | `poetry run` | — | `poetry add <pkg>` (dev: `poetry add --group dev <pkg>`) |
| PDM / Hatch | `pdm run` / `hatch run` | — | `pdm add <pkg>` / edit `pyproject.toml` |
| pip + venv | `python -m` (interpreter from `.venv/bin/`) | — | add to `requirements*.txt`/`pyproject.toml`, then `pip install -r …` |

`test_all`: `<run> pytest -q`. Real commands: `Makefile`, `justfile`,
`noxfile.py`, `tox.ini`, `[tool.poe.tasks]` / `[tool.hatch.envs.*.scripts]`,
pre-commit config, CI workflow.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| mypy configured | `<run> mypy` (paths from `[tool.mypy] files`, else `<run> mypy src tests`) | `typecheck-guard` |
| pyright / basedpyright | `<run> pyright` | `typecheck-guard` |
| no type checker | `<run> python -m compileall -q <src> tests` — syntax only; say so at confirm | `compile-guard` |

- The type checker must cover `tests/` — check `files`/`include`/`exclude`.
  An untyped or excluded test tree means the gate ignores tests.
- `ruff check` is lint, not a type gate; include it only if CI fails on it.
- Import errors are only caught at pytest collection — the targeted test run
  is the real backstop in Python.

## 4. Targeted tests

| Runner | `test_targeted` | `test_target_hint` |
|---|---|---|
| pytest | `<run> pytest -q {path}` | "{path} = the test file, optionally with ::test_name or ::TestClass::test_name" |
| Django test runner | `<run> python manage.py test {filter}` | "{filter} = dotted path app.tests.test_x.TestClass.test_method" |
| unittest | `<run> python -m unittest {filter}` | "{filter} = dotted path tests.test_x.TestClass.test_method" |

- pytest is never interactive and has no result cache (the cache plugin only
  powers `--lf`/`--ff`).
- `addopts` may add `--cov … --cov-fail-under=N` (fails every targeted run on
  coverage) or `-n auto` (xdist); append `--no-cov` for targeted runs when
  pytest-cov is configured.
- Async tests need pytest-asyncio / anyio config already present; don't add a
  marker style the repo doesn't use.

## 5. Red stub

`from app.note import create_note` with no `create_note` is an ImportError at
collection: every test in the file errors — not a valid RED. RED means the
test runs and fails for the expected reason. Declare it with its final
signature returning a typed placeholder (a dummy value of the return type),
so the failure is an assertion; `raise NotImplementedError` is acceptable only
when the test output names that stub as the cause.

`testing.red_stub`: "declare the function/method with its final signature and type hints, returning a typed placeholder of the return type; `raise NotImplementedError` acceptable when the failure names it"

A missing attribute accessed at call time (`note.create_note(...)` after
`import app.note as note`) also fails at runtime and is acceptable.
Trap: `pytest.raises(Exception)` passes against the stub (`NotImplementedError`
is an `Exception`) — assert the specific domain exception or error value.

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| mirrored `tests/` | `tests/<pkg path>/test_<module>.py` | `mirrored-tree` | `tests/<same path as src>/test_<module>.py` |
| split by kind | `tests/unit/`, `tests/integration/`, `tests/e2e/` | `mirrored-tree` | `tests/unit/<path>/test_<module>.py` |
| colocated | `test_*.py` / `*_test.py` beside code; Django `<app>/tests.py` or `<app>/tests/` | `colocated` | `<pkg>/<module>_test.py` |

Read `testpaths` / `python_files` in pytest config. Naming: `test_<behaviour>`
functions; class-based `TestX` in unittest/Django → `technical` by default.
Ownership: mirrored trees need each layer to own its slice
(`tests/unit/domain/**`); shared `conftest.py` files belong to the layer that
owns their directory (root `tests/conftest.py` → wiring layer).

## 7. Doubles & spy technique

- Harness default: hand-written fakes implementing the port (`typing.Protocol`
  or `abc.ABC`), e.g. `FakeNoteRepository` holding a dict; annotate the
  variable/fixture as the port type so the type checker verifies it.
- Stack norms: `unittest.mock` (`Mock`, `MagicMock`, `patch`), `pytest-mock`
  (`mocker`). `patch("app.service.requests.get")` patches a module global —
  it hides a missing port; flag it as a gap. Always `create_autospec(Port)` if
  the repo does use mocks for ports.
- `respx` / `responses` / `pytest-httpx` are HTTP-adapter test tools.

`testing.spy_technique`: "`mocker.spy(obj, 'method')` (pytest-mock) or `unittest.mock.patch.object(obj, 'method', wraps=obj.method)` — calls through and records calls"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| exceptions (dominant) | `class \w+(Error\|Exception)\(`, `raise `, `except ` | `exceptions (DomainError hierarchy)` | `false` | `exception subclass` |
| returns library | `from returns.result import`, `Success(`, `Failure(` | `Result[T, E] (returns)` | `true` | `isinstance / match on error type` |
| `result` package / hand-rolled | `Ok(`, `Err(`, `@dataclass(frozen=True) class …Error` | `T \| DomainError` / `Result[T, E]` | `true` | `match` on dataclass type |

Classification: driven adapters translate `sqlalchemy.exc.NoResultFound`,
`IntegrityError`, `httpx.HTTPStatusError` into domain errors; driving adapters
map domain errors to `HTTPException` / DRF responses / exit codes.

Typical `traps`:

- "bare `except:` / `except Exception: pass`"
- "`raise DomainError(...)` inside `except` without `from e`"
- "`HTTPException` (FastAPI) or `Http404` (Django) raised in services/domain"
- "ORM/HTTP-client exceptions escaping the adapter"
- "`None` returned for not-found and also for other failures"
- "`assert` used for runtime validation (stripped under `python -O`)"

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| pydantic v2 | `BaseModel`, `model_validate`, `Field(` | driving adapter request/response models, driven adapter payloads, settings — not the domain |
| DRF serializers / Django forms | `serializers.Serializer`, `forms.Form` | driving adapter |
| marshmallow / msgspec / attrs validators | `Schema`, `msgspec.Struct`, `@define` | adapters (attrs/dataclasses with `__post_init__` checks may be domain) |
| dataclasses / value objects | `@dataclass(frozen=True)` + `__post_init__` | domain — invariants |

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["`Any`", "`cast(...)`", "`# type: ignore` / `# pyright: ignore` without a code", "`# noqa` on type-relevant rules", "`getattr`/`setattr` with dynamic names", "untyped `**kwargs`/`*args`", "`dict[str, Any]` as a domain shape"]

## 11. Hexagon mapping hints

| Role | Typical appearance |
|---|---|
| domain_type | `src/<pkg>/domain/model.py`, `domain/` package; frozen dataclasses / attrs |
| domain_error | `domain/errors.py` / `exceptions.py` |
| driving_port | `service_layer/services.py`, `application/use_cases/`, command handlers |
| driving_adapter | FastAPI routers (`api/`, `routers/`), Django views/serializers, Typer/Click CLI, Celery tasks |
| driven_port | `typing.Protocol` / `abc.ABC` in `domain/ports.py` or `application/ports/` |
| driven_adapter | `adapters/repository.py`, `adapters/orm.py`, `infrastructure/` |
| test_double | `tests/fakes.py`, `Fake*`, `InMemory*`, conftest fixtures |
| composition_root | `bootstrap.py`, `main.py`/`create_app()`, `container.py` (dependency-injector), FastAPI `Depends` providers + `app.dependency_overrides` |

Typical gaps (→ `conformance.gaps`):

- Django `models.Model` subclasses as the domain (ORM = domain merge); fat
  models/views holding rules. Record as `migrate`; a pure domain beside the ORM
  model is the target.
- SQLAlchemy declarative models (`DeclarativeBase`, `Mapped[...]`) used as domain
  types; imperative mapping (`registry.map_imperatively`) keeps them pure.
- Pydantic `BaseModel` as domain entities shared from API to DB.
- FastAPI route functions querying the session directly (`Depends(get_db)` in
  the handler, no use case).
- Module-level clients/sessions (`engine = create_engine(...)` imported by
  services) — adapter constructed outside the root.

`leakage_examples`: ["sqlalchemy Session / Mapped", "django.db.models.Model", "QuerySet", "pydantic BaseModel in domain", "fastapi.HTTPException", "requests.Response / httpx.Response", "IntegrityError"]

`modules.unit`: "one subpackage per module under src/<pkg>/<module>/".

## 12. Arch tests

**import-linter** (config keys verified against seddonym/import-linter docs:
`root_package`, `include_external_packages`, `layers` contract with
`containers`, `forbidden` contract with `source_modules`/`forbidden_modules`;
CLI `lint-imports`). Starting point — replace package and module names.
`pyproject.toml`:

```toml
[tool.importlinter]
root_package = "notes"
include_external_packages = true   # required to forbid third-party packages

[[tool.importlinter.contracts]]
name = "Dependencies point inward (per module)"
type = "layers"
containers = ["notes.catalog", "notes.billing"]
layers = [
    "adapters",
    "application",
    "domain",
]

[[tool.importlinter.contracts]]
name = "Inner layers import no frameworks"
type = "forbidden"
source_modules = ["notes.catalog.domain", "notes.catalog.application"]
forbidden_modules = ["sqlalchemy", "fastapi", "pydantic", "httpx"]
```

Layers are listed outermost first: a lower layer importing a higher one fails.
The composition root (`notes.main` / `notes.bootstrap`) sits outside the
containers so it may import everything.

`commands.arch_test`: `<run> lint-imports`.

Alternative: `pytestarch` (pytest-based) if the repo prefers tests over config.

## 13. Pitfalls

- Wrong interpreter: always go through `<run>`; never bare `python`/`pytest`
  unless the repo's docs activate `.venv` explicitly.
- `uv run` syncs the environment before running (may hit the network after a
  lock change); `uv run --frozen` runs without re-locking if the repo's CI uses it.
- Coverage thresholds and xdist in `addopts` (see §4).
- Exclude from `owns` and greps: `.venv/**`, `**/__pycache__/**`, `.mypy_cache/**`,
  `.pytest_cache/**`, `.ruff_cache/**`, `build/**`, `dist/**`, `*.egg-info/**`,
  `**/migrations/**` (Django; generated by `makemigrations`), `alembic/versions/**`
  (persistence layer only), `**/*_pb2.py`, `**/*_pb2_grpc.py`, `**/*.pyi` if generated.
- Django tests need settings (`DJANGO_SETTINGS_MODULE` / pytest-django `--ds`)
  and often a DB — read `conftest.py` before assuming a unit test is DB-free.
- Circular imports surface only at runtime; the arch test catches the layer ones.

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths, drop checks for roles the repo
does not have, and run each once against the exemplar slice before committing
it — a check that hits the conforming exemplar is wrong. The comment above each
command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps
`grep` from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.py$' | grep -v '/migrations/' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# framework / ORM / HTTP client in domain or service layer
sel '<domain-pkg>/|<service-pkg>/' | xargs grep -nE '^(from|import) (sqlalchemy|django|fastapi|flask|httpx|requests|pydantic)\b' /dev/null
# HTTP exceptions raised outside the driving adapter
skip '<api-pkg>/|<views-pkg>/|tests/' | xargs grep -nE 'raise (HTTPException|Http404)|abort\(' /dev/null
# ORM / client exceptions escaping the adapter
skip '<adapters-pkg>/|tests/' | xargs grep -nE '\b(IntegrityError|NoResultFound|HTTPStatusError|RequestException)\b' /dev/null
# bare / swallowing except
printf '%s\n' "$F" | xargs grep -nE '^\s*except\s*:|except Exception:\s*(pass)?$' /dev/null
# re-raise without chaining (read each hit: is there `from e`?)
printf '%s\n' "$F" | xargs grep -nE '^\s+raise \w+Error\(' /dev/null
# string-matched error
printf '%s\n' "$F" | xargs grep -nE 'str\((e|err|exc)\) *(==|!=)|in str\((e|err|exc)\)' /dev/null
# assert as runtime validation outside tests
skip 'tests?/|test_|_test\.py$|conftest\.py$' | xargs grep -nE '^\s+assert ' /dev/null
# clock / ids in inner layers
sel '<domain-pkg>/|<service-pkg>/' | xargs grep -nE 'datetime\.(now|utcnow)\(|uuid\.uuid4\(|time\.time\(' /dev/null
# escape hatches
printf '%s\n' "$F" | xargs grep -nE '\bAny\b|cast\(|# type: ignore *$' /dev/null
```

Repo scope:

```bash
# module-level engines / clients imported by services
rg -n '^(engine|session|client|db) *= *(create_engine|Session|httpx\.Client|requests\.Session)' --glob '*.py' --glob '!**/bootstrap.py' --glob '!**/main.py'
# test fakes imported by production code
rg -n '^from tests\b|import tests\b' --glob '*.py' --glob '!tests/**'
```

## 15. Platform UI rules

n/a for APIs, workers and CLIs. Server-rendered UI (Django templates, Jinja,
HTMX partials) is `kind: view`: templates get a context built by a presenter /
view function and contain no queries (`{% for x in obj.related.all %}` is a
query in a view) and no business conditions beyond display branching.
