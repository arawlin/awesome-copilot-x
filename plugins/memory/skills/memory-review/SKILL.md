---
name: memory-review
description: 'Audit VS Code memory files (user/repo/session scopes) for redundancy, contradictions, and best-practice violations; output a severity-triaged fix list for human approval. Use when asked to "review memory", "check memory conflicts", "memory hygiene", or "memory 矛盾/冗余检查".'
argument-hint: "[all|repo|user|session]"
---

# Memory Review — 审查

对 VS Code memory tool 的文件做三类检查：**冗余 / 矛盾 / 最佳实践合规**。原则：机器发现 + 人裁决。

## When to Use This Skill

- 用户要求检查 memory 是否有矛盾、重复或格式违规
- 定期体检（如每周一次）前运行，保持 memory 可信
- 大规模重构 memory 前，先产出问题清单供决策

## 检查维度

### 1. 冗余检测

- 跨文件搜索相同关键词 / 结论（如同一 API 陷阱出现在两个文件 → 建议合并）。
- 对比**常驻指令文件**（`~/.copilot/instructions/`、`*.instructions.md`、`*.prompt.md`）——指令每次会话必加载，memory 中同内容 = 纯冗余，应删 memory 侧。
- 单文件覆盖 ≥2 个主题 → 建议拆分或合并。

### 2. 矛盾检测

- 同一主题多条记录 → 以**日期最新**为准，旧条目标注 `superseded`。
- 拿不准时用**实现验证**判定：查 `node_modules` 实际类型、跑命令实测，不猜。
- 发现矛盾必须当场解决（更新旧条目），不能只报告。

### 3. 最佳实践合规

- 条目格式：`[日期] 结论 + Source`（无 Source 的标注缺失）。
- 大小基线：单文件 >4KB 或 >120 行 → 建议拆分 / 瘦身；repo memory 总量 >30KB → 建议 consolidate。
- Scope 正确性：通用方法论进了 repo memory → 建议迁移 user memory；项目事实进了 user memory → 反向迁移。
- **文件组织**（依据：全局指令 `memory-capture.instructions.md` §文件组织规范）：按该规范核对单文件主题纯度、命名语义、大小护栏与反模式——不在此复制规范内容，以指令为准。
- 违反 memory 指南：冗长散文、缺日期、未去重。

## 工作流

### Step 1: 列出全部 memory 文件

`memory view /memories/` + `/memories/repo/` + `/memories/session/`。记录文件数与总行数。

### Step 2: 三查并输出发现表

对每个发现输出：

| # | 位置 | 类型 | 严重度 | 证据 | 建议动作 |
|---|------|------|--------|------|---------|
| 1 | `memories/repo/foo.md` | 矛盾 | 🔴 | 与 bar.md 结论相反 | 以最新为准，标 superseded |

严重度：🔴 会误导 agent（矛盾）/ 🟡 浪费 token（冗余）/ 🟢 规范问题（合规）。

### Step 3: 呈现摘要并等待裁决

```
📋 Memory Review: 发现 <N> 项
   🔴 矛盾 <n> | 🟡 冗余 <n> | 🟢 合规 <n>
建议: [修复全部] [逐项处理] [跳过]
```

### Step 4: 修复（经用户确认后）

- 矛盾：更新旧条目 + 标 `superseded`
- 冗余：合并 / 删除重复条目
- 合规：补 Source、拆大文件、迁移 scope

## Gotchas

- **不要**只报告矛盾而不当场修复——旧结论会持续误导后续会话；发现矛盾即更新旧条目并标 `superseded`。
- **不要**自动删除仍可能有价值的条目——用 `superseded` / 归档代替删除，给人留缓冲。
- **不要**把修复当作自动执行——每一步必须经用户逐项确认。
- 判断矛盾时**不要**靠猜——用实现验证（查 `node_modules` 实际类型、跑命令实测）。
- 单次最多 **20 项**，避免淹没用户。
- 安全：不写入凭证 / PII / 绝对路径（遵守 security-constraints 约定）。
