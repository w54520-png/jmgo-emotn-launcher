# H931 Background Retention

This is a device-specific result from the authorized H931 target on 2026-10-26.

## Root cause

Surfboard (`com.getsurfboard`) was not being reclaimed by low memory. Android `ApplicationExitInfo` repeatedly reported `reason=USER REQUESTED` with `description=stop com.getsurfboard due to from pid 1311`; PID 1311 was `com.jmgo.hippo`. Logcat showed Hippo calling `ActivityManager.forceStopPackage` on Surfboard and several media apps.

The Hippo APK contains `BackgroundProcessManager`. On this firmware it is enabled by default, checks third-party processes every 30 seconds, and applies a vendor kill policy. It is gated by `persist.hippo.debug.bpm`; an unset property defaults to enabled.

## Tested workaround

The following changes were applied and verified:

- Set `persist.hippo.debug.bpm=0`.
- Restarted Hippo so the static BPM switch was re-read.
- Enabled `com.jmgo.launcher` so Hippo's fixed `com.jmgo.launcher/.service.JGMessengerService` binding succeeds.
- Kept `com.oversea.aslauncher/.ui.main.MainActivity` as the preferred HOME.

After the change, Surfboard remained alive in the background for more than 70 seconds, beyond the vendor's 30-second check interval. No new Surfboard force-stop record appeared, and the JGMessengerService warning stopped. Core Hippo, autofocus, keystone, and update processes remained alive.

## Skill behavior

Use `scripts/jmgo-emotn.sh apply --keep-background ...` only when long-running third-party apps are required. The action backs up the BPM property and legacy launcher package state. `restore` puts both back; reboot after restore is recommended so Hippo re-reads its static switch.

This does not guarantee an app's own VPN service is healthy. If Surfboard still disconnects, inspect its VPN service, notification, and app-specific logs separately.
