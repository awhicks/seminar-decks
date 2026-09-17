#!/bin/bash
#
# Seminar — one-click starter
#
# Starts both servers needed for the seminar setup:
#
#   1. Seminar server  (~/src/seminar, port 4433)
#   2. Deck server     (this repo, node server.js, port 8000)
#
# Lives at this repo's root and is shared by every course folder
# (csc102, csc201, ...) — it discovers them automatically.
#
# Double-click this file in Finder, or run it from a terminal.
# Close this Terminal window (or press Ctrl-C) to stop servers
# that this script started.
#
# If a server is already running, it is left alone and reused.

# mise-managed node/npm are not on PATH in non-interactive shells
export PATH="$HOME/.local/share/mise/shims:$PATH"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEMINAR_DIR="$HOME/src/seminar"
SEMINAR_PORT=4433
DECK_PORT=8000

port_listening() {
	lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_port() {
	for i in $(seq 1 60); do
		port_listening "$1" && return 0
		sleep 0.5
	done
	return 1
}

echo "Seminar starter"
echo "==============="
echo

# --- Course folders -------------------------------------------------------
#
# A course folder is any subfolder whose deck (index.html or a
# lecture-XX.html) wires up the seminar plugin. New course folders
# are picked up automatically — no edits needed here.

COURSES=()
for dir in "$ROOT_DIR"/*/; do
	[ -d "$dir" ] || continue
	if grep -q "RevealSeminar" "$dir"index.html "$dir"lecture-*.html 2>/dev/null; then
		COURSES+=("$(basename "$dir")")
	fi
done

# --- Seminar server ------------------------------------------------------

if port_listening "$SEMINAR_PORT"; then
	echo "✓ Seminar server already running (port $SEMINAR_PORT)"
else
	if [ ! -d "$SEMINAR_DIR" ]; then
		echo "✗ Seminar server not found at $SEMINAR_DIR"
		echo "  Edit SEMINAR_DIR at the top of this script."
		exit 1
	fi

	echo "Starting seminar server..."
	(cd "$SEMINAR_DIR" && exec node server) &
	SEMINAR_PID=$!

	if wait_for_port "$SEMINAR_PORT"; then
		echo "✓ Seminar server running (port $SEMINAR_PORT)"
	else
		echo "✗ Seminar server did not come up — see errors above"
		exit 1
	fi
fi

echo

# --- Deck server ---------------------------------------------------------

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)

if [ "${#COURSES[@]}" -gt 0 ]; then
	echo "Once started, open:"
	echo
	for folder in "${COURSES[@]}"; do
		echo "  $folder"
		echo "    Projector:  http://localhost:$DECK_PORT/$folder/"
		if compgen -G "$ROOT_DIR/$folder/lecture-*.html" >/dev/null; then
			echo "    iPad:       http://${IP:-<mac-ip>}:$DECK_PORT/$folder/"
			echo "                (then tap a lecture's Presenter button)"
		else
			echo "    iPad:       http://${IP:-<mac-ip>}:$DECK_PORT/presenter.html?deck=/$folder/index.html"
		fi
		echo
	done
else
	echo "✗ No course folders found next to this script"
	echo "  (looking for subfolders whose decks use RevealSeminar)."
	exit 1
fi

if port_listening "$DECK_PORT"; then
	echo "✓ Deck server already running (port $DECK_PORT)"
	echo
	echo "Everything is up. You can close this window."
else
	# First run: install dependencies (also fills vendor/ with the
	# reveal.js engine and plugins that the decks reference).
	if [ ! -d "$ROOT_DIR/vendor" ]; then
		echo "First run — installing dependencies..."
		(cd "$ROOT_DIR" && npm install) || exit 1
		echo
	fi

	echo "Starting deck server..."
	echo
	# Foreground: closing this window stops the deck server (and
	# the seminar server, if this script started it). The server
	# binds to all interfaces so the iPad can connect.
	(cd "$ROOT_DIR" && exec npm start)
fi