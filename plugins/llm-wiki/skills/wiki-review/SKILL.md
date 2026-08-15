---
name: wiki-review
description: '人工审核待处理的会话捕获文档——对 questions_pending/ 中的主题文档（每份 session-*.md 是一个讨论主题）做 approve/reject/revise 三态裁决，含质量门（自包含、大小、粒度）、synthesis 草稿批准与存量碎片页合并模式。当用户要求 "review wiki changes"、"approve pending"，或管理人工把关的知识工作流时使用。'
argument-hint: "[all|batch|slug <id>]"
---

# Wiki Review — 人工审核

对待处理会话捕获文档的人工把关工作流（每主题一份文档）。每份文档就是一个主题；审核对其批准/拒绝/修订，定稿后文档从 `questions_pending/` 移动到 `questions_approved/` 或 `rejected/`。

## 何时使用本技能

- 用户要求 "review wiki changes"、"approve pending" 或 "manage pending knowledge"
- 在 `/wiki-capture` 产生待审核的主题文档之后、`/wiki-ingest` 之前（需要人工把关）
- 批准 synthesis 草稿，或审计存量碎片页（`merge` 模式）

## 前置条件

- 通过环境变量 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解审核 frontmatter 字段。
- 阅读 `wiki/.wiki-config.yml` 了解会话上限与保留阈值（缺失时用默认值）。

## 审核模式

| 模式 | 命令 | 说明 |
|------|---------|-------------|
| **全部** | `all` | 逐个审核每份待处理主题文档 |
| **批量** | `batch` | 一次性快速批准所有低风险主题文档 |
| **单个** | `slug <id>` | 审核某一份特定文档 |
| **存量合并** | `merge` | 按当前粒度规则审计已有页面并提议合并（如过度拆分的子概念） |

## 审核状态

| 状态 | 动作 | 文件操作 |
|-------|--------|---------------|
| **approved** | 主题原样接受 | `mv questions_pending/<id>.md questions_approved/<id>.md` |
| **rejected** | 带理由拒绝主题 | `mv questions_pending/<id>.md rejected/<id>.md` + 添加 `review` frontmatter |
| **revised** | 修订后批准主题 | 在 Chat 中修改并确认后，移至 `questions_approved/` |

每份文档是一个主题，因此审核决策按文档进行；`review` frontmatter 在单份文档上记录结果。

## 质量门（每份被审文档）

批准前，对照 LLM 消费质量规则（schema）逐项核验：

| 检查 | 通过标准 |
|-------|---------------|
| **自包含** | 主题文档单独阅读即可连贯理解——无需兄弟文档 |
| **大小上限** | session 文档 ≤ 200 行 / 约 6KB（schema, Session Capture 节） |
| **粒度** | 主题是连贯的讨论小节，而非预切的知识单元——单元切分与分类是 ingest 的职责 |
| **溯源** | 每个主题携带其会话轮次/消息来源 |

任何一项不通过的条目进入 `revised`（先修订再批准）或 `rejected`（带理由）——绝不自动批准。

## Synthesis 草稿批准

`wiki/synthesis/` 的草稿（由 `/wiki-ingest` 创建，`status: draft`）需要在此批准：

1. 阅读草稿页面。
2. 核验它回答的是**跨文档**问题（横跨多个 source 页面）——而非单文档复述（那属于知识地图）。
3. 核验论点携带溯源。
4. 批准时设置 frontmatter：`status: active`、`approved_by: "<user>"`、`approved_at: <YYYY-MM-DD>`。将任何 `questions_pending/synthesis-*.md` 移至 `questions_approved/`。
5. 在 `wiki/log.md` 和 `wiki/activity.md` 记录批准。

## 工作流

### Step 1: 加载待审队列

列出 `$LLM_WIKI_PATH/questions_pending/` 中所有文件（每主题一份 `session-*.md`）。对每份文档读取其主题内容与置信度，然后归类：
- **高置信度** + **低风险**：可批量批准。
- **中置信度** + **中风险**：标准审核。
- **低置信度** + **高风险**：需要深度审核。

### Step 2: 分诊

详细审核前先给出摘要：

```
📋 待审核：<N> 份文档
   🟢 低风险（可批量）：<n>
   🟡 中风险：<n>
   🔴 高风险（深度审核）：<n>

继续 [all|batch|skip]？
```

### Step 3: 逐份审核主题文档

对每份待处理主题文档，展示：

1. **标题**。
2. **置信度**级别。
3. **关键论点**（前 3–5 条）。
4. **溯源**摘要。
5. **裁决提示**：`[a]pprove / [r]eject / [e]dit / [s]kip`

#### 批量模式

仅对低风险主题文档，展示摘要表：

| # | 标题 | 置信度 |
|---|-------|------------|
| 1 | Foo | high |
| 2 | Bar | high |

单次确认："批准全部 <n> 份主题文档？[y/n]"

#### 修订后批准

当用户要求修订时：
1. 用户给出修订指令（如 "把日期改为 2022"）。
2. 对待处理文档应用修订。
3. 展示 diff。
4. 确认："应用此修改？[y/n]"
5. 是则移至 `questions_approved/`。在 `review.changes_requested` 记录修订。

### Step 4: 记录审核决策

在文档 frontmatter 中记录决策（每份文档是一个主题）：

```yaml
review:
  status: approved | rejected | revised
  reviewer: "<user>"
  reviewed_at: <YYYY-MM-DD>
  reason: "<reason for rejection>"
  changes_requested: "<edit summary>"
```

### Step 5: 审核期间的新鲜度检查

批准前，检查被引用的 source 页面自该条目生成后是否已更新：
- 比较引用页面的 `source_last_commit` 或 `source_hash`。
- 若来源已变化，警告："⚠️ 来源 [[sources/xxx]] 自本条目捕获后已更新，考虑重新提取。"

### Step 6: 更新日志

1. 向 `$LLM_WIKI_PATH/wiki/log.md` 追加审核操作记录（JSON Lines）。
2. 向 `$LLM_WIKI_PATH/wiki/activity.md` 追加 1 条完整记录（完整历史）。

> 不再写 user memory（wiki-activity.md 已移除）——状态按需从 log.md / questions_pending/ 派生。

## 存量合并模式

审计违反当前粒度规则的已有页面（如过度拆分的子概念 `binance-api-authentication` + `binance-request-signing-payload`）：

1. **扫描** `wiki/entities/` 和 `wiki/concepts/` 中的候选组：`related` 高度重叠、从不单独查询的子流程页、或超过大小上限的页面。
2. **提议合并**为表格：目标页（父页）+ 候选页 + 合并理由 + 溯源如何保留（保留两条 `sources` 列表）。
3. 提交用户确认：`[y/n/edit]`。
4. 批准后把内容合并进父页（子流程变成 `## sections`），**彻底删除被吸收的页面（无重定向）**，修复对被删页面的所有失效 `[[WikiLink]]` 引用，更新 `related`、`wiki/index.md`、`wiki/log.md`，并重新运行 lint。

> 未经用户确认绝不合并——这是破坏性重构。

## 被拒条目保留

被拒的主题文档移动到 `rejected/` 并记录 `review` frontmatter 理由；批准的文档原样移动到 `questions_approved/`。

| 理由 | 保留期 | 归档路径 |
|--------|-----------|--------------|
| 重复 | 1 天 | `rejected/YYYY-MM/<id>.md` |
| 质量低 | 7 天 | `rejected/YYYY-MM/<id>.md` |
| 过时 | 30 天 | `rejected/YYYY-MM/<id>.md` |
| 矛盾 | 永久 | `rejected/permanent/<id>.md` |

保留天数默认未校准——可通过 `.wiki-config.yml` 的 `rejected_retention_days` 覆盖。

定期运行 `tools/cleanup-rejected.sh` 清理过期的被拒条目。

## 注意事项（Gotchas）

- **绝不自动批准低置信度条目**——它们必须逐份单独审核。
- **拒绝时必带 `reason`**——审核记录是整条流水线的审计线索。
- **未经用户确认绝不合并存量页面**——合并是破坏性重构。
- **批准前检查新鲜度**——若引用的来源自捕获后已变化，警告并考虑重新提取。
- 批量模式仅适用于低风险条目；矛盾始终走单独审核。

## 约束

- 每次审核会话最多 **20 份主题文档**（默认；可通过 `.wiki-config.yml` 的 `review_max_items_per_session` 覆盖），避免淹没用户。
- 被拒的主题文档必须始终在审核记录中带 `reason`。
- 低置信度主题文档绝不自动批准——始终需要单独审核。
