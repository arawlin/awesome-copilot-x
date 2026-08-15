---
name: wiki-capture
description: 'Capture knowledge from the current Copilot Chat session as one document per discussion topic — write a detailed narrative summary for each topic, present the topics for human selection, then write each selected topic as its own questions_pending/session-<date>-<topic>.md for review. Knowledge-unit cutting, type-splitting, and page assignment happen at /wiki-ingest. Works from ANY workspace by detecting $LLM_WIKI_PATH. Use when user asks to "capture this conversation", "save to wiki", "extract knowledge", or after a significant technical discussion.'
argument-hint: "[--scope <current-turn|full-session>]"
---

# Wiki Capture — 知识捕获

Extract the current Chat session's knowledge as **one document per discussion topic** (the session may cover several topics, e.g. A and B, or just one, A) — no knowledge-unit cutting, no type classification, no page slugs. Present the topics for human selection, then write each selected topic as its own document for review. Knowledge-unit cutting, type classification, and page assignment happen at `/wiki-ingest`, which owns the global context (dedup, granularity, existing pages) that capture lacks.

## When to Use This Skill

- User asks to "capture this conversation", "save to wiki", or "extract knowledge" from a Copilot Chat session
- After a significant technical discussion that produced reusable knowledge (patterns, mechanisms, named tools, trade-offs)
- Before `/wiki-ingest`, when session knowledge needs to enter the human-gated review queue

## Prerequisites

- Environment variable `$LLM_WIKI_PATH` must point to the llm-wiki repo.
- If `$LLM_WIKI_PATH` is not set, fall back to writing to `.wiki-capture/` in the current workspace.
- Read the instruction file `llm-wiki-schema.instructions.md` for page format. If unavailable, follow the frontmatter template in Step 7 of this skill.
- Session limits come from `wiki/.wiki-config.yml` (`capture_max_items_per_run`); use the default when the config is absent.

## Workflow

### Step 1: Determine scope

- `--scope current-turn` (default): Extract from the current conversation turn only.
- `--scope full-session`: Extract from the entire session history.

### Step 2: Extract topics (single-pass, one document per topic)

Review the conversation and identify the **discussion topics** that actually occurred (the session may cover several topics, e.g. A and B, or just one, A). Each topic becomes its **own document**. Do NOT cut topics into knowledge units, do NOT classify anything, do NOT assign page slugs — those are `/wiki-ingest` decisions.

How to structure:
- One topic per document, following the session's natural grouping (e.g. 迁移总览、上下文文件机制、记忆系统).
- Each topic is a **detailed narrative** of what was discussed: key facts, mechanisms, trade-offs ("We chose X over Y because Z"), named things, explicit relations — written in enough detail that the human can judge its value and `/wiki-ingest` can later cut and classify it.
- Keep provenance inline: `来源：第 N 轮 …` and `[unverified]` markers for speculative claims.
- Do NOT pre-decide whether a topic will become one page, several pages, or fold into an existing page.

**Worth gate (topic level only)**: skip topics that are pure small talk or session-specific trivia with no reusable knowledge; keep everything else — the finer "standalone retrieval value" judgment belongs to `/wiki-ingest`.

### Step 3: Present topic list for human selection

Before writing any file, stop and present the session summary **topic by topic**, with enough detail per topic for the human to judge:

| Field | Content |
|-------|---------|
| 编号 + 主题标题 | Topic identity (document organization only, not a knowledge unit) |
| 一句话摘要 | What this topic covers |
| 关键要点 | 3–5 bullets of the main content discussed |
| 置信度 | high / medium / low |
| 来源 | Which turns the topic spans |

Example:

```
📋 会话主题清单（<N> 个）

1. 会话级任务规划（confidence: high）
   摘要：多步任务「先全局规划、再逐项执行、完成后复盘」的执行方法论
   - 规划先行：把任务拆成可检查的子项，先列出计划再动手
   - 单线程推进：同一时间只做一个子项，完成即标记
   - 复盘驱动：结束后回顾步骤，沉淀为可复用流程
   来源：第 2 轮「重构 X 模块」→ 第 4 轮确认该方法有效

2. SQLite-vec（confidence: medium）
   摘要：SQLite 的向量检索扩展，用于本地语义搜索
   - SQLite 官方扩展，嵌入式向量索引 [unverified]
   来源：第 6 轮提及，会话内未展开验证
```

Ask: `保留哪些主题？（输入编号如 "1,3,5"、"all" 或 "none"）`

- **Wait for explicit human selection** — never write any file before the user picks topics (fail closed).
- `none` → end the run immediately: no files written, no log update.
- Only selected topics continue to Step 4; unselected topics are discarded.

### Step 4: Self-validate (selected topics only)

For each selected topic:
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

### Step 5: Security filter (selected topics only)

Before writing, scan the selected content:
- **Credentials**: API keys, passwords, tokens → REJECT.
- **PII**: Email addresses, phone numbers, ID numbers → REDACT or REJECT.
- **Internal IPs/hostnames**: → REJECT.
- Mark sensitivity level in frontmatter: `public` / `internal` / `sensitive`.

### Step 6: Write one document per selected topic

Write each selected topic as its own document — never merge topics into a single file, and never pre-cut topics into knowledge units.

**Primary path** (if `$LLM_WIKI_PATH` is set):
```
$LLM_WIKI_PATH/questions_pending/session-<date>-<topic-slug>.md
```

**Fallback path** (if `$LLM_WIKI_PATH` is not set):
```
<workspace>/.wiki-capture/session-<date>-<topic-slug>.md
```

### Step 7: Product format

Each topic document follows the schema section「Session Capture（会话捕获文档）」. Frontmatter:

```yaml
---
type: session
id: session-<YYYYMMDD>-<topic-slug>
title: "<主题标题>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
captured_from: "<session-context>"
captured_at: <ISO timestamp>
sensitivity: public | internal | sensitive
related: []
---
```

Body — the topic's detailed narrative (one topic per document, no nested sections):

```markdown
<该主题的详细叙述：关键事实、机制、取舍理由、具名事物、关系>

来源：<第 N 轮 …>
```

- One document per topic — the document IS the topic; no knowledge-unit cutting, no page slugs.
- Keep provenance inline (来源 + `[unverified]`).

### Step 8: Update activity log

1. Append operation record to `$LLM_WIKI_PATH/wiki/log.md` (JSON Lines).
2. Append 1 full entry to `$LLM_WIKI_PATH/wiki/activity.md` (complete history).

> 不再写 user memory（wiki-activity.md 已移除）——状态按需从 log.md / questions_pending/ 派生。

## Gotchas

- **Never cut topics into knowledge units or assign page slugs** — `topic-slug` is only a document identifier; page slugs and entity/concept classification belong to `/wiki-ingest`.
- **Never write files before the human confirms the topic selection** — unselected topics must not reach `questions_pending/` (fail closed).
- **Do not merge topics into one document** — each selected topic is its own `session-<date>-<topic-slug>.md`.
- **Provenance is mandatory** — every topic must carry `来源：第 N 轮 …`; speculative claims get `[unverified]`; without provenance, `/wiki-review` cannot verify the claim.
- If `$LLM_WIKI_PATH` is unset, fall back to `<workspace>/.wiki-capture/`; if the schema instruction is unavailable, follow the Step 7 frontmatter template.

## Constraints

- Maximum **10 topic documents** per capture run (default; override via `.wiki-config.yml` `capture_max_items_per_run`).
- **One document per topic** — never merge topics into a single file, and never pre-cut a topic into knowledge units or pages.
- Never write files before the human confirms the selection — unselected topics must not reach `questions_pending/`.
- Low-confidence topics always require human review (never auto-approve).
- Sensitive topics are blocked — do not write to any file.
