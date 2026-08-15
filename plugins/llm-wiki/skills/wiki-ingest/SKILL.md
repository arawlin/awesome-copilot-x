---
name: wiki-ingest
description: '将已批准内容摄入 LLM Wiki——读取 raw/ 文档（知识地图 + entity/concept 提取）与 questions_approved/ 中已批准的会话捕获文档（知识单元切分 + 类型拆分 + 去重），产出自包含的 wiki 页面（sources/entities/concepts），带强制溯源与 LLM 消费质量规则（自包含、大小上限、渐进披露）。当用户要求 "ingest documents"、"add to wiki"、"process raw files"，或为 AI agent 构建知识库时使用。'
argument-hint: "[--source <file>] [--all]"
---

# Wiki Ingest — 文档摄入

读取 `raw/` 中的文档与 `questions_approved/` 中已批准的会话捕获文档，然后在 `wiki/sources/`、`wiki/entities/` 和 `wiki/concepts/` 下生成结构化的 wiki 页面。会话文档在此处进行**切分与类型拆分**（entity / concept）——capture 故意不做分类或切分，因为知识单元切分与类型分配需要本阶段所拥有的全局去重与粒度上下文。Wiki 的消费方是 **LLM agent**，而非人类读者：agent 按需将页面检索进有限上下文窗口，因此每页必须自包含、每个索引必须小而高信号。提取出的页面是轻量文档知识地图的叶子节点——绝不是孤立碎片，也绝不是臃肿的巨型页面。

## 何时使用本技能

- 用户要求"摄入文档"、"add to wiki"、"处理 raw 文件"
- 从原始材料（API 全文、研究笔记、技术文档）构建知识库
- 需要把已有知识去重、归类、建立关联时

## 前置条件

- 通过环境变量 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解页面格式规范。
- 阅读 `wiki/.wiki-config.yml` 了解去重阈值与安全规则。

## 工作流

### Step 1: 扫描 raw/ 目录

列出 `$LLM_WIKI_PATH/raw/` 中所有文件。若用户指定 `--source <file>`，仅处理该文件；否则处理所有未处理文件。

### Step 2: 构建文档知识地图（提取之前）

**在提取任何内容之前完成此步。** 完整阅读文档，然后产出捕捉文档整体结构的知识地图——这是防碎片化的锚点。

**使用 `llm-wiki-schema.instructions.md` 中定义的固定模板**（Source 页面 → 知识地图）——逐字写入 source 页面的 `## 知识地图` 小节。不要自创结构；schema 是单一事实源。

**如何填写每个区块：**
- **核心主题**：一句话——本文档覆盖什么知识领域？
- **章节骨架**：文档的章节 → 小节，按顺序。
- **知识块映射**：对每个知识块分类：
  - **类型 (type)**：`pattern` / `mechanism`（知识）vs `data`（参数表、错误清单——仅作参考）
  - **检索价值 (retrieval value)**：`standalone`（可单独查询 → 成页）或 `context-only`（仅在上下文中才有意义 → 并入父页 / 留在 source）
  - **归属 (home)**：落地页面（`[[concepts/<id>]]` / `[[entities/<id>]]`）、父页内的 `#anchor`、或 `本页`（保留在 source 页）
- **块间依赖**：各知识块引用或构建于哪些块，以及关系类型。

知识地图是**文档级 llms.txt**——一个小而高信号的索引，让 agent 无需整读文档即可导航。保持精简：核心主题一行、章节骨架仅到章级、每个知识块一行。绝不让它膨胀成文档复述。每个被提取的页面必须链接回它。标记为 `本页` 或 `#anchor` 的知识块留在 source / 父页，绝不单独成页。

### Step 3: 决定页面粒度（面向 LLM 消费优化）

使用 Step 2 的知识地图决定什么成为页面。**消费方是 LLM**：当单页能完整回答一次查询、无需拉取无关 token 时，检索效果最好。实体与概念使用**不同标准**：

**实体（具名事物）——放宽：任何具名、可标识的事物都可能成为页面。**
- 实体页很薄（定义 + 属性 + sources），作为跨文档身份锚点。即使低复用的实体（如一个 CLI 工具）也值得一页，因为未来的文档很可能引用同一个名字。
- 不为未命名 / 抽象的概念创建实体页——那是概念。

**概念（抽象知识）——严格：只有同时满足以下三个条件才成页：**
1. **有独立检索价值**——LLM 很可能单独查询这个思想（如鉴权方案、限流策略）。只在父主题内才有意义的子流程**不合格**。**启发式**：这个知识块能否单独一句话回答一个真实的检索问题？✅ "Binance 如何限频？" → rate-limiting（独立）；❌ "签名流程的第一步是什么？" → 并入 authentication（子流程，从不单独查询）。
2. **自包含**——仅凭本页即可完整理解，无需拉取兄弟页面。这是 LLM 检索的硬性要求。
3. **是知识非数据**——它是模式、原则或机制（why/how），而非参数表或清单（what）。

**否则，不创建单独页面：**
- **没有独立检索价值的子流程与子机制**归入父页的 `## section`（锚点）。示例："签名 payload 构建"是"API 鉴权"的子流程——如果它从不被单独查询，就并入。
- **低复用的文档专属细节**留在 source 页的知识地图中（标记 `本页`）。
- **参数表、对比矩阵、错误码清单、变更日志**是数据不是知识——直接跳过。它们存于 raw 文档；agent 按需对 "what" 实时抓取 raw 文件。

**粒度原则：自包含优先，允许原子化，杜绝重复与低信号。** 不确定时，宁选更小的自包含页面也不合并主题——臃肿页面会用无关 token 污染检索。但绝不创建与另一页重复、或 agent 不会单独查询的页面。

> 这与去重策略（宁多勿少）**刻意相反**。去重防止**重复**知识（有限上下文窗口内代价高）；粒度防止**臃肿与不自包含**。对各自的决策应用各自规则——绝不错配。

### Step 4: 提取实体与概念（单遍 + 行内自校验）

对每份文档，以知识地图与粒度规则为指导：

1. **实体**：具名可标识的事物（工具、框架、公司、人、协议、平台）。生成 `wiki/entities/<slug>.md`——任何具名、可标识的事物都合格（放宽标准，见 Step 3）。
2. **概念**：抽象思想、模式、方法论。生成 `wiki/concepts/<slug>.md`——只有满足 Step 3 中三条严格条件的概念。
3. **关系**：用 `related` 中的**结构化语义关系**（YAML）链接实体与概念：

   ```yaml
   related:
     # Structured (preferred): relation type + target + optional note
     - { relation: part-of, target: binance-api-authentication, note: "签名 payload 构建是鉴权体系的子流程" }
     # Simple reference (backward compatible): bare id
     - binance-api-types-comparison
   ```

   `relation` 枚举：`part-of` / `contains` / `causes` / `contrasts-with` / `instance-of` / `relates-to`。已知语义关系时绝不用裸链接。
4. **生成 source 页面**：`wiki/sources/<source-slug>.md`，含摘要、关键要点、**知识地图**（Step 2）、实体列表、概念列表。
5. **行内自校验**：
   - 每条论点必须有溯源（引用或转述并附来源）。
   - 分配置信度：`high`（直接陈述）、`medium`（合理推断）、`low`（推测性 → 需要人工审核）。
   - 无依据的论点加 `[unverified]` 标记。
   - **每页必须自包含**：读者（LLM）单独拉取本页即可理解，无需抓取兄弟页面。若不满足，补入缺失上下文或显式链接。
   - **遵守大小上限**（演练实测校准）：entity/concept ≤ 150 行 / 约 2KB，source ≤ 200 行 / 约 6KB（见 schema）。超限意味着按检索意图拆分或压缩。

### 知识提取原则

Wiki 存储**知识**（why、how、patterns），而非原始数据（what、specs、parameters）。提取前应用此决策矩阵：

| 复用 / 变化 | 低变化率 | 高变化率 |
|---------------|-----------------|------------------|
| **高复用** | ✅ 提取为 concept | ⚠️ 只取模式，跳过参数表 |
| **低复用** | ⚠️ 可选、低优先级 | ❌ 完全跳过 |

示例：

- ✅ **提取**：鉴权机制、限流策略、API 类型架构、流类型模式、本地订单簿算法
- ❌ **跳过**：端点参数表、完整错误码清单、变更日志、快速上手复制粘贴
- 💡 端点参数存于 raw `llms-full.txt`——AI agent 直接查询它获取 "what"，Wiki 回答 "why" 与 "how"。

**提取规则：**
- 优先**模式与原则**，而非穷举——提取 "why" 与 "how to use"，不是 "what are all the parameters"。
- 保留原文片段用于溯源。
- 显式标记不确定性——绝不编造。
- **去重检查**（LLM 语义判断，宁多勿少）：
  - 层级 1：slug 完全匹配 → 自动更新已有页面（同源）。
  - 层级 2：LLM 语义判断——对比候选页面 title/内容，判断是否为同一实体/概念：
    - 明显同一 → 合并进已有页面（合并内容，保留两条 provenance）。
    - 疑似同一但不确定 → SUGGEST-MERGE（创建 `questions_pending/merge-*.md`）。
    - 无匹配 → 创建新页面。
  - 不确定时创建新页面（宁多勿少）——合并错误的代价远大于合并重复。

### Step 5: 去重（简化三带）

| 带 | 条件 | 动作 |
|------|-----------|--------|
| 0 | slug 完全匹配 + 同源 | 自动更新已有页面 |
| 1 | LLM 语义判断为同一实体/概念 | 合并进已有页面；不确定 → SUGGEST-MERGE (`questions_pending/merge-*.md`) |
| 2 | 无匹配 | 创建新页面 |
| 3 | 检测到矛盾 | 标记（创建 `contradictions_pending/*.md`） |

> 依赖说明：去重不再依赖 RapidFuzz / SBERT（`all-MiniLM-L6-v2` 为英文模型，中文语义相似度不可靠）。语义判断由 LLM 完成。

### Step 6: 安全过滤

1. **LLM 语义检查**（主力）：扫描提取内容中的凭证、PII、网络拓扑、商业秘密、基础设施细节。检测到 `sensitive` 级别 → 拒绝，不生成。
2. **gitleaks（可选）**：若已安装 gitleaks，对生成的页面运行 `gitleaks detect --source <content> --config $LLM_WIKI_PATH/.gitleaks.toml`。未安装则跳过。
3. **pre-commit 钩子（可选）**：若存在 `.git/hooks/pre-commit`，它运行 gitleaks 扫描并在 gitleaks 缺失时优雅跳过。

### Step 7: 写入页面并更新索引

1. 将 source 页面写入 `wiki/sources/<slug>.md`——**必须包含知识地图**（核心主题、章节骨架、块→页面映射、块依赖）与**原始文档查询块**（对原始文档的渐进披露）。
2. 将实体页面写入 `wiki/entities/<slug>.md`——末尾附一行**细节指针**指向其 source 页面 / 原始文档（渐进披露）。
3. 将概念页面写入 `wiki/concepts/<slug>.md`——末尾附一行**细节指针**指向其 source 页面 / 原始文档（渐进披露）。
4. 用语义关系填充 `related`（见 Step 4.3），并从每个被提取页面添加指向其 source 页面的反向链接。
5. **可选的跨文档 synthesis（草稿）**：仅当一个问题横跨多个 source 页面、且无单页能回答时才创建 `wiki/synthesis/` 页面——GraphRAG 社区摘要的人手版。不要用 synthesis 复述单文档（其知识地图已覆盖）。synthesis 页面需要人工批准（`approved_by`）——ingest 只产出草稿，review 批准。
6. 更新 `wiki/index.md`——**全库 llms.txt**：以标准 llms.txt 行格式 `- [title](<type>/<id>.md): one-line description`（见 schema, Index 节）追加新页面，按类型/主题分组，低优先级链接放 `Optional` 小节。拆分阈值是 **1M-token 上下文窗口**：仅当索引超过 1M tokens 时才拆成主题级索引页（MOC 风格）。
7. 以 JSON Lines 格式向 `wiki/log.md` 追加操作记录。

## 会话文档摄入（Session Capture Ingestion）

第二个输入源，排在 raw 文档之后：`questions_approved/session-*.md`（每主题一份文档，格式见 schema「Session Capture」节）。本阶段拥有 capture 刻意跳过的**切分与类型拆分**。

对每份会话主题文档：

1. **把主题切分为知识单元**——每份文档是一个讨论主题，不是页面。判断它包含哪些知识单元：具名事物（实体）、模式/方法论/原理（概念）、子流程（并入父页）、数据（跳过）。独立检索价值判断就发生在这里，此时已有 wiki 是已知的。
2. **对每个单元做类型拆分**：
   - **实体**（具名、可标识的事物）→ `wiki/entities/<slug>.md`（放宽标准，Step 3）。
   - **概念**（模式/方法论）→ 仅当通过粒度三条件时写入 `wiki/concepts/<slug>.md`；子流程并入父页作为 `## section`（`#锚点`）。
   - 取舍理由（"we chose X over Y because Z"）属于概念的**核心思想**——绝不单列一类。
3. **每个单元做去重检查**——与 Step 5 相同的三带表（AUTO-UPDATE / MERGE / SUGGEST-MERGE / CREATE）。
4. **安全过滤**按 Step 6。
5. **溯源**：最终页面中的每条论点必须携带会话文档 id（`captured_from`）——保留从 session → topic → page 的链路。
6. 更新 `wiki/index.md` 与 `wiki/log.md`（Step 7）。

### 页面上限

- 每次摄入最多 **15 页**（1 source + 最多 7 entity + 最多 7 concept）——默认值；可通过 `wiki/.wiki-config.yml`（`ingest_max_pages_per_run`）覆盖。会话文档条目计入同一上限。
- 若一份文档会生成更多，先重走 Step 3（丢弃数据表、合并无独立检索价值的子流程）；若剩余页面全部自包含且检索价值各异，把摄入拆成多次会话，而非强行合并。

## 注意事项（Gotchas）

- **绝不把无独立检索价值的子流程拆成页面。** 从不单独查询的子流程（如签名 payload 构建）属于其父概念（鉴权）——单独成页只会碎片化导航而没有检索收益。并入父页作为 `## section`。
- **绝不把参数表、对比矩阵或错误清单提取为概念。** 它们是数据不是知识。复制进 wiki 页面会制造过期副本与页面膨胀；raw 文档才是它们的家。
- **source 页不是纯摘要页。** 它必须携带文档的知识地图。没有它，被提取页面就成了没有全景锚点的孤立碎片。
- **不要用裸平铺链接作为关系。** `related: [binance-api-authentication, binance-request-signing-payload]` 没有说明两者如何关联。使用结构化语义关系（见 Step 4.3）。
- **对不同的决策应用 自包含优先（粒度）与 宁多勿少（去重）。** 去重防止重复知识（有限上下文窗口内代价高）；粒度防止臃肿与不自包含。反转它们会污染检索或制造重复知识。
- **一页一个检索意图。** 如果一页需要复述背景才能被理解，它就不自包含——补入缺失上下文或显式链接。
- **保持知识地图与索引小巧。** 它们是 llms.txt 式导航，不是内容。若索引塞不进上下文窗口，拆成主题级地图。
- **绝不超页面大小上限。** 臃肿页面用无关 token 污染检索（context rot）——按检索意图拆分或压缩成高信号陈述。

## 故障排查

| 问题 | 解决方案 |
|-------|----------|
| 一份文档生成过多候选页面 | 重走 Step 3：丢弃数据表、合并无独立检索价值的子流程、只保留可独立查询的知识块 |
| 两个被提取页面高度重叠 | 它们是同一个概念——合并为一页，保留两条 provenance；若仍有不同检索价值，改为记录语义关系 |
| 一页离开其 source 就难以理解 | 它不自包含——补入缺失上下文，或显式链接（渐进披露） |
| 一页超过大小上限 | 按检索意图拆分，或把行文压缩为高信号陈述 |
| 索引页塞不进上下文窗口 | 把 `index.md` 拆成主题级 MOC 页面，根索引保持精简 |

## 参考

- `llm-wiki-schema.instructions.md` — 页面格式、frontmatter、WikiLink 语法
- `wiki-context.instructions.md` — 跨会话上下文、`$LLM_WIKI_PATH` 约定

## 输出格式

摄入结束后，总结：
- 处理的文档数：N
- 创建的 source 页面数：N
- 创建的 entity 页面数：N
- 创建的 concept 页面数：N
- 合并建议数：N
- 标记的矛盾数：N
- 拦截的敏感内容数：N
