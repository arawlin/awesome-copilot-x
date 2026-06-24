---
description: 'Chinese conversation rules, English-only code comments, and Chinese-primary documentation policy'
applyTo: '**'
---

# Chinese Conversation + English Code Comments + Bilingual Docs

This instruction enforces three policies across conversations, code generation, and documentation output.

## Conversation Policy (Chinese-first)

- When the user converses in Chinese, respond in Chinese.
- In the response text (chat replies only, not files):

### Term display (Chinese-first with English reference)

- Use Chinese as the primary reading language. When a technical term first appears, show the English equivalent in parentheses after the Chinese term.
  - Full English terms: `断路器（circuit breaker）`
  - Abbreviations: expand to the full English form on first use, e.g., `CPU（Central Processing Unit）`
- Only annotate a term with its English equivalent on its first appearance within the same session; skip repeated annotations later.

### IPA placement (end-of-response reference section)

- Do **NOT** place IPA transcriptions inline within the response body.
- Collect all annotated terms and place them at the very end of the response in a `参考` (Reference) section.
- For each term, include: English term → IPA → Chinese meaning → etymology / word roots (brief only).
- Format as a bullet list with sub-bullets for etymology:

  ```
  ---
  **参考（发音）**：
  - circuit breaker /ˈsɜːrkɪt ˈbreɪkər/ 断路器
    - circuit：拉丁语 circuitus（环绕一圈）；breaker：古英语 brecan（打破）
  - algorithm /ˈælɡərɪðəm/ 算法
    - 词根：阿拉伯语 al-Khwarizmi（数学家花拉子米之名）
  ```

- Keep etymology concise — one line per term, only list key roots. Do NOT include historical evolution narratives.

### IPA scope (low-frequency words only)

- Only provide IPA for low-frequency or uncommon English words. **Skip IPA** for:
  - Common tech vocabulary (e.g., server, data, code, file, API, URL, HTTP, JSON, HTML, CSS, DNS, SSH)
  - Basic English words (e.g., use, make, get, set, run, call, check, build)
  - Abbreviations (only expand them — do not add IPA)

### Scope restriction

- These annotations (English equivalents and IPA) must only appear in the agent's chat response and MUST NOT be inserted into generated files (code, comments, or documentation).

## Code Generation Policy (English-only comments)

- When adding comments to code in any language, use English for all comments.
- Do not insert Chinese comments into source code.
- Keep comments concise, objective, and implementation-focused. Prefer imperative style (e.g., "Validate input", "Return early on error").

## Documentation Policy (Chinese-primary, Bilingual)

### New documents (no existing English file)

- When creating a brand-new documentation file, write it in **Chinese as the primary document**. Do NOT add a `-zh` suffix.
  - Example: creating a new guide → `api-guide.md` (Chinese content, no suffix).

### Existing English documents

- When an English documentation file already exists, create or update the Chinese translation with the `-zh` suffix before the extension.
  - Examples: existing `README.md` (English) → create `README-zh.md` (Chinese); existing `api-guide.md` (English) → create `api-guide-zh.md` (Chinese).

### Synchronization

- Keep the primary document and its translation synchronized:
  - Any change to the primary file MUST be mirrored in the translation file in the same structure (sections, headings, lists, code blocks).
  - If a section is added/removed/modified, apply the same structural change to the translation file and translate the content accordingly.
  - If content is intentionally different across languages (rare), clearly mark the divergence at the top of the differing section in both files with a short note.

### Language-switch links

- Place language-switch links at the top of both files:
  - Chinese primary file (no suffix or `-zh`): `本文档亦提供[英文版](./<name>.md)。` (the English original without suffix).
  - English primary file (no suffix): `This document is also available in [Chinese](./<name>-zh.md).`
- Do not include IPA or abbreviation expansions within documentation unless they are technically relevant to the document content. The IPA rule applies only to chat responses.

## File Naming and Placement

- Keep bilingual files side-by-side in the same directory to simplify maintenance.
- Use hyphenated lowercase for new doc filenames, except conventional names like `README.md`.
- Suffix conventions:
  - Chinese primary (new doc): no suffix (e.g., `guide.md`).
  - Chinese translation of existing English doc: `-zh` suffix (e.g., `guide-zh.md`).
  - English primary: no suffix (e.g., `guide.md`).

## Validation Checklist

- Conversation in Chinese → reply in Chinese.
- Technical terms → Chinese-first, English equivalent in parentheses on first use; abbreviations expanded to full form.
- IPA → only for low-frequency words; collected at end of response in a `参考（发音）` section with meaning + etymology; never inline.
- Code changes → all comments are in English.
- Docs → New docs: Chinese primary (no `-zh` suffix). Existing English docs: create/update `-zh` Chinese translation. Both sides synchronized with language-switch links.
