#pragma once
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <time.h>

// Opt-in profiling. SKETCHYBAR_PROFILE=1 logs one stderr line per mach
// message with parse/refresh/total time and draw/window counters.
// SKETCHYBAR_TRACE_FILE=<path> appends the same lines plus click and display
// events, each prefixed with a wall-clock millisecond timestamp.
extern uint32_t g_profile_item_draws;
extern uint32_t g_profile_window_creates;
extern uint32_t g_profile_window_closes;
extern uint64_t g_profile_clear_ns;
extern uint64_t g_profile_paint_ns;
extern uint64_t g_profile_flush_ns;

#define PROFILE_TRACE_MAX_BYTES (50LL * 1024 * 1024)

static inline FILE* profile_stream(void) {
  static int initialized = 0;
  static FILE* stream = NULL;
  if (!initialized) {
    initialized = 1;
    const char* path = getenv("SKETCHYBAR_TRACE_FILE");
    if (path && path[0]) {
      struct stat st;
      if (stat(path, &st) != 0 || st.st_size < PROFILE_TRACE_MAX_BYTES) {
        stream = fopen(path, "a");
        if (stream) setvbuf(stream, NULL, _IOLBF, 0);
      }
    } else {
      const char* value = getenv("SKETCHYBAR_PROFILE");
      if (value && value[0] == '1') stream = stderr;
    }
  }
  return stream;
}

static inline bool profile_enabled(void) {
  return profile_stream() != NULL;
}

static inline uint64_t profile_now_ns(void) {
  return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}

static inline void profile_reset_counters(void) {
  g_profile_item_draws = 0;
  g_profile_window_creates = 0;
  g_profile_window_closes = 0;
  g_profile_clear_ns = 0;
  g_profile_paint_ns = 0;
  g_profile_flush_ns = 0;
}

__attribute__((format(printf, 1, 2)))
static inline void profile_log(const char* format, ...) {
  FILE* stream = profile_stream();
  if (!stream) return;
  if (stream != stderr && ftell(stream) >= PROFILE_TRACE_MAX_BYTES) return;
  fprintf(stream, "t=%llu ",
          (unsigned long long)(clock_gettime_nsec_np(CLOCK_REALTIME) / 1000000));
  va_list args;
  va_start(args, format);
  vfprintf(stream, format, args);
  va_end(args);
  fputc('\n', stream);
}
