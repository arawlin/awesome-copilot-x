---
description: 'Git 提交规范 — Conventional Commits（约定式提交）格式与约束'
applyTo: '**'
---

# Git 提交规范

> 约定式提交（Conventional Commits）。生成 commit message 或提交说明时遵循此格式。

## 格式

`<type>(<scope>): <subject>`

- **type**：`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore` / `revert`
- **scope**：模块或组件名（可选），如 `auth`, `api`, `ui`, `config`
- **subject**：祈使语气（imperative mood），首字母小写，末尾不加句号；固定使用英文

## 示例

- `feat(auth): add OAuth2 login support`
- `fix(api): handle null response in user endpoint`
- `docs(readme): update installation steps`

## 关键约束

- subject 用 `add` 而非 `added`，用 `fix` 而非 `fixed`；始终英文。

## 执行约束（提交动作）

- **禁止自动提交**：不得在任务收尾自动执行 `git commit` / `git push`；也不得未经请求先 `git add` 再提交。
- 默认交付方式 = 呈现变更摘要 + 建议 commit message，由用户手动 review 并提交。
- 仅当用户在**当次请求中明确要求提交**（如"提交"、"帮我 commit"）时才代为执行；执行前先展示变更要点（`git status` / diff 摘要）与将要使用的 commit message。
- 提交动作需要用户**手动确认**是硬性要求，不因任务"看起来完成"而豁免。
