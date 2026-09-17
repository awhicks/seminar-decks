# CSC 102 — Seminar presenter

An iPad-friendly presenter view for a reveal.js deck that is synchronized
through the [`seminar`](https://github.com/rajgoel/reveal.js-plugins/tree/master/seminar)
plugin: the presenter hosts the room, everyone else follows along.

## Files

- `lecture-XX.html` — **one deck per lecture: put your slides here** (each
  slide is a `<section>`, speaker notes go in `<aside class="notes">`).
  Each file's seminar room (`CSC102-XX`) is derived from its filename, so
  lectures don't collide with each other and copies need no edits.
- `index.html` — lecture index page (lists `lecture-XX.html` files
  automatically).
- `/presenter.html` (repo root) — touch presenter view (current/next slide,
  notes, timer, chalkboard), **shared by every course**. Hosts the seminar
  room through the deck, so it never needs its own copy of the
  server/room/hash values — it reads them from the deck.

## Running it

Double-click **`Start Seminar.command`** (at the root of this repo —
one launcher, shared by every course). It starts both
servers (skipping any that are already running), prints the URLs for each
course folder it finds, and keeps running in its Terminal window — close
the window to stop the servers it started. The first launch may need a
right-click → Open to bypass Gatekeeper's unsigned-script warning.

To stop the servers at any time (whatever started them), double-click
**`Stop Seminar.command`** (also at the repo root). It stops whatever is
listening on ports 4433 and 8000 — anything already off is reported and
skipped.

What it starts:

1. **Seminar server** — `node server` in `~/src/seminar` (edit
   `SEMINAR_DIR` at the top of the script if it lives elsewhere).
   Listens on port **4433** on this Mac.
2. **Deck server** — `npm start` in this repo (a dependency-free static server).
   Serves on **<http://localhost:8000>** (the port is set in `server.js`).

Then open:

- **Projector / audience Mac**: `http://localhost:8000/csc102/lecture-01.html`
  (auto-joins that lecture's room as a participant)
- **iPad**: `http://<mac-ip>:8000/presenter.html?deck=/csc102/lecture-01.html`
  (or open `http://<mac-ip>:8000/csc102/` and tap a lecture's **Presenter**
  button) → enter a presenter name + the host password → you are hosting.
  The name and password are remembered in the iPad's Safari, so
  repeat sessions are one tap on **Start Presenter** (clear them via
  Safari's website-data settings if needed).

Bookmark the iPad URL (or add it to the Home Screen). If your Mac's IP
changes regularly, give it a static DHCP lease or use its `.local`
hostname (e.g. `http://my-mac.local:8000/...`) so the bookmark keeps working.

### Why nothing needs copying between the two apps

- The deck derives the seminar server address from the hostname you open
  it with (`http://<hostname>:4433`), since both servers run on the same
  machine. A changed LAN IP requires no edits.
- Each lecture's room has an explicit venue (e.g. `url: 'CSC102-01'`), so it
  does not matter whether someone opens the deck via `localhost` or via the
  LAN IP — everyone lands in the same room.
- `presenter.html` reads the seminar configuration straight from the deck
  (shown on its login screen) and drives the plugin inside the deck iframe.

## Starting a new lecture

1. Copy any existing lecture file: `cp lecture-02.html lecture-03.html`
2. Replace the slides with the new lecture's content.

That's it — the seminar room, venue, and page title are all derived from
the **filename** (`lecture-03.html` → room `CSC102-03`), and the lecture
index page lists new files automatically. No numbers to bump by hand.

Keep `hash:` identical in every lecture file — it's per-**password**, so
the same host password works for all of them.

## Controlling a different deck

The presenter always takes the deck from its `?deck=` parameter (there is
no default — the shared presenter at the server root doesn't belong to any
one course):

```text
http://<mac-ip>:8000/presenter.html?deck=/csc102/lecture-02.html
```

**The path must point at an existing deck file.** If it doesn't exist,
the dev server silently serves the reveal.js demo page in its place —
the presenter will show the demo slides and login will fail with
"No Seminar plugin in the deck".

The target deck needs the seminar plugin wired up (copy from
`csc102/index.html`):

- `<script>` tags for socket.io and `seminar/plugin.js`
- a `seminar: { server, url, room, hash, autoJoin: true }` block in
  `Reveal.initialize(...)`
- `RevealSeminar` in the `plugins: [...]` array
- `<aside class="notes">` elements for speaker notes (shown in the presenter)

## One-time setup

- **Host password hash**: open `http://localhost:4433` in a browser and
  generate a bcrypt hash for your chosen password, then set it as
  `seminar.hash` in the deck. The hash is stable — regenerate only when
  you change the password.
- **Room name**: any string; keep it the same for everyone (it lives in the
  deck config).

## Reusing this setup for another course

Copy the whole `csc102/` folder (e.g. to `csc201/`) inside the reveal.js
repo, then edit the copy's lecture files:

- Replace the example `<section>`s with your slides (speaker notes in
  `<aside class="notes">`).
- Change the `url:`/`room:` values (e.g. `'CSC201-01'`) so each course
  gets its own rooms.
- Keep `seminar.hash` as is — the hash is per-**password**, not per-deck,
  so the same host password works everywhere and never needs regenerating.

`presenter.html` and `Start Seminar.command` are not copied — both live at
the repo root and are shared by every course. The presenter takes each
course's deck from `?deck=`, and the launcher discovers course folders
(any subfolder whose deck uses `RevealSeminar`) automatically.

## Notes

- **Chalkboard**: the Current Slide panel shows the live deck, so you can
  draw directly on it (✏️ Draw annotates the slide, ▦ Board opens the
  chalkboard, 🎨 cycles the pen color, ⌫ Clear erases the slide). Everything
  you draw is broadcast through the seminar room — participants see it live.
  The same keys work as in a normal deck: B (board), C (draw), X (color),
  Delete (clear), plus ←/→ to navigate.
- Host the room from exactly **one** place — the presenter. All other
  viewers auto-join as participants. When the last host leaves, the room
  closes and participants are kicked out.
- Open pages through the deck server (`http://...`), not `file://` — the
  seminar server address is derived from the page hostname.
