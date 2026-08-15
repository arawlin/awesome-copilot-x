---
name: wiki-lint
description: '对 LLM Wiki 运行健康检查——检测矛盾、孤立页、过期内容、格式违规与 LLM 消费问题（页面过大、知识地图缺失、细节指针缺失、索引过大）。问题输出到 lint_pending/ 供人工审核，绝不直接修改页面。当用户要求 "check wiki health"、"lint wiki"、"find issues"，或审计知识库质量时使用。'
argument-hint: "[--scope <all|stale|orphans|contradictions|format>]"
---

# Wiki Lint — 健康检查

审计 LLM Wiki 的质量问题。所有发现进入 `lint_pending/`——**绝不直接修改 wiki 页面**。

## 何时使用本技能

- 用户要求 "check wiki health"、"lint wiki"、"find issues"，或审计知识库质量
- 作为周期性健康检查，或在 `/wiki-ingest` 之后捕捉结构/格式问题
- 在 `/wiki-review` 的 `merge` 模式之前，浮现碎片化候选

## 前置条件

- 通过环境变量 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 阅读指令文件 `llm-wiki-schema.instructions.md` 了解页面生命周期与 frontmatter 规则。
- 阅读 `wiki/.wiki-config.yml` 了解新鲜度阈值。

## Lint 检查项

### 1. 过期检测（三层混合）

**第 1 层——确定性预筛（无需 LLM）：**

| 检查 | 条件 | stale_reason |
|-------|-----------|-------------|
| 审核逾期 | `current_date > review_by` | `review_due` |
| 来源已变 | `source_hash` 不匹配 | `source_changed` |
| 来源已删 | `git diff --name-status` 显示 D | `source_deleted` |
| schema 过期 | `page.schema_version < index.schema_version` | `stale_schema` |

**第 2 层——优先级打分：**
对每个过期候选打分：逾期天数（×2）+ 有 source_changed（+30）+ 有 source_deleted（+40）+ schema 缺口（+20）。得分 > 50 的页面进入第 3 层。

**第 3 层——LLM 语义复核：**
对高优先级页面，阅读页面及其来源。判断内容是否语义过时（如 "Ethereum uses Proof of Work" 而所有来源现在都说 PoS）。只建议——不重写。

### 2. 矛盾检测（4 类）

| 类型 | 检测方法 |
|------|-----------------|
| **事实矛盾** | 两个页面断言互斥的事实（A 说 X，B 说非 X） |
| **日期/数字冲突** | 正则：同一实体的日期、百分比、金额不一致 |
| **观点分歧** | 不同页面标记的观点互相矛盾 |
| **时效冲突** | 更新的来源与更旧页面内容矛盾 |

矛盾格式化为：
```markdown
> ⚠️ **矛盾**：[[entities/ethereum]] 声称 "Ethereum uses PoW"，但 [[sources/ethereum-2-0-overview]] 声称 "Ethereum transitioned to PoS in 2022"。
```

### 3. 孤立页检测

找出零入链 WikiLink 的页面：
- 扫描所有 wiki 页面的 `[[<type>/<id>]]` 引用。
- 列出未被任何其他页面引用的页面。
- 标记为 `lint_pending/orphan-<id>.md`。

### 4. 格式校验

对照 schema 要求检查每个页面：
- **缺失必填字段**：`type`、`id`、`title`、`created`、`updated`。
- **无效状态值**：必须是 `draft | active | stale | contradicted | archived` 之一。
- **失效 WikiLink**：指向不存在页面的链接。
- **schema 版本**：`schema_version` 低于全局版本的页面。

### 5. LLM 消费质量检查

与 LLM 消费规则（schema：大小上限、知识地图、渐进披露、小索引）对齐的确定性结构检查。语义判断（自包含、粒度）留在 `/wiki-review`——lint 只标记机器可查的问题。

| 检查 | 条件 → lint 报告 |
|-------|------------------------|
| 页面大小上限 | 页面 > 约 300 行或 > 约 4KB → `oversize-<id>.md` |
| 知识地图缺失 | source 页无 `## 知识地图` 小节 → `missing-knowledge-map-<id>.md` |
| 知识地图膨胀 | 知识地图小节 > 约 80 行 → `bloated-knowledge-map-<id>.md` |
| 原始文档查询块缺失 | source 页缺 `## 原始文档查询` → `missing-raw-query-<id>.md` |
| 细节指针缺失 | entity/concept 页无结尾细节指针 → `missing-detail-pointer-<id>.md` |
| 索引过大 | `wiki/index.md` > 约 20K tokens → `index-oversized.md`（建议拆主题级 MOC） |
| 索引格式不合规 | 索引条目非 llms.txt 行格式（`- [title](path): description`）→ `index-format.md` |

## 输出

按问题类别生成一个 `lint_pending/*.md` 文件，含结构化发现。格式：

```markdown
---
type: lint-report
category: staleness | contradiction | orphan | format
created: <YYYY-MM-DD>
severity: high | medium | low
affected_pages: [<id1>, <id2>]
---

# Lint Report: <category>

## Findings

### <page-id>
- **Issue**: <description>
- **Recommendation**: <action>
- **Auto-fix available**: yes | no
```

用 lint 操作记录更新 `wiki/log.md`。

## 注意事项（Gotchas）

- **绝不直接修改 wiki 页面**——lint 只向 `lint_pending/` 写报告；修复经由 review/ingest 流程。
- **语义判断留在 `/wiki-review`**——lint 只标记机器可查的问题（大小、知识地图、细节指针、索引）；自包含与粒度是 review 的职责。
- **报告所有问题，不在首个错误处停下**——完整报告优于部分报告。
- 矛盾发现必须包含两个冲突页面的完整上下文，而非单侧。

## 约束

- **绝不直接修改 wiki 页面**——只生成 lint 报告。
- 报告所有问题，不在首个错误处停下。
- 对矛盾，包含两个冲突页面的完整上下文。
- 若提供了 `--scope` 过滤器，遵守之。
