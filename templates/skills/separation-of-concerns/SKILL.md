---
name: separation-of-concerns
description: "Which layer of the hexagon owns a given piece of logic, and why. Use when deciding where a rule belongs, when a file is doing two jobs, when a change would touch several layers at once, when tempted to reach past a neighbour layer, or when reviewing whether code sits in the right place. Covers the placement tests, one-reason-to-change, the usual misplacements, and the smells that mean a boundary was crossed. Pairs with hexagonal-architecture (the boundary itself), the project's architecture skill (this project's names and paths), and extract-til-you-drop (decomposition inside a layer)."
---

# Separation of concerns

Three questions, three skills, and they do not overlap:

| Question | Skill |
|---|---|
| Where is the boundary, and what crosses it? | `hexagonal-architecture` |
| **Which side of it does this logic go on?** | **this skill** |
| How far do I decompose once it is on the right side? | `extract-til-you-drop` |

This skill assumes the hexagon. It does not restate the dependency rule, ports,
adapters or injection — those are in `hexagonal-architecture`, once.

## The test that settles most arguments

> Would this rule still be true if the framework, the transport, and the storage
> all changed?

- **Yes** → it is a business rule. It belongs in the innermost layer that can
  hold it.
- **No** → it is a detail. It belongs in the layer that owns that detail.

Second test, for the remaining cases:

> What would force this file to change?

A file with two answers is two files. That is the one-reason-to-change rule, and
it is what makes a layer boundary real instead of decorative.

## The usual placement mistakes

| Logic | Wrong home | Right home |
|---|---|---|
| Rule about one entity (is this value legal?) | use case, or repeated in callers | the entity or value object itself |
| Business validation (is this allowed?) | driving adapter or form config | domain, or the use case for cross-entity policy |
| Shape validation (is this well-formed?) | scattered | the driving adapter, where untrusted input enters, once |
| Orchestration across dependencies | driving adapter | application use case |
| Loading/success/error transitions | ad-hoc in each caller | the unit that owns the operation |
| Error classification (driver error → typed failure) | propagated upward raw | the driven adapter that produced it |
| Presentation formatting (dates, currency, labels) | domain | driving adapter / presentation |
| Clock, id generation, randomness, timers | called directly inside a rule or use case | a driven port, injected; the value arrives as a parameter |
| Retry, caching, pooling, connection handling | use case | driven adapter |
| Authorization decision | driving adapter or transport | domain or application (the transport only carries identity) |
| Mapping wire/row shape ↔ domain type | nowhere — the shapes were merged | the adapter, explicitly |

Two directions of failure, both common:

- **Logic drifting outward** — a rule ends up in a component or handler because
  that is where the change was noticed. It then exists once per caller.
- **Details leaking inward** — a storage or transport type appears in a business
  signature "just for now". Every caller is now coupled to that technology.

## Naming a port is a placement decision

A port named after its implementation (`PostgresUserPort`, `RedisCache`,
`S3Storage`, `GrpcBillingClient`) is not a port. The name is the tell: it describes a mechanism, so
the inside now knows the mechanism, and the boundary moved without anyone
deciding to move it.

Name a driven port for the capability the inside needs (`UserRepository`,
`Clock`, `NotificationSender`), and a driving port for the use case the
application offers.

## Reaching past a neighbour

A layer talks to its neighbours, not through them. An outer layer that imports
two layers down has silently made the middle layer optional — and the rule the
middle layer enforces is now skippable.

Same rule sideways: one module (package, crate, project) reaches another
through its published contract, never into its internals.

## Smells

Structural breakages are listed as anti-patterns in `hexagonal-architecture`.
These are the *placement* smells — the code is on the wrong side, even though the
boundary still exists:

- A business rule expressed in a driving adapter — handler, controller, UI
  component, form config, CLI parser, message consumer.
- A caller that knows *how* an operation works rather than *that* it happened.
- A unit whose test needs a real database, network, renderer, or clock.
- A file that changes for two unrelated reasons.
- A "util"/"helper"/"manager"/"service" file with no single nameable owner —
  that name is where misplaced logic accumulates.
- A conditional on the *kind* of caller (`if isWeb`, `if fromAdmin`) inside inner
  logic — the caller's identity leaked in.

## When two layers both seem right

Choose the inner one **only** if the rule survives the framework/transport/
storage test above. Otherwise choose the outer one — a detail parked in the
inner layer is harder to find later than a rule parked outward.

If you genuinely cannot decide, that is a signal the concept is missing a name.
Name it, give it its own unit, and the boundary usually becomes obvious.

Never resolve it by duplicating the logic on both sides.
