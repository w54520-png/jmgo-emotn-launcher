---
name: jmgo-emotn-launcher
description: Use when an authorized JMGO H931 or Android 11 projector needs its default HOME replaced over ADB, EMOTN UI installed, or a bundled launcher used after ADB setup.
---

# JMGO EMOTN Launcher

Use this skill only on a projector the user owns or is authorized to administer. It targets the verified H931 Android 11 firmware family; do not apply the vendor root path to another model.

## Operating rules

- Confirm the target IP and that `adb devices` reports `device`.
- Run the bundled probe before changing anything. Require `ro.product.model=H931`, SDK 30, `ro.build.version.incremental=1.1.31.31`, and `ro.debuggable=1`.
- Install `assets/emotn-ui.apk` only when `com.oversea.aslauncher` is absent. If EMOTN UI is unavailable, use the bundled launcher or require an owner-supplied APK with `--emotn-apk`.
- Use `--bundled-launcher` to install the original, dependency-free `Projector Home` included in this Skill instead of EMOTN UI. If EMOTN is unavailable, `apply` falls back to it automatically.
- Treat `homefix.apk` as optional; do not install or enable it by default. Use `--with-homefix` only when the device-specific fallback service has been tested.
- On verified H931 firmware, use `--keep-background` when the user needs long-running third-party apps such as a VPN client. It disables Hippo's vendor background cleaner and enables the legacy launcher package only for its messenger service; EMOTN remains the preferred HOME.
- Keep `com.jmgo.arwen`, `com.jmgo.hippo`, `com.jmgo.autokeystone`, `com.jmgo.tofautofocus`, `com.jmgo.update`, `com.jmgo.remotecontrolota`, and `com.mediatek.*` enabled. This skill changes the launcher only; it does not debloat unrelated packages.
- Back up every device file and the current preferred HOME component before editing. Never use `adb remount`, delete system APKs, factory-reset, or flash boot/recovery/vendor partitions.
- Ask the user before rebooting unless the user explicitly requested unattended execution.
- Treat `assets/emotn-ui.apk` and `assets/rootexec.dex` as owner-device artifacts and redistribute them only with permission. `assets/projector-launcher.apk` is the original launcher built from `launcher/`.

## Runbook

Read `references/device-notes.md` for the firmware-specific rationale, then run:

```bash
scripts/jmgo-emotn.sh probe --host 192.168.0.24:5555
scripts/jmgo-emotn.sh apply --host 192.168.0.24:5555 --reboot
scripts/jmgo-emotn.sh verify --host 192.168.0.24:5555
```

To use the bundled launcher instead of EMOTN UI:

```bash
scripts/jmgo-emotn.sh apply --host 192.168.0.24:5555 --bundled-launcher --reboot
```

`references/disabled-package-observation.md` records a device-specific disabled-package snapshot, and `references/background-retention.md` records the tested H931 background-retention workaround. The Skill does not automatically disable the app store, game center, or Arwen.

Use `--yes` only after the user has approved the device changes and reboot. Use `--emotn-apk PATH`, `--homefix-apk PATH`, `--with-homefix`, and `--keep-background` only when those optional behaviors are appropriate. The `apply` command creates a remote backup under `/data/local/tmp/jmgo-emotn-backup/` and prints its location.

If verification reports a HOME chooser, tell the user to press HOME, choose **EMOTN UI**, and select **Always**. Re-run `verify`; the expected resolver is `com.oversea.aslauncher/.ui.main.MainActivity`.

## Rollback

Before rollback, confirm the backup directory printed by `apply` belongs to this run. Then run:

```bash
scripts/jmgo-emotn.sh restore --host 192.168.0.24:5555 --reboot
```

Rollback restores `launcher.cfg`, the vendor keylayout, secure accessibility settings, the saved preferred HOME component, the saved `persist.jmgo.home` value, the Hippo BPM property, and the legacy launcher package state. It leaves the EMOTN APK installed so the user can choose it again later.

## Failure handling

- If the model/build check fails, stop and report the exact properties; do not guess a compatible firmware.
- If the vendor `hippo` root bridge is missing or does not return `uid=0`, stop before editing `/vendor` or `/data/system`.
- If the keylayout is not `Vendor_1d5a_Product_c081.kl`, leave key mapping untouched and report that the remote mapping needs a device-specific study.
- If the device does not return after reboot, wait for it to reappear on the same IP, then use the printed backup path and the device's physical Settings/launcher controls before attempting rollback.
