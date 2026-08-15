---
name: wiki-sync
description: '将 LLM Wiki 同步到远程 Git——在用户明确确认后提交 wiki 变更并推送到 origin/main（单人简化）。任何被删除的 wiki 页面恢复为 stale 而非物理删除。当用户要求 "sync wiki"、"push wiki changes" 时使用。'
argument-hint: "[--dry-run]"
---

# Wiki Sync — 同步到远程

单人直接同步：提交 wiki 变更并推送到 `origin/main`。无功能分支、无冲突机制。

## 何时使用本技能

- 用户要求 "sync wiki"、"push wiki changes"，或提交 llm-wiki 仓库
- 在 `/wiki-capture` / `/wiki-review` / `/wiki-ingest` 产生需要到达远程的本地变更之后

## 前置条件

- 通过 `$LLM_WIKI_PATH` 可访问 llm-wiki 仓库。
- 若未配置远程，仅本地提交并跳过推送。

## 工作流

### Step 1: 检测变更

```bash
cd "$LLM_WIKI_PATH" && git status --short
```

对变更分类：

| Git 状态 | 动作 |
|-----------|--------|
| `A` | 新页面——原样提交 |
| `M` | 已修改——提交变更 |
| `D` | 删除的 wiki 页面——**绝不物理删除**：从 HEAD 恢复（`git checkout HEAD -- <file>`），设置 frontmatter `status: stale`、`stale_reasons: ["source_deleted"]`，然后提交 |
| `R` | 重命名——移动文件 + 更新所有 `[[WikiLink]]` 引用 |

### Step 2: 推送前确认

展示 Step 1 的分类变更摘要（加上 `git diff --stat`）并请求明确确认：

```
📦 同步预览：<a> 新增，<m> 修改，<d> 恢复为 stale
推送到 origin/main？[y/n]
```

推送到远程是高影响动作——未经此确认绝不推送；默认拒绝。

### Step 3: 提交并推送

```bash
git add wiki/ raw/ questions_pending/ questions_approved/ lint_pending/ rejected/
git commit -m "wiki: <N> pages changed (added=<a>, modified=<m>, stale=<d>)"
git push origin main
```

### Step 4: 更新 last_commit

将 `wiki/index.md` frontmatter 的 `last_commit` 更新为新 HEAD SHA，然后提交并推送。

### Step 5: 记录日志

向 `wiki/log.md` 追加同步记录（JSON Lines）。

## 注意事项（Gotchas）

- **未经明确确认绝不推送**——推送是高影响动作；默认拒绝。
- **绝不物理删除 wiki 页面**——git 状态中的 `D` 意味着从 HEAD 恢复并标记 `status: stale`，绝不 `git rm`。
- **先使用 `--dry-run`**——在提交任何内容前报告变更。
- 若未配置远程，仅本地提交并跳过推送——不要让同步失败。

## 选项

- `--dry-run`：报告检测到的变更，不提交。
