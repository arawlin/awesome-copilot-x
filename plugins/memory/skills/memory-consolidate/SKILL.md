---
name: memory-consolidate
description: 'Consolidate VS Code memory files — merge same-topic files, migrate wrong-scope entries, archive stale items, enforce size baselines, resolve superseded markers. Use after memory-review, or when asked to "consolidate memory", "merge memory files", "clean up memory", or "memory 合并/清理".'
argument-hint: "[plan|apply]"
---

# Memory Consolidate — 管理 / 合并

周期性维护 memory 文件：合并、迁移、归档、瘦身。通常由 `/memory-review` 的输出驱动。

## When to Use This Skill

- 用户要求合并 / 清理 / 瘦身 memory 文件
- `/memory-review` 产出了修复清单，需要执行
- 周期维护（如每月一次），或 repo memory 总量超基线（>30KB）

## 维护基线

| 项 | 基线 |
|---|---|
| 单文件 | ≤4KB / ≤120 行，单主题 |
| repo memory 总量 | ≤30KB |
| 文件命名 | 主题即文件名（如 `drizzle-orm.md`） |
| 更新策略 | 更新已有文件，不新建 |
| 条目生命周期 | >60 天且未被引用 → 归档候选 |

## 工作流

### Step 1: 加载 review 输出

优先复用 `/memory-review` 的问题清单；没有则先跑 review。

### Step 2: 按类型处理

- **合并**：同主题多文件 → 合并为一个，保留各自 Source 与日期；重复条目只留最新。
- **迁移**：通用方法论 → user memory；项目事实 → repo memory（用 `memory rename` 或重建）。
- **归档**：>60 天未引用且无 `⚠️` 标记的旧条目 → 删除或移入概括条目。
- **拆分**：超 4KB 且多主题 → 按主题拆文件。
- **superseded 清理**：标注 `superseded` 的条目保留 30 天后再删（给记忆留缓冲）。

### Step 3: 展示 diff 摘要

合并 / 删除前先展示影响：

```
📋 Consolidate 计划: 合并 <n> 文件 | 迁移 <n> 条 | 归档 <n> 条
预计: 51KB → 22KB
[应用] [调整]
```

### Step 4: 应用（经确认）

逐一执行；完成后 `memory view` 验证结构与大小符合基线。

## Gotchas

- **不要**合并不同主题的文件——宁可拆分；主题混在一起会显著提高后续查找成本。
- **不要**丢失 Source 与日期——破坏可追溯性，未来无法回查结论出处。
- **不要**在用户确认前执行合并 / 删除——每次操作前先展示 diff。
- **不要**机械套用「>60 天」归档规则——它是候选而非硬性；近期频繁引用的条目即使超期也应保留。
- `superseded` 条目保留 **30 天**缓冲后再清理，别急着删。
