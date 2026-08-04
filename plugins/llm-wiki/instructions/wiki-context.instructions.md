---
description: "跨会话 Wiki 上下文感知 — 会话启动时读取 wiki-activity.md 热缓存，提示用户 Wiki 最新状态"
applyTo: "**"
---

# Wiki 跨会话上下文

## 触发时机

每次新会话启动时，自动执行以下步骤。

## 步骤

### 1. 读取热缓存

`/memories/wiki-activity.md` 属于 **user memory**，其内容（最近 5 条 + 待办摘要 + 上次会话）已随 user memory 前 200 行**合并预算**自动加载进上下文——**无需额外读取**。

> ⚠️ 注意：user memory 的 200 行是**全部文件汇总后的上限**（含 `## 文件名` 标题行），不是单文件 200 行。因此 `wiki-activity.md` 必须保持精简，否则字母序靠后的内容会被截断。

如需完整操作历史，读取 `$LLM_WIKI_PATH/wiki/activity.md`（git 追踪，不占用 user memory 预算）。

### 2. 解析 Wiki 状态

从已加载的 `wiki-activity.md` 中提取：

- **最近更新**：最近 5 条操作
- **待审核**：`questions_pending/` 待审核条目数量
- **Lint 问题**：`lint_pending/` 待处理问题数量
- **上次会话摘要**

### 3. 向用户提示

简短提示 Wiki 最新状态，格式如下：

```
📚 Wiki 状态：
- 最近更新了 X 个页面
- Y 条知识待审核
- Z 个 lint 问题待处理
```

不强制交互，仅被动提示。如用户询问 Wiki 相关问题，优先从 Wiki 热缓存中检索。

## 更新触发（写回路径）

- **`$LLM_WIKI_PATH/wiki/log.md`**（JSON Lines 审计日志）— `/wiki-capture`、`/wiki-ingest`、`/wiki-review`、`/wiki-lint`、`/wiki-sync` 每次操作的完整记录。
- **`$LLM_WIKI_PATH/wiki/activity.md`**（完整人类可读历史）— 追加 1 条完整操作记录。
- **`/memories/wiki-activity.md`**（user memory 精简热缓存）— 追加 1 条并**滚动保留最近 5 条**；详细历史不再写入 user memory。
