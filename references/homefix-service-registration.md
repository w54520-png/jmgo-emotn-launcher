# HomeFix Accessibility Registration on H931

This note records the verified registration sequence for the optional
`local.jmgo.homefix/local.jmgo.homefix.HomeRedirectService` accessibility
service on the authorized H931 (Android 11 / API 30 / firmware 1.1.31.31).

## Three required conditions

1. **Bypass the SettingsProvider package check.** The firmware's
   `SettingsProvider.mutateSecureSetting` rejects writes to
   `enabled_accessibility_services` unless the caller is
   `com.jmgo.hippo`. Consequently, `settings put secure` can return without
   an error but leave the stored value unchanged, even if a third-party app
   holds `WRITE_SECURE_SETTINGS`. The root action backs up and edits
   `/data/system/users/0/settings_secure.xml` instead.
2. **Store the fully-qualified component.** The setting must contain exactly
   `local.jmgo.homefix/local.jmgo.homefix.HomeRedirectService`; the abbreviated
   `.HomeRedirectService` form is listed under `Crashed services` on this
   build. With the full name, `dumpsys accessibility` shows the service in
   `Bound services` and no HomeFix entry in `Crashed services`.
3. **Restart `system_server` after changing the XML.** AccessibilityManager
   keeps the previous secure-setting value in memory. Once the backup-protected
   XML edit succeeds, run `kill -9 $(pidof system_server)` from the root bridge;
   init restarts it and it loads the persisted setting. A full reboot has the
   same effect. The project helper restarts only when it actually adds HomeFix.

## Why the provider API is not used

Do not use `app_process` with `IContentProvider.call` as an alternative.
Android 11 lacks `android.content.AttributionSource`, and this API level has
the four-argument provider signature `(method, arg, callingPackage, extras)`.
Calling it with API-31 arguments/positions can crash the provider and restart
`system_server`. The backed-up direct XML path is the stable device-specific
route.

## Verification

Run `scripts/jmgo-emotn.sh verify --host 192.168.0.24:5555`. Its accessibility
section prints the relevant bound/crashed lines and emits one of
`homefix_status=bound`, `homefix_status=crashed`, or `homefix_status=not-listed`.
Only `bound` with no HomeFix entry in `Crashed services` verifies registration.
