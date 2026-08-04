---
description: "跨会话 Wiki 上下文感知 — 通过 $LLM_WIKI_PATH 定位 Wiki，状态按需从事实源派生"
applyTo: "**"
---

# Wiki 跨会话上下文

## 定位与指针

- Wiki 数据仓库通过环境变量 `$LLM_WIKI_PATH` 定位。
- **完整操作历史**：`$LLM_WIKI_PATH/wiki/activity.md`（git 追踪，唯一的人类可读历史档案）。
- **审计日志**：`$LLM_WIKI_PATH/wiki/log.md`（JSON Lines）。
- **索引**：`$LLM_WIKI_PATH/wiki/index.md`（页面目录 + freshness 策略）。

> 不再维护 user memory 热缓存（`wiki-activity.md` 已移除）。原因：易变状态放入稀缺的常驻预算会产生漂移，且实证不驱动 agent 行为；状态一律从事实源按需派生。

## 按需派生状态（当用户询问 Wiki 或执行 wiki 操作时）

不要信任二手缓存，直接从事实源派生：

1. **最近更新**：读取 `$LLM_WIKI_PATH/wiki/log.md` 尾部（最近若干条 JSON Lines）。
2. **待审核**：`ls $LLM_WIKI_PATH/questions_pending/` 计数。
3. **Lint 问题**：`ls $LLM_WIKI_PATH/lint_pending/` 计数。
4. **上次会话**：`$LLM_WIKI_PATH/wiki/activity.md` 顶部最新条目。

## 向用户提示

当用户询问 Wiki 状态或开始 wiki 相关任务时，可简短提示：

```
📚 Wiki 状态：
- 最近更新了 X 个页面
- Y 条知识待审核
- Z 个 lint 问题待处理
```

不强制交互，仅在被询问或任务相关时提供。不主动打断无关会话。

## 写回路径（wiki 操作后）

- **`$LLM_WIKI_PATH/wiki/log.md`**（JSON Lines）— `/wiki-capture`、`/wiki-ingest`、`/wiki-review`、`/wiki-lint`、`/wiki-sync` 每次操作的完整记录。
- **`$LLM_WIKI_PATH/wiki/activity.md`** — 追加 1 条完整人类可读记录。
- user memory 不写入任何 wiki 状态。
