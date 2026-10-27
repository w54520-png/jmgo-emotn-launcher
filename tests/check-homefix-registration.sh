#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_ACTION="$ROOT_DIR/scripts/root-action.sh"
RUNNER="$ROOT_DIR/scripts/jmgo-emotn.sh"

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if ! grep -Eq "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require 'HOMEFIX="local\.jmgo\.homefix/local\.jmgo\.homefix\.HomeRedirectService"' "$ROOT_ACTION" \
  'HomeFix must use the fully-qualified accessibility component.'
require 'setprop persist\.jmgo\.home "\$PERSIST_HOME"' "$ROOT_ACTION" \
  'persist.jmgo.home must be set inside the root action invoked through rootexec.dex.'
require 'pidof system_server' "$ROOT_ACTION" \
  'A changed accessibility XML must restart system_server so it rereads the setting.'
require 'kill -9 \$system_server_pid' "$ROOT_ACTION" \
  'The system_server PID must be killed after a changed accessibility XML.'
require 'root_action set-persist' "$RUNNER" \
  'Apply after reboot must reassert persist.jmgo.home through the root bridge.'

printf 'PASS: HomeFix registration safeguards are present.\n'
