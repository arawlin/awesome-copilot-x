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
related:                    # 语义关系：结构化写法（推荐），见下方说明
  # 结构化：{ relation: <part-of|contains|causes|contrasts-with|instance-of|relates-to>, target: <id>, note: "<一句话>" }
  - { relation: part-of, target: <id>, note: "<关系说明>" }
  # 简单引用（向后兼容）：裸 id
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

正文结构：摘要 → 知识地图（必填）→ 关键要点 → 提及的实体 → 引入的概念 → 原始文档查询

**知识地图（knowledge map，必填）**：文档级 llms.txt——小而高信号的导航索引，让 agent 无需加载全文即可定位知识块（消费方是 LLM，上下文窗口有限）。**固定结构如下，逐字写入 source 页面 `## 知识地图` 区块；保持精简，禁止膨胀成文档复述：**

```markdown
## 知识地图

**核心主题**：<一句话概括本文档覆盖的知识领域>

**章节骨架**：
1. <章节> → <小节 1>、<小节 2>
2. ...

**知识块映射**：

| 知识块 | 类型 | 检索价值 | 归属 |
|--------|------|----------|------|
| <名称> | pattern / mechanism / data | standalone / context-only | [[concepts/<id>]]、[[entities/<id>]]、`#锚点` 或 `本页` |

**块间依赖**：
- <块 A> → <块 B>（<part-of / builds-on / contrasts-with>）
```

填写规则：
- **核心主题**：一句话概括本文档覆盖的知识领域。
- **章节骨架**：文档章节 → 小节，按原文顺序列出。
- **知识块映射**：每个知识块标注 `类型`（pattern/mechanism 为知识，data 为参考数据）、`检索价值`（standalone=会被单独查询 → 可成页；context-only=只在上下文中有意义 → 并入父页/本页）、`归属`（落地页面 `[[concepts/<id>]]` / `[[entities/<id>]]`、父页内锚点 `#锚点`、或 `本页` 保留在 source 页）。
- **块间依赖**：知识块之间的引用/构建关系及关系类型。

每个被提取的实体/概念页面必须链接回此知识地图；标记为 `本页` 或 `#锚点` 的知识块绝不独立成页。

**大小上限**（演练实测校准）：source 页 ≤ 200 行 / 约 6KB（含知识地图与关键要点）；超限则压缩关键要点或将低信号细节下放到原始文档查询。

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

**粒度标准（放宽）**：任何具名可标识的事物均可独立成页——实体页是跨文档身份锚点，即使当前低复用也值得一页；不具名的抽象概念不属于实体。

**页面质量硬标准（所有页面适用）**：
- **自包含**：单独拉取本页即可完整理解，不依赖跨页拼装。
- **大小上限**（演练实测校准）：entity/concept ≤ 150 行 / 约 2KB；超限则按检索意图拆分或压缩。
- **progressive disclosure**：页末附一行「需要参考级细节 → 原始文档/上游页面」指引。

`related` 用结构化语义关系（见 Frontmatter 说明），禁裸链接。

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

**粒度标准（严格三条件，全部满足才独立成页）**：① 有独立检索价值（LLM 会单独查询该思想；无独立检索价值的子流程/子机制并入父概念页用 `#锚点`）；② 自包含（单独拉取可完整理解）；③ 是知识非数据（模式/原则/机制，而非参数表/对比矩阵/错误码清单）。

**页面质量硬标准（所有页面适用）**：
- **自包含**：单独拉取本页即可完整理解，不依赖跨页拼装。
- **大小上限**（演练实测校准）：entity/concept ≤ 150 行 / 约 2KB；超限则按检索意图拆分或压缩。
- **progressive disclosure**：页末附一行「需要参考级细节 → 原始文档/上游页面」指引。

`related` 用结构化语义关系（见 Frontmatter 说明），禁裸链接。

### Synthesis（综合页面）

位于 `wiki/synthesis/`，已批准的综合问答。定位为**跨文档主题综合**（GraphRAG 社区摘要的人手版）：仅在「一个问题横跨多个 source 页面且无单页能回答」时，ingest 生成 `draft` 状态的草稿；单文档叙事由该文档的知识地图覆盖，不使用 synthesis 复述。`approved_by` / `approved_at` 由 review 流程填写。

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
