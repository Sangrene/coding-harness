# Stack pack: TypeScript / JavaScript

`project.stack: typescript` · Pack = defaults and signals; the repo's actual code wins.

## 1. Detection signals

| File | Proves |
|---|---|
| `package.json` | Node/JS project; `packageManager` field pins the manager (`pnpm@9…`, `yarn@4…`) |
| `package-lock.json` | npm |
| `yarn.lock` (+ `.yarnrc.yml` = Yarn Berry 2+, else Classic 1.x) | yarn |
| `pnpm-lock.yaml`, `pnpm-workspace.yaml` | pnpm |
| `bun.lock` (text, Bun ≥ 1.2) / `bun.lockb` | bun |
| `tsconfig.json` (+ `references`) | TypeScript; project references → `tsc -b` |
| `jest.config.*`, `vitest.config.*` / `test` block in `vite.config.*`, `bunfig.toml` | test runner |

The lockfile wins over README instructions. Two lockfiles → ask.

Workspace (→ `workspace`): `workspaces` in root `package.json` (npm/yarn/bun),
`pnpm-workspace.yaml` `packages:`, `turbo.json`, `nx.json` / `project.json`,
`lerna.json`. Each app (`apps/*`) with its own hexagon = one package; shared
libs (`packages/*`) are usually contracts (`workspace.contracts`) or their own
`library`-shape package.

`project.language`: "TypeScript 5.x" from the `typescript` devDependency.
Frameworks: `next`, `react-router` / `@remix-run/*`, `expo`, `react-native`,
`vue`, `svelte`, `@angular/core`, `express`, `fastify`, `hono`, `@nestjs/core`,
`@apollo/client`, `@tanstack/react-query`, `mobx`, `zustand`, `@reduxjs/toolkit`,
`prisma`, `drizzle-orm`, `typeorm`.

## 2. Commands

| Manager | `run` | `exec` | `add_dependency` |
|---|---|---|---|
| npm | `npm run` | `npx` | `npm install <pkg>` (`-D` dev) |
| yarn Berry | `yarn` | `yarn dlx` (one-off) / `yarn <bin>` (installed) | `yarn add <pkg>` |
| yarn Classic | `yarn` | `yarn <bin>` | `yarn add <pkg>` |
| pnpm | `pnpm` | `pnpm exec` (installed) / `pnpm dlx` (one-off) | `pnpm add <pkg>`; in a workspace `pnpm --filter <name> add <pkg>` |
| bun | `bun run` | `bunx` | `bun add <pkg>` |
| Expo | — | — | `<exec> expo install <pkg>` (pins SDK-compatible versions) |

`test_all` = the repo's `test` script, made non-interactive (see §4).
Real commands: `package.json` `scripts` (root and per workspace), `turbo.json`
pipelines (`turbo run typecheck --filter=<pkg>`), Nx targets (`nx run <proj>:test`),
CI workflow. Never use `npx` in a repo pinned to pnpm/yarn/bun.

## 3. Gate

| Situation | `gate` | `gate_name` |
|---|---|---|
| repo has a `typecheck` / `type-check` / `tsc` script | `<run> typecheck` | `typecheck-guard` |
| none, single tsconfig | `<exec> tsc --noEmit` (or `-p <tsconfig>`) | `typecheck-guard` |
| project references | the repo's `tsc -b` script | `typecheck-guard` |
| Vue / Svelte / Astro | `vue-tsc --noEmit` / `svelte-check` / `astro check` | `typecheck-guard` |
| plain JS | none — tests are the only gate; say so | — |

- Check the tsconfig that the gate uses **includes test files**. Many repos
  `exclude: ["**/*.test.ts"]` or keep tests in `tsconfig.spec.json` — then the
  gate must run both configs, or tests are never typechecked (vitest/esbuild,
  babel-jest and bun strip types without checking).
- Root `tsconfig.json` with `"files": []` + `references` checks nothing under
  plain `tsc --noEmit`.
- `next build` / `vite build` typecheck too but are minutes slower — not the gate.
- Add `<run> lint` to the gate only if lint rules carry correctness (e.g.
  `no-floating-promises`) and the repo's CI fails on them.

## 4. Targeted tests

| Runner | `test_targeted` | `test_target_hint` |
|---|---|---|
| vitest | `<exec> vitest run {path}` | "{path} = the test file, e.g. src/note/note.test.ts" |
| jest | `<exec> jest {path} --watchAll=false` | "{path} = the test file path (treated as a regex)" |
| bun | `bun test {path}` | "{path} = the test file; `bun test` only runs files named *.test/_test/*.spec" |
| node:test | `node --test {path}` (+ the repo's loader, e.g. `--import tsx`) | "{path} = the test file" |
| playwright (e2e, separate runner) | `<exec> playwright test {path}` | "{path} = the spec file" |

- Vitest: `vitest` without `run` enters watch mode in a TTY. Always `vitest run`.
- Jest: `--watchAll=false` overrides a `--watch` baked into the script; `CI=true`
  also disables watch. Jest 30 renamed `--testPathPattern` to
  `--testPathPatterns` — pass the path positionally to avoid both.
- Name filter when needed: vitest/jest `-t "<name>"`, bun `-t`
  (`--test-name-pattern`), node `--test-name-pattern`.
- None of these cache results; jest's cache is the transform cache only.

## 5. Red stub

A missing export is a module error at import time in vitest/jest (all tests in
the file fail) and a compile error under the typecheck gate. Declare the export
with its final signature returning a typed placeholder, so RED is an assertion
failure. The placeholder depends on the **return shape**, not the layer — one
stub sentence for every agent is wrong (a sync domain rule given
`errAsync(...)` no longer typechecks).

| Return shape | Stub | Typical layers |
|---|---|---|
| sync `Result<T, E>` | `return ok(<dummy T>)` — `ok([])`, `ok(0)`, `ok({ … } as const satisfies T)` with wrong-but-valid values | domain rules, mappers, validators |
| plain value `T` | return a typed dummy (`""`, `0`, `[]`, an object literal of `T`) | pure domain functions, selectors |
| async `ResultAsync<T, E>` / `Promise<T>` | `return okAsync(<dummy T>)` / `Promise.resolve(<dummy T>)` | use cases, ports' adapters, fakes |
| hook (`use*`) | return a fixed placeholder object of the hook's declared return type — static values, no-op callbacks, no React state | view-models / presenters |
| component | render `null` (`return null`) with the final props type | views |
| state store / class | the class with its final interface, getters returning the initial value, setters as no-ops | state |

Pick `ok` vs `err` for the dummy so the first test **fails**: if the first test
asserts success, the stub returns `err`-shaped or wrong `ok` data; never a value
that happens to pass. `throw new Error("not implemented")` is acceptable only
when the test output names that stub as the cause.

`testing.red_stub` (map form; drop keys for shapes the repo has no layer of):

```yaml
red_stub:
  sync:      "declare the export with its final signature; return ok(<dummy>) for a Result, a typed dummy for a plain value"
  async:     "declare the export with its final signature; return okAsync(<dummy>) (or Promise.resolve(<dummy>))"
  hook:      "declare the hook with its final return type; return a fixed placeholder object of that type (static values, no-op callbacks, no useState/useEffect)"
  component: "declare the component with its final props type; render null"
  state:     "declare the store with its final interface; getters return the initial value, setters are no-ops"
```

Each layer renders the key for its own shape (`RED_STUB` per layer, see
harness-init render map): `domain` → sync, `application` / `driven-adapter` →
async, `presentation` → hook, `view` → component, `state` → state. A layer that
mixes shapes (domain with async rules) gets both lines.

Trap: `expect(() => f()).toThrow()` / `rejects.toThrow()` without a matcher
pass against the stub — assert the error class/message, or the `err` kind of
the returned Result.

## 6. Test placement & naming conventions

| Layout | Detect by | `placement` | `path_formula` |
|---|---|---|---|
| colocated | `src/**/x.test.ts` beside `x.ts` | `colocated` | `<dir>/<file>.test.ts` |
| `__tests__` folders | `src/**/__tests__/x.test.ts` | `colocated` | `<dir>/__tests__/<file>.test.ts` |
| mirrored tree | `test/` or `tests/` mirroring `src/` | `mirrored-tree` | `tests/<same path>/<file>.test.ts` |
| e2e | `e2e/`, `playwright/`, `cypress/` | `mirrored-tree` (second runner) | `e2e/<flow>.spec.ts` |

Suffix: read the runner's `include`/`testMatch` — `.test.ts` vs `.spec.ts`
matters. Naming: `describe`/`it` sentences → usually `user-facing`.
Ownership: colocated tests belong to the layer that owns the directory; a
mirrored tree needs each layer to own its slice (`tests/domain/**`).

## 7. Doubles & spy technique

- Harness default: hand-written fakes typed as the port:
  `const repo: NoteRepository = createInMemoryNoteRepository()`.
- Stack norms: `vi.fn`/`jest.fn` stubs, `vi.mock`/`jest.mock` module mocking,
  MSW for HTTP, `@testing-library/*` for components. Module mocking of the
  repo's own modules hides a missing port — flag it as a gap
  (`doubles.style: mocking-framework`), don't extend it.

`testing.spy_technique`: "`vi.spyOn(obj, 'method')` / `jest.spyOn` — calls through to the real method by default and records calls; restore in afterEach"

## 8. Errors

| Convention | Grep for | `errors.type` | `never_throw` | `discriminate_by` |
|---|---|---|---|---|
| neverthrow | `from 'neverthrow'`, `ResultAsync`, `okAsync`, `errAsync` | `Result<T, E> / ResultAsync<T, E> (neverthrow)` | `true` | `kind field on E` |
| Effect | `from 'effect'`, `Effect.fail`, `Data.TaggedError` | `Effect<A, E, R>` | `true` | `_tag` |
| fp-ts / hand-rolled union | `Either`, `{ ok: true … } \| { ok: false … }` | `Either<E, A>` / `Result<T, E>` | `true` | `_tag` / `ok` + `kind` |
| exceptions | `class \w+Error extends Error`, `throw new` | `exceptions (DomainError subclasses)` | `false` | `instanceof` |

Typical `traps`:

- "`.map(() => ok(x))` nests a Result — use `.andThen`"
- "`ResultAsync.fromPromise(p)` without an error mapper → `unknown` error"
- "`_unsafeUnwrap()` / `_unsafeUnwrapErr()` outside tests"
- "floating promise / un-awaited ResultAsync"
- "`catch (e)` then `(e as Error).message` — `e` is unknown"
- "throwing inside a Result chain (`.map(() => { throw … })`)"
- "Effect `runPromise`/`runSync` inside inner layers — run only at the edge"
- "`.match(() => undefined, () => undefined)` / `void result` with no named reason — swallow unless the no-op is named (error-handling no-op rule)"
- "`error.message ===` / `.includes(` / `.startsWith(` — string-typed error; branch on `kind`"
- "`ResultAsync<T, Error>` in a port — untyped error; use `<Domain>Error`"

### neverthrow idioms (→ `ERROR_TYPE_DETAIL`, `COMPOSITION_PATTERNS`, `ERROR_COMPOSITION_IDIOMS`)

API names verified against the neverthrow v8 README (Context7 `/supermacro/neverthrow`).
Render only the rows the repo uses or will need; every example rewritten with
the repo's own types.

| Need | Use | Not |
|---|---|---|
| sequence a step that can fail | `.andThen(f)` (sync) / `.asyncAndThen(f)` (sync → async) | `.map(() => ok(…))` |
| transform the value / the error | `.map(f)` / `.mapErr(f)` | re-wrapping by message |
| several independent Results, stop at first error | `Result.combine([a, b])` → `Result<[A, B], EA \| EB>` | nested `andThen` for independent steps |
| validation: collect every error | `Result.combineWithAllErrors([a, b])` → `Result<[A, B], (EA \| EB)[]>` | `combine` (loses all but the first) |
| several independent async calls in parallel | `ResultAsync.combine([a, b])` (also `ResultAsync.combineWithAllErrors`) | `Promise.all` over unwrapped values |
| a side effect without changing the value | `.andTee(f)` (success) | `.map(x => { log(x); return x })` |
| early-return style in a long chain | `safeTry(function* () { const x = yield* step(); … return ok(r) })` | `isErr()` ladders |
| wrap a throwing sync call | `Result.fromThrowable(fn, toDomainError)` | `try/catch` |
| wrap a promise | `ResultAsync.fromPromise(p, toDomainError)`; `ResultAsync.fromThrowable(fn, toDomainError)` when `fn` may throw before returning the promise | `fromPromise` without an error mapper (`unknown` error) |

Placement (→ `ERROR_BOUNDARY_RULES`): `fromThrowable` / `fromPromise` /
`ResultAsync.fromThrowable` appear **only in driven adapters** (and the HTTP
client wrapper the adapters share). Inner layers receive already-converted
domain values and domain errors; a `fromPromise` in a use case is a missing
adapter. The transport error type (`ApiError`, `AxiosError`, `Response`) is
importable only under the adapters / HTTP-client directory.

Error type: one discriminated union per domain (`{ kind: "notFound"; … } |
{ kind: "unexpected"; cause: unknown }`); ports and use cases return
`ResultAsync<T, <Domain>Error>`, never `ResultAsync<T, Error>`. An `Error`
subclass carrying `kind` is acceptable — **pick one per domain**, never both.
Keep `cause` for logging; never parse it.

### Traps with examples (→ `TRAPS_WITH_EXAMPLES`)

```typescript
// ❌ .map wraps the callback's return: ResultAsync<Ok<true, never>, E>
.map(() => ok(true))
// ✅ plain value
.map(() => true)
// ✅ callback can fail → andThen
.andThen((x) => mightFail(x))
```

```typescript
// ❌ both branches swallowed, nothing records the failure
void useCase.release(ids).match(() => undefined, () => undefined);
// ✅ the failure goes somewhere a caller reads
useCase.release(ids).mapErr((error) => alerter.error(error));
// ✅ allowed no-op, named: the use case already wrote the outcome to state
const stateAlreadyUpdated = () => undefined;
void useCase.release(ids).match(stateAlreadyUpdated, stateAlreadyUpdated);
```

```typescript
// ❌ string-typed error, matched by message
if (error.message === "Failed to sign in") …
// ✅ branch on the discriminant; no default, so a new kind fails to compile
switch (error.kind) { case "invalidCredentials": …; case "network": …; case "unexpected": … }
```

```typescript
// ❌ catch-all conversion inside a use case
ResultAsync.fromPromise(file.text(), (e) => (e instanceof Error ? e : new Error(String(e))))
// ✅ the adapter converts; the use case receives a domain value or a <Domain>Error
```

```typescript
// ❌ _unsafeUnwrap in production code — throws on err
const user = getUser(id)._unsafeUnwrap();
// ✅ tests only: expect(result._unsafeUnwrap()).toEqual(…); in code, map / andThen / match
```

## 9. Validation

| Library | Grep for | Belongs in |
|---|---|---|
| zod | `z.object(`, `safeParse` | driving adapter (request/form) and driven adapter (wire response) — parse, then map to domain |
| ArkType | `type({`, `from 'arktype'` | same |
| valibot | `v.object(`, `from 'valibot'` | same |
| TypeBox | `Type.Object(` (Fastify) | driving adapter |
| class-validator | `@IsString()` DTOs (NestJS) | driving adapter DTOs only |

`z.infer<typeof Schema>` used as the domain type = no translation boundary (gap).

## 10. Type escape hatches

`architecture.type_escape_hatches`: ["`as` casts (incl. `as unknown as`)", "`any`", "non-null `!`", "`@ts-ignore` / `@ts-expect-error`", "`// eslint-disable` for type rules", "`Function` / `object` / `{}` types", "untyped `JSON.parse` result"]

## 11. Hexagon mapping hints

| Role | Frontend (React/RN/Vue) | Node backend (Express/Fastify/Nest/Hono) |
|---|---|---|
| domain_type | `src/domain/`, `features/<f>/domain/`, `*.core.ts`, `*.model.ts` | `src/<module>/domain/` |
| domain_error | `errors.ts` union with `kind` | same, or `*Error extends Error` |
| driving_port | `*.use-case.ts`, `application/` functions | `application/*Service`, use-case functions |
| driving_adapter | route loaders/actions, screens' route files, deep-link / push handlers | routes/controllers, Nest `@Controller`, queue consumers, CLI commands |
| presentation (layer kind) | view-models / presenters: `use*` hooks, `*.view-model.ts`, `*.presenter.ts` — UI state, call use cases | — |
| view (layer kind) | components `*.tsx`: render props from a presentation model, own no state or decisions | server-rendered templates, if any |
| driven_port | `ports/*.ts` interfaces | same; Nest needs an injection token (interfaces vanish at runtime) |
| driven_adapter | API clients (`*.repository.ts`, Apollo/fetch/tRPC), storage | DB repos (Prisma/Drizzle/TypeORM), HTTP clients |
| test_double | `*.fake.ts`, `in-memory-*.ts`, `__fakes__/` | same |
| composition_root | `main.tsx` / provider tree / `container.ts` | `server.ts`/`main.ts`, Nest `AppModule` |

State stores (MobX/Zustand/Redux) → a `kind: state` layer between use cases
and presentation. Components are `kind: view`, never `presentation`;
view-models are `kind: presentation`, never `driving-adapter` (see DETECTION
kind mapping).

Shared capability ports (→ `SHARED_PORTS_TABLE`): grep `ports/` and
`shared/` for `Clock`, `IdGenerator` / `Ids`, `Scheduler` / `Timer`,
`Alerter` / `Notifier`, `Logger`, `AccessTokenProvider`, and for each record
the real implementation (`systemClock`, `uuidV7IdGenerator`,
`timeoutScheduler`) and the test fake (`fixedClock`, `sequentialIds`,
`manualScheduler`, `createFakeAlerter`). Inner layers that call `new Date()`,
`Date.now()`, `crypto.randomUUID()`, `setTimeout` instead are gaps.

Typical gaps (→ `conformance.gaps`):

- `type NoteRepo = ReturnType<typeof createNoteRepo>` → port derived from adapter.
- GraphQL/OpenAPI generated types (`__typename`, `components['schemas']`) or
  Prisma types (`import { Note } from '@prisma/client'`) used as domain types.
- `fetch`/`useQuery` directly in components — driving adapter calling the
  driven side, no use case.
- Module-level singletons (`export const api = new ApiClient()`) imported
  everywhere — adapter constructed outside the composition root.
- Next.js server actions / route handlers holding business rules.

`leakage_examples`: ["__typename", "@prisma/client types", "AxiosError / Response", "ApolloError", "NextRequest", "TypeORM @Entity", "z.infer of a wire schema"]

## 12. Arch tests

**dependency-cruiser** (config keys verified against sverweij/dependency-cruiser
docs: `forbidden[].from/to.path|pathNot`, `$1` back-reference,
`dependencyTypes`, `options.doNotFollow`, `options.tsConfig.fileName`;
config auto-discovered since v13). Starting point — adapt the path regexes.
`.dependency-cruiser.cjs`:

```js
/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: 'domain-depends-on-nothing-outward',
      severity: 'error',
      from: { path: '^src/([^/]+)/domain/' },
      to: { path: '^src/[^/]+/(application|adapters|ui)/' },
    },
    {
      name: 'domain-no-npm-except-allowlist',
      severity: 'error',
      from: { path: '^src/[^/]+/domain/' },
      to: { dependencyTypes: ['npm'], pathNot: ['node_modules/(neverthrow|arktype)/'] },
    },
    {
      name: 'application-depends-on-domain-only',
      severity: 'error',
      from: { path: '^src/[^/]+/application/' },
      to: { path: '^src/[^/]+/(adapters|ui)/' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
  },
};
```

`commands.arch_test`: `<exec> depcruise src` (non-zero exit on `error` violations).

Alternatives: `eslint-plugin-boundaries` (element types + `boundaries/element-types`
rule) when the repo prefers lint; Nx `@nx/enforce-module-boundaries` with tags
when Nx is present.

## 13. Pitfalls

- Watch modes: `vitest` (no `run`), `jest --watch` inside the `test` script,
  `bun test --watch`. Always use the §4 invocations.
- `npx` in a pnpm/yarn/bun repo installs a second copy or the wrong version.
- Path aliases (`@/…`) need tsconfig `paths` AND the runner's resolver
  (vitest `vite-tsconfig-paths`, jest `moduleNameMapper`).
- ESM/CJS mismatch in jest (`SyntaxError: Cannot use import statement`) is a
  config problem, not a test failure — report BLOCKED.
- Exclude from `owns` and greps: `node_modules/**`, `dist/**`, `build/**`,
  `.next/**`, `.expo/**`, `.turbo/**`, `coverage/**`, `storybook-static/**`,
  `**/__generated__/**`, `**/*.generated.ts`, `**/gql/**` (codegen),
  `**/*.d.ts` that are generated, `ios/**` + `android/**` in Expo managed apps.
- Snapshot files (`__snapshots__/`) are owned by the layer owning the test.
- `postinstall` / codegen scripts must run after dependency changes — record
  them in the dependency step, not the gate.

## 14. Reviewer greps

Feeds `verify.mechanical_checks` and `STACK_REVIEW_GREPS`. Starting points:
replace every `<…>` with the repo's real paths and suffixes (from the hexagon
mapping), drop checks for roles the repo does not have, and run each once
against the exemplar slice before committing it — a check that hits the
conforming exemplar is wrong. `<domain>` = any feature directory. The comment
above each command says what it catches; each must print nothing.

Diff scope. `$F` = changed files, one per line (always quote it: zsh does not word-split); `sel` / `skip` filter it; `/dev/null` keeps `grep`
from reading stdin when the selection is empty:

```bash
F=$( { git diff --name-only HEAD; git ls-files -o --exclude-standard; } | grep -E '\.(ts|tsx)$' | sort -u)
sel()  { printf '%s\n' "$F" | grep -E  "$1"; }
skip() { printf '%s\n' "$F" | grep -vE "$1"; }

# port derived from its adapter
sel '<ports>/' | xargs grep -n 'ReturnType<typeof create' /dev/null
# wire-response parsing outside adapters
skip '<adapters>/|<http-client>/' | xargs grep -nE 'responseType:|\.json\(\)|<ResponseDto>' /dev/null
# backend casing / wire enums outside adapters (tune the enum regex to the API's prefixes)
skip '<adapters>/' | xargs grep -nE '"[a-z]+_[a-z_]+\??":|\b<WIRE_ENUM_PREFIX>_[A-Z_]+\b' /dev/null
# transport error type outside adapters
skip '<adapters>/|<http-client>/' | xargs grep -nwE 'ApiError|AxiosError' /dev/null
# framework / platform / time / ids in inner layers
sel '<domain-dir>/|<use-case-suffix>$|<ports>/' | xargs grep -nE 'from "(react|react-native|expo-[a-z-]+|mobx|uuid)"|\b(window|document|navigator)\.|AppState|Platform\.|Linking\.|setTimeout|setInterval|new Date\(\)|Date\.now\(\)' /dev/null
# store setter called from UI
sel '^(<ui-dirs>)/' | grep -v '\.test\.' | xargs grep -nE '[a-zA-Z]+(Store|State)\.(set|add|remove|clear|update)[A-Za-z]*\(' /dev/null
# string-matched error
printf '%s\n' "$F" | xargs grep -nE '\.message (===|!==)|message\.(includes|startsWith)\(' /dev/null
# nested Result
printf '%s\n' "$F" | xargs grep -nE '\.map\(\(\) => (ok|err)\(' /dev/null
# unexplained no-op match (a named no-op passes)
printf '%s\n' "$F" | xargs grep -nE 'match\(\(\) => undefined, *\(\) => undefined\)' /dev/null
# _unsafeUnwrap outside tests
skip '\.test\.|/tests?/' | xargs grep -n '_unsafeUnwrap' /dev/null
# fromPromise / fromThrowable outside adapters
skip '<adapters>/|<http-client>/|\.test\.' | xargs grep -nE 'fromPromise|fromThrowable' /dev/null
# try/catch in inner layers
sel '<domain-dir>/|<use-case-suffix>$|<ports>/' | xargs grep -nE '\btry \{|catch \(' /dev/null
# untyped error in a port
sel '<ports>/' | xargs grep -nE '(Result|ResultAsync)<[^,>]+, *Error>' /dev/null
# React state / effects in view files (narrow exception: useRef + an effect calling a native ref method on an own node)
sel '\.tsx$' | grep -vE '\.test\.|\.stories\.|<view-model-suffix>' | xargs grep -nwE 'useState|useReducer|useEffect|useMemo|useCallback' /dev/null
# context reached from a view
sel '\.tsx$' | grep -vE '\.test\.|\.stories\.' | xargs grep -n '<useAppContext>' /dev/null
# hover in a view (platform: react-native only)
sel '\.tsx$' | xargs grep -n 'hover:' /dev/null
# view-model test stubbing a core or asserting store / repository
sel '<view-model-suffix>\.test\.' | xargs grep -nE 'spyOn\([a-zA-Z]*(Core|UseCase), *"[a-zA-Z]+"\)\.mock|expect\([a-zA-Z]*(Store|Repository)\.' /dev/null
# escape hatches (one allowed cast: branding an id inside a mapper)
printf '%s\n' "$F" | xargs grep -nE ' as [A-Z]| as unknown|: any\b|<any>|@ts-ignore|@ts-expect-error' /dev/null
```

Repo scope (whole tree, reported as new-vs-baseline against "Known deviations"):

```bash
# ports derived from adapters / fakes
rg -n 'ReturnType<typeof create' src --glob '!*.test.*' --glob '!**/tests/**'
rg -l 'ReturnType<typeof createFake' src
# untyped error in ports
rg -n 'ResultAsync<[^,]*, Error>' --glob '<port-file-glob>'
# state port declared next to the store implementation
rg -n '\binterface\b|Interface\b' --glob '<store-file-glob>'
# reactions / subscriptions outside the composition root (inside it, each must carry no decision)
rg -n '\b(reaction|autorun|subscribe)\(' src --glob '!<composition-root-dir>/**' --glob '!*.test.*'
# tests / fakes imported by the composition root
rg -n "from ['\"].*(/tests?/|\.fake['\"])" <composition-root-files>
# composition root importing the UI layer
rg -n 'from "@/(<ui-dirs>)/' <composition-root-dir>
# platform calls in the composition root
rg -n 'window\.|Linking\.|AppState\.' <composition-root-files>
# context reached from views
rg -l '<useAppContext>' <ui-dirs> --glob '*.tsx' --glob '!*.test.*' --glob '!*.stories.*'
# i18n key parity, per namespace (when skills.optional.i18n): one line per missing key.
# A missing translation is the I18N_MISSING_MARKER value, never an absent key.
diff <(jq -r 'paths(scalars)|join(".")' <locales>/en/<ns>.json | sort) \
     <(jq -r 'paths(scalars)|join(".")' <locales>/fr/<ns>.json | sort)
```

Locale files that are TS/JS modules, not JSON: compare exported keys by
reading both files, or a one-off `node -e` the user approves.

## 15. Platform UI rules

Feeds `PLATFORM_UI_RULES` (component-design, view builders) and
`PRESENTATION_PLATFORM_RULES` (presentation-model, view-model builders), by
`skills.optional.component_design.platform`. Keep only rules the repo's code
already follows or the user confirms; every primitive named must exist in its
dependencies.

### React Native / Expo (`platform: react-native`)

View rules:

- RN primitives only — `View`, `Text`, `Pressable`, `TextInput`, `ScrollView`,
  `FlatList`, `Modal`, `Image` (or `expo-image` when installed). No DOM tags.
- Long or unbounded lists use `FlatList` / `SectionList` (or `FlashList` when
  installed), never `.map()` inside a `ScrollView`.
- Respect safe areas (`react-native-safe-area-context` `SafeAreaView` /
  `useSafeAreaInsets`), never hard-coded status-bar padding.
- Touch targets at least 44×44 pt (`hitSlop` when the visual is smaller).
- No hover: style pressed / disabled with `active:` / `disabled:` (NativeWind)
  or `Pressable` `style={({ pressed }) => …}`. `hover:` in a `.tsx` is a finding.
- Accessibility text (`accessibilityLabel`, `accessibilityHint`, `accessibilityRole`
  labels) is user-visible text: through `t()` when i18n is enabled.
- Platform differences in platform files (`Foo.ios.tsx`, `Foo.android.tsx`,
  `Foo.web.tsx`), not `Platform.OS` branches inside components.
- `preview: none` → no `.stories.tsx` files; keep atoms and molecules
  props-only so a preview tool can render them later.

Presentation rules:

- Navigation is UI plumbing: `useRouter`, `useLocalSearchParams`, `Link` /
  `router` from `expo-router` (or React Navigation hooks) are allowed in
  presentation models and route files, **never** in use cases or domain.
- `AppState`, `Linking`, `Alert`, `Keyboard`, haptics: reached through a port or
  the context, not called from a presentation model directly.

### Web React (`platform: web`)

View rules:

- Semantic HTML first (`button`, `a`, `label`, `nav`); no click handlers on
  `div`. Every input has a label; images have `alt` (through `t()` with i18n).
- Hover is allowed but never the only affordance; keyboard focus styles stay.
- Lists render with stable `key`s from domain ids, never array indexes for
  reorderable data.
- Framework links (`next/link`, React Router `Link`) for in-app navigation, not
  `window.location`.
- Server components / loaders (Next.js, React Router) are driving adapters:
  they call use cases, never adapters directly.

Presentation rules:

- `useRouter` / `useNavigate` / `useSearchParams` allowed in presentation
  models and route modules, never in use cases.
- `window`, `localStorage`, `document` reached through a port.

Vue / Svelte / Angular: same split (template = view, composable / store
facade / service = presentation); write the rules from the repo's exemplar.
