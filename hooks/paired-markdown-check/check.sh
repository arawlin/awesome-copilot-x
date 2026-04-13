#!/usr/bin/env bash
# Validate that managed Markdown files are updated together with their bilingual sibling.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not in a git repository. Skipping bilingual Markdown check."
  exit 0
fi

changed_files=()
managed_files=()
failures=()

contains_file() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

add_unique_file() {
  local file="$1"
  if [[ -z "$file" ]]; then
    return 0
  fi
  if ! contains_file "$file" "${changed_files[@]:-}"; then
    changed_files+=("$file")
  fi
}

is_managed_markdown() {
  local path="$1"

  if [[ "$path" != *.md ]]; then
    return 1
  fi

  if [[ "$path" != */* ]]; then
    return 0
  fi

  if [[ "$path" == plan/*.md ]]; then
    return 0
  fi

  if [[ "$path" == .github/* ]]; then
    return 1
  fi

  if [[ "$path" =~ ^docs/.+\.md$ ]]; then
    return 0
  fi

  return 1
}

counterpart_for() {
  local path="$1"
  if [[ "$path" == *-zh.md ]]; then
    echo "${path%-zh.md}.md"
  else
    echo "${path%.md}-zh.md"
  fi
}

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    add_unique_file "$file"
  done < <(git diff --name-only -z --diff-filter=ACMRTUXB HEAD --)
else
  while IFS= read -r -d '' file; do
    add_unique_file "$file"
  done < <(git diff --name-only -z --cached --diff-filter=ACMRTUXB --)

  while IFS= read -r -d '' file; do
    add_unique_file "$file"
  done < <(git diff --name-only -z --diff-filter=ACMRTUXB --)
fi

while IFS= read -r -d '' file; do
  add_unique_file "$file"
done < <(git ls-files --others --exclude-standard -z)

for file in "${changed_files[@]:-}"; do
  if is_managed_markdown "$file"; then
    managed_files+=("$file")
  fi
done

if [[ ${#managed_files[@]} -eq 0 ]]; then
  echo "No managed Markdown changes detected."
  exit 0
fi

for file in "${managed_files[@]}"; do
  counterpart=$(counterpart_for "$file")

  if [[ ! -e "$counterpart" ]] && ! contains_file "$counterpart" "${changed_files[@]:-}"; then
    failures+=("Missing bilingual sibling: $file -> $counterpart")
    continue
  fi

  if ! contains_file "$counterpart" "${managed_files[@]}"; then
    failures+=("Updated without paired sibling change: $file -> $counterpart")
  fi
done

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "Bilingual Markdown check failed:"
  for failure in "${failures[@]}"; do
    echo "- $failure"
  done
  echo "Update the English and -zh Markdown files in the same change."
  exit 2
fi

echo "Bilingual Markdown check passed."