---
name: wiki-sync
description: 'Sync the LLM Wiki to remote Git — commit wiki changes and push to origin/main after explicit user confirmation (single-user simplification). Restores any deleted wiki pages as stale instead of physical deletion. Use when user asks to "sync wiki", "push wiki changes".'
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

### Step 2: Confirm before pushing

Present the classified change summary from Step 1 (plus `git diff --stat`) and ask for explicit confirmation:

```
📦 Sync preview: <a> added, <m> modified, <d> restored as stale
Push to origin/main? [y/n]
```

Pushing to the remote is a high-impact action — never push without this confirmation; default to no.

### Step 3: Commit and push

```bash
git add wiki/ raw/ questions_pending/ questions_approved/ lint_pending/ rejected/
git commit -m "wiki: <N> pages changed (added=<a>, modified=<m>, stale=<d>)"
git push origin main
```

### Step 4: Update last_commit

Update `wiki/index.md` frontmatter `last_commit` to the new HEAD SHA, then commit and push.

### Step 5: Log

Append sync record to `wiki/log.md` (JSON Lines).

## Options

- `--dry-run`: Report detected changes without committing.
