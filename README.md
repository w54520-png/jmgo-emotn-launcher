# JMGO EMOTN Launcher Skill

This Codex Skill changes the HOME launcher on an authorized JMGO H931 projector
over ADB. It verifies the device, backs up vendor routing files, installs a
launcher, maps the remote HOME key, and supports rollback.

## Launcher choices

- Existing `com.oversea.aslauncher` / owner-supplied EMOTN UI is preferred.
- `--bundled-launcher` installs the original `Projector Home` in
  `assets/projector-launcher.apk`. It lists installed apps, supports remote
  focus navigation, and opens Android Settings.
- The bundled launcher is clean-room code and is not EMOTN UI.

## Example

```bash
scripts/jmgo-emotn.sh apply \
  --host 192.168.0.24:5555 \
  --bundled-launcher \
  --keep-background \
  --reboot
```

Use only on a projector you own or administer. The device-specific EMOTN APK
and root bridge may require separate redistribution permission.
