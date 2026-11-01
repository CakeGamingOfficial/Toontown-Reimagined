#!/bin/bash
# Starts the dedicated district. Leave this terminal open.
# Ctrl+C tells connected toons the district is closing, then stops the server.
# Ctrl+C again stops it immediately.
GODOT="${HOME}/Godot_v4.7.2-stable_linux.x86_64"
PROJECT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$GODOT" ]; then
	echo "Could not find Godot at $GODOT"
	exit 1
fi
if [ ! -f "$PROJECT/project.godot" ]; then
	echo "Could not find the project at $PROJECT"
	exit 1
fi

chmod +x "$GODOT" 2>/dev/null
STOP_FILE="$(mktemp "${TMPDIR:-/tmp}/tt-stop.XXXXXX")"
stopping=0
server_pid=0

shutdown_server() {
	if [ "$stopping" -eq 1 ]; then
		echo "Stopping immediately."
		if [ "$server_pid" -ne 0 ]; then
			kill -KILL "$server_pid" 2>/dev/null || true
		fi
		rm -f "$STOP_FILE"
		exit 1
	fi
	stopping=1
	echo "Telling players the district is closing..."
	printf 'quit\n' > "$STOP_FILE"
}

trap shutdown_server INT TERM

"$GODOT" --headless --path "$PROJECT" -- --stop-file "$STOP_FILE" &
server_pid=$!
while kill -0 "$server_pid" 2>/dev/null; do
	wait "$server_pid" || true
done
status=$?
rm -f "$STOP_FILE"
exit "$status"
