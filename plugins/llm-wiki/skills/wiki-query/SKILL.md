---
name: wiki-query
description: '查询 LLM Wiki 知识库——读取 wiki/index.md 目录，选择性加载相关页面，以带 [[WikiLink]] 引用的综合回答回复。当用户提出可能由 wiki 知识回答的问题、要求 "search the wiki"，或需要知识库中的交叉引用信息时使用。'
argument-hint: "<question>"
---

# Wiki Query — 知识查询

通过阅读与综合 LLM Wiki 知识库中的信息来回答用户问题。

## 何时使用本技能

- 用户提出可能由 wiki 知识回答的问题、要求 "search the wiki"，或需要交叉引用信息
- 在抓取外部文档之前——wiki 回答 "why/how" 并指向原始来源获取 "what"
- 当答案横跨多个页面、需要带 [[WikiLink]] 引用的综合时

## 前置条件

- 通过环境变量 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解 WikiLink 语法与页面结构。

## 工作流

### Step 1: 读取索引

读取 `$LLM_WIKI_PATH/wiki/index.md` 获取完整页面目录。解析：
- 按类型（sources / entities / concepts / synthesis）与标签分组的所有页面。
- 用于相关性匹配的页面标题与 ID。

### Step 2: 选择相关页面

基于用户问题，识别候选页面：

1. **BM25 预筛（仅大库）**：若 `wiki/index.md` 超过约 20K tokens，或 wiki 超过约 5,000 页，改用捆绑的搜索脚本而非扫描整个索引：
   ```bash
   python3 <skill-dir>/scripts/search.py "<question>" --top-k 15
   ```
   脚本输出带分数的排序 `[[<type>/<id>]]` 候选——把这些作为候选集，跳过步骤 2–4。
2. **索引扫描**：读取 `wiki/index.md`（全库 llms.txt，条目为标准 llms.txt 行格式）——将问题词匹配到页面标题、标签与 ID。
3. **知识地图导航**：对匹配领域，读取相关 `sources/` 页面的 `## 知识地图` 以定位精确知识块（及其归属页面），而非凭标题猜测。
4. **语义相关性**：优先选择标题/标签与问题领域重叠的页面。
5. **选择预算**：最多选择 **10–15 页**，控制在 token 预算内（页面内容目标 1,500–12,000 tokens）。

### Step 2.5: 检查 source 页的原始回退指令

Wiki 概念/实体页存储**知识**（why、how、patterns）。它们刻意省略存于原始来源文档中的**参考数据**。

1. 读取相关 `sources/` 页获取主题领域。
2. 若 source 页包含带 `fetch_webpage` URL 的 `Agent 指令` 块，将该 URL 作为 wiki 页面未覆盖的细节级信息的权威参考。
3. 这不是领域专属——适用于任何来源（API 文档、技术规格、协议标准等），只要 wiki 提取了模式、raw 来源保有穷尽细节。

### Step 3: 读取选中的页面

从 `wiki/<type>/<id>.md` 完整读取每个选中页面。优先级：
- `synthesis/` 页面优先（预先综合的答案）。
- `entities/` 页面用于事实查询。
- `concepts/` 页面用于解释性查询。
- `sources/` 页面用于溯源查询。

**跟随细节指针（渐进披露）**：若选中页面的答案需要参考级细节（参数、精确字段），跟随页面结尾的细节指针到其 source 页面 / 原始文档，而非猜测或抓取无关页面。若选中页面不自包含，跟随其链接补齐缺失上下文。

### Step 4: 综合答案

1. **交叉引用**多个页面的信息。
2. **解决矛盾**：若两个页面陈述冲突事实，显式注明矛盾：
   ```
   > ⚠️ **矛盾**：[页面 A] 声称 X，而 [页面 B] 声称 Y。
   ```
3. **撰写答案**，带行内 [[WikiLink]] 引用：
   ```
   Ethereum transitioned to Proof of Stake in 2022 (see [[concepts/proof-of-stake]]).
   ```
4. **置信度**：基于来源质量与一致性，给出整体答案置信度（high / medium / low）。

### Step 5: 来源归属

在答案末尾列出所有咨询过的页面：

```
---
**咨询的来源：**
- [[entities/ethereum]] — Ethereum 实体页
- [[concepts/proof-of-stake]] — PoS 概念页
- [[sources/ethereum-whitepaper]] — 原始白皮书
```

## 注意事项（Gotchas）

- **绝不编造信息**——若 wiki 不含答案，直接说明；绝不凭空捏造 WikiLink 或引用。
- **跟随细节指针而非猜测**——参考级细节（参数、精确字段）存于原始来源；使用 source 页的 `Agent 指令` URL 块。
- **显式呈现矛盾**——两页冲突时，陈述双方而非默默选一。
- **控制选择预算**（10–15 页 / 1,500–12,000 tokens）——过度选择会污染上下文窗口。
- 大库（索引 >约 20K tokens 或 >约 5,000 页）时，运行捆绑的 BM25 `search.py` 而非扫描整个索引。

## 性能说明

- 纯文件方式在 **0–5,000 页**内表现良好（已在 performance-scale-estimation-spike 中验证）。
- 单次查询无论 wiki 总大小都消耗约 1,500–12,000 tokens。
- 超出该规模后，捆绑的 BM25 预筛（[`search.py`](./scripts/search.py)，零依赖 Python 3）把候选选择控制在预算内——见 Step 2.1。

## 输出约束

- 始终用 [[WikiLink]] 引用来源。
- 绝不编造信息——若 wiki 不含答案，直接说明。
- 当置信度为 `low` 时，清楚说明局限。
