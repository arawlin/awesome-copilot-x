---
description: '写 commit message、建议提交内容或收尾播报变更时使用。覆盖 Conventional Commits 与 why-first body'
applyTo: '**'
---

# Git 提交规范

> 约定式提交（Conventional Commits）。

## 格式

`<type>(<scope>): <subject>`

- **type**：`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` /
  `build` / `ci` / `chore` / `revert`
- **scope**：模块或组件名（可选），如 `auth`, `api`, `ui`, `config`
- **subject**：祈使语气（`add` 而非 `added`），首字母小写，末尾不加句号，
  ≤72 字符；固定英文

## 结构（why-first）

diff 已展示 what，body 只回答 why。

- **body**：与 subject 空一行；写改动前的问题、为何选此方案、放弃过哪些替代方案；
  subject 已自解释时省略
- **footer**：与前文空一行；`Closes #123` / `Refs #789` 引 issue，
  `BREAKING CHANGE: <说明>` 标破坏性变更；无内容则省略

```text
fix(auth): prevent token refresh loop on expired sessions

Session expiry mid-request triggered a token refresh that itself failed
validation and triggered another refresh, looping until the app crashed.
A guard flag now aborts the cycle when a refresh is already in flight and
returns a clean 401 instead.

Closes #312
```

## 拆分

- 不同文件、互不相关的目的 → 拆多条
- 同一文件但两个独立关注点（如修复 + 重构）→ 建议拆
- 拆开后无法单独成立 → 合为一条
- 输出多条建议时，逐条标注包含的文件或范围

## 执行约束（提交动作）

- **禁止自动提交**：不得在任务收尾自动执行 `git commit` / `git push`，
  也不得未经请求先 `git add`
- 收尾时工作树仍有未提交改动 → 主动给出变更摘要 + 建议 message
  （可复制代码块）；同一批改动不重复播报
- 仅当当次请求明确要求提交（"提交"、"帮我 commit"）才执行；
  执行前先展示要点与该 message，等用户手动确认
