# Fire OS 7.7.1.7, no root: replacing the home screen, measured

Field notes from one Fire TV Stick, October 2026. Every command here was run on the
device; the timing numbers come from Android's own event log, and the extracted logs
are in [`bench/logs/`](bench/logs/).

**Device:** Fire TV Stick 3rd gen (`AFTSSS` / `sheldon`) · Fire OS **7.7.1.7**
(PS7717/5741) · Amazon Fire TV Home `7321874.1` · Android 9 / API 28 · no root.

**Discussion:** [XDA — Fire TV General](https://xdaforums.com/t/fire-os-7-7-1-7-the-home-key-is-eaten-by-amazoninputswitchservice-and-two-working-redirects-measured-1-3s-vs-6-3s.4805824/)

---

## Read this first: this is not a discovery

Other people solved this before I did, and for most readers one of their projects is
the better answer. I've listed all of them in [Prior art](#prior-art), with dates.

What is actually new here:

1. **A side-by-side measurement** of the two working redirect architectures on the
   same device, same day, same stimulus — because the difference between them is
   about five seconds, and nobody had published that ([section 4](#4-measurements)).
2. **The `AFTSSS` / PS7717 datapoint.** Existing work covers the same build on a Fire
   TV Edition TV, and older builds on Sticks.
3. **Naming the component that eats the HOME key:** `AmazonInputSwitchService`
   ([section 2.4](#24-why-home-never-reaches-the-filter-amazoninputswitchservice)).
   I could not find this named in any public write-up.

If you just want a launcher instead of Amazon's home screen:

- **Fire OS 8** → [Home on Fire](https://github.com/toolicious/home-on-fire). Its
  redirect is near-instant there.
- **Fire OS 7** → Shelf's guard plus the alarm setting below, **if you want it fast**.
  Home on Fire also works but takes ~6 s per HOME press on this build, hidden behind
  its loading animation. Measured, not guessed.

---

## TL;DR

| Approach | On Fire OS 7.7.1.7 |
|---|---|
| `cmd package set-home-activity` | Prints `Success`. Ignored. |
| `pm disable-user com.amazon.tv.launcher` | `Cannot disable a protected package` |
| `pm uninstall --user 0 com.amazon.tv.launcher` | `DELETE_FAILED_INTERNAL_ERROR` |
| `pm suspend` | No `SUSPEND_APPS` permission |
| Accessibility key filter (`LauncherHijack`, `FTVLaunchX`) | Service binds, receives **zero** HOME events |
| Foreground watcher (redirect to your launcher) | **Works.** 1.2–1.4 s to screen with Shelf + the alarm setting; ~6.3 s with Home on Fire |

Debloat works fine via `pm disable-user`; 20 packages removed here, 7 are protected.

---

## 1. The device

```console
$ adb connect <tv-ip>:5555
$ adb shell getprop ro.product.device      # sheldon
$ adb shell getprop ro.build.version.name  # 7.7.1.7
$ adb shell getprop ro.build.version.incremental  # PS7717/5741
$ adb shell dumpsys package com.amazon.tv.launcher | grep versionName  # 7321874.1
```

Developer options → ADB debugging must be on. Everything below runs over the network
as the `shell` user (uid 2000); no root, nothing written to `/system`.

---

## 2. What does not work, and how it fails

### 2.1 `cmd package set-home-activity`

```console
$ adb shell cmd package set-home-activity tv.shelf.home/.Home
Success

$ adb shell cmd package resolve-activity -c android.intent.category.HOME
priority=0 ... name=com.amazon.tv.launcher/.ui.HomeActivity_vNext
```

It reports success and changes nothing. Pressing HOME still opens Amazon's home. The
command writes the preferred home *hint*; Fire OS does not consult it for the HOME key.

### 2.2 Disabling or removing Amazon's launcher

```console
$ adb shell pm disable-user --user 0 com.amazon.tv.launcher
Exception: Cannot disable a protected package: com.amazon.tv.launcher

$ adb shell pm uninstall --user 0 com.amazon.tv.launcher
Failure [DELETE_FAILED_INTERNAL_ERROR]

$ adb shell pm suspend com.amazon.tv.launcher
Exception: Neither user 2000 nor current process has android.permission.SUSPEND_APPS
```

`com.amazon.firehomestarter` is protected the same way.

### 2.3 Accessibility key filtering

`LauncherHijack` and `FTVLaunchX` request `CAPABILITY_CAN_REQUEST_FILTER_KEY_EVENTS`
and filter `KEYCODE_HOME`. On this build the service binds, the capability is granted,
and the filter callback is never invoked for HOME.

**Verify it yourself, properly:** check with a real remote press, not just
`adb shell input keyevent 3`. adb-injected keys can take a different path through
`InputManager`, so a synthetic press can make a dead filter look alive or a working
one look broken.

### 2.4 Why HOME never reaches the filter: `AmazonInputSwitchService`

This firmware ships a dedicated service for input routing:

```console
$ adb shell ls /system/fireos/etc/init/ | grep -i input
amazoninputswitchservice_fosinit.xml
```

`com.amazon.inputswitch` / `AmazonInputSwitchService` sits between the remote and the
accessibility input filter, and it consumes the HOME key before the filter sees it.
That is consistent with everything observable on the device:

- D-pad keys **do** reach the accessibility filter; HOME does not.
- The launcher is protected at the package-manager level, so the key cannot be
  re-pointed at the AOSP level either.
- The window still changes to Amazon's home, which is why a **watcher** can react even
  though a **filter** cannot.

**Honesty about the evidence:** the service's existence and init entry are observed on
this build; the "it consumes HOME first" conclusion is an inference from the key
behaviour plus where the service sits in the stack. I have not decompiled it. If you
want to confirm, log `dumpsys activity services | grep -i inputswitch` while pressing
HOME on a remote.

---

## 3. What works: redirect, not interception

Something watches for Amazon's home activity becoming the foreground window and starts
your launcher on top. Two implementations exist, and they are **not** equivalent on
Fire OS 7.

### 3.1 Alarm-based guard (Shelf) — 1.2 s

Shelf's `Guard` accessibility service (which only watches window state, not screen
contents) starts the target through an `AlarmManager` `PendingIntent`.
`system_server` sends that alarm, and **system-server-originated launches are exempt
from the post-HOME app-switch lock**.

The exemption only helps if alarms may fire immediately, which by default they may not:
Android normally requires `min_futurity` (5 s) of lead time. Hence:

```console
$ adb shell settings put global alarm_manager_constants min_futurity=0
```

Remove that one setting and the trick collapses — measured in
[section 4](#4-measurements), 1.2 s becomes 1.7–4.0 s.

### 3.2 Normal launch (Home on Fire) — 6.3 s

Home on Fire starts the target with a normal activity launch, so it hits
`APP_SWITCH_DELAY_TIME`: Android holds back app launches for up to 5 s after a HOME
press. It covers the wait with a configurable loading mask. That mask is not cosmetic —
it is hiding the same lock the alarm path avoids.

Its own README says exactly this, so this is not a criticism of the app; it is the
reason the two numbers differ.

---

## 4. Measurements

**Method.** For every run: force-stop Kodi, start it, wait 6 s, clear the log,
`input keyevent 3` (HOME), wait 12 s, capture `logcat -b all -v time`.
Metric is wall-clock from Kodi pausing with `userLeaving=true` (the HOME press) to the
replacement launcher's `Displayed <component>` line — i.e. when it is actually on
screen, not when it was requested.

Script: [`bench/bench.sh`](bench/bench.sh). Raw extracts: [`bench/logs/`](bench/logs/).

| Config | Runs (ms) | Median |
|---|---|---|
| Shelf guard, `min_futurity=0` | 1291 · 1233 · 1384 | **1291 ms** |
| Shelf guard, `min_futurity=0` (repeat, after restoring the setting) | 1074 · 1416 | ~1.2 s |
| Shelf guard, **`min_futurity` deleted** | 3981 · 1703 | 1.7–4.0 s |
| Home on Fire 1.5.2 → Shelf | 6307 · 6750 · 6255 | **6307 ms** |

**What the user sees on a HOME press** (from the run logs):

| | Amazon home visible | Then | Total |
|---|---|---|---|
| Shelf | ~1.2 s | your launcher | 1.29 s |
| Home on Fire | ~2.0 s | loading mask ~4 s | 6.31 s |

**Caveats.** One device, one build, `input keyevent 3` as the stimulus (a remote press
follows the same activity transitions, but the input path differs). Warm caches: apps
had been started repeatedly, so cold-start numbers would be worse for both.

**One Home on Fire bug, reproducible:** in all three runs it logged its target as
having appeared with `cls=android.widget.FrameLayout` — never the launcher's real
window (`tv.shelf.home/tv.shelf.home.Home`). It declares success about a second before
the launcher draws, and one run ended with `Mask teardown cap reached, fading without
a confirmed content window`. Reported upstream.

---

## 5. Setting it up (Shelf 1.8, the fast path)

Shelf is MIT, on GitHub (`rlubsey/shelf`), and ships the guard. Manual equivalent of its
installer:

```console
D="adb -s <tv-ip>:5555"

$D shell dumpsys deviceidle whitelist +tv.shelf.home
$D shell pm grant tv.shelf.home android.permission.WRITE_SECURE_SETTINGS
$D shell appops set tv.shelf.home SYSTEM_ALERT_WINDOW allow
$D shell settings put global alarm_manager_constants min_futurity=0

# rebind the accessibility service from a clean state
$D shell settings put secure enabled_accessibility_services '""'
$D shell settings put secure enabled_accessibility_services tv.shelf.home/tv.shelf.home.Guard
$D shell settings put secure accessibility_enabled 1

$D shell cmd package set-home-activity tv.shelf.home/.Home
$D shell am start -W -n tv.shelf.home/.Home
```

Verify, don't assume:

- HOME from inside an app → your launcher in about a second.
- `am force-stop <app>` → your launcher (this is the "back out of an app" case).
- `cmd package set-home-activity` and then a direct launch of
  `com.amazon.tv.launcher/.ui.HomeActivity_vNext` → still replaced.
- Reboot and repeat. If the guard does not reattach, you are not done.

Fire OS Settings stays reachable with the remote's Settings key
(`KEYCODE_SETTINGS` → `com.amazon.tv.settings.v2/.hud.HudActivity`), even though the
settings package exposes no leanback launcher activity of its own.

### About the accessibility service being "bound but deaf"

Observed once, after the Stick sat idle for ~20 minutes: the service was bound and
enabled, Amazon's home came up on HOME, and nothing redirected. Starting an app
manually fixed it, and the guard process pid had changed — consistent with the process
having been killed while idle and the first window event after the restart being lost.

Treat the guard as best-effort: if HOME ever lands on Amazon's home, press HOME again
or start any app. Not a reason to avoid the approach; a reason not to be surprised.

---

## 6. Debloat

`pm uninstall --user 0` now fails for essentially everything on this build:

```console
$ adb shell pm uninstall --user 0 com.amazon.tv.acr
Failure [DELETE_FAILED_INTERNAL_ERROR]
```

`pm disable-user` works:

```console
$ adb shell pm disable-user --user 0 com.amazon.tv.acr
Package com.amazon.tv.acr new state: disabled-user
```

20 packages removed on this device: 18 disabled, 2 uninstalled
(`com.amazon.gamehub`, `com.amazon.shoptv.client`). The full list, plus the 7 that are
protected and why, is in [`docs/debloat.md`](docs/debloat.md).

Kept deliberately: Alexa/voice, Silk, Appstore, input and pairing, `tv.keypolicymanager`,
`com.amazon.aria`, WebView, screen mirroring. Removing the app store or the input
stack is how people end up with a bricked remote.

**7 packages are protected** and cannot be disabled, including
`com.amazon.device.software.ota` and `com.amazon.device.software.ota.override`.

---

## 7. OTA: an update can undo all of this

The OTA packages are protected, so `pm disable-user` cannot touch them. What *can* be
done over ADB, and what this repo did:

- `com.amazon.tv.forcedotaupdater.v2` **can** be disabled (it is not protected).
- The remaining OTA surface can be starved with app-ops and network policy:
  `appops set <pkg> RUN_ANY_IN_BACKGROUND ignore`, plus
  `cmd netpolicy set restrict-background true` and a blacklist entry.
- The thorough option, which I did **not** implement here, is an on-device DNS filter
  (personalDNSfilter as a local VPN) pointing the OTA endpoints at `127.0.0.1`.
  [`humblemuzzu/dumbtv`](https://github.com/humblemuzzu/dumbtv) does exactly this and
  documents it well. My earlier claim that there is "nothing you can do from adb" was
  wrong — there is nothing you can do with `pm`, but DNS is a real lever.

Assume an OTA will eventually revert the launcher and the debloat. The DNS route is the
only thing that meaningfully resists it.

---

## 8. Undo

[`firetv-undo.sh`](firetv-undo.sh) puts HOME back on Amazon, re-enables the 18 disabled
packages, reinstalls the 2 uninstalled ones, and clears the alarm setting.

```console
$ bash firetv-undo.sh
```

Nothing here touches `/system`, and a factory reset also undoes all of it.

---

## 9. Prior art

Recorded honestly, because the first version of this write-up implied the ground was
empty and it was not.

| Date | Work | What it already had |
|---|---|---|
| 2026-06-12 | [Home on Fire](https://github.com/toolicious/home-on-fire) — [XDA thread](https://xdaforums.com/t/app-firetv-noroot-home-on-fire-use-any-launcher-as-your-fire-tv-home-home-button-boot-fire-os-8-7.4791567/) (284 replies) | Foreground-watch redirect as a standalone app; boot launch; escape gestures; the 5 s lock and its loading mask. Fire OS 7.7.1.4–.5 and 8.x |
| 2026-09-13 | [webserver-x.de](https://webserver-x.de/20260913/fire-tv-stick-alternative-launcher-home-button-without-root/) | UsageStats-driven watcher, no accessibility service, on 6.7.1.1 |
| 2026-09-28 | [jeremykenedy/fire-tv-toolkit](https://github.com/jeremykenedy/fire-tv-toolkit/blob/main/docs/LAUNCHER.md) | "Fire OS does not hand the Home key to accessibility services"; a `Home Redirect` helper doing the same watch |
| 2026-10-18 | [humblemuzzu/dumbtv](https://github.com/humblemuzzu/dumbtv/blob/main/docs/HOW-IT-WORKS.md) | Same build (7.7.1.7) on a Fire TV Edition TV. `set-home-activity` ignored; HOME not interceptable; `APP_SWITCH_DELAY_TIME`; `alarm_manager_constants min_futurity=0`; overlay to hide the flash; protected packages; OTA via DNS |
| 2026-10-17 | [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) — ~18k stars in 4 days | Android TV / Google TV focus with Fire OS 6 and 8 lists; disables the stock launcher and rolls back if Home does not land. Its troubleshooting docs cover `set-home-activity` reporting Success without effect, and `priority` being ignored for non-system HOME filters |
| — | [Launcher Manager](https://xdaforums.com/t/app-firetv-noroot-launcher-manager-change-launcher-without-root.4176349) | Its own notice: does not work on Fire OS 7 PS7706 or newer |
| — | [dknos/firetv-projectivy-fire-os-8](https://github.com/dknos/firetv-projectivy-fire-os-8) | What fails on 8.1.6.6, and what to configure instead |

`dumbtv` in particular documents the alarm trick and the 5 s lock in more depth than
this repo does. If you want a maintained, scripted end-to-end tool, use it rather than
copying commands from here.

---

## 10. Corrections to the first version

The first version of this write-up (and the XDA thread it came from) said things that
were wrong. Kept here rather than quietly edited:

- **"Every guide out there is now wrong."** No. Home on Fire works, and it is in the
  same subforum. The accurate statement is narrower: the methods in section 2 are dead.
- **"An update can undo all this; nothing you can do about it from adb."** Half wrong.
  You cannot disable the OTA packages, but you can point their endpoints at a dead DNS
  server from ADB. See section 7.
- **Implied novelty.** The mechanism was already public in several places. Section 9.

---

## Repo layout

```
README.md              this file
bench/bench.sh         the measurement script (force-stop Kodi → HOME → logcat)
bench/RESULTS.md       numbers, method, per-run detail
bench/logs/            extracted event logs for every run
docs/prior-art.md      longer notes on the earlier work
docs/debloat.md        the 20 packages, the 7 protected ones, exact commands
docs/xda-reply.md      the correction post for the existing XDA thread
firetv-undo.sh         one-command revert
```

Device serial and network address are omitted deliberately. Nothing here is Amazon
code; scripts and text are MIT.
