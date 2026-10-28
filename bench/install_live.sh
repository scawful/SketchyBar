#!/bin/bash
# Install bin/sketchybar as Barista's fork binary and restart the service.
# Rolls back to the Homebrew binary if the fork does not stay up.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEST_DIR="$HOME/.local/libexec/sketchybar-barista"
DEST="$DEST_DIR/sketchybar"
SERVICE="gui/$UID/homebrew.mxcl.sketchybar"
SETTLE="${SETTLE:-15}"

server_pid() { pgrep -f 'sketchybar --config' | head -1; }

mkdir -p "$DEST_DIR"
cp "$ROOT/bin/sketchybar" "$DEST.new"
mv -f "$DEST.new" "$DEST"
launchctl kickstart -k "$SERVICE"
sleep 3
first_pid="$(server_pid || true)"
sleep "$SETTLE"
pid="$(server_pid || true)"
command="$(ps -o command= -p "${pid:-0}" 2>/dev/null || true)"

if [ -n "$pid" ] && [ "$pid" = "$first_pid" ] && [[ "$command" == "$DEST "* ]]; then
  echo "fork running: pid $pid"
  exit 0
fi

echo "fork unstable (pid ${first_pid:-none} -> ${pid:-none}); rolling back" >&2
rm -f "$DEST"
launchctl kickstart -k "$SERVICE"
exit 1
