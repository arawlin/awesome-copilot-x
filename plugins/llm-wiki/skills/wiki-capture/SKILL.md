---
name: wiki-capture
description: '从当前 Copilot Chat 会话捕获知识——按讨论主题拆分为每主题一份文档，为每个主题撰写详细叙述摘要，先列出主题供人工选择，再将选中的主题各自写入 questions_pending/session-<date>-<topic>.md 待审核。知识单元切分、类型拆分与页面分配由 /wiki-ingest 完成。适用于任意工作区（检测 $LLM_WIKI_PATH）。当用户要求 "capture this conversation"、"save to wiki"、"extract knowledge"，或重大技术讨论之后使用。'
argument-hint: "[--scope <current-turn|full-session>]"
---

# Wiki Capture — 知识捕获

从当前 Chat 会话中提取知识，**按讨论主题拆分为每主题一份文档**（会话可能包含多个主题，如 A 和 B，也可能只有一个 A）——不做知识单元切分、不做类型分类、不分配页面 slug。先列出主题供人工选择，再将选中的每个主题各自写成一份文档待审核。知识单元切分、类型分类与页面分配由 `/wiki-ingest` 完成，它拥有 capture 所缺乏的全局上下文（去重、粒度、已有页面）。

## 何时使用本技能

- 用户要求 "capture this conversation"、"save to wiki" 或 "extract knowledge"（从 Copilot Chat 会话捕获知识）
- 在产生可复用知识（模式、机制、具名工具、取舍理由）的重大技术讨论之后
- 在 `/wiki-ingest` 之前，当会话知识需要进入人工审核队列时

## 前置条件

- 环境变量 `$LLM_WIKI_PATH` 必须指向 llm-wiki 仓库。
- 若未设置 `$LLM_WIKI_PATH`，回退到当前工作区的 `.wiki-capture/`。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解页面格式；若不可用，遵循本技能 Step 7 的 frontmatter 模板。
- 会话上限来自 `wiki/.wiki-config.yml`（`capture_max_items_per_run`）；配置缺失时使用默认值。

## 工作流

### Step 1: 确定范围

- `--scope current-turn`（默认）：仅提取当前这一轮对话。
- `--scope full-session`：提取整个会话历史。

### Step 2: 提取主题（单遍，每主题一份文档）

回顾会话并识别实际发生的**讨论主题**（会话可能覆盖多个主题，如 A 和 B，也可能只有一个 A）。每个主题成为**独立的一份文档**。不要将主题切分为知识单元、不要做任何分类、不要分配页面 slug——这些是 `/wiki-ingest` 的决策。

组织结构：
- 每个主题一份文档，按会话的自然分组（如 迁移总览、上下文文件机制、记忆系统）。
- 每个主题是**详细叙述**：关键事实、机制、取舍理由（"We chose X over Y because Z"）、具名事物、显式关系——详细到人工能判断其价值、`/wiki-ingest` 后续能切分与分类。
- 行内保留溯源：`来源：第 N 轮 …`，推测性论点加 `[unverified]` 标记。
- 不要预判一个主题将来会成为一个页面、多个页面，还是并入已有页面。

**值得性门（仅主题级）**：跳过纯寒暄或没有可复用知识的会话专属琐事；其余全部保留——更细的「独立检索价值」判断属于 `/wiki-ingest`。

### Step 3: 列出主题供人工选择

在写任何文件之前停下，**逐个主题**展示会话摘要，每个主题给出足够细节供人工判断：

| 字段 | 内容 |
|-------|---------|
| 编号 + 主题标题 | 主题标识（仅是文档组织，不是知识单元） |
| 一句话摘要 | 该主题覆盖什么 |
| 关键要点 | 讨论的主要内容 3–5 条 |
| 置信度 | high / medium / low |
| 来源 | 该主题跨越哪几轮 |

示例：

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

提问：`保留哪些主题？（输入编号如 "1,3,5"、"all" 或 "none"）`

- **等待人工明确选择**——在用户选定主题之前绝不写任何文件（fail closed）。
- `none` → 立即结束本次运行：不写文件、不更新日志。
- 只有被选中的主题进入 Step 4；未选中的主题丢弃。

### Step 4: 自校验（仅选中的主题）

对每个选中的主题：
1. **溯源检查**：每条论点必须引用会话中的具体消息或轮次。
2. **置信度评估**：
   - `high`：用户明确陈述或双方达成一致。
   - `medium`：从讨论中合理推断。
   - `low`：推测性——标记为必须人工审核。
3. **不确定性标记**：推测内容加 `[unverified]`。

**提取规则：**
- 完整性优先于精确性。
- 尽量保留原始措辞。
- 显式标记不确定性。
- 跳过琐碎对话（寒暄、闲聊）——只捕获实质性知识。

### Step 5: 安全过滤（仅选中的主题）

写入前扫描选中的内容：
- **凭证**：API key、密码、token → 拒绝。
- **PII**：邮箱、手机号、身份证号 → 脱敏或拒绝。
- **内网 IP / 主机名** → 拒绝。
- 在 frontmatter 标记敏感级别：`public` / `internal` / `sensitive`。

### Step 6: 每个选中的主题写一份文档

将每个选中的主题各自写成一份文档——绝不把多个主题合并进同一文件，也绝不把主题预切成知识单元。

**主路径**（已设置 `$LLM_WIKI_PATH`）：
```
$LLM_WIKI_PATH/questions_pending/session-<date>-<topic-slug>.md
```

**回退路径**（未设置 `$LLM_WIKI_PATH`）：
```
<workspace>/.wiki-capture/session-<date>-<topic-slug>.md
```

### Step 7: 产出格式

每份主题文档遵循 schema「Session Capture（会话捕获文档）」节。Frontmatter：

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

正文——该主题的详细叙述（一份文档一个主题，无嵌套小节）：

```markdown
<该主题的详细叙述：关键事实、机制、取舍理由、具名事物、关系>

来源：<第 N 轮 …>
```

- 一份文档一个主题——文档即主题；不做知识单元切分、不分配页面 slug。
- 每节保留行内溯源（来源 + `[unverified]`）。

### Step 8: 更新活动日志

1. 向 `$LLM_WIKI_PATH/wiki/log.md` 追加操作记录（JSON Lines）。
2. 向 `$LLM_WIKI_PATH/wiki/activity.md` 追加 1 条完整记录（完整历史）。

> 不再写 user memory（wiki-activity.md 已移除）——状态按需从 log.md / questions_pending/ 派生。

## 注意事项（Gotchas）

- **绝不把主题切分为知识单元或分配页面 slug**——`topic-slug` 只是文档标识；页面 slug 与 entity/concept 分类属于 `/wiki-ingest`。
- **人工确认主题选择前绝不写文件**——未选中的主题不得进入 `questions_pending/`（fail closed）。
- **不要把主题合并进同一份文档**——每个选中的主题是各自的 `session-<date>-<topic-slug>.md`。
- **溯源强制**——每个主题必须携带 `来源：第 N 轮 …`；推测内容加 `[unverified]`；无溯源则 `/wiki-review` 无法核验。
- 若 `$LLM_WIKI_PATH` 未设置，回退到 `<workspace>/.wiki-capture/`；若 schema 指令不可用，遵循 Step 7 的 frontmatter 模板。

## 约束

- 每次捕获最多 **10 份主题文档**（默认；可通过 `.wiki-config.yml` 的 `capture_max_items_per_run` 覆盖）。
- **每主题一份文档**——绝不把主题合并进同一文件，也绝不把主题预切成知识单元或页面。
- 人工确认选择前绝不写文件——未选中的主题不得进入 `questions_pending/`。
- 低置信度主题必须人工审核（绝不自动批准）。
- 敏感主题被拦截——不写入任何文件。
