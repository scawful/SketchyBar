#!/bin/bash
# Usage: popup_bench.sh <label> [pairs]
# Times raw popup.drawing on/off round trips against the running SketchyBar.
SB=/opt/homebrew/bin/sketchybar
LABEL="${1:-run}"
PAIRS="${2:-20}"
ITEMS=(control_center front_app clock volume apple_menu)
for item in "${ITEMS[@]}"; do $SB --set "$item" popup.drawing=off; done
for _ in 1 2 3; do $SB --set control_center popup.drawing=on; $SB --set control_center popup.drawing=off; done
perl -MTime::HiRes=time,sleep -e '
  my ($sb, $label, $pairs, @items) = @ARGV;
  my (%on, %off);
  for my $p (1..$pairs) {
    for my $it (@items) {
      my $s = time; system($sb, "--set", $it, "popup.drawing=on"); push @{$on{$it}}, (time-$s)*1000;
      sleep 0.08;
      $s = time; system($sb, "--set", $it, "popup.drawing=off"); push @{$off{$it}}, (time-$s)*1000;
      sleep 0.05;
    }
  }
  sub med { my @v = sort { $a <=> $b } @_; return $v[int(@v/2)] }
  sub p95 { my @v = sort { $a <=> $b } @_; return $v[int(@v*0.95)] }
  my (@all_on, @all_off);
  for my $it (@items) {
    push @all_on, @{$on{$it}}; push @all_off, @{$off{$it}};
    printf "%-8s %-15s open med %6.1f p95 %6.1f | close med %6.1f p95 %6.1f\n", $label, $it,
      med(@{$on{$it}}), p95(@{$on{$it}}), med(@{$off{$it}}), p95(@{$off{$it}});
  }
  printf "%-8s %-15s open med %6.1f p95 %6.1f | close med %6.1f p95 %6.1f\n", $label, "ALL",
    med(@all_on), p95(@all_on), med(@all_off), p95(@all_off);
' "$SB" "$LABEL" "$PAIRS" "${ITEMS[@]}"
