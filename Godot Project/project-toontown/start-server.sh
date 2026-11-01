#!/bin/bash
# Starts the dedicated district. Leave this terminal open. Ctrl+C stops it.
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
exec "$GODOT" --headless --path "$PROJECT"
