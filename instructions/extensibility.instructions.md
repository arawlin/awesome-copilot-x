---
description: 'Extensibility rules for naming, data model, API contracts, and event formats. Enforces contract-layer extensibility and implementation-layer YAGNI.'
applyTo: '**'
---

# Extensibility Rules

Project-wide rules for designing extensible artifacts. Every named entity, data model, API contract, and event format must consider future version extensibility — but extensibility must not be confused with premature implementation.

## Core Principle: Layered Extensibility

Extensibility requirements differ by change cost. Apply the right rule to the right layer.

| Layer | Rule | Rationale |
| --- | --- | --- |
| Contract layer (naming, schema, API, events) | Must consider extensibility | High change cost — breaking changes once published |
| Implementation layer (internal code, private logic) | Follow YAGNI | Low change cost — refactorable in minutes |

**Do not** apply a blanket "make everything extensible" rule. Over-engineering the implementation layer slows MVP validation and risks designing extensibility for the wrong direction — a wrong extensibility design is worse than no extensibility.

## Contract Layer — Must Be Extensible

These artifacts are expensive to change once published. Design them for forward compatibility from day one.

- **Naming**: field names, type names, API endpoints, event names
- **Database schema**: table structure, column names, relationships
- **Public API contracts**: request/response shapes, error codes, headers
- **Event/message formats**: payload structure, topic names, schema registry
- **Core domain models**: entity relationships, state enumerations

### Forward Compatibility Techniques

- Make new fields optional with sensible defaults
- Never remove or rename published fields — add new ones instead
- Version APIs explicitly when breaking changes are unavoidable
- Design enumerations to accept unknown values gracefully (extensible enums)

## Implementation Layer — Follow YAGNI

These artifacts are cheap to change. Do not pre-build for hypothetical needs.

- Internal functions, private variables, helper utilities
- Code structure and module organization (refactorable via IDE tools)
- UI component internal state
- Configuration parameters (hardcode MVP paths; extract to config only after the need is confirmed)

**Do not**:
- Build abstraction layers for hypothetical multi-source data before a second source is confirmed
- Pre-configure all parameters "for flexibility"
- Add indirection layers to adapt to unknown futures
- Pre-create all possible database columns "just in case"

## Naming for Extensibility

Naming is the highest-leverage, zero-cost extensibility action. Get it right at design time.

### Rules

- **Name for business semantics, not version, source, or environment.** Names encode *what* a thing is, not *when* or *where* it was introduced.
- **Never embed version numbers in names.** Use `price`, not `price_v1`. Version changes go through new fields, new types, or new files — not name suffixes.
- **Never embed source identity in names.** Use `price`, not `binance_price`. Source-specific data belongs in dedicated fields, nested structures, or tags.
- **Name for responsibility, not implementation strategy.** Prefer `Coordinator` over `SlotScheduler`; prefer `SessionSupervisor` over `StreamManager`. When the implementation strategy changes, the abstract name must still hold.
- **Keep names stable.** If a name might later carry different semantics, choose a more abstract name now, or split into separate entities at design time.

### Good vs Bad

```text
// Good: business-semantic, version-agnostic, source-agnostic
record Kline {
    symbol: string
    price: number
    volume: number
    timestamp: number
}

// Bad: version and source encoded in names
record KlineV1 {              // version in record name
    binance_price: number      // source in field name
    spot_volume_v1: number     // version + source in field name
}
```

### Abstract Names vs Runtime Names

**Code identifiers and runtime identifiers serve different purposes and follow different stability expectations.**

- **Abstract names** (type names, function names, variable names in source code) describe *what* a thing is responsible for. They should be stable across versions and free of implementation-strategy details.
- **Runtime names** (topics, queues, schedule IDs, stream names, deployment identifiers) describe *which instance* of a thing is running. They carry dimensional context — the attributes that distinguish one running instance from another.

| Name kind | Answers | Stability | Should include |
| --- | --- | --- | --- |
| Abstract name (type, function, variable) | "What is this?" | High — rename is a breaking change | Business responsibility |
| Runtime name (topic, queue, schedule ID) | "Which one is this?" | Medium — new instances are additive | Distinguishing dimensions |

**Rule of thumb:** If adding a new variant (new data type, new source, new protocol) would force you to rename an existing entity, the name is too specific. If the name is stable but you cannot tell two running instances apart, it is missing runtime dimensions.

### Name for Responsibility, Not Implementation Strategy

**Avoid baking the current algorithm or resource-management tactic into a long-lived name.** Today's implementation choice may not survive the next version.

- Prefer `Coordinator` over `SlotScheduler` — "slot" is a resource-allocation tactic, not the core responsibility.
- Prefer `LaneController` over `PollingScheduler` — "polling" is one execution model among several; the responsibility is keeping a lane progressing.
- Prefer `SessionSupervisor` over `StreamManager` — "stream" describes transport, not responsibility.

When the implementation strategy changes, the abstract name should still hold. If it would not, it was too specific.

### Dimension Inclusion Principle

**Only include a dimension in a runtime name when it changes one of the following:**

- Execution model or control logic
- Scheduling rhythm or trigger cadence
- Resource pool, rate-limit budget, or capacity domain
- Retry policy, timeout profile, or recovery semantics
- Task semantics — what the task *means* to do, not just what data it carries

If a dimension does not change any of these, it does not belong in the runtime name — even if it appears in the data flowing through the system.

**Corollary:** Control-plane names and data-plane names may carry different dimension sets for the same system. A data topic name describes what data is inside; a control topic name describes what action to take and under what execution constraints. The dimensions that matter for storage and routing are not always the dimensions that matter for scheduling and execution.

### Positional Semantics over Accumulative Suffixes

**When a runtime name needs multiple dimensions, use a consistent positional pattern — not ad-hoc suffix accumulation.**

Positional naming gives every token a fixed slot with a stable meaning. Adding a new dimension means adding a new position (or leaving an existing position empty with a well-defined default), not inventing a new suffix string.

```text
// Good: positional — every token has a stable slot
cmd.fetch.kline.spot.rest.incremental

// Bad: accumulative — suffixes pile up with no fixed order
fetch_jobs_incremental_spot_rest_kline
```

- Positional names are machine-parsable and human-scannable — you learn the slot order once and can read any name.
- Accumulative names force readers to parse the whole string and mentally reorder tokens to understand what is being described.
- A positional pattern with a fixed separator (`.`, `-`, `/`) is self-documenting: the separator itself signals "this is a dimension boundary."

### Public vs Internal

- **Public API surfaces**: names are hard to change once released. Apply the rules above with extra rigor — a naming mistake here is a breaking change.
- **Internal code** (local variables, private functions, unexported types): renaming is cheap via refactoring tools. The rules still apply, but the cost of a misjudgment is lower — err on the side of shipping and rename later if needed.

### New Names in Responses

When generating code that introduces **new** named entities (fields, types, functions, variables, config keys, topics, etc.), list them at the end of the response. Only list names that are newly introduced in the current response — names that have already appeared earlier in the conversation must NOT be repeated.

```text
---
**New names introduced**:
- `price` — price field, version-agnostic, source-agnostic
- `Kline` — K-line data structure, business-semantic name
```

## Key Insight: Extensibility Space ≠ Premature Implementation

| ❌ Wrong interpretation | ✅ Correct practice |
| --- | --- |
| Pre-create all possible fields | Use semantic naming; add fields when needed (adding fields is non-breaking) |
| Build abstraction layers for hypothetical multi-source data | Keep names source-agnostic (`price` not `binance_price`); implement single-source first |
| Pre-configure all parameters | Hardcode MVP paths; extract to config after the need is confirmed |
| Build universal interfaces for unknown futures | Keep interfaces stable and semantically clear; do not add indirection for hypothetical scenarios |

**Extensibility lives in semantic naming and forward-compatible contracts — not in pre-written code. Naming thoughtfully is zero-cost; implementing prematurely is high-cost.**

## Non-Breaking Changes — Safe to Defer

These changes do not affect existing contracts and can be added when needed. Do not pre-implement them.

- Adding a field (database column, optional API field, optional event attribute)
- Adding a value to an enumeration
- Adding a new endpoint
- Adding a new event type

## Decision Heuristic

When deciding whether to design for extensibility now or defer:

1. **Is this a contract-layer artifact?** (naming, schema, API, events, domain model) → Design for extensibility now.
2. **Is this an implementation-layer artifact?** (internal code, private logic) → Follow YAGNI; defer until the need is confirmed.
3. **Is the change non-breaking?** (adding fields, enum values, endpoints) → Safe to defer; do not pre-implement.
4. **Would a wrong extensibility design be worse than no design?** → If the future direction is uncertain, prefer a stable semantic name over a speculative abstraction.
