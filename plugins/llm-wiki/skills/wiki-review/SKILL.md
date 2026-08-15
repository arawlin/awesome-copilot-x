---
name: wiki-review
description: 'Review pending session capture documents — approve, reject, or revise topic documents in questions_pending/ (each session-*.md is one discussion topic) via three-state review, with quality gates (self-containment, size, granularity), synthesis draft approval, and a legacy merge mode for pages violating current granularity rules. Use when user asks to "review wiki changes", "approve pending", or manage the human-gated knowledge workflow.'
argument-hint: "[all|batch|slug <id>]"
---

# Wiki Review — 人工审核

Human-gated approval workflow for pending session capture documents (one document per topic). Each document IS a topic; review approves/rejects/revises it, then the finalized document moves `questions_pending/` → `questions_approved/` or `rejected/`.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read the instruction file `llm-wiki-schema.instructions.md` for review frontmatter fields.
- Read `wiki/.wiki-config.yml` for session limits and retention thresholds (defaults apply when absent).

## Review Modes

| Mode | Command | Description |
|------|---------|-------------|
| **All** | `all` | Review every pending topic document one by one |
| **Batch** | `batch` | Quick-approve all low-risk topic documents at once |
| **Single** | `slug <id>` | Review one specific pending document |
| **Legacy merge** | `merge` | Audit existing pages against current granularity rules and propose merges (e.g., over-split sub-concepts) |

## Review States

| State | Action | File operation |
|-------|--------|---------------|
| **approved** | Topic accepted as-is | `mv questions_pending/<id>.md questions_approved/<id>.md` |
| **rejected** | Topic declined with reason | `mv questions_pending/<id>.md rejected/<id>.md` + add `review` frontmatter |
| **revised** | Topic approved with edits | Modify in Chat, confirm, then move to `questions_approved/` |

Each document is one topic, so review decisions are per-document; the `review` frontmatter records the outcome on the single document.

## Quality Gate (every reviewed item)

Before approving, verify each item against the LLM-consumption quality rules (schema):

| Check | Pass criteria |
|-------|---------------|
| **Self-contained** | The topic document reads coherently on its own — no sibling documents required |
| **Size cap** | Session document ≤ 200 lines / ~6KB（schema, Session Capture 节） |
| **Granularity** | Topic is a coherent discussion section, NOT a pre-cut knowledge unit — unit cutting and classification are ingest's job |
| **Provenance** | Every topic carries its session turn/message source |

Items failing any check go to `revised` (edit before approve) or `rejected` (with reason) — never auto-approved.

## Synthesis Draft Approval

`wiki/synthesis/` drafts (created by `/wiki-ingest` with `status: draft`) require approval here:

1. Read the draft page.
2. Verify it answers a **cross-document** question (spans multiple source pages) — not a single-document restatement (that belongs in the knowledge map).
3. Verify claims carry provenance.
4. On approval, set frontmatter: `status: active`, `approved_by: "<user>"`, `approved_at: <YYYY-MM-DD>`. Move any `questions_pending/synthesis-*.md` to `questions_approved/`.
5. Log the approval in `wiki/log.md` and `wiki/activity.md`.

## Workflow

### Step 1: Load pending queue

List all files in `$LLM_WIKI_PATH/questions_pending/` (one `session-*.md` document per topic). For each document, read its topic content and confidence level, then categorize:
- **High confidence** + **low risk**: Eligible for batch approval.
- **Medium confidence** + **medium risk**: Standard review.
- **Low confidence** + **high risk**: Deep review required.

### Step 2: Triage

Present a summary before detailed review:

```
📋 Pending Review: <N> items
   🟢 Low risk (batch-eligible): <n>
   🟡 Medium risk: <n>
   🔴 High risk (deep review): <n>

Proceed with [all|batch|skip]?
```

### Step 3: Review each topic document

For each pending topic document, present:

1. **Title**.
2. **Confidence** level.
3. **Key claims** (first 3–5 bullet points).
4. **Provenance** summary.
5. **Decision prompt**: `[a]pprove / [r]eject / [e]dit / [s]kip`

#### Batch mode

For low-risk topic documents only, present a summary table:

| # | Title | Confidence |
|---|-------|------------|
| 1 | Foo | high |
| 2 | Bar | high |

Single confirmation: "Approve all <n> topic documents? [y/n]"

#### Approve-with-Edit

When user requests edits:
1. User provides edit instruction (e.g., "change date to 2022").
2. Apply the edit to the pending document.
3. Show the diff.
4. Confirm: "Apply this change? [y/n]"
5. If yes, move to `questions_approved/`. Record edit in `review.changes_requested`.

### Step 4: Record review decisions

Record the decision in the document's frontmatter (each document is one topic):

```yaml
review:
  status: approved | rejected | revised
  reviewer: "<user>"
  reviewed_at: <YYYY-MM-DD>
  reason: "<reason for rejection>"
  changes_requested: "<edit summary>"
```

### Step 5: Freshness check during review

Before approving, check if any referenced source pages have been updated since the pending item was generated:
- Compare `source_last_commit` or `source_hash` of referenced pages.
- If a source has changed, warn: "⚠️ Source [[sources/xxx]] has been updated since this item was captured. Consider re-extracting."

### Step 6: Update logs

1. Append review operation record to `$LLM_WIKI_PATH/wiki/log.md` (JSON Lines).
2. Append 1 full entry to `$LLM_WIKI_PATH/wiki/activity.md` (complete history).

> 不再写 user memory（wiki-activity.md 已移除）——状态按需从 log.md / questions_pending/ 派生。

## Legacy Merge Mode

Audit existing pages that violate current granularity rules (e.g., over-split sub-concepts like `binance-api-authentication` + `binance-request-signing-payload`):

1. **Scan** `wiki/entities/` and `wiki/concepts/` for candidate groups: pages with heavy `related` overlap, sub-flow pages never queried alone, or pages exceeding the size cap.
2. **Propose merges** as a table: target page (parent) + candidate pages + merge rationale + how provenance is preserved (keep both `sources` lists).
3. Present for user confirmation: `[y/n/edit]`.
4. On approval, merge content into the parent page (sub-flows become `## sections`), **delete the absorbed pages outright (no redirects)**, then fix any broken `[[WikiLink]]` references to the removed pages, update `related`, `wiki/index.md`, `wiki/log.md`, and re-run lint.

> Never merge without user confirmation — this is a destructive restructuring.

## Rejected Item Retention

Rejected topic documents move to `rejected/` with the `review` frontmatter reason recorded; approved documents move to `questions_approved/` as-is.

| Reason | Retention | Archive path |
|--------|-----------|-------------|
| Duplicate | 1 day | `rejected/YYYY-MM/<id>.md` |
| Low quality | 7 days | `rejected/YYYY-MM/<id>.md` |
| Outdated | 30 days | `rejected/YYYY-MM/<id>.md` |
| Contradiction | Permanent | `rejected/permanent/<id>.md` |

Retention days are defaults (uncalibrated) — override via `.wiki-config.yml` `rejected_retention_days`.

Run `tools/cleanup-rejected.sh` periodically to purge expired rejected items.

## Constraints

- Maximum **20 topic documents** per review session (default; override via `.wiki-config.yml` `review_max_items_per_session`) to avoid overwhelming the user.
- Rejected topic documents must always include a `reason` in the review record.
- Never auto-approve low-confidence topic documents — they always require individual review.
