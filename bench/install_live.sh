#!/bin/bash
# Install bin/sketchybar as Barista's fork binary and restart the service.
# Rolls back to the previously installed binary (or Homebrew's, if there was
# none) when the new one does not stay up.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEST_DIR="$HOME/.local/libexec/sketchybar-barista"
DEST="$DEST_DIR/sketchybar"
PREV="$DEST.prev"
SERVICE="gui/$UID/homebrew.mxcl.sketchybar"
SETTLE="${SETTLE:-15}"

server_pid() { pgrep -f 'sketchybar --config' | head -1; }

mkdir -p "$DEST_DIR"
rm -f "$PREV"
[ -f "$DEST" ] && cp -p "$DEST" "$PREV"
cp "$ROOT/bin/sketchybar" "$DEST.new"
mv -f "$DEST.new" "$DEST"
launchctl kickstart -k "$SERVICE"
sleep 3
first_pid="$(server_pid || true)"
sleep "$SETTLE"
pid="$(server_pid || true)"
command="$(ps -o command= -p "${pid:-0}" 2>/dev/null || true)"

if [ -n "$pid" ] && [ "$pid" = "$first_pid" ] && [[ "$command" == "$DEST "* ]]; then
  echo "fork running: pid $pid (previous binary kept at $PREV)"
  exit 0
fi

echo "fork unstable (pid ${first_pid:-none} -> ${pid:-none}); rolling back" >&2
if [ -f "$PREV" ]; then
  mv -f "$PREV" "$DEST"
else
  rm -f "$DEST"
fi
launchctl kickstart -k "$SERVICE"
exit 1
