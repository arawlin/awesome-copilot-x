---
name: wiki-capture
description: 'Capture knowledge from the current Copilot Chat session into a single session document — extract reusable knowledge as an unclassified summary, present a detailed candidate summary for human selection, then write only the selected items to questions_pending/session-<date>-<slug>.md for review. Type-splitting and page assignment happen at /wiki-ingest. Works from ANY workspace by detecting $LLM_WIKI_PATH. Use when user asks to "capture this conversation", "save to wiki", "extract knowledge", or after a significant technical discussion.'
argument-hint: "[--scope <current-turn|full-session>]"
---

# Wiki Capture — 知识捕获

Extract structured knowledge from the current Chat session into ONE session document — no type-splitting here. Present a detailed candidate summary for human selection, then write only the selected items into the single document for review. Entity/concept classification and page assignment happen at `/wiki-ingest`, which owns the global context (dedup, granularity, existing pages) that capture lacks.

## Prerequisites

- Environment variable `$LLM_WIKI_PATH` must point to the llm-wiki repo.
- If `$LLM_WIKI_PATH` is not set, fall back to writing to `.wiki-capture/` in the current workspace.
- Read the instruction file `llm-wiki-schema.instructions.md` for page format. If unavailable, follow the frontmatter template in Step 7 of this skill.
- Session limits come from `wiki/.wiki-config.yml` (`capture_max_items_per_run`); use the default when the config is absent.

## Workflow

### Step 1: Determine scope

- `--scope current-turn` (default): Extract from the current conversation turn only.
- `--scope full-session`: Extract from the entire session history.

### Step 2: Extract candidate knowledge (single-pass, unclassified)

Review the conversation and extract **reusable knowledge as an undifferentiated summary** — do NOT classify items as entity or concept. Type classification and page assignment belong to `/wiki-ingest`, which owns the global context (dedup, granularity, existing pages) that capture lacks.

What to look for (extraction signals, not categories):
- **Named, identifiable things** (tools, frameworks, companies, people, protocols) — future cross-document reference anchors.
- **Reusable patterns, methodologies, principles** — including trade-off rationale ("We chose X over Y because Z").
- **Explicit relations** ("X uses Y", "X is a type of Z") — recorded inline with the related item, never a separate candidate.

**Granularity gate (worth judgment, not type judgment)**: capture an item only if it has standalone retrieval value + is self-contained + is knowledge-not-data. Sub-flows / session-specific details that would never be queried alone → fold into the parent item or skip; this keeps the pending queue reviewable instead of fragmented.

### Step 3: Present detailed candidate summary for human selection

Before writing any file, stop and summarize each candidate in enough detail for the human to judge — a bare table is not enough. For every candidate, include:

| Field | Content |
|-------|---------|
| 编号 + Slug + 标题 | Candidate identity |
| 一句话摘要 | What knowledge this item captures |
| 关键要点 | 3–5 bullets of the main claims the page will contain |
| 置信度 | high / medium / low |
| 来源 | Which turn or message each claim comes from |

Example:

```
🧾 候选知识清单（<N> 项）

1. session-scoped-planning / 会话级任务规划（confidence: high）
   摘要：多步任务「先全局规划、再逐项执行、完成后复盘」的执行方法论
   - 规划先行：把任务拆成可检查的子项，先列出计划再动手
   - 单线程推进：同一时间只做一个子项，完成即标记
   - 复盘驱动：结束后回顾步骤，沉淀为可复用流程
   来源：第 2 轮「重构 X 模块」→ 第 4 轮确认该方法有效

2. sqlite-vec / SQLite-vec（confidence: medium）
   摘要：SQLite 的向量检索扩展，用于本地语义搜索
   - SQLite 官方扩展，嵌入式向量索引 [unverified]
   来源：第 6 轮提及，会话内未展开验证
```

Ask: `提取哪些条目？（输入编号如 "1,3,5"、"all" 或 "none"）`

- **Wait for explicit human selection** — never write any file before the user picks items (fail closed).
- `none` → end the run immediately: no files written, no log update.
- Only selected candidates continue to Step 4; unselected candidates are discarded.

### Step 4: Self-validate (selected items only)

For each selected item:
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

### Step 5: Security filter (selected items only)

Before writing, scan the selected content:
- **Credentials**: API keys, passwords, tokens → REJECT.
- **PII**: Email addresses, phone numbers, ID numbers → REDACT or REJECT.
- **Internal IPs/hostnames**: → REJECT.
- Mark sensitivity level in frontmatter: `public` / `internal` / `sensitive`.

### Step 6: Write ONE session document (selected items only)

Write the selected items into a single session document — never split them into per-type files.

**Primary path** (if `$LLM_WIKI_PATH` is set):
```
$LLM_WIKI_PATH/questions_pending/session-<date>-<slug>.md
```

**Fallback path** (if `$LLM_WIKI_PATH` is not set):
```
<workspace>/.wiki-capture/session-<date>-<slug>.md
```

### Step 7: Product format

The session document follows the schema section「Session Capture（会话捕获文档）」. Frontmatter:

```yaml
---
type: session
id: session-<YYYYMMDD>-<slug>
title: "<会话主题>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
captured_from: "<session-context>"
captured_at: <ISO timestamp>
sensitivity: public | internal | sensitive
related: []
---
```

Body:

```markdown
## 候选知识清单

### 1. <标题>（confidence: high）

摘要：<一句话>

关键要点：
- <要点 1>
- <要点 2>

来源：<第几轮 / 哪条消息>
```

- One `###` section per candidate item.
- Every item must include its 「与我讨论的内容」 information (key points + provenance).

### Step 8: Update activity log

1. Append operation record to `$LLM_WIKI_PATH/wiki/log.md` (JSON Lines).
2. Append 1 full entry to `$LLM_WIKI_PATH/wiki/activity.md` (complete history).

> 不再写 user memory（wiki-activity.md 已移除）——状态按需从 log.md / questions_pending/ 派生。

## Constraints

- Maximum **10 extracted items** per capture run (default; override via `.wiki-config.yml` `capture_max_items_per_run`).
- **One session document per capture run** — never split items into per-type files (`entity-*` / `concept-*` are retired).
- Never write files before the human confirms the selection — unselected candidates must not reach `questions_pending/`.
- Low-confidence items always require human review (never auto-approve).
- Sensitive items are blocked — do not write to any file.
