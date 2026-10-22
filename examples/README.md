# Examples

Filled `harness.yml` manifests (schema v2, see `../harness.schema.yml`). The four
stack-named files (`nextjs-apollo-web`, `react-router-web`, `expo-mobile`,
`rust-axum-service`) are modelled on real codebases and anonymized; the rest are
illustrative and say so in their header.

| File | Stack | Kind | Shape | Conformance | What it demonstrates |
|---|---|---|---|---|---|
| `nextjs-apollo-web.harness.yml` | TypeScript — Next.js, Apollo, Zustand, Jest (yarn) | web-app | full | partial | Legacy services left as `migrate` gaps; a `domain-builder` split out of the repository layer; `.agent.md` suffix; memory file moved because root `AGENTS.md` belongs to `next dev`. |
| `react-router-web.harness.yml` | TypeScript — React Router, MobX, ArkType, neverthrow, Vitest (bun) | web-app | full | partial | A migration that has mostly landed: narrow, real residual gaps; `mechanical_checks` lifted from the repo's own gap audit; excludes that carve the state port out of `ports/`. |
| `expo-mobile.harness.yml` | TypeScript — Expo / React Native, MobX, Vitest + jest-expo (bun) | mobile-app | full | partial | Two runners with per-layer `test_targeted`; `bunx expo install`; `component_design` on `react-native` with no preview; AGENTS.md versioned-docs rule carried forward. |
| `rust-axum-service.harness.yml` | Rust — Axum, sqlx, cargo workspace | service | full | partial | Modular monolith (one crate per module); `cargo check --all-targets` so tests compile in the gate; builders own their `tests.rs` instead of a separate test author; in-memory adapters selected in fakes mode recorded as driven adapters, their reuse as test doubles a `migrate` gap. |
| `go-service.harness.yml` | Go 1.23 — chi, pgx, sqlc | service | full | greenfield | Consumer-side interfaces as driven ports; sentinel + typed errors with `errors.Is/As`; `go vet` gate; `-count=1`; generated code excluded from every owner; go-arch-lint `generate`. |
| `dotnet-api.harness.yml` | C# 13 — ASP.NET Core 9, EF Core, ErrorOr, FluentValidation | service | full | partial | `separate-project` tests; composition-root files carved out of each layer with `excludes`; `max_files: 5` for infrastructure; port-declared-in-Infrastructure gap; NetArchTest `generate`. |
| `library.harness.yml` | Rust — single crate | library | library | conforming | The scaled hexagon: public API as driving port, `driving_adapter` and `composition_root` absent by shape, ports injected by the consumer. |
| `workspace.harness.yml` | Go API + TypeScript React web | fullstack | full (per package) | greenfield | Workspace form: `packages[]` each with its own commands, architecture, layers and testing; prefixes `api` / `web`; OpenAPI contract owned by `api`. |
