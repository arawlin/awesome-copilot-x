---
name: memory-capture
description: Actively extract memory-worthy knowledge from the current conversation (or a selected range) and write it to the correct memory file per the memory-capture rules (filter → scope → topic file → dedup). Use when user asks to "review this session for memory", "extract memory entries", "capture what we learned", "盘点本会话/批量提取 memory". 规则单一事实源见 memory-capture.instructions.md；与 memory-review/consolidate 配合。
argument-hint: "[all|selection]"
---

# Memory Capture — 主动提取

主动盘点当前会话（或指定范围）的知识，按全局指令 `memory-capture.instructions.md`（applyTo: '**'，已注册进每次会话的指令上下文）的规则提取并写入对应 memory 文件。

> **规则单一事实源**：过滤标准、条目格式、scope 选择、文件组织规范均以 `memory-capture.instructions.md` 为准。本 skill 只执行流程，不复制规则，避免双源漂移。

## 触发场景

- 「回顾本会话，把值得记的提取成 memory」
- 「盘点这几次讨论的决策 / 踩坑」
- 「把这段分析存进 repo memory」（先选定范围再调用）

## 工作流

### Step 1: 明确范围

- `all`：整个当前会话
- `selection`：用户指定的讨论 / 范围（不确定时询问）

### Step 2: 列出候选知识点

回顾范围内对话，按全局指令 `memory-capture.instructions.md` 的**触发信号**列出候选：

- 验证过的结论、踩坑修复、架构决策、契约变更
- 外部来源（fetch / context7 / github）产生的新颖可复用结论

### Step 3: 应用过滤并归类

对每个候选，按全局指令 `memory-capture.instructions.md` 依次执行：

1. **过滤**：按指令的过滤标准判定是否可记
2. **scope**：按指令的 scope 选择规则归入 user / repo / session
3. **文件归属**：按指令的文件组织规范选择主题文件——已有匹配 → 追加；不匹配 → 新建
4. **查重**：`memory view` 对应文件，已有则跳过或合并

### Step 4: 呈现候选清单

```
📋 候选条目: <N> 条
| # | 条目（[日期] 结论） | 建议文件 | 过滤命中 |
|---|--------------------|---------|---------|
| 1 | ...                 | repo/drizzle-orm.md | 易错+已验证 |

[全部写入] [逐条选择] [跳过]
```

### Step 5: 写入（经确认）

按全局指令 `memory-capture.instructions.md` 的条目格式追加到对应文件末尾，遵守其每会话上限。

## 约束

- 写入前必须经用户确认（除非用户显式要求直接写）。
- 遵守全局指令 `memory-capture.instructions.md` 的每会话上限。
- 不复制全局指令的规则内容——按名字引用（该指令为全局注册，安装后路径不确定，不依赖相对路径），保持单一事实源。
- 与 `/memory-review`（事后查矛盾 / 冗余）和 `/memory-consolidate`（合并 / 归档）配合：capture 写入，review 把关，consolidate 维护。
