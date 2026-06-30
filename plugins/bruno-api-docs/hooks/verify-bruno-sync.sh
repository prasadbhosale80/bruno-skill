#!/usr/bin/env bash
# Stop hook: block session end when API routes changed (any framework) but the
# Bruno collection was not updated in the same session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SKILL_PATH="$SCRIPT_DIR/../skills/bruno-api-docs-skill/SKILL.md"
[[ -f "$SKILL_PATH" ]] && SKILL_PATH="$(cd "$(dirname "$SKILL_PATH")" && pwd)/SKILL.md"

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Avoid infinite Stop loops (Claude Code caps consecutive blocks, but be safe).
if [[ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  exit 0
fi

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

COLLECTION_DIR="$(detect_collection_dir)"

# Which source files changed routes this session (excluding the collection itself)?
changed_files=""
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  [[ "$f" == "$COLLECTION_DIR"/* ]] && continue
  if file_has_route_change "$f"; then
    changed_files="${changed_files}- ${f}"$'\n'
  fi
done < <(changed_source_files)

[[ -n "$changed_files" ]] || exit 0

# Routes changed. If the collection was also touched, assume the agent synced it.
if collection_touched "$COLLECTION_DIR"; then
  exit 0
fi

if collection_found; then
  next_step="Update the Bruno collection under ${COLLECTION_DIR}/ now:
- CREATED endpoint → add a .bru (meta, method, {{baseUrl}} URL, params, body, tests/assert, docs)
- UPDATED endpoint → edit the existing .bru (URL, method, body, tests, docs) — no duplicates
- DELETED endpoint → remove the .bru and clean dead chaining vars"
else
  next_step="This repo has no Bruno collection yet. ASK THE USER (AskUserQuestion) whether to
create it as \"${DEFAULT_COLLECTION_DIR}/\" or a different folder name, then scaffold it:
- create the folder with a bruno.json manifest
- add a .bru per changed endpoint (meta, method, {{baseUrl}} URL, params, body, tests, docs)"
fi

reason=$(cat <<EOF
Bruno collection is out of sync with API route changes.

Source files with endpoint changes this session:
$(echo "$changed_files" | sed '/^$/d')

No matching .bru / bruno.json changes were found under ${COLLECTION_DIR}/.

${next_step}

Reference the "bruno-api-docs-skill" skill (also at ${SKILL_PATH}) for .bru syntax.
Rules: {{baseUrl}} only (no hardcoded hosts), secrets in vars:secret, bru.* not pm.*,
one .bru per endpoint, kebab-case filenames. Then end the turn again.
EOF
)

jq -n --arg reason "$reason" '{
  "decision": "block",
  "reason": $reason
}'
