---
name: 'Memory Capture'
description: 'Extract reusable knowledge into memory — external sources and in-session findings, with scope selection and dedup rules. 通用 memory 提取准则'
applyTo: '**'
---

# Memory Capture — 提取准则

将可复用的知识提取到 memory，供跨会话召回。三档 scope：

| Scope | 路径 | 用途 |
|---|---|---|
| user | `/memories/` | 跨项目通用偏好/方法论（前 200 行自动加载，务必精炼） |
| repo | `/memories/repo/` | 当前代码库事实、约定、命令（按需读取） |
| session | `/memories/session/` | 本次会话临时状态（会话结束清除） |

## 触发信号

1. **外部来源**：使用 `fetch_webpage`、`mcp_context7_get-library-docs`、`github_repo`、`github_text_search` 后，发现新颖且可复用的结论。
2. **会话内产出**：验证过的结论、踩坑修复、架构决策、契约变更——尤其修复过 bug 或推翻过旧假设的。

## 过滤标准（满足 ≥2 才记）

- **易错**？违反会被坑 / 结论藏在文档深处
- **已验证**？亲手验证 / 实测 / 官方确认
- **高频**？未来会话大概率需要

满足 0-1 条 → 不记，留在 source 文档中。理由：memory 是精炼索引而非文档副本，冗余条目会稀释 agent 的信噪比。

## 优先级标记

- `⚠️`：breaking change、安全问题、版本级弃用/移除、数据丢失类 bug
- 无标记：非显而易见的 API 模式、gotcha、最佳实践、配置技巧、依赖约束

## 每会话上限

最多 **8 条**。超出的只保留最有影响力的，其余合并成一条概括。理由：防止单会话大量写入淹没 memory，宁可少而精。

## 条目格式（单行）

```markdown
- [YYYY-MM-DD] ⚠️ 结论。Source: <tool>: <params>
```

示例：

- [2026-06-24] `useOptimistic` requires reducer signature `(state, action) => newState`. Source: context7: /vercel/next.js, topic="useOptimistic", mode=code, page=1.
- [2026-06-24] ⚠️ React 19 removes `forwardRef` — ref is now a regular prop. Source: fetch_webpage: https://react.dev/blog/2024/12/05/react-19.
- [2026-08-01] ⚠️ 结论。Source: repo: new-bitres-web-server <上下文>

Source 必须可回查：

| 来源 | Source 格式 |
|---|---|
| `fetch_webpage` | `fetch_webpage: <url>` |
| `mcp_context7_get-library-docs` | `context7: <lib>, topic="...", mode=<code\|info>, page=<n>` |
| `github_repo` | `github_repo: <owner>/<repo>, query="..."` |
| `github_text_search` | `github_text_search: <scope>, query="..."` |
| 会话内产出 | `repo: <仓库> <上下文>` |

## Scope 选择

- 通用方法论 / 工具用法（跨项目）→ user memory
- 本仓库事实 / 约定 / 命令 → repo memory
- 大段、有争议或待确认内容 → 先写 **session memory** 或询问用户，不要直接写入持久 memory

## 文件组织规范（三档 scope 统一适用）

- **按主题分类**：一个文件一个主题；命名即主题（业务语义，如 `drizzle-orm.md`），不用来源/版本/时间命名。
- **分类决策**：问「这条知识在未来什么任务场景会被检索？」→ 那个领域即文件名。已有匹配主题文件 → 追加；不匹配 → 新建。
- **大小护栏**：文件 >4KB 或覆盖 >1 个主题 → 拆分；写入前先 `memory view` 找到对应主题文件。
- **反模式**：不建单一巨文件（如 `memory.md`）；不按来源（如 `context7.md`）或时间分类；同一条知识不跨文件复制——用「单一事实源 + 引用」。

## 去重

写入前先 `memory view` 检查对应文件：已有则跳过或合并；否则追加到文件末尾。
