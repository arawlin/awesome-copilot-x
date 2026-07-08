---
description: 'Write self-contained, non-redundant spike research sections. Each task owns its output; all other tasks reference it with one-line pointers. Never copy-paste facts between sections.'
applyTo: '**/spikes/**/*.md'
---

# Spike Research Section Writing

Write each research task section as a self-contained unit that owns its facts. When another section needs those facts, use a one-line pointer. Never duplicate.

## Single Source of Truth

Define every fact exactly once in the entire spike document. All other sections reference it.

```
Good: Section A defines the field table.
      Section B writes: "Use field X from Section A's table to select the parser."

Bad:  Section A defines the field table.
      Section B copies the same table. Section C copies it again.
      One update → three places drift.
```

## Own vs. Delegate

### Place in the owning section

| Content | Rule |
|---------|------|
| Design decisions | The decision and its rationale. Comparison tables stay here. Do not place in Handler Rules or Schema Draft. |
| Definitive outputs | Field tables, schemas, algorithm pseudocode, state machines. Do not place idempotency strategies or SQL examples in Handler Rules. |
| Trade-off analysis | Why A over B. State the decisive factor, not every factor. |
| Visualizations | Only diagrams unique to this section. Cross-cutting diagrams go in the spike-level Summary. |

### Replace with a pointer

| Content | Owned by | Use this instead |
|---------|----------|-----------------|
| Another section's full config | That section | `# ...（full config: see §Design-X）` |
| How another section consumes this output | That section | `Consumer usage: see §Implementation-Y.` |
| Reversed-decision debates | Not archived | Final decision + one-line reason only. |
| Cross-section comparison tables | Each section owns its half | Each section references the other. |

### Boundary test

Ask: *"If Section X changes, must this section also change?"* If yes, move the content to Section X and replace it here with a pointer.

## Cross-Reference Format

Reference at section level, not line level. Section identifiers survive edits; line numbers do not.

```markdown
# Reference another section's output
The consumer reads the exchange identifier from the upstream section's field table
to select the parser. See §Field-Definitions.

# Omit another section's config block
# ...（full pipeline config: see §Pipeline-Config）

# In a cross-reference summary table
| Downstream Section | Depends on: field X (parser selection), field Y (trace).
  Counting is the consumer's own responsibility. |
```

## Investigation Results Structure

Research sections within `### Investigation Results` follow a three-layer progression. Each layer is a separate `####` section. Never mix layers in one section.

| Layer | Section | Content | Style |
|-------|---------|---------|-------|
| **Discovery** | `#### T{N}.{n} Topic Name` | Findings, design alternatives, comparison tables, why A over B | Tables + narrative |
| **Specification** | `#### Handler Rules` or `#### Schema Draft` | Inputs, rules, state transitions. Facts only, no rationale. | Concise lists |
| **Implementation** | `#### Control Loop Pseudocode` | Go pseudocode, key SQL conditional UPDATE statements | Code blocks + minimal comments |

When a spike produces a definitive schema (DDL, JSON schema, Protobuf `.proto`), place it in a single `#### Schema Draft` section. Include the declaration: "All subsequent sections refer to this definition." No other section redefines it.

### Task numbering

Research tasks use `T{N}.{n}` format, where `{N}` is the spike sequence number and `{n}` is the task number within that spike. New discoveries append with incrementing `.n`.

```
T6.1  — spike 6, task 1
T6.2  — spike 6, task 2
T1.9  — spike 1, task 9 (new discovery added during research)
```

## Round Marking

Tag completed sections and candidate proposals with their round and date.

| Scenario | Format |
|----------|--------|
| Completed round | `T6.1 ✅ (2026-06-26 Round 1)` |
| Candidate proposal, pending confirmation | `(candidate, Round 5 supplement)` |

## Decision Records

Archive the final state. Delete the debate.

```
✅ Keep:
Decision: field X removed.
Reason: requires parsing, violating the zero-parse principle.
Counting belongs to the downstream consumer.

❌ Delete:
Decision: Should we include field X?
| Pros | Cons |
| integrity check | violates zero-parse |
| cheap to compute | consumer can count |
✅ Accepted (optional) …[later reversed]…
```

When a decision goes through propose → accept → reverse → remove, keep only the final outcome and its one-line reason. The debate history belongs in chat history, not in the spike document.

## Research Workflow

- Write findings immediately after each lookup or analysis. Do not batch at the end.
- Tag every conclusion with its source.
- When a section's conclusion changes, immediately check every section that references it for stale pointers.

## Completion Checklist

Run after finishing each research section:

- [ ] Any field, schema, or config duplicated elsewhere? Replace with pointers.
- [ ] Any full config from another section present here? Reduce to `# ...（see §Section-Name）`.
- [ ] Any reversed-decision debate still present? Trim to final outcome + one-line reason.
- [ ] Names and keys referenced here match the actual definitions in their owning sections?
- [ ] Every downstream dependency declared in the section's output table has a corresponding item in the target section?
- [ ] All counts (fields, headers, time values) match the actual definitions?
