---
name: wiki-capture
description: Capture knowledge from the current Copilot Chat session — extract entities, concepts, relationships, and decisions, then write structured output to questions_pending/ for human review. Works from ANY workspace by detecting $LLM_WIKI_PATH. Use when user asks to "capture this conversation", "save to wiki", "extract knowledge", or after a significant technical discussion.
argument-hint: "[--scope <current-turn|full-session>]"
---

# Wiki Capture — 知识捕获

Extract structured knowledge from the current Chat session and write to `questions_pending/` for human review.

## Prerequisites

- Environment variable `$LLM_WIKI_PATH` must point to the llm-wiki repo.
- If `$LLM_WIKI_PATH` is not set, fall back to writing to `.wiki-capture/` in the current workspace.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for page format.

## Workflow

### Step 1: Determine scope

- `--scope current-turn` (default): Extract from the current conversation turn only.
- `--scope full-session`: Extract from the entire session history.

### Step 2: Extract knowledge (single-pass + inline self-validation)

Review the conversation and extract:

| Category | Examples | Output format |
|----------|----------|---------------|
| **Entities** | Tools, frameworks, libraries, companies, people, protocols | `questions_pending/entity-<slug>.md` |
| **Concepts** | Patterns, methodologies, algorithms, architectural decisions | `questions_pending/concept-<slug>.md` |
| **Relations** | "X uses Y", "X is a type of Z" | Embedded in entity/concept pages as `related` |
| **Decisions** | "We chose X over Y because Z" | `questions_pending/decision-<slug>.md` |

### Step 3: Self-validate

For each extracted item:
1. **Provenance check**: Every claim must reference a specific message or turn in the conversation.
2. **Confidence assessment**:
   - `high`: Explicitly stated by user or agreed upon.
   - `medium`: Reasonably inferred from discussion.
   - `low`: Speculative — mark for mandatory human review.
3. **Uncertainty marking**: Tag speculative content with `[unverified]`.

**Extraction rules:**
- Prefer completeness over precision.
- Preserve original wording where possible.
- Mark uncertainty explicitly.
- Skip trivial chat (greetings, small talk) — only capture substantive knowledge.

### Step 4: Security filter

Before writing, scan extracted content:
- **Credentials**: API keys, passwords, tokens → REJECT.
- **PII**: Email addresses, phone numbers, ID numbers → REDACT or REJECT.
- **Internal IPs/hostnames**: → REJECT.
- Mark sensitivity level in frontmatter: `public` / `internal` / `sensitive`.

### Step 5: Write to target

**Primary path** (if `$LLM_WIKI_PATH` is set):
```
$LLM_WIKI_PATH/questions_pending/<type>-<slug>.md
```

**Fallback path** (if `$LLM_WIKI_PATH` is not set):
```
<workspace>/.wiki-capture/<type>-<slug>.md
```

### Step 6: Product format

Each `questions_pending/*.md` file must include:

```yaml
---
type: entity | concept | decision
id: <slug>
title: "<title>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
captured_from: "<session-context>"
captured_at: <ISO timestamp>
confidence: high | medium | low
sensitivity: public | internal | sensitive
related: []
---
```

Body section must include a **"与我讨论的内容" (Discussed Content)** section with provenance.

### Step 7: Update activity log

Append to `memories/wiki-activity.md` (User Memory): captured entities/concepts count, pending review count.

## Constraints

- Maximum **10 extracted items** per capture run.
- Low-confidence items always require human review (never auto-approve).
- Sensitive items are blocked — do not write to any file.
