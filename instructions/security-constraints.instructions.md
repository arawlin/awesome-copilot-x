---
description: '安全约束 — commit 到 git 的内容不得含绝对路径、凭证、PII、内网地址、DB 连接串'
applyTo: '**'
---

# 安全约束（Git 提交内容）

> 全局约束，适用于所有仓库。写入任何要 commit 到 git 的文件内容时遵循。

## 核心规则

**不得出现以下敏感信息：**

- **绝对路径**（如 `/Users/xxx/...`、`/home/xxx/...`、`C:\Users\xxx\...`）
- **密码、密钥、token**（API key、SSH key、access token、refresh token 等）
- **个人身份信息**（用户名、邮箱、手机号、身份证号等，除非是公开的 git author 信息）
- **内部网络地址**（内网 IP、内部域名、内部服务地址）
- **数据库连接串**（含密码的 DSN）

## 替代方案

- **绝对路径** → 用占位符代替，如 `<repo-root>`、`<llm-wiki-root>`、`<docs-workspace-root>`；真实路径映射存于本地 memory（`/memories/repo/`），不进入 git。
- **密码/密钥** → 引用环境变量名（如 `$DB_PASSWORD`）或 secrets 管理器路径，不写明文。
- **个人信息** → 用角色代称（如「用户」、「管理员」）。

## 适用范围

- ✅ 源代码文件（含注释）
- ✅ 文档文件（.md、.txt、.rst）
- ✅ 配置文件（.yml、.json、.toml、.env 示例可用占位符）
- ✅ Spike 文档、ADR、设计文档
- ✅ Commit message
- ✅ PR 描述
- ❌ 不适用：本地 memory 文件（`/memories/` 本身不进 git，可存真实路径映射）

## 验证流程

在 commit 前自查：
1. `grep -rn "/Users/" <要提交的文件>` 确认无绝对路径
2. `grep -rnE "(password|secret|token|api[_-]?key)\s*[:=]" <要提交的文件>` 确认无明文凭证
3. 如发现违反，立即用占位符替换并重新验证

## 例外

- 公开的 git author name/email 不受此约束（这些本就随 commit 公开）
- 文档中引用的第三方公开路径（如 `https://github.com/...`）不受此约束
