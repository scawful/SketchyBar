#!/usr/bin/env python3
"""Summarize a SKETCHYBAR_TRACE_FILE log.

Usage: bench/trace_report.py <trace.log> [--since-hours N]

Reports click-to-popup latency (click event until the popup toggle message
finished rendering), bucketed by how long SketchyBar had been idle since the
previous click, plus space/display switch settle times and event-lock waits.
"""
import argparse
import re
import statistics
import time

LINE = re.compile(r"^t=(\d+) kind=(\w+) ?(.*)$")
FIELD = re.compile(r"(\w+)=(\S+)")
IDLE_BUCKETS = [(60, "<1m"), (600, "1-10m"), (3600, "10-60m"), (float("inf"), ">60m")]
CLICK_WINDOW_MS = 3000
SETTLE_WINDOW_MS = 2000


def parse(path, since_ms):
    events = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            match = LINE.match(raw.strip())
            if not match:
                continue
            t = int(match.group(1))
            if t < since_ms:
                continue
            fields = dict(FIELD.findall(match.group(3).split(" msg=")[0]))
            events.append((t, match.group(2), fields))
    return events


def ms(value):
    return float(value.rstrip("ms"))


def pct(values, q):
    if not values:
        return float("nan")
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(q * len(ordered)))]


def summary(label, values):
    if not values:
        return f"{label:<28} n=0"
    return (f"{label:<28} n={len(values):<5} med={statistics.median(values):7.1f}ms "
            f"p95={pct(values, 0.95):7.1f}ms max={max(values):7.1f}ms")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace")
    parser.add_argument("--since-hours", type=float, default=0)
    args = parser.parse_args()
    since_ms = int((time.time() - args.since_hours * 3600) * 1000) if args.since_hours else 0
    events = parse(args.trace, since_ms)

    msgs = [(t, f) for t, kind, f in events if kind == "msg"]
    click_latency = {label: [] for _, label in IDLE_BUCKETS}
    cross_display = []
    last_click = None
    for t, kind, f in events:
        if kind != "click":
            continue
        idle_s = (t - last_click) / 1000 if last_click else float("inf")
        last_click = t
        item = f.get("item")
        toggle = next((mt for mt, mf in msgs
                       if t <= mt <= t + CLICK_WINDOW_MS and mf.get("popup") == item), None)
        if toggle is None:
            continue
        latency = toggle - t
        bucket = next(label for limit, label in IDLE_BUCKETS if idle_s <= limit)
        click_latency[bucket].append(latency)
        if f.get("adid") != f.get("active"):
            cross_display.append(latency)

    print("click -> popup rendered, by idle time since previous click")
    for _, label in IDLE_BUCKETS:
        print("  " + summary(label, click_latency[label]))
    print("  " + summary("cross-display clicks", cross_display))

    print("\nspace/display switch: handler time and time until messages settle")
    for kind in ("space_change", "display_change"):
        handlers, settle, burst = [], [], []
        for t, k, f in events:
            if k != kind:
                continue
            handlers.append(ms(f.get("handler", "0ms")))
            window = [(mt, mf) for mt, mf in msgs if t <= mt <= t + SETTLE_WINDOW_MS]
            if window:
                settle.append(window[-1][0] - t)
                burst.append(sum(ms(mf.get("total", "0ms")) for _, mf in window))
        print("  " + summary(f"{kind} handler", handlers))
        print("  " + summary(f"{kind} settle", settle))
        print("  " + summary(f"{kind} render work", burst))

    waits = [ms(f["wait"]) for _, kind, f in events if kind == "lock_wait"]
    totals = [ms(f["total"]) for _, f in msgs]
    print("\nevent loop")
    print("  " + summary("lock waits > 2ms", waits))
    print("  " + summary("message handling", totals))
    span_h = (events[-1][0] - events[0][0]) / 3.6e6 if events else 0
    print(f"\n{len(events)} events over {span_h:.1f}h")


if __name__ == "__main__":
    main()
