#!/usr/bin/env bash
# Shared helpers for the Bruno collection sync hooks.
# Framework-agnostic: detects API route changes across Python, JS/TS, Go, Rust,
# Ruby, PHP, Java/Kotlin, C#, Elixir — and auto-detects the Bruno collection root.
#
# Sourced by detect-endpoint-change.sh and verify-bruno-sync.sh.

# --- source file extensions we treat as possible route definitions ---------
SRC_EXT_RE='\.(py|js|jsx|ts|tsx|mjs|cjs|go|rs|rb|php|java|kt|kts|scala|cs|ex|exs)$'

# Files that are also route/contract sources even without the extensions above.
SPEC_NAME_RE='(openapi|swagger)\.(ya?ml|json)$|\.graphql$|schema\.graphqls?$|routes\.rb$|urls\.py$'

# Directories never worth scanning for route changes.
IGNORE_DIR_RE='(^|/)(node_modules|vendor|dist|build|out|target|\.venv|venv|\.git|__pycache__|\.next|\.nuxt)/'

# --- route declaration patterns, one framework family per alternative -------
# Kept deliberately specific so everyday calls like dict.get()/logger.info()
# do NOT match. This is a heuristic guard, not a parser.
route_regex() {
  local p=()
  # Python/JS instance decorators: @app.get(  @router.post(  @bp.route(  @app.websocket(
  p+=('@[A-Za-z_][A-Za-z0-9_]*\.(get|post|put|patch|delete|head|options|websocket|route|api_route)[[:space:]]*\(')
  # Class/method decorators (NestJS, Spring, Micronaut, JAX-RS, Symfony):
  p+=('@(Get|Post|Put|Patch|Delete|Options|Head|All|Sse|GetMapping|PostMapping|PutMapping|PatchMapping|DeleteMapping|RequestMapping|GET|POST|PUT|PATCH|DELETE|Path|Route|Router)[[:space:]]*[({]')
  # Rust attribute macros (actix-web, rocket): #[get("/x")]  #[post(...)]
  p+=('#\[(get|post|put|patch|delete|head|options|route)[[:space:]]*\(')
  # Uppercase HTTP-verb method calls (Go gin/echo/chi/fiber): r.GET(  e.POST(  app.DELETE(
  p+=('[A-Za-z_][A-Za-z0-9_]*\.(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE)[[:space:]]*\(')
  # Lowercase verb calls on conventional router vars (Express/Koa/Fastify):
  p+=('(^|[^A-Za-z0-9_.])(app|router|api|apiRouter|route|routes|server|srv|http|group|grp|rg|mux|fastify|hono)\.(get|post|put|patch|delete|head|options|all|use)[[:space:]]*\(')
  # Laravel / PHP: Route::get(  Route::apiResource(
  p+=('Route::(get|post|put|patch|delete|options|any|match|resource|apiResource|group)[[:space:]]*\(')
  # Django URLConf + DRF: path(  re_path(  url(  router.register(
  p+=('(^|[^A-Za-z0-9_.])(path|re_path|url)[[:space:]]*\(|router\.register[[:space:]]*\(')
  # Rust router builders (axum/warp/tower): .route(  .nest(  .service(  web::resource(  web::scope(
  p+=('\.route[[:space:]]*\(|\.nest[[:space:]]*\(|\.service[[:space:]]*\(|web::(resource|scope)[[:space:]]*\(')
  # Registration / mounting helpers across stacks:
  p+=('include_router|register_blueprint|add_url_rule|add_api_route|add_route[[:space:]]*\(|HandleFunc[[:space:]]*\(|MapControllers|MapGet|MapPost|MapPut|MapDelete')
  # Ruby on Rails routes.rb DSL: get '...', resources :x, namespace :y, root
  p+=("(^|;|do[[:space:]])[[:space:]]*(get|post|put|patch|delete|resources?|namespace|scope|match|root|mount)[[:space:]]+[\"':]")
  ( IFS='|'; echo "${p[*]}" )
}

ROUTE_REGEX="$(route_regex)"

# is_source_path REL  -> 0 if the path is a route/contract source worth scanning
is_source_path() {
  local rel="$1"
  echo "$rel" | grep -qE "$IGNORE_DIR_RE" && return 1
  echo "$rel" | grep -qE "$SRC_EXT_RE" && return 0
  echo "$rel" | grep -qE "$SPEC_NAME_RE" && return 0
  return 1
}

# rel_path ABS  -> path relative to $PROJECT_DIR (or unchanged if outside)
rel_path() {
  local path="$1"
  if [[ "$path" == "$PROJECT_DIR"/* ]]; then
    echo "${path#"$PROJECT_DIR"/}"
  else
    echo "$path"
  fi
}

# Default name proposed when no collection exists yet.
DEFAULT_COLLECTION_DIR="bruno-collection"

# collection_marker -> path to a Bruno collection manifest (bruno.json or
# collection.bru), or empty if the repo has no collection yet.
collection_marker() {
  local marker=""
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    marker=$(
      {
        git ls-files 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null
      } | grep -iE '(^|/)(bruno\.json|collection\.bru)$' | head -n1
    )
  fi
  if [[ -z "$marker" ]]; then
    marker=$(
      find . \( -name node_modules -o -name .git -o -name vendor \) -prune -o \
        -type f \( -iname bruno.json -o -iname collection.bru \) -print 2>/dev/null \
        | sed 's|^\./||' | head -n1
    )
  fi
  echo "$marker"
}

# collection_found -> 0 if a Bruno collection already exists in the repo.
collection_found() {
  [[ -n "$(collection_marker)" ]]
}

# detect_collection_dir -> the Bruno collection root (folder holding the marker).
# Falls back to DEFAULT_COLLECTION_DIR when none exists yet.
detect_collection_dir() {
  local marker
  marker="$(collection_marker)"
  if [[ -n "$marker" ]]; then
    dirname "$marker"
  else
    echo "$DEFAULT_COLLECTION_DIR"
  fi
}

# git_route_delta FILE -> emits the added/removed route lines for a tracked file
git_route_delta() {
  local f="$1"
  {
    git diff -U0 HEAD -- "$f" 2>/dev/null || true
    git diff -U0 --cached -- "$f" 2>/dev/null || true
  } | grep -E '^[+-]' | grep -vE '^[+-]{3} ' | grep -E "$ROUTE_REGEX" || true
}

# file_has_route_change FILE -> 0 if FILE's working-tree state changes any route.
# Covers modified (diff), deleted (removed route lines in diff), and new
# untracked files (grep), so callers don't special-case each.
file_has_route_change() {
  local f="$1"
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    [[ -n "$(git_route_delta "$f")" ]] && return 0
    # untracked / brand-new file: not part of `git diff HEAD`, so grep it
    if [[ -f "$f" ]] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      grep -qE "$ROUTE_REGEX" "$f" 2>/dev/null && return 0
    fi
    return 1
  fi
  # No git: best-effort — treat presence of a route line as a change
  [[ -f "$f" ]] && grep -qE "$ROUTE_REGEX" "$f" 2>/dev/null && return 0
  return 1
}

# changed_source_files -> working-tree source files (staged+unstaged+untracked+deleted)
changed_source_files() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  {
    git diff --name-only HEAD 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u | while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    is_source_path "$f" && echo "$f"
  done
}

# collection_touched COLLECTION_DIR -> 0 if any .bru/bruno.json under it changed
collection_touched() {
  local dir="$1"
  command -v git >/dev/null 2>&1 || return 1
  git rev-parse --git-dir >/dev/null 2>&1 || return 1
  local hits
  hits=$(
    {
      git diff --name-only HEAD -- "$dir" 2>/dev/null || true
      git diff --cached --name-only -- "$dir" 2>/dev/null || true
      git ls-files --others --exclude-standard -- "$dir" 2>/dev/null || true
    } | grep -E '\.bru$|/bruno\.json$' || true
  )
  [[ -n "$hits" ]]
}
