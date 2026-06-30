# Bruno API Docs — Claude Code Plugin

A Claude Code **plugin** that teaches the agent to read, write, and maintain [Bruno](https://www.usebruno.com) API testing collections — and keeps that collection **in sync with your API routes automatically**, in any language or framework.

It bundles three things:

1. **`bruno-api-docs-skill`** — the full bru-lang reference (condensed from the official Bruno docs) so the agent writes valid `.bru` files on the first try instead of guessing Postman-style `pm.*` syntax.
2. **Sync hooks** — a `PostToolUse` hook that nudges the agent the moment an API route changes, and a `Stop` hook that blocks the turn from ending if routes changed but the collection wasn't updated.
3. **A drop-in `CLAUDE.md` rule** you can append to any repo to make the sync mandatory.

The route detection is **framework-agnostic**: FastAPI, Flask, Django, Express, NestJS, Fastify, Spring, Go (gin/echo/chi), Rails, Laravel, Rust (axum/actix), ASP.NET, and more.

---

## Install (Claude Code)

From any Claude Code session:

```text
/plugin marketplace add prasadbhosale80/bruno-skill
/plugin install bruno-api-docs@bruno-skill
```

That's it — the marketplace is this GitHub repo, and the plugin pulls in the skill and the hooks. Start a new session (or it loads immediately) and confirm with `/plugin` → Manage.

> Prefer the CLI? The same works headless:
> ```bash
> claude plugin marketplace add prasadbhosale80/bruno-skill
> claude plugin install bruno-api-docs@bruno-skill
> ```

### Make the sync a hard rule in a repo (optional but recommended)

The hooks already enforce sync. To also bake the rule into a project's instructions, append the bundled `CLAUDE.md` block to that repo's `CLAUDE.md`:

```bash
curl -fsSL https://raw.githubusercontent.com/prasadbhosale80/bruno-skill/main/CLAUDE.md >> CLAUDE.md
```

---

## How the sync works

```
        you edit a route handler                 you finish your turn
                 │                                        │
        PostToolUse hook                              Stop hook
   detect-endpoint-change.sh                     verify-bruno-sync.sh
                 │                                        │
   "route changed in X →                  routes changed but no .bru touched?
    update the collection"                 → BLOCK with what to fix
                 ▼                                        ▼
   agent updates the .bru in the same change, then the turn ends clean
```

- **Collection auto-detection** — the hooks find your collection by locating the folder that contains `bruno.json` or `collection.bru`. No path to configure.
- **No collection yet?** The hook tells the agent to **ask you** whether to create it as `bruno-collection/` or under a name you choose, then scaffold it with a `bruno.json` manifest.
- **Precision over noise** — the patterns match real route declarations (`@router.get(...)`, `r.GET(...)`, `Route::get(...)`, `path(...)`, `.route(...)`, …) and deliberately ignore everyday calls like `dict.get()` or `logger.info()`.

---

## What the skill covers

- Full `.bru` anatomy — `meta`, methods, `params`, `headers`, all body types, `auth`, `tests`, `assert`, `docs`
- Complete scripting API — `req.*`, `res.*`, `bru.*`: runtime/env vars, chaining, `sendRequest`, `runRequest`
- Chai test patterns + the no-code `assert {}` operator set
- Variables system & precedence, interpolation, dynamic (Faker.js) variables
- Bruno CLI — run, filter by tag, reporters, sandbox modes, GitHub Actions
- GraphQL (queries, mutations, subscriptions, Query Builder) and WebSocket
- Recipes — request chaining, data-driven testing, polling, token refresh
- Secrets management, OpenAPI / Postman / Insomnia import
- Hard rules for agents (never `pm.*`, secrets only in `vars:secret`, `~` to disable, …)

## Usage

Once installed it triggers automatically on Bruno-related work, or when you change API routes. Example prompts:

- *"Scaffold a Bruno collection for the routes in `src/routes/`."*
- *"Add a happy-path and a 404 test to `users/get-user.bru`."*
- *"Write a request-chaining flow: login, then create an order using the returned token."*
- *"Convert this Postman collection to Bruno."*

---

## Repo structure

```
.
├── .claude-plugin/
│   └── marketplace.json                  ← marketplace catalog (this repo)
├── plugins/
│   └── bruno-api-docs/
│       ├── .claude-plugin/
│       │   └── plugin.json               ← plugin manifest
│       ├── skills/
│       │   └── bruno-api-docs-skill/
│       │       └── SKILL.md              ← the bru-lang reference skill
│       └── hooks/
│           ├── hooks.json                ← PostToolUse + Stop hook config
│           ├── lib.sh                    ← collection auto-detect + route detection
│           ├── detect-endpoint-change.sh ← PostToolUse nudge
│           └── verify-bruno-sync.sh      ← Stop guard (blocks on drift)
├── CLAUDE.md                             ← drop-in sync rule (append to your repo)
├── README.md
└── LICENSE
```

## Use the skill in other agents (Cursor, Codex, manual)

`SKILL.md` is an open format. To use it without the plugin system, copy just the skill folder:

```bash
git clone https://github.com/prasadbhosale80/bruno-skill.git

# Claude Code / Claude Desktop — personal, all projects:
cp -r bruno-skill/plugins/bruno-api-docs/skills/bruno-api-docs-skill ~/.claude/skills/

# or project-scoped:
mkdir -p .claude/skills && cp -r bruno-skill/plugins/bruno-api-docs/skills/bruno-api-docs-skill .claude/skills/

# Cursor:
mkdir -p .cursor/skills && cp -r bruno-skill/plugins/bruno-api-docs/skills/bruno-api-docs-skill .cursor/skills/
```

(The hooks are a Claude Code feature; other agents get the skill only.)

---

## Customizing route detection

The detection regexes live in [`plugins/bruno-api-docs/hooks/lib.sh`](plugins/bruno-api-docs/hooks/lib.sh) under `route_regex()`. To add a framework or naming convention your team uses (e.g. a custom router variable name for lowercase-verb routers), add an alternative there. The known lowercase-verb router vars are intentionally a fixed set (`app`, `router`, `api`, …) to avoid false positives from `dict.get()`-style calls.

## Credits & license

Reference content compiled from the official Bruno documentation (<https://docs.usebruno.com>), an MIT-licensed open-source project. Released under the MIT License — see [`LICENSE`](LICENSE).
