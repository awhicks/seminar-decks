# Seminar decks

Course slide decks with an iPad-friendly presenter view, synchronized
to audience screens through the
[`seminar`](https://github.com/rajgoel/reveal.js-plugins/tree/master/seminar)
plugin: the presenter hosts the room, everyone else follows along —
including chalkboard drawings.

Built on [reveal.js](https://revealjs.com) (vendored from npm at
install time — no separate reveal.js checkout needed).

## Layout

```
seminar-decks/
├── Start Seminar.command   ← double-click to run everything
├── Stop Seminar.command    ← double-click to stop it
├── presenter.html          ← shared presenter view (all courses)
├── server.js               ← static deck server (port 8000)
├── vendor/                 ← reveal.js + plugins (built by npm install)
├── csc102/                 ← one course per folder
└── csc201/
```

Each course folder has its own `README.md` with details
(new lectures, speaker notes, the per-course workflows).

## One-time setup

1. **This repo**: `npm install` (fills `vendor/`). The Start script
   also does this automatically on first run.
2. **Seminar server** (separate project, not on npm):
   ```sh
   git clone https://github.com/rajgoel/seminar.git ~/src/seminar
   cd ~/src/seminar && npm install
   ```
   If you clone it elsewhere, edit `SEMINAR_DIR` at the top of
   `Start Seminar.command`.
3. **Host password** (once): open `http://localhost:4433` after
   starting, generate a bcrypt hash for your chosen password, and set
   it as `seminar.hash` in the decks. The hash is per-**password**, so
   the same hash works in every deck. See a course README for details.

## Running it

Double-click **`Start Seminar.command`**. It starts both servers
(skipping any already running), prints the URLs for every course
folder it finds, and keeps running in its Terminal window — close the
window (or double-click `Stop Seminar.command`) to stop.

- **Projector / audience Mac**: `http://localhost:8000/csc102/`
- **iPad**: the printed URL — either a course index (tap a lecture's
  **Presenter** button) or a direct
  `presenter.html?deck=/csc201/index.html` link.

## Adding a course

Copy a course folder (e.g. `cp -R csc201 csc301`), replace the slides,
and change its `seminar.room` so it doesn't collide. The launcher,
presenter, and index pages pick it up automatically — nothing else to
edit. See `csc102/README.md` for the per-lecture variant used there.

## Server deployment

This setup is designed for a trusted LAN. For running it on a server
exposed to a wider network (TLS, Docker, hardening), see
**[PLAN.md](PLAN.md)**.