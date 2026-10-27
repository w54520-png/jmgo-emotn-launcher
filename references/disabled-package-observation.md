# H931 Disabled-Package Observation

This is a device-specific observation from the authorized H931 target on 2026-10-26. It is evidence for review, not an instruction to disable packages on other devices.

## Current disabled packages

| Package | Partition/type | Observation | Recommendation |
| --- | --- | --- | --- |
| `com.jmgo.appshop` | system app | JmGO app market UI and download service are disabled; no related error was found in the sampled logs. | Candidate for a later opt-in test only. |
| `com.jmgo.appstore` | data app | App store and app-download services are disabled; no related error was found in the sampled logs. | Candidate for a later opt-in test only. |
| `com.jmgo.os.gamecenter` | data app | Game center activity/provider are disabled; no related error was found in the sampled logs. | Candidate for a later opt-in test only. |
| `com.jmgo.arwen` | updated system app | This historical sample had stock Arwen disabled while EMOTN remained the preferred HOME. Later testing established that this state can make HOME unusable when `persist.jmgo.home=arwen`. | Keep enabled. `startHomeHook` matches candidates with `pkg.contains(persist.jmgo.home)`; a disabled matching Arwen package cannot launch. |
| `com.jmgo.launcher` | updated system app | JmGO OS launcher is disabled. `com.jmgo.hippo` and other clients repeatedly attempt to bind `com.jmgo.launcher/.service.JGMessengerService`, producing `Unable to start service ... not found` warnings about every 10 seconds. | Do not include in the Skill's disable list. This is an observable side effect. |

## Health sample

- Boot completed; uptime was about 55 minutes at collection time.
- No new ANR was reported since boot.
- Display was on and the EMOTN/H931 core processes (`hippo`, autofocus, keystone, and update) were alive.
- The HomeFix accessibility service was listed as crashed. The later root-cause and corrected registration sequence are recorded in `homefix-service-registration.md`; it remains opt-in only.

## Decision

The launcher Skill records this inventory but does not disable any of these packages automatically. The three store/game packages need a longer observation period across reboot, projection, autofocus/keystone, remote input, OTA checks, and app installation before becoming an opt-in action. `com.jmgo.arwen` and `com.jmgo.launcher` must remain enabled: the former is a HOME fallback candidate, and the latter provides the messenger service Hippo attempts to bind.
