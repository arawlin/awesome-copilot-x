---
name: wiki-review
description: Review pending wiki knowledge entries — approve, reject, or revise items in questions_pending/ via three-state file-system state machine. Use when user asks to "review wiki changes", "approve pending", or manage the human-gated knowledge workflow.
argument-hint: "[all|batch|slug <id>]"
---

# Wiki Review — 人工审核

Human-gated approval workflow for pending wiki knowledge entries. Uses file-system state machine: `questions_pending/` → `questions_approved/` or `rejected/`.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `plugins/instructions/llm-wiki-schema.instructions.md` for review frontmatter fields.

## Review Modes

| Mode | Command | Description |
|------|---------|-------------|
| **All** | `all` | Review every pending item one by one |
| **Batch** | `batch` | Quick-approve all low-risk items at once |
| **Single** | `slug <id>` | Review one specific pending item |

## Review States

| State | Action | File operation |
|-------|--------|---------------|
| **approved** | Accept as-is | `mv questions_pending/<id>.md questions_approved/<id>.md` |
| **rejected** | Decline with reason | `mv questions_pending/<id>.md rejected/<id>.md` + add `review` frontmatter |
| **revised** | Approve with edits | Modify in Chat, confirm, then move to `questions_approved/` |

## Workflow

### Step 1: Load pending queue

List all files in `$LLM_WIKI_PATH/questions_pending/`. Count and categorize:
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

### Step 3: Review each item

For each pending item, present:

1. **Title** and **type** (entity/concept/decision).
2. **Confidence** level.
3. **Key claims** (first 3–5 bullet points).
4. **Provenance** summary.
5. **Decision prompt**: `[a]pprove / [r]eject / [e]dit / [s]kip`

#### Batch mode

For low-risk items only, present a summary table:

| # | Slug | Title | Confidence |
|---|------|-------|------------|
| 1 | entity-foo | Foo | high |
| 2 | concept-bar | Bar | high |

Single confirmation: "Approve all <n> items? [y/n]"

#### Approve-with-Edit

When user requests edits:
1. User provides edit instruction (e.g., "change date to 2022").
2. Apply the edit to the pending file.
3. Show the diff.
4. Confirm: "Apply this change? [y/n]"
5. If yes, move to `questions_approved/`. Record edit in `review.changes_requested`.

### Step 4: Record review decisions

For each reviewed item, add `review` field to frontmatter:

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

Append review operation record to `$LLM_WIKI_PATH/wiki/log.md`.
Update `memories/wiki-activity.md` pending count.

## Rejected Item Retention

| Reason | Retention | Archive path |
|--------|-----------|-------------|
| Duplicate | 1 day | `rejected/YYYY-MM/<id>.md` |
| Low quality | 7 days | `rejected/YYYY-MM/<id>.md` |
| Outdated | 30 days | `rejected/YYYY-MM/<id>.md` |
| Contradiction | Permanent | `rejected/permanent/<id>.md` |

Run `tools/cleanup-rejected.sh` periodically to purge expired rejected items.

## Constraints

- Maximum **20 items** per review session (to avoid overwhelming the user).
- Rejected items must always include a `reason` in the review record.
- Never auto-approve low-confidence items — they always require individual review.
