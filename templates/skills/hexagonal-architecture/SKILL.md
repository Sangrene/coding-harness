---
name: hexagonal-architecture
description: "Hexagonal architecture (ports & adapters) with clean layering — the architecture this project enforces, always, in any language. Use when designing or implementing any feature or fix, adding a domain, declaring a port (interface, trait, abstract type), writing an adapter or mapper, wiring the composition root or DI container, choosing what a library exposes, or reviewing whether code respects the hexagon. Covers the dependency rule, driving vs driven ports and adapters, domain purity, translation at the boundary, dependency injection, scaled shapes (full, minimal, library), and the anti-patterns that quietly dissolve the hexagon. Not optional and not per-project: every project using this harness is hexagonal."
---

# Hexagonal architecture (ports & adapters)

**Not a style choice. Every project using this harness is hexagonal with clean
layering, and every agent enforces it.** Terminology follows Cockburn: the
application talks to the outside over technology-agnostic **ports**;
**adapters** translate the technical exchange. The project's architecture skill
(`architecture`, or `<prefix>-architecture` per package) maps this model onto
real names and paths.

## The hexagon

```text
driving adapter ──calls──► driving port ──► APPLICATION ──► DOMAIN (depends on nothing)
(handler, CLI, UI, consumer)                     │ uses
                                                 ▼
driven adapter ──implements──► driven port (declared by the inside)
(DB, HTTP client, files, clock, external API)
```

- **Driving (primary)** — the outside calls in: a driving adapter invokes a
  driving port, the use case offered. The application does not know who called.
- **Driven (secondary)** — the application calls out: it declares a driven port
  for what it *needs*; a driven adapter implements it with a technology.

Both kinds of port are declared **by the inside**, in the inside's vocabulary. A
port written to match an existing client library is not a port. A port is
whatever the language uses to name a contract without an implementation
(interface, trait, protocol, abstract class, function type).

## The dependency rule

Dependencies point inward, always. Domain depends on nothing. Application depends
on domain and its own ports. Adapters depend on ports. Nothing inward depends on
anything outward. Inside domain and application files:

- no framework, HTTP, UI, ORM, driver, serialization or transport import;
- no infrastructure type in any signature — no row, DTO, response object, ORM
  entity, framework error;
- no wire annotation on a domain type (serialization attributes, struct tags,
  serde-style derives, wire discriminators);
- no global state reaching a concrete adapter, store or client (module-level
  singleton, package-level variable, static service locator, lazy global);
- no I/O, no clock, no randomness, no environment access except through a port.

If you just typed one of those into an inner file, stop. The design is wrong and
injection is the fix — not a comment, not "temporarily".

## Domain layer

Holds the rules and the vocabulary. Pure: constructible in a test with no
infrastructure, unchanged if the database, transport and UI were all replaced.

- **Entities and value objects carry behaviour**, not just shape. A rule about an
  entity belongs on it. Dedicated types over primitives for concepts with rules
  (`Email`, `Money`) — validation lives there once.
- **Domain errors are domain types**; every failure case is distinguishable
  without reading text (discriminant, variant, sentinel value, subtype). No
  infrastructure error type crosses into the domain.
- **Driven ports live with the domain or application that needs them** — never
  with their implementation.
- An **anemic** domain (schemas with no behaviour, use cases that only forward
  to a repository) is a degenerate case, not a variant: the inner layer is
  decorative.

## Application layer

Use cases load through driven ports, invoke domain behaviour, persist, and
return a typed result. They depend on ports only, never an adapter; hold
orchestration and cross-entity policy (not single-entity rules, formatting,
transport or persistence detail); and own their operation's consistency
boundary.

## Adapters

- A driven adapter **implements** a port and **translates** both ways
  (infrastructure shape ↔ domain type). Raw infrastructure values never pass.
- A driven adapter **classifies** raw failures (status code, driver error, parse
  failure) into the port's typed error kinds. No caller string-matches a message.
- A driving adapter parses untrusted input into domain types, calls **one** use
  case, and maps the typed result to its transport. It holds no business rule.
- An adapter never imports another adapter concretely; it injects a port.
- **A driven adapter's I/O is not unit-tested.** Integration or contract tests
  cover it where the repo has them; otherwise its bar is being *injectable*.
- **Driving adapters and presentation models are tested at their own
  behaviour** (parsing, error mapping, which use case is called and when),
  never re-asserting the use case's. **Mappers and translators are
  unit-tested** like domain code, kept separate from the I/O.
- Every port has a test double. A test-only double lives with the tests and is
  never imported by production wiring. An in-memory adapter production may
  select (offline/fakes mode) is an adapter, lives with the adapters, and is
  chosen in the composition root.

## Translation is mandatory

The most common quiet dissolution: a schema parses the response and is passed
inward as the domain type. The skipped code was the anti-corruption boundary;
every API change becomes a domain change. The domain type and the transport/persistence type are
**separate types**, even when their fields match today. The mapping function is
the boundary.

## Composition root and dependency injection

Concrete adapters are constructed only in the composition root and injected
downward; nowhere else reads configuration or picks an implementation. The root
holds no business logic; it wires, and can swap the outside for doubles.

Dependencies arrive as parameters (constructor, factory or function argument, a
deps object of ports). A DI container is acceptable only at the root; nothing
below resolves from it. Never an import of a concrete thing, a global, or
service location. When a test is hard to write, the injection is missing; a
heavier mock vents that pressure and freezes the bad design.

## Anti-patterns

Each means the hexagon is broken, not merely untidy: (1) framework/ORM/
serialization type or annotation in a domain type; (2) infrastructure error
crossing a port; (3) the port derived from its adapter — type inferred from the
implementation, or port and adapter in the same file, package or project;
(4) no translation at the boundary; (5) business rule in a driving adapter
(handler, component, form config, parser); (6) a driving adapter calling a
driven port directly, skipping the use case; (7) adapter constructed outside
the composition root, even "just for this test" or behind a lazy singleton;
(8) anemic domain; (9) business logic in the bootstrap file; (10) a concrete
type in a use case's constructor where a port belongs.

## Enforcing it mechanically

A violation is cheapest when the build rejects it: where the stack allows,
encode the rule as inward-only module/package references plus boundary tests
that fail the gate. The project's architecture skill names this repo's tool. A
mechanical check is a floor, not a substitute: it catches imports, not a rule
sitting in a handler.

## Scaled shapes

The shape declares which roles do not exist; **scaling removes roles, never
rules.** Remaining roles obey everything above.

| Shape | For | Removes | Still required |
|---|---|---|---|
| full | services, apps, workers | nothing | all roles |
| minimal | CLIs, small workers | separate application layer (use cases may sit beside the domain) | driving port, driven ports + adapters, one driving adapter, composition root |
| library | packages consumed by code | driving adapter, composition root | domain, driven ports, translation in any shipped adapter |

In a **library** the public API *is* the driving port (no infrastructure type)
and the consumer is the composition root. The library never constructs its own
infrastructure, reads global configuration or picks an implementation; a
default adapter is opt-in and injected. A role that should exist but does not
is a deviation, not a shape.

## Clean layering inside the hexagon

`domain → application → (ports) → adapters`, inward only, each layer changing
for one reason. Placement: `separation-of-concerns`. Decomposition:
`extract-til-you-drop`. Proving the inside without the outside: `tdd`.
