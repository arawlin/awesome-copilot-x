---
description: "Project-wide naming principle: every named entity must consider future version extensibility. Applies to fields, variables, functions, types, files, topics, config keys, DB objects, and all other named artifacts."
applyTo: "**"
---

# Naming for Extensibility

## Core Principle

**Every name must be chosen with future version extensibility in mind.** When naming anything, assume V2, V3, and beyond will exist — the current name must not become an obstacle to future expansion.

This applies to ALL named entities: fields, variables, functions, methods, types, interfaces, files, directories, topics, queues, config keys, database columns, tables, API endpoints, and any other artifact that carries a name.

## Rules

- **Name for business semantics, not for version, source, or environment.** Names encode what something _is_, not when or where it was introduced.
- **Never embed version numbers in names.** Use `price`, not `price_v1`. Version changes go through new fields, new types, or new files — not name suffixes.
- **Never embed source identity in names.** Use `price`, not `binance_price`. Source-specific data belongs in dedicated fields, nested structures, or tags — not in the name.
- **Keep names stable.** If a name might later carry different semantics, choose a more abstract name now, or split into separate entities at design time.

## Abstract Names vs Runtime Names

**Code identifiers and runtime identifiers serve different purposes and follow different stability expectations.**

- **Abstract names** (type names, function names, variable names in source code) describe _what_ a thing is responsible for. They should be stable across versions and free of implementation-strategy details.
- **Runtime names** (topics, queues, schedule IDs, stream names, deployment identifiers) describe _which instance_ of a thing is running. They carry dimensional context — the attributes that distinguish one running instance from another.

| Name kind | Answers | Stability | Should include |
|---|---|---|---|
| Abstract name | "What is this?" | High — rename is a breaking change | Business responsibility |
| Runtime name | "Which one is this?" | Medium — new instances are additive | Distinguishing dimensions |

**Rule of thumb:** If adding a new variant (new data type, new source, new protocol) would force you to rename an existing entity, the name is too specific. If the name is stable but you cannot tell two running instances apart, it is missing runtime dimensions.

## Name for Responsibility, Not Implementation Strategy

**Avoid baking the current algorithm or resource-management tactic into a long-lived name.** Today's implementation choice may not survive the next version.

- Prefer `Coordinator` over `SlotScheduler` — "slot" is a resource-allocation tactic, not the core responsibility.
- Prefer `LaneController` over `PollingScheduler` — "polling" is one execution model among several; the responsibility is keeping a lane progressing.
- Prefer `SessionSupervisor` over `StreamManager` — "stream" describes transport, not responsibility.

When the implementation strategy changes, the abstract name should still hold. If it would not, it was too specific.

## Dimension Inclusion Principle

**Only include a dimension in a runtime name when it changes one of the following:**

- Execution model or control logic
- Scheduling rhythm or trigger cadence
- Resource pool, rate-limit budget, or capacity domain
- Retry policy, timeout profile, or recovery semantics
- Task semantics — what the task _means_ to do, not just what data it carries

If a dimension does not change any of these, it does not belong in the runtime name — even if it appears in the data flowing through the system.

**Corollary:** Control-plane names and data-plane names may carry different dimension sets for the same system. A data topic name describes what data is inside; a control topic name describes what action to take and under what execution constraints. The dimensions that matter for storage and routing are not always the dimensions that matter for scheduling and execution.

## Positional Semantics over Accumulative Suffixes

**When a runtime name needs multiple dimensions, use a consistent positional pattern — not ad-hoc suffix accumulation.**

Positional naming gives every token a fixed slot with a stable meaning. Adding a new dimension means adding a new position (or leaving an existing position empty with a well-defined default), not inventing a new suffix string.

```
// Good: positional — every token has a stable slot
cmd.fetch.kline.spot.rest.incremental

// Bad: accumulative — suffixes pile up with no fixed order
fetch_jobs_incremental_spot_rest_kline
```

- Positional names are machine-parsable and human-scannable — you learn the slot order once and can read any name.
- Accumulative names force readers to parse the whole string and mentally reorder tokens to understand what is being described.
- A positional pattern with a fixed separator (`.`, `-`, `/`) is self-documenting: the separator itself signals "this is a dimension boundary."

## Public vs Internal

- **Public API surfaces**: names are hard to change once released. Apply the rules above with extra rigor — a naming mistake here is a breaking change.
- **Internal code** (local variables, private functions, unexported types): renaming is cheap via refactoring tools. The rules still apply, but the cost of a misjudgment is lower — err on the side of shipping and rename later if needed.

## New Names in Responses

When generating code that introduces **new** named entities (fields, types, functions, variables, config keys, topics, etc.), list them at the end of the response. Only list names that are newly introduced in the current response — names that have already appeared earlier in the conversation must NOT be repeated.

```
---
**New names introduced**:
- `price` — price field, version-agnostic, source-agnostic
- `Kline` — K-line data structure, business-semantic name
```


## Example

```
// Good: business-semantic, version-agnostic
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
