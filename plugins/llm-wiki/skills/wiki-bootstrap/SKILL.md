---
name: wiki-bootstrap
description: '从 GitHub 仓库冷启动构建新的 LLM Wiki——用 4 级优先级提取从 README、docs/、issues 与 PRs 中提取知识。目标：3 个启动问题可答、最少 11 页。当用户要求 "bootstrap wiki"、"initialize wiki from repo"，或启动全新知识库时使用。'
argument-hint: "[--repo <path>] [--phases <A|AB|ABC>]"
---

# Wiki Bootstrap — 冷启动引导

从现有 GitHub 仓库初始化一个新的 LLM Wiki。

## 何时使用本技能

- 用户要求 "bootstrap wiki"、"initialize wiki from repo"，或启动全新知识库
- 从现有 GitHub 仓库首次搭建 LLM Wiki
- 只存在源仓库、需要从零重建 wiki 时

## 前置条件

- 目标仓库必须本地可访问。
- 通过环境变量 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解页面格式。

## 提取阶段（4 级优先级）

### 阶段 A：概览种子（P0 — 必做）

**来源**：`README.md`

提取：
- **1 个 source 页**：README 摘要。
- **3–6 个 entity 页**：提及的核心工具、框架、服务。
- **3–6 个 concept 页**：关键模式、架构概念。

**目标**：7–13 页。这是最小可用 wiki。

### 阶段 B：约束种子（P1 — 推荐）

**来源**：`docs/` 目录（所有 `.md` 文件）

从文档中提取额外的实体与概念。合并/更新阶段 A 的页面。

**目标**：额外 5–15 页。

### 阶段 C：社区种子（P2 — 可选，opt-in）

**来源**：高参与度 Issues（👍 ≥ 5）

将痛点、功能请求与变通方案提取为概念。

**目标**：额外 3–8 页。

### 阶段 D：决策种子（P3 — 可选，opt-in）

**来源**：已合并的 PR（标题 + 描述）

提取架构决策与理由，作为相关 concept 页内容的一部分（绝不单独成页）。

**目标**：额外 2–5 页。

## 工作流

### Step 1: 扫描目标仓库

读取仓库结构。展示摘要：

```
📊 仓库分析：
   语言：<detected>
   README：<size>
   Docs：docs/ 中 <n> 个文件
   Issues：<n> 个打开，<n> 个高参与度
   已合并 PRs：<n> 个最近

预计引导规模：Phase A = 7–13 页，Phase AB = 12–28 页
继续 [A|AB|ABC|full]？
```

### Step 2: 执行提取（逐阶段）

对每个阶段，使用与 `/wiki-ingest` 相同的提取逻辑，**包括其粒度与质量约定**：
1. 阅读来源文档。
2. 构建文档知识地图（小而高信号；见 `/wiki-ingest` Step 2）。
3. 提取实体、概念、决策——应用粒度规则：概念须满足有独立检索价值 + 自包含 + 是知识非数据；子流程并入父页（`#锚点`）；决策/理由并入相关 concept 页内容（绝不单独成页）。
4. 生成带溯源的 wiki 页面，遵守页面质量硬标准（自包含、≤ 约 300 行 / 约 4KB、结尾细节指针）。
5. 自校验（置信度级别）。
6. 安全过滤。

阶段 A 的页面目标（3–6 entity + 3–6 concept）是上限而非配额——不要为了凑数过度拆分。

### Step 3: 批量确认

提取后，把全部生成的页面作为一批展示（而非逐个）：

```
📦 引导完成：生成 <N> 页
   Sources：<n>
   Entities：<n>
   Concepts：<n>

页面列表：
   [[entities/foo]] — Foo
   [[concepts/bar]] — Bar
   ...

审核并批准全部？[y/n/edit]
```

这把人工把关循环压缩为单次批量确认。

### Step 4: 启动验证

批准后，运行 3 个预定义启动问题：

1. "这个项目是什么？" — 应从 source 页返回项目概览。
2. "核心概念有哪些？" — 应从 concept 页列出概念。
3. "如何开始？" — 应从 README source 返回设置/快速上手。

评分：≥ 2/3 正确 = 引导成功。

若引导失败（< 2/3），建议运行阶段 B（docs/）补充内容。

### Step 5: 收尾

1. 用所有新页面更新 `wiki/index.md`。
2. 向 `wiki/log.md` 追加引导记录。
3. 向 `wiki/activity.md` 追加 1 条完整记录。
4. 汇报：
   ```
   ✅ 引导成功！
      页面：<N>
      启动问答：<score>/3
      Wiki 已可查询。试试 /wiki-query "what is this project?"
   ```

## 注意事项（Gotchas）

- **阶段页面目标是上限而非配额**——绝不为了凑数过度拆分页面。
- **Issues/PRs 阶段仅 opt-in**——未经用户明确同意绝不抓取 GitHub Issues 或 PRs。
- **绝不绕过批量确认**——所有生成页面必须在收尾前经人工审核。
- **决策/理由绝不单独成页**——并入相关 concept 页内容。
- 最小可用是 **11 页**——优先深度与质量，而非凑数达标。

## 约束

- 单次引导会话最多总页数 **50 页**（默认；可通过 `.wiki-config.yml` 的 `bootstrap_max_pages` 覆盖）。
- 最小可用：**11 页**（1 source + 5 entity + 5 concept）。
- Issues/PRs 阶段**仅 opt-in**——未经同意绝不抓取。
- 人工把关：收尾前必须批量确认。
