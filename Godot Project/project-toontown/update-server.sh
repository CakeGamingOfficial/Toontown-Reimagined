#!/bin/bash
# Fast-forwards this checkout to the latest commit on its upstream branch.
# AMP: add a Manual scheduled task that runs this script, then restart the instance.
# This does not stop the running district. The new code loads on the next start.
PROJECT="$(cd "$(dirname "$0")" && pwd)"

if ! command -v git >/dev/null 2>&1; then
	echo "Could not find git."
	exit 1
fi
if ! git -C "$PROJECT" rev-parse --show-toplevel >/dev/null 2>&1; then
	echo "Could not find a git checkout at $PROJECT"
	exit 1
fi

ROOT="$(git -C "$PROJECT" rev-parse --show-toplevel)"
cd "$ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
	echo "The server has local changes. Leave them out of this checkout before updating."
	exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" = "HEAD" ]; then
	echo "This checkout is not on a branch."
	exit 1
fi

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -z "$UPSTREAM" ]; then
	echo "Branch $BRANCH has no upstream. Push it once with: git push -u origin $BRANCH"
	exit 1
fi

echo "Updating $BRANCH from $UPSTREAM"
GIT_TERMINAL_PROMPT=0 git pull --ff-only
status=$?
if [ "$status" -ne 0 ]; then
	echo "The update failed. The district is still on the old code."
	exit "$status"
fi

echo "Now at $(git rev-parse --short HEAD). Restart the district so this code loads."
exit 0
