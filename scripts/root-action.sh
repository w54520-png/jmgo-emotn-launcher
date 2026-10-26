#!/system/bin/sh
set -eu

ACTION="${1:-}"
ENABLE_HOMEFIX="${2:-0}"
KEEP_BACKGROUND="${3:-0}"
BACKUP="/data/local/tmp/jmgo-emotn-backup"
CFG="/vendor/etc/launcher.cfg"
KL="/vendor/usr/keylayout/Vendor_1d5a_Product_c081.kl"
SECURE="/data/system/users/0/settings_secure.xml"
PERSIST_FILE="$BACKUP/persist.jmgo.home.orig"
HOME_FILE="$BACKUP/home.component.orig"
BPM_FILE="$BACKUP/persist.hippo.debug.bpm.orig"
LAUNCHER_STATE_FILE="$BACKUP/com.jmgo.launcher.state.orig"
HOMEFIX="local.jmgo.homefix/local.jmgo.homefix.HomeRedirectService"

backup_once() {
  src="$1"
  dst="$2"
  if [ -e "$src" ] && [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    chmod 644 "$dst"
  fi
}

mkdir -p "$BACKUP"

case "$ACTION" in
  probe)
    id
    getprop persist.jmgo.home
    ;;
  backup)
    backup_once "$CFG" "$BACKUP/launcher.cfg.orig"
    backup_once "$KL" "$BACKUP/Vendor_1d5a_Product_c081.kl.orig"
    backup_once "$SECURE" "$BACKUP/settings_secure.xml.orig"
    if [ ! -e "$HOME_FILE" ]; then
      cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -1 > "$HOME_FILE" || true
      chmod 644 "$HOME_FILE"
    fi
    if [ ! -e "$PERSIST_FILE" ]; then
      getprop persist.jmgo.home > "$PERSIST_FILE"
      chmod 644 "$PERSIST_FILE"
    fi
    if [ ! -e "$BPM_FILE" ]; then
      bpm_value="$(getprop persist.hippo.debug.bpm)"
      if [ -n "$bpm_value" ]; then
        printf 'value:%s\n' "$bpm_value" > "$BPM_FILE"
      else
        printf '%s\n' unset > "$BPM_FILE"
      fi
      chmod 644 "$BPM_FILE"
    fi
    if [ ! -e "$LAUNCHER_STATE_FILE" ]; then
      if pm list packages -d | grep -q '^package:com.jmgo.launcher$'; then
        printf '%s\n' disabled > "$LAUNCHER_STATE_FILE"
      else
        printf '%s\n' enabled > "$LAUNCHER_STATE_FILE"
      fi
      chmod 644 "$LAUNCHER_STATE_FILE"
    fi
    echo "$BACKUP"
    ;;
  apply)
    backup_once "$CFG" "$BACKUP/launcher.cfg.orig"
    backup_once "$KL" "$BACKUP/Vendor_1d5a_Product_c081.kl.orig"
    backup_once "$SECURE" "$BACKUP/settings_secure.xml.orig"
    if [ ! -e "$HOME_FILE" ]; then
      cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -1 > "$HOME_FILE" || true
      chmod 644 "$HOME_FILE"
    fi
    if [ ! -e "$PERSIST_FILE" ]; then
      getprop persist.jmgo.home > "$PERSIST_FILE"
      chmod 644 "$PERSIST_FILE"
    fi
    if [ ! -e "$BPM_FILE" ]; then
      bpm_value="$(getprop persist.hippo.debug.bpm)"
      if [ -n "$bpm_value" ]; then
        printf 'value:%s\n' "$bpm_value" > "$BPM_FILE"
      else
        printf '%s\n' unset > "$BPM_FILE"
      fi
      chmod 644 "$BPM_FILE"
    fi
    if [ ! -e "$LAUNCHER_STATE_FILE" ]; then
      if pm list packages -d | grep -q '^package:com.jmgo.launcher$'; then
        printf '%s\n' disabled > "$LAUNCHER_STATE_FILE"
      else
        printf '%s\n' enabled > "$LAUNCHER_STATE_FILE"
      fi
      chmod 644 "$LAUNCHER_STATE_FILE"
    fi

    if grep -q '^launcher:' "$CFG"; then
      sed 's/^launcher:.*/launcher: com.oversea.aslauncher/' "$CFG" > "$CFG.tmp"
      cp "$CFG.tmp" "$CFG"
      rm -f "$CFG.tmp"
    else
      printf '%s\n' 'launcher: com.oversea.aslauncher' >> "$CFG"
    fi

    if [ -e "$KL" ]; then
      line="$(grep -E '^key 264 ' "$KL" || true)"
      case "$line" in
        'key 264   HOME'|'key 264 HOME') ;;
        'key 264   NEW_LUNA'|'key 264 NEW_LUNA') sed -i 's/^key 264   NEW_LUNA$/key 264   HOME/; s/^key 264 NEW_LUNA$/key 264 HOME/' "$KL" ;;
        *) echo "unexpected key 264 mapping: $line" >&2; exit 21 ;;
      esac
      sed -i 's/^key 195   HOME$/# key 195 (undefined)/; s/^key 195 HOME$/# key 195 (undefined)/' "$KL"
    fi

    if [ "$ENABLE_HOMEFIX" = 1 ]; then
      pm grant local.jmgo.homefix android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
      if [ -e "$SECURE" ] && ! grep -q "$HOMEFIX" "$SECURE"; then
        current="$(grep -o 'name="enabled_accessibility_services" value="[^"]*"' "$SECURE" | sed 's/.*value="//; s/"$//' | head -1)"
        if [ -n "$current" ]; then
          updated="$current:$HOMEFIX"
        else
          updated="$HOMEFIX"
        fi
        sed -i "s|name=\"enabled_accessibility_services\" value=\"[^\"]*\"|name=\"enabled_accessibility_services\" value=\"$updated\"|" "$SECURE"
      fi
    fi
    if [ "$KEEP_BACKGROUND" = 1 ]; then
      setprop persist.hippo.debug.bpm 0
      pm enable --user 0 com.jmgo.launcher >/dev/null 2>&1 || true
      hippo_pid="$(pidof com.jmgo.hippo || true)"
      [ -z "$hippo_pid" ] || kill -9 $hippo_pid || true
    fi
    cmd package set-home-activity com.oversea.aslauncher/.ui.main.MainActivity 2>/dev/null || true
    setprop persist.jmgo.home aslauncher
    ;;
  restore)
    [ -e "$BACKUP/launcher.cfg.orig" ] && cp "$BACKUP/launcher.cfg.orig" "$CFG"
    [ -e "$BACKUP/Vendor_1d5a_Product_c081.kl.orig" ] && cp "$BACKUP/Vendor_1d5a_Product_c081.kl.orig" "$KL"
    [ -e "$BACKUP/settings_secure.xml.orig" ] && cp "$BACKUP/settings_secure.xml.orig" "$SECURE"
    if [ -s "$HOME_FILE" ]; then
      original_home="$(cat "$HOME_FILE")"
      case "$original_home" in
        */*) cmd package set-home-activity "$original_home" 2>/dev/null || true ;;
      esac
    fi
    if [ -e "$BPM_FILE" ]; then
      original_bpm="$(cat "$BPM_FILE")"
      case "$original_bpm" in
        value:*) setprop persist.hippo.debug.bpm "${original_bpm#value:}" ;;
        unset) setprop persist.hippo.debug.bpm "" ;;
      esac
    fi
    if [ -e "$LAUNCHER_STATE_FILE" ]; then
      case "$(cat "$LAUNCHER_STATE_FILE")" in
        disabled) pm disable-user --user 0 com.jmgo.launcher >/dev/null 2>&1 || true ;;
        enabled) pm enable --user 0 com.jmgo.launcher >/dev/null 2>&1 || true ;;
      esac
    fi
    if [ -e "$PERSIST_FILE" ]; then
      setprop persist.jmgo.home "$(cat "$PERSIST_FILE")"
    fi
    ;;
  *)
    echo "usage: root-action.sh probe|backup|apply|restore" >&2
    exit 2
    ;;
esac
