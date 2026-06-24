---
description: 'Auto-save new knowledge from web, Context7, or GitHub source lookups into repo memory for persistent cross-session recall'
applyTo: '**'
---

# Knowledge → Repo Memory

After fetching technical knowledge from an external source, save reusable findings to `/memories/repo/<topic>.md`.

## Trigger

Apply after using: `fetch_webpage`, `mcp_context7_get-library-docs`, `github_repo`, `github_text_search`.

## Capture Criteria

Save if the information is **novel and reusable**. Skip trivial facts, common knowledge, and duplicates.

| Priority | When to use |
|---|---|
| `⚠️` | Breaking change, security issue, version-specific deprecation/removal, known data-loss bug |
| (none) | Non-obvious API pattern, gotcha, best-practice idiom, config tip, dependency constraint |

## Per-Session Limit

At most **8 entries per session**. If a session yields more, keep only the most impactful ones and summarize the rest in one entry.

## Entry Format

One line per entry. The source field must contain enough detail to re-fetch later:

```markdown
- [YYYY-MM-DD] ⚠️ Key finding. Source: <tool>: <params>
```

Examples:

```markdown
- [2026-06-24] `useOptimistic` requires reducer signature `(state, action) => newState`. Source: context7: /vercel/next.js, topic="useOptimistic", mode=code, page=1.
- [2026-06-24] ⚠️ React 19 removes `forwardRef` — ref is now a regular prop. Source: fetch_webpage: https://react.dev/blog/2024/12/05/react-19.
- [2026-06-24] Tailwind v4 uses CSS-first config via `@theme` instead of `tailwind.config.js`. Source: context7: /tailwindlabs/tailwindcss, topic="v4 upgrade", mode=info.
- [2026-06-24] prisma.$queryRaw returns `any` — use `prisma.$queryRaw<MyType>` for typed results. Source: github_repo: prisma/prisma, query="queryRaw generic".
```

### Source Field Convention

Encode the retrieval route in the source field using `<tool>: <key-params>`:

| Tool | Source format |
|---|---|
| `fetch_webpage` | `fetch_webpage: <url>` |
| `mcp_context7_get-library-docs` | `context7: <libraryID>, topic="...", mode=<code\|info>, page=<n>` |
| `github_repo` | `github_repo: <owner>/<repo>, query="..."` |
| `github_text_search` | `github_text_search: <scope>, query="..."` |

## Merging

Before writing, check for duplicates with `memory view`. If the finding already exists, skip it. Otherwise append at the end of the file.
