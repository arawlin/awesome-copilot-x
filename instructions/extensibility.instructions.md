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

| Name kind | Answers | Stability | Should include |
| --- | --- | --- | --- |
| Abstract name (type, function, variable) | "What is this?" | High — rename is a breaking change | Business responsibility |
| Runtime name (topic, queue, schedule ID) | "Which one is this?" | Medium — new instances are additive | Distinguishing dimensions |

For runtime names with multiple dimensions, use a consistent positional pattern — not ad-hoc suffix accumulation.

```text
// Good: positional — every token has a stable slot
cmd.fetch.kline.spot.rest.incremental

// Bad: accumulative — suffixes pile up with no fixed order
fetch_jobs_incremental_spot_rest_kline
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
