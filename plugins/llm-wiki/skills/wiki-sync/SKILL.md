---
name: wiki-sync
description: Incremental Git sync for the LLM Wiki — detect changes via commit SHA checkpoint, handle six change types (Added/Modified/Deleted/Renamed/Copied/Type-changed), commit via sync/auto-{timestamp} branches. Use when user asks to "sync wiki", "push wiki changes", or after ingest/review sessions.
argument-hint: "[--dry-run] [--force]"
---

# Wiki Sync — 增量同步

Synchronize wiki changes to the remote Git repository using commit SHA checkpoint mechanism (adapted from yysun/git-wiki).

## Prerequisites

- The `llm-wiki` repo must be accessible via `$LLM_WIKI_PATH` environment variable.
- Read `wiki/.wiki-config.yml` for sync configuration.

## Workflow

### Step 1: Detect changes

Read the `last_commit` value from `wiki/index.md` frontmatter:

```bash
git diff --name-status -M50% <last_commit> HEAD
```

If `last_commit` is `null` (first sync), use initial commit.

### Step 2: Classify changes

| Git status | Change type | Action |
|-----------|-------------|--------|
| `A` | Added | New page — commit as-is |
| `M` | Modified | Updated page — commit changes |
| `D` | Deleted | Mark as `stale` in frontmatter (NEVER physically delete wiki pages) |
| `Rxxx` | Renamed | Move file + update all `[[WikiLink]]` references |
| `Cxxx` | Copied | New page derived from existing — commit as new |
| `T` | Type changed | Update metadata only |

### Step 3: Handle deleted files

**CRITICAL: Never physically delete wiki pages.** When `git diff` shows `D`:
1. Restore the file from previous commit: `git checkout <last_commit> -- <file>`
2. Update frontmatter: set `status: stale`, `stale_reasons: ["source_deleted"]`
3. Commit the restored file with updated metadata.

### Step 4: Commit and push

1. Create sync branch: `sync/auto-{YYYY-MM-DD-HHmmss}`
2. Commit all changes with message:
   ```
   sync: <N> pages changed (added=<a>, modified=<m>, renamed=<r>, stale=<d>)
   ```
3. Push branch to remote.
4. Update `wiki/index.md` frontmatter `last_commit` to new HEAD SHA.
5. Append sync record to `wiki/log.md`.

### Step 5: Conflict resolution (if needed)

If remote has diverged:
1. Fetch remote: `git fetch origin`
2. Detect conflicts: `git diff <local>..<remote> -- wiki/`
3. **File-level conflicts**: Prefer local changes (wiki is source of truth).
4. **Semantic conflicts**: Flag for human review in `lint_pending/sync-conflict-*.md`.
5. Force push only with `--force` flag.

## Sync Frequency

| Frequency | Trigger | Use case |
|-----------|---------|----------|
| Immediate | After each page write | No conflict risk (single user) |
| Session-end | After `/wiki-capture` session | Low conflict risk |
| After-review | After `/wiki-review` approval | Human-confirmed changes |

## Options

- `--dry-run`: Detect changes and report without committing.
- `--force`: Force push to remote (use with caution).
