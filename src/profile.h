#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Opt-in message profiling: SKETCHYBAR_PROFILE=1 logs one stderr line per
// mach message with parse/refresh/total time and draw/window counters.
extern uint32_t g_profile_item_draws;
extern uint32_t g_profile_window_creates;
extern uint32_t g_profile_window_closes;

static inline bool profile_enabled(void) {
  static int enabled = -1;
  if (enabled < 0) {
    const char* value = getenv("SKETCHYBAR_PROFILE");
    enabled = value && value[0] == '1';
  }
  return enabled;
}

static inline uint64_t profile_now_ns(void) {
  return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}

static inline void profile_reset_counters(void) {
  g_profile_item_draws = 0;
  g_profile_window_creates = 0;
  g_profile_window_closes = 0;
}
