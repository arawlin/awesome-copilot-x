---
description: "跨会话 Wiki 上下文感知 — 会话启动时读取 wiki-activity.md 热缓存，提示用户 Wiki 最新状态"
applyTo: "**"
---

# Wiki 跨会话上下文

## 触发时机

每次新会话启动时，自动执行以下步骤。

## 步骤

### 1. 读取热缓存

读取 User Memory 文件 `/memories/wiki-activity.md` 的前 200 行。

### 2. 解析 Wiki 状态

从 `wiki-activity.md` 中提取：

- **最近更新**：最近 10 条 Wiki 页面变更
- **热缓存**：Top 5 高频实体/概念
- **待审核**：`questions_pending/` 中的待审核条目数量
- **Lint 问题**：`lint_pending/` 中的待处理问题数量
- **上次会话摘要**：最近一次会话的操作记录

### 3. 向用户提示

简短提示 Wiki 最新状态，格式如下：

```
📚 Wiki 状态：
- 最近更新了 X 个页面
- Y 条知识待审核
- Z 个 lint 问题待处理
```

不强制交互，仅被动提示。如用户询问 Wiki 相关问题，优先从 Wiki 热缓存中检索。

## 更新触发

以下操作后自动更新 `wiki-activity.md`：

- `/wiki-capture` — 知识提取后追加
- `/wiki-ingest` — 文档摄入后追加
- `/wiki-review` — 审核完成后更新待审核计数
- `/wiki-lint` — lint 完成后更新 lint 计数
