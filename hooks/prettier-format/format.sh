#!/bin/bash
set -e

# Check if we are in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Not in a git repository. Skipping formatting."
  exit 0
fi

# Check for prettier or npx
if ! command -v prettier >/dev/null 2>&1 && ! command -v npx >/dev/null 2>&1; then
  echo "Prettier/npx not found. Skipping formatting."
  exit 0
fi

echo "Running Prettier on modified files..."

# Use git diff to find modified files (staged and unstaged) relative to HEAD
# -z handles filenames with spaces
# --diff-filter=ACM excludes deleted files
# --name-only lists filenames
# pipe to xargs -0 to handle null-terminated strings
# prettier --write modifies files in place
# --ignore-unknown skips files prettier doesn't support

if command -v npx >/dev/null 2>&1 && [ -f "package.json" ]; then
  git diff --name-only --diff-filter=ACM -z HEAD | xargs -0 npx prettier --write --ignore-unknown
else
  if command -v prettier >/dev/null 2>&1; then
    git diff --name-only --diff-filter=ACM -z HEAD | xargs -0 prettier --write --ignore-unknown
  else
    echo "Prettier not found locally or globally. Skipping."
  fi
fi

echo "Formatting complete."
