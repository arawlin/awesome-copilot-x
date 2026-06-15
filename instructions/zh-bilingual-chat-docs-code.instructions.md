---
description: 'Chinese conversation rules, English-only code comments, and synchronized bilingual documentation policy (-zh)'
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
- Collect all IPA transcriptions and place them at the very end of the response in a `参考` (Reference) section, formatted as a bullet list:

  ```
  ---
  **参考（发音）**：
  - circuit breaker /ˈsɜːrkɪt ˈbreɪkər/
  - reverse /rɪˈvɜːrs/
  ```

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

## Documentation Policy (Bilingual with synchronized -zh)

- Default documentation is written in English.
- For every documentation file created or updated, also create/update a sibling Chinese file with the `-zh` suffix before the extension.
  - Examples: `README.md` → `README-zh.md`, `api-guide.md` → `api-guide-zh.md`.
- Keep the English and Chinese documents synchronized:
  - Any change to the English file MUST be mirrored in the `-zh` file in the same structure (sections, headings, lists, code blocks).
  - If a section is added/removed/modified in English, apply the same structural change to the `-zh` file and translate the content accordingly.
  - If content is intentionally different across languages (rare), clearly mark the divergence at the top of the differing section in both files with a short note.
- Place language-switch links at the top of both files:
  - English file: `This document is also available in [Chinese](./<name>-zh.md).`
  - Chinese file: `本文档亦提供[英文版](./<name>.md)。`
- Do not include IPA or abbreviation expansions within documentation unless they are technically relevant to the document content. The IPA rule applies only to chat responses.

## File Naming and Placement

- Keep bilingual files side-by-side in the same directory to simplify maintenance.
- Use hyphenated lowercase for new doc filenames, except conventional names like `README.md`.

## Validation Checklist

- Conversation in Chinese → reply in Chinese.
- Technical terms → Chinese-first, English equivalent in parentheses on first use; abbreviations expanded to full form.
- IPA → only for low-frequency words; collected at end of response in a `参考（发音）` section; never inline.
- Code changes → all comments are in English.
- Docs → English default + synchronized `-zh` file created/updated, with language-switch links.
