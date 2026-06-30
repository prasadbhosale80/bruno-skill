#!/usr/bin/env bash
# PostToolUse hook: when an edit changes an API route (any framework), nudge the
# agent to sync the Bruno collection in the same change. Non-blocking.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SKILL_PATH="$SCRIPT_DIR/../skills/bruno-api-docs-skill/SKILL.md"
[[ -f "$SKILL_PATH" ]] && SKILL_PATH="$(cd "$(dirname "$SKILL_PATH")" && pwd)/SKILL.md"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Collect candidate files to inspect from the tool input.
candidates=()
case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit)
    fp=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    [[ -n "$fp" ]] && candidates+=("$(rel_path "$fp")")
    ;;
  Bash)
    cmd=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    # Pull file-looking tokens out of the command (sed/mv/rm/cp on source files).
    while IFS= read -r tok; do
      [[ -n "$tok" ]] && candidates+=("$(rel_path "$tok")")
    done < <(echo "$cmd" | grep -oE '[A-Za-z0-9_./-]+' | grep -E "$SRC_EXT_RE" | sort -u)
    ;;
  *)
    exit 0
    ;;
esac

[[ ${#candidates[@]} -gt 0 ]] || exit 0

COLLECTION_DIR="$(detect_collection_dir)"

changed=""
delta_hint=""
for rel in "${candidates[@]}"; do
  is_source_path "$rel" || continue
  # Don't nudge for edits inside the collection itself.
  [[ "$rel" == "$COLLECTION_DIR"/* ]] && continue
  if file_has_route_change "$rel"; then
    changed="${changed}- ${rel}"$'\n'
    d="$(git_route_delta "$rel" 2>/dev/null || true)"
    [[ -n "$d" ]] && delta_hint="${delta_hint}${rel}:"$'\n'"${d}"$'\n'
  fi
done

[[ -n "$changed" ]] || exit 0

if collection_found; then
  collection_line="Bruno collection root (auto-detected): ${COLLECTION_DIR}/"
else
  collection_line="No Bruno collection found in this repo yet. Before creating .bru files,
ASK THE USER (use the AskUserQuestion tool) whether to create the collection as
\"${DEFAULT_COLLECTION_DIR}/\" or under a different folder name. Then create that
folder with a bruno.json manifest and put the .bru files there."
fi

context=$(cat <<EOF
BRUNO COLLECTION SYNC REQUIRED — do it in THIS change, not as a follow-up.

API route definitions changed in:
${changed}
${collection_line}
Bru-lang reference: the "bruno-api-docs-skill" skill (also at ${SKILL_PATH})

Actions by change type:
- ENDPOINT CREATED  → add a .bru under the matching resource folder: meta (name/type/seq),
  method block with {{baseUrl}} URL, params:path/query, headers, body matching the real
  payload, at least one happy-path + one error test/assert, and a docs {} block.
- ENDPOINT UPDATED  → edit the existing .bru (never duplicate); refresh URL/method/body and
  update tests/assertions + jsonSchema so they actually exercise the new contract.
- ENDPOINT DELETED  → remove the .bru; drop dead chaining vars; renumber seq if needed.

Rules: one .bru per endpoint, kebab-case filenames, {{baseUrl}} only (no hardcoded hosts),
secrets in vars:secret, preserve bru.setVar() chains, use bru.* / req.* / res.* (never pm.*).
EOF
)

if [[ -n "$delta_hint" ]]; then
  context="${context}

Detected route diff hints:
${delta_hint}"
fi

jq -n --arg ctx "$context" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": $ctx
  }
}'
