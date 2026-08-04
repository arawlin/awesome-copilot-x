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
