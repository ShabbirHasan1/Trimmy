#!/usr/bin/env bash
# Reset Trimmy: kill running instances, build, test, package, relaunch, verify.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/Trimmy.app"
APP_PROCESS_PATTERN="Trimmy.app/Contents/MacOS/Trimmy"
DEBUG_PROCESS_PATTERN="${ROOT_DIR}/.build/debug/Trimmy"
RELEASE_PROCESS_PATTERN="${ROOT_DIR}/.build/release/Trimmy"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

kill_all_trimmy() {
  for _ in {1..10}; do
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -x "Trimmy" 2>/dev/null || true
    if ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 \
      && ! pgrep -f "${DEBUG_PROCESS_PATTERN}" >/dev/null 2>&1 \
      && ! pgrep -f "${RELEASE_PROCESS_PATTERN}" >/dev/null 2>&1 \
      && ! pgrep -x "Trimmy" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
  done
}

# 1) Kill all running Trimmy instances (debug and packaged).
log "==> Killing existing Trimmy instances"
kill_all_trimmy

# 2) Build, test, package.
run_step "swift build" swift build -q
run_step "swift test" swift test -q
run_step "package app" "${ROOT_DIR}/Scripts/package_app.sh" debug

# 3) Launch the packaged app.
run_step "launch app" open "${APP_BUNDLE}"

# 4) Verify the app stays up for at least 1s.
sleep 1
if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
  log "OK: Trimmy is running."
else
  fail "App exited immediately. Check crash logs in Console.app (User Reports)."
fi
