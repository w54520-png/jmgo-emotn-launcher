#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB_BIN="${ADB:-adb}"
HOST="${ADB_HOST:-}"
EMOTN_APK="${EMOTN_APK:-$SKILL_DIR/assets/emotn-ui.apk}"
BUNDLED_LAUNCHER_APK="${BUNDLED_LAUNCHER_APK:-$SKILL_DIR/assets/projector-launcher.apk}"
HOMEFIX_APK="${HOMEFIX_APK:-$SKILL_DIR/assets/homefix.apk}"
ROOT_DEX="$SKILL_DIR/assets/rootexec.dex"
REMOTE_DIR="/data/local/tmp/jmgo-emotn"
REMOTE_ROOT_SCRIPT="$REMOTE_DIR/root-action.sh"

usage() {
  cat <<'EOF'
Usage: jmgo-emotn.sh <probe|apply|verify|restore> --host HOST [options]

Options:
  --host HOST          ADB endpoint, for example 192.168.0.24:5555
  --emotn-apk PATH     Owner-supplied EMOTN UI APK
  --bundled-launcher    Use the original Projector Home bundled with this Skill
  --homefix-apk PATH   Owner-supplied optional HOME fallback APK
  --with-homefix       Install and enable the optional HOME fallback
  --keep-background     Disable H931 BPM cleanup and keep the messenger service available
  --reboot             Reboot after apply or restore
  --yes                Skip the confirmation prompt for device changes/reboot
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    probe|apply|verify|restore) ACTION="$1"; shift ;;
    --host) HOST="${2:-}"; shift 2 ;;
    --emotn-apk) EMOTN_APK="${2:-}"; shift 2 ;;
    --bundled-launcher) USE_BUNDLED_LAUNCHER=1; shift ;;
    --homefix-apk) HOMEFIX_APK="${2:-}"; shift 2 ;;
    --with-homefix) WITH_HOMEFIX=1; shift ;;
    --keep-background) KEEP_BACKGROUND=1; shift ;;
    --reboot) REBOOT=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

: "${ACTION:?missing action}"
: "${HOST:?missing --host}"
REBOOT="${REBOOT:-0}"
YES="${YES:-0}"
WITH_HOMEFIX="${WITH_HOMEFIX:-0}"
KEEP_BACKGROUND="${KEEP_BACKGROUND:-0}"
USE_BUNDLED_LAUNCHER="${USE_BUNDLED_LAUNCHER:-0}"
SERIAL="$HOST"

device_adb() { "$ADB_BIN" -s "$SERIAL" "$@"; }
shell() { device_adb shell "$@"; }
prop() { shell getprop "$1" | tr -d '\r'; }

connect() {
  "$ADB_BIN" connect "$HOST" >/dev/null 2>&1 || true
  state="$($ADB_BIN devices | awk -v h="$HOST" '$1==h {print $2}')"
  [ "$state" = "device" ] || die "ADB endpoint is not authorized/online: $HOST ($state)"
}

check_identity() {
  [ "$(prop ro.product.model)" = "H931" ] || die "unsupported model: $(prop ro.product.model)"
  [ "$(prop ro.build.version.sdk)" = "30" ] || die "unsupported SDK: $(prop ro.build.version.sdk)"
  [ "$(prop ro.build.version.incremental)" = "1.1.31.31" ] || die "unsupported firmware: $(prop ro.build.version.incremental)"
  [ "$(prop ro.debuggable)" = "1" ] || die "ro.debuggable is not 1"
}

push_root_bridge() {
  [ -f "$ROOT_DEX" ] || die "missing $ROOT_DEX; provide the owner-device root bridge asset"
  device_adb shell "mkdir -p '$REMOTE_DIR'"
  device_adb push "$ROOT_DEX" "$REMOTE_DIR/rootexec.dex" >/dev/null
  device_adb push "$SCRIPT_DIR/root-action.sh" "$REMOTE_ROOT_SCRIPT" >/dev/null
  device_adb shell "chmod 755 '$REMOTE_ROOT_SCRIPT'"
  HIPPO_APK="$(shell 'find /system/system_ext/app /system_ext/app /vendor/app -type f -iname "*hippo*.apk" 2>/dev/null | head -1' | tr -d '\r')"
  [ -n "$HIPPO_APK" ] || die "could not locate the H931 hippo system APK"
}

root_action() {
  action="$1"
  extra="${2:-}"
  extra_two="${3:-}"
  extra_three="${4:-}"
  command="sh $REMOTE_ROOT_SCRIPT $action $extra $extra_two $extra_three"
  device_adb shell "CLASSPATH=$REMOTE_DIR/rootexec.dex:$HIPPO_APK app_process /system/bin local.jmgo.diagnostic.RootExec '$command'" 2>&1 | tee /tmp/jmgo-emotn-root.out
  sleep 1
}

root_probe() {
  root_action probe
  device_adb shell "CLASSPATH=$REMOTE_DIR/rootexec.dex:$HIPPO_APK app_process /system/bin local.jmgo.diagnostic.RootExec 'id > $REMOTE_DIR/root-id.out; chmod 644 $REMOTE_DIR/root-id.out'" >/dev/null 2>&1
  sleep 1
  id_output="$(shell cat "$REMOTE_DIR/root-id.out" 2>/dev/null || true)"
  printf '%s\n' "$id_output"
  echo "$id_output" | grep -q 'uid=0(root)' || die "vendor root bridge did not return uid=0"
}

install_if_missing() {
  if [ "$USE_BUNDLED_LAUNCHER" = 1 ]; then
    TARGET_PACKAGE="com.codex.projector.launcher"
    TARGET_ACTIVITY="com.codex.projector.launcher/.MainActivity"
    if ! shell pm path "$TARGET_PACKAGE" >/dev/null 2>&1; then
      [ -f "$BUNDLED_LAUNCHER_APK" ] || die "bundled launcher is absent: $BUNDLED_LAUNCHER_APK"
      device_adb install -r "$BUNDLED_LAUNCHER_APK"
    fi
  elif shell pm path com.oversea.aslauncher >/dev/null 2>&1; then
    TARGET_PACKAGE="com.oversea.aslauncher"
    TARGET_ACTIVITY="com.oversea.aslauncher/.ui.main.MainActivity"
  elif [ -f "$EMOTN_APK" ]; then
    device_adb install -r "$EMOTN_APK"
    TARGET_PACKAGE="com.oversea.aslauncher"
    TARGET_ACTIVITY="com.oversea.aslauncher/.ui.main.MainActivity"
  elif [ -f "$BUNDLED_LAUNCHER_APK" ]; then
    echo "EMOTN UI APK unavailable; falling back to bundled Projector Home"
    device_adb install -r "$BUNDLED_LAUNCHER_APK"
    TARGET_PACKAGE="com.codex.projector.launcher"
    TARGET_ACTIVITY="com.codex.projector.launcher/.MainActivity"
  else
    die "no launcher APK available; provide --emotn-apk PATH or use the bundled asset"
  fi
  if [ "$WITH_HOMEFIX" = 1 ] && ! shell pm path local.jmgo.homefix >/dev/null 2>&1; then
    [ -f "$HOMEFIX_APK" ] || die "HomeFix requested but APK is absent: $HOMEFIX_APK"
    device_adb install -r "$HOMEFIX_APK"
  fi
  shell pm path "$TARGET_PACKAGE" >/dev/null || die "launcher package is unavailable after install: $TARGET_PACKAGE"
}

confirm_change() {
  [ "$YES" = 1 ] && return
  printf 'Apply launcher changes to %s? Type yes: ' "$HOST" >&2
  read -r answer
  [ "$answer" = yes ] || die "cancelled"
}

confirm_reboot() {
  [ "$REBOOT" = 1 ] || return
  [ "$YES" = 1 ] && return
  printf 'Reboot %s now? Type yes: ' "$HOST" >&2
  read -r answer
  [ "$answer" = yes ] || die "changes applied; reboot skipped"
}

verify() {
  echo "persist.jmgo.home=$(prop persist.jmgo.home)"
  echo "persist.hippo.debug.bpm=$(prop persist.hippo.debug.bpm)"
  echo "launcher.cfg:"
  shell cat /vendor/etc/launcher.cfg
  echo "keylayout:"
  device_adb shell "grep -E '^(key 264|# key 195)' /vendor/usr/keylayout/Vendor_1d5a_Product_c081.kl || true"
  echo "home resolver:"
  shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | tail -1
  echo "focused window:"
  shell dumpsys window | grep -m 2 -E 'mCurrentFocus|mFocusedApp' || true
  echo "accessibility:"
  shell dumpsys accessibility | grep -m 3 -A 2 -B 2 'local.jmgo.homefix' || true
}

connect
check_identity

case "$ACTION" in
  probe)
    printf 'model=%s sdk=%s firmware=%s build=%s\n' "$(prop ro.product.model)" "$(prop ro.build.version.sdk)" "$(prop ro.build.version.incremental)" "$(prop ro.build.display.id)"
    push_root_bridge
    root_probe
    verify
    ;;
  apply)
    confirm_change
    install_if_missing
    push_root_bridge
    root_probe
    root_action backup
    root_action apply "$WITH_HOMEFIX" "$KEEP_BACKGROUND" "$([ "$TARGET_PACKAGE" = com.codex.projector.launcher ] && echo bundled || echo emotn)"
    echo "remote backup: $REMOTE_DIR"
    confirm_reboot
    if [ "$REBOOT" = 1 ]; then
      device_adb reboot
      for _ in $(seq 1 60); do
        sleep 1
        "$ADB_BIN" connect "$HOST" >/dev/null 2>&1 || true
        state="$($ADB_BIN devices | awk -v h="$HOST" '$1==h {print $2}')"
        [ "$state" = device ] && break
      done
      connect
    fi
    verify
    ;;
  verify)
    verify
    ;;
  restore)
    confirm_change
    push_root_bridge
    root_probe
    root_action restore
    confirm_reboot
    [ "$REBOOT" = 1 ] && device_adb reboot
    ;;
esac
