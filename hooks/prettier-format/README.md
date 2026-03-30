---
name: 'Prettier Format'
description: 'Automatically formats modified files using Prettier when a session ends'
tags: ['formatting', 'prettier', 'code-style']
---

# Prettier Format Hook

Automatically formats files modified during a GitHub Copilot session using Prettier, ensuring code style consistency.

## Overview

This hook runs at the end of each Copilot session and:

1. Identifies files modified during the session (unstaged and staged changes).
2. Runs `prettier --write` on these files.
3. Uses the project's existing `.prettierrc` configuration.

## Features

- **Automatic Formatting**: Keeps code clean without manual intervention.
- **Project Config**: Respects your existing `.prettierrc` and `.prettierignore`.
- **Smart Detection**: Only formats files that have been modified.

## Installation

1. Copy this hook folder to your repository's `.github/hooks/` directory:

   ```bash
   cp -r hooks/prettier-format .github/hooks/
   ```

2. Ensure the script is executable:

   ```bash
   chmod +x .github/hooks/prettier-format/format.sh
   ```

3. Commit the hook configuration to your repository.

## Configuration

The hook is configured in `hooks.json` to run on the `sessionEnd` event:

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "bash": ".github/hooks/prettier-format/format.sh",
        "timeoutSec": 30
      }
    ]
  }
}
```

## Requirements

- **Prettier**: Must be installed in your project (`npm install --save-dev prettier`) or globally available.
- **Git**: Must be a git repository.

## Customization

You can modify `format.sh` to:

- Use a different formatter (e.g., `eslint --fix`).
- Change the file patterns to check.
