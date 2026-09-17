# PLAN — Server deployment, hardening, Docker

Status: **notes + plan, not yet implemented.** The current setup is
designed for a trusted LAN (Mac + iPad on the same network). This plan
covers what it would take to run it on a server exposed to a wider
network / the internet.

---

## 1. Current state (what a server would need to reproduce)

### Moving parts

| Piece | What it is | Where it comes from |
|---|---|---|
| Deck server | vite **dev server** (`npm start -- --host`), port 8000 | reveal.js repo |
| Seminar server | express + socket.io app (`node server`), port 4433 | **cloned from source**: `github.com/rajgoel/seminar` → `~/src/seminar` |
| reveal.js-plugins | chalkboard / customcontrols / seminar client plugins | npm package `reveal.js-plugins@^4.6.0`, added to `package.json` |
| socket.io client | loaded by decks from **CDN** (cdnjs, pinned 4.6.1) | must match server's socket.io 4.6.1 |
| Font Awesome | loaded by decks from **CDN** | cdnjs 6.4.0 |
| Courses | `csc102/`, `csc201/` folders (decks + index) | in-repo |
| Shared UI | `presenter.html` (repo root), `Start/Stop Seminar.command` | in-repo |
| Node | mise-managed (`~/.local/share/mise/shims` needed on PATH in non-interactive shells) | — |

### Install friction (the "notes")

- **Seminar server is not on npm.** It must be cloned:
  ```sh
  git clone https://github.com/rajgoel/seminar.git ~/src/seminar
  cd ~/src/seminar && npm install        # express, cors, socket.io, moment, bcrypt
  ```
  `bcrypt` is a **native module** — needs build toolchain (or prebuilt
  binaries) on the host. This matters most inside Docker.
- **reveal.js-plugins must be added as a dependency** of the reveal.js
  repo (`npm install reveal.js-plugins`) because decks reference
  `../node_modules/reveal.js-plugins/...` for plugin code and CSS.
- Decks load socket.io and Font Awesome from CDNs — a server deployment
  (especially offline or firewalled classrooms) should **vendor these
  locally**.
- The seminar **server's** socket.io version must match the **client**
  version the decks load (4.6.1 today). Pin both.

### Current security posture (LAN-trust assumptions)

1. **vite dev server in production** — no rate limiting, no security
   headers, dev-oriented file serving. Not meant to be exposed.
2. **Plain HTTP** on both ports — password and session sniffable in
   transit.
3. **No brute-force protection** on the host-password check.
4. **Anyone with the URL joins as a participant** (by design for a
   classroom; on the public internet that's "anyone who finds it").
5. **Decks hardcode `http://<page-hostname>:4433`** — assumes both
   servers share a host and speak plain HTTP. Breaks under TLS/reverse
   proxy until changed.
6. **CORS wide open** — the seminar server runs
   `app.use(cors({ credentials: true, origin: true }))`, i.e. it
   reflects any origin **with credentials allowed**. Must be locked to
   the deployment origin before exposure. (Port is `process.env.PORT
   || 4433` — already env-configurable.)

---

## 2. Hardening plan

### H1 — Stop using the vite dev server

- `npm run build` to produce `dist/`.
- Serve statically: `dist/`, course folders, `presenter.html`, and the
  plugin assets decks reference under
  `node_modules/reveal.js-plugins/` (either expose that path or copy
  `chalkboard/`, `customcontrols/`, `seminar/` plugin files into the
  static tree at build time — copying is cleaner).
- Vendor the socket.io client + Font Awesome locally so decks have no
  CDN dependency.
- Result: a plain static file server (Caddy/nginx) instead of vite.

### H2 — TLS everywhere

- One reverse proxy (Caddy recommended: automatic Let's Encrypt, and
  WebSocket proxying is one line) as the only exposed thing:
  - `https://host/` → static deck files
  - `https://host/seminar/` → seminar server (proxy WebSocket upgrade)
- Firewall everything else; 443 (and 80→redirect) only. 8000/4433 bind
  to localhost.
- **Deck change:** replace
  `server: 'http://' + window.location.hostname + ':4433'` with
  same-origin derivation, e.g.
  `server: window.location.origin + '/seminar'` (socket.io client
  handles `https`/`wss` upgrade transparently). One shared snippet —
  update the lecture template + `csc201/index.html`.

### H3 — Protect the host login

- Add `express-rate-limit` (or proxy-level limiting) to the seminar
  server's `open_or_join_room` endpoint — e.g. 10 attempts / 15 min /
  IP.
- Optional, cheap win: make room names unguessable
  (`CSC102-01` → `CSC102-01-x7qf`) since room + password are both
  needed to host. Derived from filename today; would need a suffix
  map or env-provided secret.

### H4 — Tighten the seminar server

- Restrict CORS `origin` to the deployment's origin(s) — currently
  `cors({ credentials: true, origin: true })` reflects any origin with
  credentials. Note: behind a same-origin Caddy proxy, CORS becomes
  unnecessary entirely and the middleware can be dropped.
- The port is already env-configurable (`PORT`); keep it internal.
- Run as non-root, read-only filesystem where possible (comes free
  with Docker below).

### H5 — Password management

- Today the bcrypt hash lives in the deck HTML (fine — bcrypt is
  one-way). For the server, template the hash into decks at container
  start from a `SEMINAR_HASH` env var so rotation doesn't mean editing
  files. Keep "hash is per-password, shared across decks" property.

---

## 3. Dockerization plan

**Shape:** `docker compose` with two services behind one published
port. No vite, no CDN, no host Node install.

```
┌────────────────────────────────────────────┐
│ host: 443 (only open port)                 │
│                                            │
│  caddy service                             │
│   ├─ /            → static decks (built)   │
│   └─ /seminar/    → seminar service        │
│                                            │
│  seminar service (internal only)           │
│   └─ node server  (rajgoel/seminar)        │
└────────────────────────────────────────────┘
```

### D1 — `Dockerfile` (multi-stage)

```dockerfile
# ---- build: compile reveal.js dist + fetch plugin assets ----
FROM node:20 AS build
WORKDIR /repo
COPY package*.json ./
RUN npm ci                       # includes reveal.js-plugins
COPY . .
RUN npm run build                # → dist/

# ---- runtime: static files + seminar server ----
FROM node:20-slim AS runtime
# seminar server (cloned at build — not on npm)
RUN git clone --depth 1 https://github.com/rajgoel/seminar.git /seminar
WORKDIR /seminar
RUN npm ci --omit=dev            # bcrypt: prebuilt binaries usually
                                 # available for node:20-slim; if not,
                                 # add build-essential+python3 here
```

Notes:
- `bcrypt`'s native build is the main image risk — verify prebuilds on
  the target platform, keep the build-tool fallback documented.
- The static tree handed to Caddy: `dist/`, course folders,
  `presenter.html`, vendored socket.io client + Font Awesome, and the
  three plugin folders copied out of `node_modules/reveal.js-plugins/`.

### D2 — `docker-compose.yml`

```yaml
services:
  caddy:
    image: caddy:2
    ports: ["443:443", "80:80"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - static:/srv                     # built static tree
    depends_on: [seminar]
  seminar:
    build: .
    expose: ["4433"]                    # internal only — not published
    environment:
      - SEMINAR_HASH=${SEMINAR_HASH}    # templated into decks at start
    restart: unless-stopped
```

### D3 — `Caddyfile` (sketch)

```caddyfile
seminar.example.edu {
    encode gzip
    handle /seminar/* {
        uri strip_prefix /seminar
        reverse_proxy seminar:4433
    }
    handle {
        root * /srv
        file_server
    }
}
```

### D4 — Remaining decisions / work items

- [ ] Domain name + TLS (Let's Encrypt via Caddy, or internal CA for
      an on-campus box)
- [ ] Deck `server:` URL change (H2) — one snippet, all decks
- [ ] Vendor socket.io client + Font Awesome, pin versions
- [ ] Entry-point script that templates `SEMINAR_HASH` into course
      deck files at container start (D2/H5)
- [ ] Rate limiting on the seminar server (H3) — needs a small patch
      to the cloned repo; carry it as a patch file or fork
- [ ] CORS origin restriction in the seminar server (H4) — same
      patch/fork question
- [ ] Decide whether `Start/Stop Seminar.command` get a server-mode
      sibling (e.g. `deploy.sh` wrapping `docker compose up -d`) or
      the LAN scripts stay the only workflow
- [ ] Test matrix: iPad Safari over TLS, chalkboard broadcast through
      the proxy (WebSocket upgrade), participant auto-join, host
      takeover with wrong password → rate limit kicks in

---

## 4. What stays the same

- Course folders remain the unit of content — copy folder, edit
  slides. Docker build picks them up.
- `presenter.html` stays a single shared file; `?deck=` routing is
  unchanged.
- Host-password hash stays per-password (not per-deck), so one env
  var covers all courses.
- The LAN workflow (`Start/Stop Seminar.command`) is untouched — this
  plan adds a server mode rather than replacing it.