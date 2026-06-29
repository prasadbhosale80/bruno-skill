---
name: bruno
description: "Use this skill whenever working with Bruno API testing collections — creating, editing, or generating .bru files; writing pre-request or post-response scripts; adding tests and assertions; organizing collections and environments; running collections via CLI; writing GraphQL requests; or generating documentation. Triggers: any mention of Bruno, .bru files, bruno.json, bru lang, Bruno CLI, Bruno collections, or tasks like 'create API tests', 'write Bruno scripts', 'add Bruno assertions'. Also use when asked to scaffold a new API collection from source code, add CI/CD pipeline for Bruno tests, or convert Postman/Insomnia collections to Bruno."
license: Reference documentation compiled from https://docs.usebruno.com (MIT-licensed open source project)
---

# Bruno API Testing — Reference

## What is Bruno

Bruno is a local-first, open-source API client. Collections are plain `.bru` text files on disk — version-controllable, diff-friendly, Git-native. No cloud sync, no proprietary formats.

**Mental model:**
- **Collection** = a folder with a `bruno.json` manifest
- **Request** = one `.bru` file
- **Environments** = `.bru` files inside `environments/`

---

## Bru Language — File Anatomy

Each request is a `.bru` file (new `.yaml` OpenCollection format also supported; `.bru` is most common).

```bru
meta {
  name: Get User
  type: http          # http | graphql | websocket
  seq: 1              # sort/execution order
  tags: [smoke, users]
}

get {
  url: https://api.example.com/users/:userId
}

params:query {
  include: profile
  ~debug: true        # ~ prefix = disabled, not sent
}

params:path {
  userId: 42          # replaces :userId in url
}

headers {
  Authorization: Bearer {{access_token}}
  Content-Type: application/json
  ~X-Debug-Mode: enabled
}

body:json {
  { "name": "John Doe", "email": "john@example.com" }
}

script:pre-request {
  req.setHeader("X-Request-ID", bru.interpolate("{{$guid}}"));
}

script:post-response {
  bru.setVar("userId", res.body.id);
}

tests {
  test("should return 200", function () {
    expect(res.getStatus()).to.equal(200);
  });
}

assert {
  res.status: eq 200
  res.body.id: isNotEmpty
  res.responseTime: lt 2000
}

docs {
  Fetches a single user by userId path param. Requires Bearer token. 404 if not found.
}
```

**Syntax rules:** `~` prefix = disabled. `seq` controls order. `type` is `http`, `graphql`, or `websocket`. Tags filter requests in CLI runs.

---

## HTTP Methods

```bru
get | post | put | patch | delete | head | options { url: ... }
```
Custom methods (`LIST`, `SEARCH`) supported via UI.

---

## Request Body Types

```bru
body:json { { "name": "Alice", "role": "admin" } }

body:form-urlencoded {
  username: alice
  password: secret
  ~remember_me: true
}

body:multipart-form {
  username: alice
  ~file: @/path/to/file.pdf
}

body:text { Hello, plain text body }

body:xml {
  <user><name>Alice</name><role>admin</role></user>
}

body:graphql {
  query GetUser($id: ID!) { user(id: $id) { id name email } }
}
body:graphql:vars { { "id": "123" } }
```

---

## Parameters

```bru
params:query {        # → ?page=1&limit=20
  page: 1
  limit: 20
  ~verbose: true
}

params:path {         # url must use :placeholder, e.g. /users/:userId/posts/:postId
  userId: 42
  postId: 101
}
```

---

## Collection & Environment Structure

```
my-api-collection/
├── bruno.json                 ← manifest (required)
├── environments/
│   ├── local.bru
│   ├── staging.bru
│   └── production.bru
├── auth/
│   ├── login.bru
│   └── refresh-token.bru
└── users/
    ├── get-users.bru
    ├── create-user.bru
    └── delete-user.bru
```

**`bruno.json`:**
```json
{
  "version": "1",
  "name": "My API Collection",
  "type": "collection",
  "ignore": ["node_modules", ".git"]
}
```

**`environments/local.bru`:**
```bru
vars {
  baseUrl: http://localhost:3000
  apiVersion: v1
}
vars:secret {
  access_token:
  api_key:
}
```

---

## Variables System

Precedence (highest → lowest):

| Type | Scope | Storage | Script Access |
|------|-------|---------|---------------|
| Runtime | Current run | Memory | `bru.setVar()` / `bru.getVar()` |
| Request | Single request | `.bru` | `bru.getRequestVar()` |
| Folder | Folder + children | folder `.bru` | `bru.getFolderVar()` |
| Environment | Active env | env `.bru` | `bru.getEnvVar()` |
| Collection | Whole collection | `bruno.json` | `bru.getCollectionVar()` |
| Global | All collections | App storage | `bru.getGlobalEnvVar()` |
| Process Env | OS env | `.env` | `bru.getProcessEnv()` |

**Interpolation** — use `{{varName}}` anywhere (URLs, headers, body, params):
```bru
get { url: {{baseUrl}}/{{apiVersion}}/users/{{userId}} }
headers { Authorization: Bearer {{access_token}} }
# {{?Enter password}}        → prompt at runtime, never stored
# {{process.env.MY_SECRET}}  → process env var
```

---

## Scripting API

Two phases: `script:pre-request` (runs before send, can modify `req`, no `res`) and `script:post-response` (runs after, can read `res`, set vars, chain). Both have `bru.*`.

### Request object (`req`) — pre-request only
```javascript
req.getUrl() / req.setUrl(url)
req.getMethod() / req.setMethod("POST")
req.getHeader(name) / req.setHeader(name, val)
req.setHeaders({ "X-Custom": "value" })
req.deleteHeader(name)
req.getBody()                 // parsed object
req.getBody({ raw: true })    // raw string
req.setBody({ ... })
req.setTimeout(10000)
req.setMaxRedirects(3)
req.getExecutionMode()        // "runner" | "standalone"
req.getExecutionPlatform()    // "app" | "cli"
req.getName() / req.getTags()
```

### Response object (`res`) — post-response & tests
```javascript
res.status / res.statusText           // or res.getStatus() / res.getStatusText()
res.headers                           // plain object, keys lowercased
res.getHeader(name) / res.getHeaders()
res.body / res.getBody()              // auto-parsed JSON (or string)
res.setBody({ ... })                  // replace for downstream tests
res.responseTime / res.getResponseTime()
res.getSize()                         // { body, headers, total }
res.url / res.getUrl()                // after redirects
```

### Environment vars
```javascript
bru.getEnvName()
bru.getEnvVar(key) / bru.setEnvVar(key, val)
bru.setEnvVar(key, val, { persist: true })   // saves to disk
bru.hasEnvVar(key) / bru.deleteEnvVar(key) / bru.deleteAllEnvVars()
bru.getAllEnvVars()
bru.getGlobalEnvVar(key) / bru.setGlobalEnvVar(key, val) / bru.hasGlobalEnvVar(key) / bru.getAllGlobalEnvVars()
```

### Runtime vars (in-memory, for chaining requests)
```javascript
bru.setVar(key, val) / bru.getVar(key) / bru.hasVar(key)
bru.getAllVars() / bru.deleteVar(key) / bru.deleteAllVars()
// Scoped reads (read-only):
bru.getCollectionVar(k) / bru.hasCollectionVar(k)
bru.getFolderVar(k) / bru.getRequestVar(k)
bru.getProcessEnv("SECRET_TOKEN")    // from OS env / .env
```

### Utilities
```javascript
await bru.sleep(3000)                 // pause (polling loops)
bru.interpolate("{{$guid}}")          // resolve dynamic/env vars
bru.cwd()                             // collection path
bru.isSafeMode()                      // true (default) | false (developer)
bru.disableParsingResponseJson()      // call in pre-request; getBody() → string
bru.getSecretVar("service.key")       // needs secret manager config
```

### Ad-hoc & chained requests
```javascript
// Fire an arbitrary HTTP request:
const resp = await bru.sendRequest({
  method: "POST", url: "https://auth.example.com/token",
  headers: { "Content-Type": "application/x-www-form-urlencoded" },
  data: { grant_type: "client_credentials", client_id: bru.getEnvVar("CLIENT_ID") },
  timeout: 5000
})
bru.setEnvVar("access_token", resp.data.access_token, { persist: true })

// Run an existing collection request by path:
const authResp = await bru.runRequest("auth/login")
bru.setVar("token", authResp.body.token)
// ⚠️ Never call bru.runRequest() from a collection-level script (infinite loop).
```

---

## Tests (Chai)

Live in the `tests {}` block. Uses Chai.js — all `expect()` syntax works.

```javascript
test("returns 200", function () {
  expect(res.getStatus()).to.equal(200)
})

test("returns correct user", function () {
  const body = res.getBody()
  expect(body).to.have.property("id")
  expect(body.email).to.contain("@example.com")
  expect(body.role).to.be.oneOf(["admin", "user"])
})

// Bruno-specific JSON helpers:
expect(res.getBody()).to.have.jsonBody()
expect(res.getBody()).to.have.jsonBody("user.id", 123)

// JSON Schema (Ajv, drafts 04/06/07/2019-09/2020-12):
expect(res.getBody()).to.have.jsonSchema({
  type: "object", required: ["id", "email"],
  properties: {
    id: { type: "integer" },
    email: { type: "string", format: "email" },
    createdAt: { type: "string", format: "date-time" }
  }
})

// Arrays:
const users = res.getBody()
expect(users).to.be.an("array")
expect(users).to.have.lengthOf.above(0)
users.forEach(u => expect(u.email).to.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/))

// Save token for chaining:
bru.setVar("authToken", res.getBody().token)
```

**Chai quick reference:**
```javascript
// Equality:   .equal(x) (===)  .eql(x) (deep)  .not.equal(x)
// Types:      .be.a("string")  .an("array")  .an("object")  .be.true/false/null/undefined
// Existence:  .have.property("k")  .have.all.keys("a","b")  .exist  .be.empty  .not.be.empty
// Strings:    .contain("s")  .match(/re/)  .startWith("p")
// Numbers:    .be.above(n)  .below(n)  .within(a,b)  .at.least(n)
// Arrays:     .have.lengthOf(n)  .include("x")  .have.members([...])
```

---

## Assertions (No-Code)

Declarative checks in the `assert {}` block.

```bru
assert {
  res.status: eq 200
  res.body.status: eq success
  res.body.id: isNotEmpty
  res.body.name: contains John
  res.responseTime: lt 1000
  res.headers['content-type']: contains application/json
  res.body.users[0].id: isNotEmpty
  res.body.score: gte 90
}
```

**Operators:**

| Category | Operators |
|----------|-----------|
| Comparison | `eq` `neq` `gt` `gte` `lt` `lte` |
| String | `contains` `notContains` `startsWith` `endsWith` `matches` `notMatches` |
| Null/Empty | `isNull` `isNotNull` `isEmpty` `isNotEmpty` |
| Defined | `isDefined` `isUndefined` |
| Boolean | `isTruthy` `isFalsy` |
| Type | `isNumber` `isString` `isBoolean` `isArray` `isJson` |
| Range | `between` `length` `in` `notIn` |

---

## Request Chaining

Standard authenticated multi-step pattern:

```bru
# 1. auth/login.bru
post { url: {{baseUrl}}/auth/login }
body:json { { "email": "{{email}}", "password": "{{password}}" } }
script:post-response {
  if (res.getStatus() === 200) {
    bru.setVar("authToken", res.getBody().token)
    bru.setVar("userId", res.getBody().user.id)
  }
}
```
```bru
# 2. users/get-user.bru (runs after login)
get { url: {{baseUrl}}/users/{{userId}} }
headers { Authorization: Bearer {{authToken}} }
```

---

## Data-Driven Testing

Run the same requests against multiple inputs from CSV/JSON.

```json
// request body placeholders
{ "name": "{{name}}", "job": "{{job}}" }
```
```csv
name,job
John Doe,Software Engineer
Jane Smith,Product Manager
```
```javascript
// Access iteration data in scripts:
bru.runner.iterationData.get("name")   // single field
bru.runner.iterationData.get()         // all fields
bru.runner.iterationData.stringify()   // JSON string
bru.runner.iterationData.has("name")
bru.runner.iterationIndex              // 0-based
bru.runner.totalIterations
req.setBody({ name, job })
```

---

## Collection Runner Control

```javascript
bru.runner.setNextRequest("Check Job Status")  // jump (alias: bru.setNextRequest)
bru.runner.stopExecution()                     // stop whole run
bru.setNextRequest(null)                        // stop after current
bru.runner.skipRequest()                        // skip (call in pre-request)
// Skip by tag:
if (req.getTags().includes("skip-in-ci") && bru.getEnvVar("CI") === "true") {
  bru.runner.skipRequest()
}
```

---

## Bruno CLI

```bash
npm install -g @usebruno/cli
```

**Run:**
```bash
bru run                                   # whole collection
bru run request.bru                       # specific file(s)/folder(s)
bru run users/ auth/login.bru
bru run -r                                # recursive
bru run --env staging
bru run --env production --env-var baseUrl=https://custom-url.com
bru run --csv-file-path ./data/test-data.csv
bru run --json-file-path ./data/test-data.json
bru run --iteration-count 5
```

**Filter:**
```bash
bru run --tags smoke,users               # ALL listed tags
bru run --exclude-tags slow,integration  # exclude ANY
bru run --tests-only                     # only reqs with tests/assertions
bru run --bail                           # stop on first failure
bru run --delay 500                      # ms between requests
bru run --parallel
```

**Report:**
```bash
bru run --reporter-html results.html
bru run --reporter-junit results.xml     # CI
bru run --reporter-json results.json
bru run --reporter-skip-request-body / --reporter-skip-response-body / --reporter-skip-body
```

**Security / sandbox:**
```bash
bru run --insecure                       # self-signed certs
bru run --cacert ./certs/ca.pem
bru run --disable-cookies / --noproxy
bru run                                  # default safe mode (v3+): no require()/fs
bru run --sandbox=developer              # enables require(), Node built-ins, fs
```

**GitHub Actions:**
```yaml
name: API Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: usebruno/bruno-cli-action@v2
        with:
          collection: ./bruno-collection
          environment: staging
          reporter-junit: results.xml
      - uses: dorny/test-reporter@v1
        if: always()
        with: { name: Bruno Tests, path: results.xml, reporter: java-junit }
```

---

## Authentication

```bru
auth:bearer { token: {{access_token}} }

auth:basic { username: {{username}}  password: {{password}} }

auth:apikey {
  key: X-API-Key
  value: {{api_key}}
  placement: header        # header | query
}

auth:awsv4 {
  accessKeyId: {{AWS_ACCESS_KEY}}
  secretAccessKey: {{AWS_SECRET_KEY}}
  region: us-east-1
  service: execute-api
}

# OAuth2 (configured in UI). In scripts:
#   bru.getOauth2CredentialVar("access_token")
#   bru.resetOauth2Credential("credential-id")   // force re-auth
```

---

## Documentation

Markdown docs at 4 levels (collection / folder / request / env). Request-level lives in the `docs {}` block; full Markdown supported, HTML sanitized (no `<script>`).

```bru
docs {
  ## Create User
  Creates a new user. **Required:** `name`, `email`. **Auth:** Bearer w/ `users:write`.
  ### Errors
  - `400` – Validation failed
  - `409` – Email already registered
}
```
Auto-generate HTML: Bruno UI → Collection → ... → Export → Generate Docs.

---

## Common Patterns & Recipes

**Token refresh (auto-retry)** — collection-level post-response:
```javascript
if (res.getStatus() === 401) {
  const r = await bru.runRequest("auth/refresh-token")
  if (r.status === 200) {
    bru.setEnvVar("access_token", r.body.token, { persist: true })
    bru.setNextRequest(req.getName())   // 1 retry only
  }
}
```

**CRUD suite** (each file passes data to the next via `setVar`/`getVar`):
```
users/  01-create (POST→{{userId}})  02-get  03-update  04-list  05-delete
```

**Polling until complete:**
```javascript
// job-creation post-response:
bru.setVar("jobId", res.getBody().id)
bru.setVar("pollRetries", 0)
bru.setNextRequest("Poll Job Status")

// "Poll Job Status" pre-request:
if (parseInt(bru.getVar("pollRetries") || "0") >= 10) bru.runner.stopExecution()

// "Poll Job Status" post-response:
const body = res.getBody()
if (body.status === "pending") {
  bru.setVar("pollRetries", parseInt(bru.getVar("pollRetries") || "0") + 1)
  await bru.sleep(2000)
  bru.setNextRequest("Poll Job Status")   // loop
} else {
  bru.setVar("jobResult", body.result)
  bru.setNextRequest("Process Job Result")
}
```

**Dynamic base URL per environment** — set `baseUrl` in each `environments/*.bru`, reference `{{baseUrl}}` in requests.

---

## Secrets Management

Never hardcode secrets in `.bru` files.

```bash
# .env (add to .gitignore!)
ACCESS_TOKEN=my_secret_token
```
```bru
headers { Authorization: Bearer {{process.env.ACCESS_TOKEN}} }
```
```javascript
bru.getProcessEnv("ACCESS_TOKEN")
```
Secret env vars → `vars:secret { ... }` block (stored encrypted in app, not in file). External managers (AWS/Azure/HashiCorp): `bru.getSecretVar("my-service.api_key")`.

---

## Import / Export / Conversion

```bash
bru import openapi --source ./openapi.yaml --output ./collection/ --collection-name "My API"
bru import openapi --source ./openapi.yaml --output ./collection/ --group-by path
```
UI import formats: Postman (v2.0/2.1), Insomnia, OpenAPI 3.x, WSDL (SOAP), Hoppscotch.

---

## GraphQL

```bru
meta { name: Get Albums  type: graphql  seq: 1 }
post { url: https://graphqlzero.almansi.me/api }
headers { Content-Type: application/json }

body:graphql {
  query GetUser($id: ID!, $includeProfile: Boolean!) {
    user(id: $id) {
      id name
      profile @include(if: $includeProfile) { avatar bio }
    }
  }
}
body:graphql:vars {
  { "id": "{{userId}}", "includeProfile": true }
}

tests {
  test("returns user", function () {
    expect(res.getBody()).to.not.have.property("errors")
    expect(res.getBody().data.user).to.have.property("id")
  })
}
```

**Operations:** `query` (read), `mutation` (create/update/delete), `subscription` (real-time stream — Bruno supports it).

**Use variables over inline values** for security (prevents injection), reusability, type safety, readability.

**Visual Query Builder** (Query tab → sidebar toggle): load schema via introspection or upload `.graphql`/`.json` (cached after first load). Check fields to include (selecting nested auto-selects parents); required args (`!`) auto-enabled; enums→dropdown, bools→selector, args auto-converted to variables. Editor ↔ builder sync bidirectionally. **Limits:** one operation per request, max 7 nesting levels, complex list-input types (`[InputType!]`) must be written in the editor.

---

## WebSocket (Bruno 2.13.0+)

Persistent full-duplex channel. `wss://` in production, `ws://` for local/dev.

```bru
meta { name: Live Chat  type: websocket  seq: 1 }
websocket { url: wss://echo.websocket.org }
headers {
  Authorization: Bearer {{access_token}}
  Sec-WebSocket-Protocol: mqtt, wamp
  Sec-WebSocket-Version: 13               # RFC 6455
}
```

**Message types:** Text (commands/status), JSON (structured), XML (legacy/SOAP).
**Lifecycle:** Connect (handshake) → compose + select type + Send → history shows `→` sent / `←` received w/ timestamps → Disconnect (history preserved).
**Settings:** Connection timeout (default 30s, 1–300s); auto-reconnect on drop.
Rejected subprotocol → `400 Bad Request` (check connection log).

| | HTTP | WebSocket |
|---|------|-----------|
| Connection | Request-Response | Persistent |
| Data flow | Unidirectional | Bidirectional |
| Use case | REST APIs | Real-time / chat / live feeds |

---

## Dynamic Variables (Faker.js)

`{{$varName}}` syntax anywhere; **case-sensitive, camelCase**. In scripts: `bru.interpolate("{{$varName}}")`.

```
# IDs / time
{{$guid}} {{$randomUUID}}      UUID v4
{{$randomNanoId}}              Nano ID
{{$timestamp}}                 Unix seconds
{{$isoTimestamp}}              ISO 8601

# People
{{$randomFirstName}} {{$randomLastName}} {{$randomFullName}}
{{$randomEmail}} {{$randomUserName}} {{$randomPhoneNumber}} {{$randomJobTitle}}

# Internet
{{$randomUrl}} {{$randomDomainName}} {{$randomIP}} {{$randomIPV6}}
{{$randomUserAgent}} {{$randomPassword}}

# Data types
{{$randomBoolean}} {{$randomInt}} (0–1000) {{$randomWord}} {{$randomLoremSentence}}

# Location
{{$randomCity}} {{$randomCountry}} {{$randomStreetAddress}}
{{$randomLatitude}} {{$randomLongitude}}

# Business / finance
{{$randomCompanyName}} {{$randomPrice}} {{$randomCurrencyCode}} {{$randomCurrencySymbol}}
{{$randomBankAccount}} {{$randomCreditCardMask}} {{$randomBitcoin}}

# Dates
{{$randomDateFuture}} {{$randomDatePast}} {{$randomDateRecent}}
{{$randomWeekday}} {{$randomMonth}}

# Files / colors
{{$randomFileName}} {{$randomMimeType}} {{$randomFileExt}}
{{$randomColor}} {{$randomHexColor}}
```
```javascript
// In scripts:
req.setBody({
  id: bru.interpolate("{{$randomUUID}}"),
  name: bru.interpolate("{{$randomFullName}}"),
  email: bru.interpolate("{{$randomEmail}}")
})
```

---

## Variable Interpolation — Advanced (v2.2.0+)

```javascript
bru.setVar("user", { username: "alice", isVerified: true, preferences: { theme: "dark" } })
bru.setVar("apiTypes", ["REST", "GraphQL", "gRPC"])
bru.setVar("configs", [{ port: 3000 }, { port: 8080 }])
bru.setVar("createdAt", new Date())
```
```json
{
  "user": "{{user.username}}",          // "alice"
  "theme": "{{user.preferences.theme}}", // "dark"
  "primary": "{{apiTypes[0]}}",         // "REST"
  "all": {{apiTypes}},                  // full array
  "devPort": {{configs[0].port}},       // 3000
  "ts": "{{createdAt}}"                 // "2025-04-23T13:57:56.341Z"
}
```

**Declarative vars (no scripting)** — `vars:pre-request` / `vars:post-response` blocks; post-response accepts JSONPath dot-notation on `res`:
```bru
vars:pre-request { baseUrl: https://api.example.com  userId: 42 }
vars:post-response {
  createdId: res.body.id
  authToken: res.body.token
  statusCode: res.status
}
```

---

## Quick Cheatsheet

```
Create request         → .bru file w/ meta + method + url
Run collection         → bru run --env staging
Run with data          → bru run --csv-file-path data.csv
HTML report            → bru run --reporter-html results.html
CI (GitHub Actions)    → usebruno/bruno-cli-action@v2
Pass data between reqs → bru.setVar() → bru.getVar()
Save to env (persist)  → bru.setEnvVar(k, v, { persist: true })
Disable param/header   → prefix with ~
Stop on failure        → bru run --bail
Filter by tag          → bru run --tags smoke
Skip request           → bru.runner.skipRequest() (pre-request)
Jump to request        → bru.setNextRequest("name")
Read process env       → bru.getProcessEnv("VAR")
External HTTP call     → await bru.sendRequest({ method, url, data })
Run another request    → await bru.runRequest("folder/request")
Assert no-code         → assert { res.status: eq 200 }
Assert with code       → test("...", () => expect(...))
```

---

## Key Rules for Agents

1. Every `.bru` file needs a `meta` block with `name`, `type`, `seq`.
2. `type` is only `http`, `graphql`, or `websocket`.
3. Use `{{variableName}}` for all dynamic values — never hardcode secrets/tokens/env URLs.
4. Secret variables go in `vars:secret { }` — never plain `vars`.
5. **Never call `bru.runRequest()` from a collection-level script** (infinite loop).
6. Default CLI sandbox is safe mode (v3+); add `--sandbox=developer` only when `require`/`fs` is needed.
7. Always add tests (`tests {}`) or assertions (`assert {}`) for requests with meaningful responses.
8. Use `seq` for execution order, `tags` for selective CI runs.
9. Docs go in `docs {}` — Markdown supported, HTML sanitized.
10. All files are plain text — commit to Git alongside source.
11. **Never use `pm.*`** — Bruno uses `bru.*`, `req.*`, `res.*`. No Postman compat layer.
12. Prefix disabled params/headers with `~`.
13. WebSocket uses `wss://` in production.
14. GraphQL Query Builder: one operation per request, max 7 nesting levels.
15. Dynamic variables are case-sensitive `camelCase` (`{{$randomFirstName}}`).

---

## Docs Index — https://docs.usebruno.com

REST · GraphQL (overview / query-builder / variables) · WebSocket (overview / create-request / message-types) · Variables · Interpolation · Dynamic Variables · Scripting · JS API Reference · Testing · Assertions · Data-Driven Tests · Request Chaining · Bru Lang (tag-reference) · CLI (overview / commandOptions) · Auth · Secrets · OpenAPI Import · API Docs · AI Agents
