#!/bin/bash
#
# Seminar — one-click stopper
#
# Stops the servers started by Start Seminar.command:
#
#   1. Seminar server  (port 4433)
#   2. Deck server     (vite, port 8000)
#
# Only processes listening on those two ports are touched —
# anything else on this Mac is left alone. Servers that are
# not running are reported and skipped.
#
# Double-click this file in Finder, or run it from a terminal.
# The first launch may need a right-click → Open to bypass
# Gatekeeper's unsigned-script warning.

SEMINAR_PORT=4433
DECK_PORT=8000

stop_port() {
	local port="$1"
	local name="$2"
	local pids

	pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null)

	if [ -z "$pids" ]; then
		echo "✓ $name not running (nothing on port $port)"
		return 0
	fi

	echo "Stopping $name (port $port, pid $(echo $pids | tr '\n' ' '))..."

	kill $pids 2>/dev/null

	# Give it a few seconds to shut down cleanly...
	for i in $(seq 1 20); do
		if ! lsof -tiTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
			echo "✓ $name stopped"
			return 0
		fi
		sleep 0.25
	done

	# ...then force.
	kill -9 $pids 2>/dev/null
	sleep 0.5

	if lsof -tiTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
		echo "✗ $name did not stop — check Activity Monitor for the pid above"
		return 1
	else
		echo "✓ $name stopped (forced)"
		return 0
	fi
}

echo "Seminar stopper"
echo "==============="
echo

stop_port "$SEMINAR_PORT" "Seminar server"
stop_port "$DECK_PORT" "Deck server"

echo
echo "Done."