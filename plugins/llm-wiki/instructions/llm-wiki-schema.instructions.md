---
description: "LLM Wiki 页面格式规范 — 定义 frontmatter 字段、页面生命周期、WikiLink 语法。被所有 Wiki 操作 Skill 引用。"
applyTo: "**/wiki/**/*.md"
---

# LLM Wiki 页面格式规范

## YAML Frontmatter（前置元数据）

每个 Wiki 页面必须包含 YAML frontmatter，字段如下：

```yaml
---
type: source | entity | concept | synthesis | index
id: <唯一-slug>
title: <显示标题>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags:
  - <标签1>
  - <标签2>
sources:                    # 可选：实体/概念页面使用
  - <来源-id>
related:
  - <实体或概念-id>
# ── 以下均为可选字段 ──
schema_version: "0.1"      # 页面创建时的 schema 版本
status: active              # draft | active | stale | contradicted | archived
last_reviewed: <YYYY-MM-DD>
review_by: <YYYY-MM-DD>
stale_reasons: []           # review_due | source_changed | source_deleted | semantic_superseded | stale_schema
source_last_commit: <sha>
source_hash: <sha256>
---
```

### 必填字段

| 字段 | 描述 |
| --- | --- |
| `type` | 页面类型：`source`、`entity`、`concept`、`synthesis`、`index` |
| `id` | 唯一 slug，全局不重复 |
| `title` | 人类可读的显示标题 |
| `created` | 页面创建日期（ISO） |
| `updated` | 最后修改日期（ISO） |

### 页面生命周期状态

| 状态 | 含义 |
| --- | --- |
| `draft` | 新创建，待审核 |
| `active` | 正常可用 |
| `stale` | 可能过时，需关注 |
| `contradicted` | 与新来源存在矛盾 |
| `archived` | 已归档，不再活跃 |

### 设计原则

- **永不自动删除页面**：源文件删除只触发 `stale`，物理删除由人工决定。
- **stale ≠ 错误**：stale 表示"需要关注"，不是"内容是错的"。
- **human-gated**：所有自动发现的问题进入 `lint_pending/`，不直接改写页面。

## WikiLink 语法

- 格式：`[[<type>/<id>]]`，如 `[[entities/ethereum]]`、`[[concepts/proof-of-stake]]`
- 解析规则：约定路径 `wiki/<type>/<id>.md` 优先 → 索引回退

## 页面类型与结构

### Source（来源页面）

位于 `wiki/sources/`，每篇摄入文档对应一个页面。

```yaml
---
type: source
id: <source-slug>
title: "<文档标题>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
authors: []
published: <YYYY-MM-DD>
entities_extracted: []
concepts_extracted: []
---
```

正文结构：摘要 → 关键要点 → 提及的实体 → 引入的概念 → 原始文档查询

**原始文档查询区块**（必填）：每个 source 页面必须在末尾包含以下区块，为 AI agent 提供查询原始参考数据的回退路径：

```markdown
## 原始文档查询

本 Wiki 存储从本文档中提炼的架构级知识（模式、原则、机制、对比）。
如需查询本文档涵盖的**参考级细节**，请直接从原始文档获取：

> **Agent 指令**：当 Wiki 概念页面无法满足查询的细节层级时，
> 使用 `fetch_webpage` 工具获取 `<原始文档的完整 URL>` 并从中搜索相关信息。
> Wiki 概念页面提供 "why" 和 "how"，原始文档提供 "what"。
```

`<原始文档的完整 URL>` 替换为实际的文档地址

### Entity（实体页面）

位于 `wiki/entities/`，具名可标识事物。

```yaml
---
type: entity
id: <entity-slug>
title: "<实体名>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
category: platform | tool | framework | person | company | protocol
sources: []
related: []
---
```

正文结构：定义 → 关键属性 → 出现在（来源列表）

### Concept（概念页面）

位于 `wiki/concepts/`，抽象思想、模式、方法论。

```yaml
---
type: concept
id: <concept-slug>
title: "<概念名>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
sources: []
related: []
---
```

正文结构：定义 → 核心思想 → 相关概念 → 出现在

### Synthesis（综合页面）

位于 `wiki/synthesis/`，已批准的综合问答。

```yaml
---
type: synthesis
id: <synthesis-slug>
title: "<问题标题>"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: []
sources: []
related: []
question: "<原始问题>"
approved_by: <审核人>
approved_at: <YYYY-MM-DD>
---
```

正文结构：问题 → 综合回答（含引用）→ 来源
