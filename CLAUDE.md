<!-- ▼ APPEND THIS SECTION TO YOUR CLAUDE.md ▼ -->

## Bruno Collection Sync (MANDATORY)

This repo ships a Bruno API collection (the folder containing `bruno.json` / `collection.bru` — auto-detected; default `bruno-collection/` if you haven't created one yet). It is the source of truth for API testing and must never drift from the actual API. **Whenever you create, modify, or remove an API endpoint — in any language or framework (FastAPI/Flask/Django, Express/NestJS, Spring, Go, Rails, Laravel, Rust, an OpenAPI spec, a GraphQL resolver, …) — update the Bruno collection in the same change, not as a follow-up.** A PR that touches endpoints but not the collection is incomplete.

If no collection exists yet, **ask the user** whether to create it as `bruno-collection/` or under a different folder name before scaffolding it (with a `bruno.json` manifest).

Follow the `bruno-api-docs-skill` skill for `.bru` syntax. The rules below define *when* and *what* to sync.

### Trigger → Action

**Endpoint CREATED** → add a new `.bru` file:
- Place it under the folder matching the resource (e.g. `users/`, `auth/`). Create the folder if missing.
- Include `meta` (`name`, `type: http|graphql`, next free `seq` in that folder), the method block with the URL using `{{baseUrl}}` (never a hardcoded host), `params:path`/`params:query`, `headers`, and the request body block matching the real payload schema.
- Add **at least one happy-path test and one error-case** (`tests {}` or `assert {}`) — e.g. `res.status: eq 200/201` plus a body-shape check. Use `jsonSchema` when the response schema is known.
- Add a `docs {}` block: one-line purpose, required params, auth scope, and notable error codes (400/401/404/409…).
- If the endpoint needs auth, reference the chain var (`Authorization: Bearer {{authToken}}`) rather than re-authenticating.

**Endpoint UPDATED** → edit the existing `.bru` file (do not create a duplicate):
- Path/route change → update the URL and `params:path`.
- Method change → swap the method block.
- Request/response shape change → update body block, `params`, and **adjust tests/assertions and `jsonSchema`** to match. Stale assertions that still pass are a bug.
- New required header/auth → add it; new optional field → add it disabled with `~`.
- Keep `meta.name` stable unless the resource is renamed (rename the file too).

**Endpoint DELETED** → remove the corresponding `.bru` file. Then:
- Remove any now-dead chaining vars or downstream requests that depended only on it.
- Renumber `seq` in the affected folder if a gap breaks intended run order.

### Cross-cutting rules
- **Mirror the structure**: one `.bru` per endpoint, folder per resource, filenames kebab-case (`get-user.bru`, `create-user.bru`).
- **Variables, not literals**: `{{baseUrl}}`, `{{access_token}}`, `{{userId}}`. New environment-specific values → add to every `environments/*.bru`; secrets → `vars:secret { }`, never plain `vars`, never the file.
- **Preserve chains**: if other requests read a var this endpoint sets via `bru.setVar()`, keep that contract intact when editing.
- **Tag for CI**: tag smoke-critical endpoints `smoke`; tag slow/integration ones so `bru run --exclude-tags` works.
- **Never use `pm.*`** — Bruno is `bru.*` / `req.*` / `res.*`.
- After syncing, sanity-check with `bru run --env local --bail` (or the relevant env) before considering the change done.

### Quick checklist before committing an endpoint change
- [ ] `.bru` file added / edited / deleted to match the code
- [ ] URL uses `{{baseUrl}}`; no hardcoded hosts or secrets
- [ ] `params`, `headers`, body reflect the real contract
- [ ] Tests/assertions updated and actually exercise the new behavior
- [ ] `docs {}` updated
- [ ] New env vars propagated to all `environments/*.bru`
- [ ] Collection runs clean locally

<!-- ▲ END SECTION ▲ -->
