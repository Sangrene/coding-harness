# Rule packs by layer kind

Installer reference. Not emitted as a file.

Each `layers[]` entry has a `kind`. Render the bullets under the matching
`## kind:` heading, verbatim, into that agent's `{{KIND_RULES}}`. Fill the
placeholders inside the bullets like any other template. `kind: other` has no
pack: drop the `{{KIND_RULES}}` section from that agent.

Kind → pack: `domain`, `application`, `driven-adapter`, `driving-adapter`
(transports: HTTP handler, CLI, queue consumer), `state`, `presentation`
(view-model / presenter), `view` (humble UI component), `wiring`. A UI
component layer is always `view`; a view-model is always `presentation`. A
bullet whose condition does not hold (no i18n, no presentation model) is
dropped, as its own wording says.

These are invariants. They hold in every stack, so they never name a language
keyword, a library or a file suffix. The repo-specific rules (`layers[].rules`)
render separately into `{{RULES}}` and never restate a rule from here. When a
repo rule contradicts a pack rule, the pack wins and the contradiction is a
`conformance` gap, not a softer pack.

"References" below means whatever the stack uses to depend on another unit: an
import, a `use`, a package import, a project reference.

---

## kind: domain

- **References nothing outside the domain**, except the standard library and the
  failure type named in `{{ERRORS_SKILL}}`. No framework, transport, storage,
  serialization, UI, clock or random source — and nothing from a port, adapter
  or use-case folder.
- **Project vocabulary, never the backend's.** Names, casing, enum values and
  date types are the project's: `createdAt` as a date, not `created_date` as a
  string; `Analysing`, not `"ANALYSIS_IN_PROGRESS"`. Translation is the driven
  adapter's mapper, never yours.
- **One named, public, pure function (or entity method) per rule.** A rule is
  every "only if", "must", "cannot", "at most", "when X then Y". Its name states
  the rule: `canSaveDraft`, `isExpired`, `removeSection`.
- **Time and identity come in as parameters.** Never read the system clock or
  generate an id inside the domain; the caller passes `now` and the new id.
- **A rule that can fail returns the domain failure** through the project's
  failure type. A rule that cannot fail returns a plain value.
- **Add error kinds, never a catch-all.** Each distinct failure is its own kind
  (variant, subtype, sentinel value, discriminant). A generic message-string
  error is a finding.
- **One test per branch of every rule, plus the boundaries**: empty collection,
  last item, exact cap, one past the cap. Pure input → output. If a domain test
  needs a double, the rule depends on something it must not.

## kind: application

- **Calls rules, does not write them.** Every condition that decides what is
  allowed, every limit, every cascade is a domain function. If the one you need
  does not exist, report `STATUS: blocked`, `NEXT: {{DOMAIN_AGENT}}`.
- **Decide from the entity you were given or loaded through a port, never from a
  state read.** Reading state to decide whether or how to act is a hidden rule.
  Reading state to compute the next value you write back is fine.
- **Clock, ids, scheduling and environment are injected ports.** Never read the
  system time, generate an id, start a timer or touch a platform global here.
- **Never self-start.** Nothing is subscribed, scheduled or spawned at
  construction (no reaction, timer, background task, goroutine, hosted
  service). Expose a method; the composition root subscribes it.
- **Dependencies reference ports only.** The use case's constructor arguments,
  dependency record or dependency struct name port types — never an adapter, a
  concrete state class, or a framework type.
- **One test per branch the use case takes**: rule allowed / refused, port ok /
  each error kind. Do not re-enumerate a domain rule's inputs; `{{DOMAIN_AGENT}}`
  tests those. Build the real use case with a double for every port.
- **Assert the returned result and the state written through ports.** Assert an
  error by its kind, never by its message text.
- **Size is a smell.** A use case past ~80 lines of logic almost always hides a
  rule that belongs in the domain.

## kind: driven-adapter

- **Work order: port → mapper (test-first) → adapter → in-memory adapter →
  double.** Each step reads the finished previous one.
- **The port is declared by the inside, in domain types, in its own file.** Never
  derive it from the adapter and never declare it beside the implementation.
- **Every implementation states the port it implements**, so drift fails the
  build: an annotation, an `implements` clause, or a compile-time assertion
  (`var _ NoteRepository = (*PgNoteRepository)(nil)` in Go). The adapter, the
  in-memory adapter and the double all do this.
- **Translate at the boundary, both directions.** The wire or row shape never
  leaves the adapter; a mapper turns it into the domain type and back.
- **Classify every infrastructure failure into a domain error kind here.** No raw
  driver, HTTP or SDK error crosses the port.
- **An adapter never references a use case.** If it needs something the
  application provides (a fresh token, the current user), declare a small port
  for it and let the composition root pass an implementation.
- **Only the operations the feature needs now.** No speculative CRUD.
- **Mappers are pure functions with decisions, so they are unit-tested**: one
  case per enum value, each date or number parse, each null or absent field,
  each error classification. The adapter's I/O itself (the query, the call, the
  write) is not unit-tested — integration or contract tests cover it where the
  repo has them.

## kind: driving-adapter

A transport entry point: HTTP or RPC handler, CLI command, queue or event
consumer, scheduled job. UI components are `kind: view`; view-models are
`kind: presentation`.

- **Parse and validate input at the edge.** The raw request, argv or message
  becomes the use case's input here; nothing unvalidated goes inward.
- **Call exactly one driving port per action.** Never a driven port, a
  repository or a state setter directly.
- **Map every error kind to the transport**: status code, exit code, retry or
  dead-letter, error body. No raw error text reaches the caller.
- **No business rule.** A condition that decides what is allowed belongs to
  `{{DOMAIN_AGENT}}`; report `STATUS: blocked` rather than writing it here. Past
  ~150 lines, an adapter almost always hides one.
- **Tests test the adapter's own behaviour**: input parsing, which use case is
  called, when, with what arguments, and when it is not called; and the error →
  transport mapping for each outcome. Use real use cases over fake ports; observe calls with
  {{SPY_TECHNIQUE}}. Never re-assert the use case's effects, and never stub a
  use case's return value.

## kind: state

- **The state port is separate from the state implementation**, in its own file,
  and references no framework or reactivity type — domain types and read-only
  collections only. Use cases reference the port, never the class.
- **Setters and fields only.** A setter assigns. No dedupe, ordering, cascade,
  derived rule or async work. If the prompt asks for one ("add, skipping
  duplicates"), write a plain setter and report in `OUTCOME` that the rule
  belongs to `{{DOMAIN_AGENT}}`.
- **Error fields hold the domain error type**, never a generic error.
- **Not unit-tested.** If you feel a state class needs a test, it holds logic,
  and that logic is in the wrong place.
- **You are optional.** If the state is local to one view or one call, report
  `STATUS: needs-orchestrator` rather than adding state nobody shares.
- **Field names come from the dispatch prompt** when you run in parallel with
  another builder. Use them verbatim.

## kind: presentation

The view-model / presenter between a view and the use cases. It is the UI's
driving adapter: everything the view needs is decided and exposed here.

- **Holds UI state, calls use cases, and owns UI plumbing.** Form values,
  loading and error display, selection, and navigation (routing calls, links,
  back) live here — UI plumbing is allowed in this layer and never in a use
  case. A business rule: never — report `STATUS: blocked`,
  `NEXT: {{DOMAIN_AGENT}}`.
- **Reaches use cases and read-only state through what the composition root
  provides.** Never constructs or references an adapter, never calls a state
  setter or a driven port.
- **The form's input type is the use case's input type**, never redeclared
  locally.
- **Maps each error kind to a user-facing message** by kind, never by text.
- **Exposes a render-ready shape**: values, flags (`isLoading`, `canSubmit`,
  `isEmpty`) and handlers. Every condition the view would otherwise compute is
  a named field here, so the view only branches on flags.
- **Tests test the presentation model's own behaviour**: use-case calls
  (arguments, timing, not called), what it exposes, and the error → message
  mapping. Real use cases over fake ports; observe calls
  with {{SPY_TECHNIQUE}}. Never assert state contents, port calls or outcomes the
  use-case test already covers.
- **Size is a smell.** Past ~150 lines, decompose — and look for the rule it is
  hiding.

## kind: view

A humble UI component. It renders what the presentation model returns, and
nothing else.

- **Renders, never decides.** No local state, effects, memoisation or
  derived-state hooks (or their equivalent in this stack's UI framework). The
  only local thing allowed is a ref to an imperative platform handle — focus,
  scroll, measure — used to call that handle, never to remember a value.
- **No smuggled state.** State disguised as something else is still state, and
  is a finding: a ref or mutable holder that remembers a value between
  renders; a context read used to decide or to reach a use case or setter; a
  module-level variable; URL or route parameters parsed and acted on in the
  view; a timer or subscription started from the view. Each belongs to the
  presentation model.
- **Branches only on presentation flags.** A rendering branch (`isLoading`,
  `isEmpty`, `hasError`) reads a flag the presentation model exposes. A
  comparison, count, date check or permission check computed in the view is a
  rule or a presentation decision in the wrong place.
- **Events go straight to presentation-model handlers**, passing what the user
  entered. Never a use case, a state setter, a driven port or an adapter.
- **Props in, markup out.** Data and handlers arrive as props or from the
  presentation model's return value; the view never fetches, reads storage or
  formats a domain value with a rule in it.
- **Every user-facing string goes through the translation call**
  (`{{I18N_SKILL}}`) — labels, placeholders, accessibility labels, errors.
  Drop this bullet when i18n is not enabled.
- **Split by nameable concern.** When a part of the view can be named (header,
  row, empty state, form section), it is its own component; a view that keeps
  growing is usually holding a decision that belongs in the presentation model.
- **Behaviour is tested on the presentation model.** A view test, where the
  repo has them, checks rendering only; a view that needs a logic test holds
  logic.

## kind: wiring

- **Construct adapters here and nowhere else.** Inner layers receive them
  injected.
- **Factories, not ambient singletons.** No module-level or package-level
  instance, `init()` side effect or static service locator; call a factory once
  here and pass the result.
- **Pass ports.** Use cases receive port-typed dependencies; every registry,
  container entry or context field is typed as the port, never the concrete
  class.
- **Fully faked mode uses the in-memory adapters.** Never reference anything
  under the test-double folders (`{{DOUBLES_LOCATION}}`). Every new adapter is
  registered in both the real and the in-memory branch.
- **Subscriptions that trigger use cases** are set up here, disposed on
  shutdown, and contain no condition beyond passing data. A cross-domain rule
  ("release X when Y is done") is a use case: report `STATUS: blocked` and name
  the application layer's agent.
- **Adapters never receive use cases.** Pass a port implementation built from
  them instead.
- **The surface handed to driving adapters exposes use cases and read-only
  state**, never state setters.
- **Registration is mechanical.** Match the existing layout; do not restructure
  beyond these rules. A decision written here belongs in an inner layer.
