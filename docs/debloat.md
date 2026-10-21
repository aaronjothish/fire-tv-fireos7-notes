# Debloat reference — Fire OS 7.7.1.7 on AFTSSS

Two commands, one that works and one that mostly does not:

```console
$ adb shell pm uninstall --user 0 com.amazon.tv.acr
Failure [DELETE_FAILED_INTERNAL_ERROR]

$ adb shell pm disable-user --user 0 com.amazon.tv.acr
Package com.amazon.tv.acr new state: disabled-user
```

`pm uninstall --user 0` fails with `DELETE_FAILED_INTERNAL_ERROR` for essentially every
preinstalled package on this build. `pm disable-user` works and is reversible with
`pm enable`. Nothing below writes to `/system`.

## Disabled (18)

| Package | Why |
|---|---|
| `com.amazon.hybridadidservice` | ad ID service |
| `com.amazon.media.recommendations` | recommendation rows / promotion |
| `com.amazon.tv.acr` | automatic content recognition (screen fingerprinting) |
| `com.amazon.perfc` | performance telemetry |
| `com.amazon.perfcollection` | performance telemetry |
| `com.amazon.wirelessmetrics.service` | network telemetry |
| `com.amazon.dp.logger` | device telemetry logging |
| `com.amazon.tv.notificationcenter` | promo notifications |
| `com.amazon.tv.support` | support app |
| `com.amazon.tv.releasenotes` | release-notes app |
| `com.amazon.bueller.music` | bundled music app |
| `com.amazon.bueller.photos` | bundled photo app |
| `com.amazon.minitv.android.app` | MiniTV (region-specific video app) |
| `com.amazon.tv.livetv` | Live TV tab |
| `com.amazon.shoptv.firetv.client` | shopping client |
| `com.amazon.storm.lightning.tutorial` | tutorial |
| `com.amazon.tmm.tutorial` | tutorial |
| `com.amazon.tv.forcedotaupdater.v2` | forced OTA updater — **not** protected, unlike the OTA packages themselves |

## Uninstalled for user 0 (2)

`com.amazon.gamehub`, `com.amazon.shoptv.client` — `pm uninstall --user 0` worked for
these two. Restore with `cmd package install-existing <pkg>`.

## Protected — cannot be disabled (7)

```console
$ adb shell pm disable-user --user 0 com.amazon.device.software.ota
Exception: Cannot disable a protected package: com.amazon.device.software.ota
```

- `com.amazon.ftvads.deeplinking`
- `com.amazon.device.metrics`
- `com.amazon.device.crashmanager`
- `com.amazon.device.logmanager`
- `com.amazon.device.rdmapplication`
- `com.amazon.device.software.ota`
- `com.amazon.device.software.ota.override`

The last two mean an OTA can restore everything else on this page. See section 7 of the
README for what can still be done (app-ops, network policy, DNS).

## Deliberately kept

Alexa/voice, Silk, the Appstore, input and pairing packages, `tv.keypolicymanager`,
`com.amazon.aria`, WebView, screen mirroring, Fire OS Settings.

Removing the app store, the input stack, or Settings is how a TV ends up with a working
screen and a remote that does nothing. The gain is small and the recovery is a factory
reset.

## Checking state

```console
$ adb shell pm list packages -d        # disabled
$ adb shell pm list packages -u        # uninstalled for the user
$ adb shell dumpsys package <pkg> | grep -E "enabled=|versionName"
```

`enabled=3` means disabled for the user; `enabled=0` is the default state.
