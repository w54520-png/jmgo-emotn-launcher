# H931 Notes

## Why normal Android launcher commands fail

The H931 firmware contains a `JmgoWmHook` in the framework. It reads `/vendor/etc/launcher.cfg`, chooses a matching `launcher:` package, and rewrites the preferred HOME activity. `cmd package set-home-activity` can report success while the vendor hook later restores `com.jmgo.arwen`.

The durable routing change is to keep the vendor hook alive but change its launcher candidate to:

```text
launcher: com.oversea.aslauncher
```

The runtime property `persist.jmgo.home=aslauncher` helps the current session but may be rewritten to `launcher` or `arwen` during boot. The vendor configuration and Android's final HOME choice are the persistence sources.

The helper also calls `cmd package set-home-activity` for the verified EMOTN activity and backs up the previous resolved HOME component. If Android still presents a chooser, select **EMOTN UI** and **Always** once; later boots should use the saved preferred component.

On this H931 build, Hippo's `BackgroundProcessManager` can call `forceStopPackage` on third-party apps every 30 seconds. Setting `persist.hippo.debug.bpm=0` before restarting Hippo disables that vendor cleaner. Because Hippo also binds a fixed `com.jmgo.launcher/.service.JGMessengerService`, the tested workaround enables the legacy launcher package while leaving EMOTN as the preferred HOME. The `--keep-background` option applies and backs up both changes.

## Root bridge

The H931 build exposes a vendor `hippo` API. The bundled `rootexec.dex` calls the API with the API-30, three-argument signature and runs a supplied shell command asynchronously as:

```text
uid=0(root) context=u:r:hal_jmgohwmanager_default:s0
```

The skill must verify this result before touching `/vendor` or `/data/system`.

## Remote mapping

On the verified H931 remote, Linux reports the physical button as `BTN_8` with event code `264` and an additional `MSC_SCAN=195` tag. Android's keylayout uses the event code, so the correct mapping is:

```text
key 264 HOME
# key 195 (undefined)
```

Do not map `195` based only on the MSC scan tag.

## Protected components

Keep the optics, remote, input, and update components enabled. In particular, do not disable `com.jmgo.arwen` merely because it is the stock home: the vendor hook and fallback path depend on it. Do not disable `com.jmgo.hippo`, autofocus/keystone services, `com.jmgo.update`, `com.jmgo.remotecontrolota`, or any `com.mediatek.*` package in this launcher skill.
