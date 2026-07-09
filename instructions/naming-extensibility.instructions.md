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
