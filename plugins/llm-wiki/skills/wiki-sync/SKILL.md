---
name: wiki-sync
description: Sync the LLM Wiki to remote Git — commit wiki changes and push to origin/main directly (single-user simplification). Restores any deleted wiki pages as stale instead of physical deletion. Use when user asks to "sync wiki", "push wiki changes".
argument-hint: "[--dry-run]"
---

# Wiki Sync — 同步到远程

Single-user direct sync: commit wiki changes and push to `origin/main`. No feature branches, no conflict machinery.

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH`.
- If no remote is configured, commit locally and skip push.

## Workflow

### Step 1: Detect changes

```bash
cd "$LLM_WIKI_PATH" && git status --short
```

Classify changes:

| Git status | Action |
|-----------|--------|
| `A` | New page — commit as-is |
| `M` | Modified — commit changes |
| `D` | Deleted wiki page — **never physically delete**: restore from HEAD (`git checkout HEAD -- <file>`), set frontmatter `status: stale`, `stale_reasons: ["source_deleted"]`, then commit |
| `R` | Renamed — move file + update all `[[WikiLink]]` references |

### Step 2: Commit and push

```bash
git add wiki/ raw/ questions_pending/ questions_approved/ lint_pending/ rejected/
git commit -m "wiki: <N> pages changed (added=<a>, modified=<m>, stale=<d>)"
git push origin main
```

### Step 3: Update checkpoint

Update `wiki/index.md` frontmatter `last_commit` to the new HEAD SHA, then commit and push.

### Step 4: Log

Append sync record to `wiki/log.md` (JSON Lines).

## Options

- `--dry-run`: Report detected changes without committing.
