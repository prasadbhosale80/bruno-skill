# Bruno Skill for Claude

An Agent Skill that teaches Claude — and any agent that supports the open `SKILL.md` format (Claude Code, Cursor, Codex CLI, Gemini CLI) — to read, write, and maintain [Bruno](https://www.usebruno.com) API testing collections.

It packages the full bru-lang reference (condensed from the official Bruno docs) so the agent produces valid `.bru` files on the first try instead of guessing Postman-style `pm.*` syntax. Ships with a drop-in `CLAUDE.md` rule that keeps your collection in sync whenever API endpoints change.

---

## Why

Bruno collections are plain-text `.bru` files committed next to your source — ideal for an AI agent to maintain, *if* it knows the bru-lang syntax and the `bru.* / req.* / res.*` scripting API cold. Without that, agents reach for Postman conventions, hardcode hosts and secrets, and write assertions that don't match the response shape. This skill closes that gap.

## What's included

| File | Purpose |
|------|---------|
| `bruno/SKILL.md` | The skill — complete bru-lang, scripting, CLI, GraphQL, WebSocket reference |
| `CLAUDE.md.patch.md` | Drop-in rule to auto-sync the collection on endpoint create / update / delete |

## What the skill covers

- Full `.bru` anatomy — `meta`, methods, `params`, `headers`, all body types, `auth`, `tests`, `assert`, `docs`
- Complete scripting API — `req.*`, `res.*`, `bru.*`: runtime/env vars, chaining, `sendRequest`, `runRequest`
- Chai test patterns + the no-code `assert {}` operator set
- Variables system & precedence, interpolation, dynamic (Faker.js) variables
- Bruno CLI — run, filter by tag, reporters, sandbox modes, GitHub Actions
- GraphQL (queries, mutations, subscriptions, Query Builder) and WebSocket
- Recipes — request chaining, data-driven testing, polling, token refresh
- Secrets management, OpenAPI / Postman / Insomnia import
- Hard rules for agents (never `pm.*`, secrets only in `vars:secret`, `~` to disable, etc.)

---

## Installation

> A skill is just a folder containing a `SKILL.md`. Keep this repo's `bruno/` folder intact and copy it into the right directory.

### Claude Code / Claude Desktop

```bash
git clone https://github.com/<you>/bruno-skill.git

# Personal — available across all projects:
cp -r bruno-skill/bruno ~/.claude/skills/

# OR project-scoped — commit it with the repo it tests:
mkdir -p .claude/skills && cp -r bruno-skill/bruno .claude/skills/
```

Start a new session — the skill is auto-detected from its `description`. Confirm with `/skills`.

### Claude.ai (Pro / Max / Team / Enterprise)

Zip the skill folder and upload it under **Settings → Features** (code execution must be enabled; skills are per-user).

```bash
cd bruno && zip -r ../bruno-skill.zip . && cd ..
```

### Cursor / other agents

The `SKILL.md` format is an open standard. For Cursor, drop it in the project skills folder:

```bash
mkdir -p .cursor/skills && cp -r bruno-skill/bruno .cursor/skills/
```

---

## Usage

Once installed it triggers automatically on Bruno-related work. Example prompts:

- *"Scaffold a Bruno collection for the routes in `src/routes/`."*
- *"Add a happy-path and a 404 test to `users/get-user.bru`."*
- *"Write a request-chaining flow: login, then create an order using the returned token."*
- *"Convert this Postman collection to Bruno."*

## Keeping collections in sync

`CLAUDE.md.patch.md` is a rule block instructing the agent to update the matching `.bru` file in the **same change** whenever an endpoint is created, updated, or deleted — so the collection never drifts from the API. Append it to your repo's `CLAUDE.md`:

```bash
cat bruno-skill/CLAUDE.md.patch.md >> CLAUDE.md
```

Then edit the two paths it assumes — `bruno-collection/` (collection root) and `environments/local.bru` — to match your layout.

---

## Repo structure

```
.
├── README.md
├── CLAUDE.md
└── bruno-api-docs-skill/
    └── SKILL.md
```

## Credits & license

Reference content compiled from the official Bruno documentation (<https://docs.usebruno.com>), an MIT-licensed open-source project. Released under the MIT License — see `LICENSE`.
