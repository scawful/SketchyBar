#!/bin/bash
# Usage: dirty_open_bench.sh <label> [rounds]
# Rewrites hidden popup rows the way a space-change script does, waits, then
# opens the popup and reports the open message's refresh time from the trace.
SB=/opt/homebrew/bin/sketchybar
TRACE="${SKETCHYBAR_TRACE_FILE:-$HOME/Library/Logs/sketchybar-barista/trace.log}"
LABEL="${1:-run}"
ROUNDS="${2:-15}"
HOST=control_center
ROWS=(cc.header cc.layout_ops_header cc.layout.bsp cc.layout.stack cc.layout.float)

$SB --set "$HOST" popup.drawing=off
start_ms=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000')
for round in $(seq 1 "$ROUNDS"); do
  args=()
  for row in "${ROWS[@]}"; do args+=(--set "$row" "label=Space $round $row"); done
  $SB "${args[@]}"
  sleep 0.4
  $SB --set "$HOST" popup.drawing=on
  sleep 0.3
  $SB --set "$HOST" popup.drawing=off
  sleep 0.3
done

awk -v t0="$start_ms" -v host="$HOST" -v label="$LABEL" '
  { split($1, t, "="); if (t[2] < t0) next }
  /kind=msg/ && $0 ~ ("popup=" host " ") && /popup.drawing=on/ {
    for (i = 1; i <= NF; i++) if ($i ~ /^refresh=/) { sub(/refresh=/, "", $i); sub(/ms/, "", $i); v[n++] = $i + 0 }
  }
  /kind=msg/ && /msg=--set cc.header/ {
    for (i = 1; i <= NF; i++) if ($i ~ /^refresh=/) { sub(/refresh=/, "", $i); sub(/ms/, "", $i); d[m++] = $i + 0 }
  }
  function med(a, k,   i, j, x) {
    for (i = 1; i < k; i++) { x = a[i]; for (j = i - 1; j >= 0 && a[j] > x; j--) a[j + 1] = a[j]; a[j + 1] = x }
    return k ? a[int(k / 2)] : -1
  }
  END { printf "%-10s open refresh med %6.1fms (n=%d) | dirty-update refresh med %6.1fms (n=%d)\n", label, med(v, n), n, med(d, m), m }
' "$TRACE"
