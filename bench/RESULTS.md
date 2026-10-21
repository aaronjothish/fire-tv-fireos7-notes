# Measurement detail

## Setup

- Fire TV Stick 3rd gen (`AFTSSS` / `sheldon`), Fire OS 7.7.1.7 (PS7717/5741), Android 9.
- Stimulus app: Kodi (`org.xbmc.kodi`), already launched once (warm).
- Launcher: Shelf 1.8 (`tv.shelf.home`, versionCode 108), used as the *target* in both
  configurations so the comparison is about the redirect, not the launcher.
- Everything over `adb` on the LAN.

## Procedure per run

1. `am force-stop org.xbmc.kodi`
2. `am start -n org.xbmc.kodi/.Splash`
3. wait 6 s
4. `logcat -b all -c`
5. `input keyevent 3` (HOME)
6. wait 12 s (must outlast the 5 s app-switch lock)
7. `logcat -b all -d -v time`

## Metric

`t(am_pause_activity org.xbmc.kodi/.Main, userLeaving=true)` → `t(Displayed <target>)`.

The first is the HOME press as Android records it. The second is the launcher's first
frame on screen. Time spent "requesting" a launch is excluded, which is why Home on
Fire's own "target appeared" log line is not used — it fires early (see below).

## Configurations

**A. Shelf guard** — accessibility service `tv.shelf.home/tv.shelf.home.Guard`,
`alarm_manager_constants=min_futurity=0`, target Shelf itself.

**A′. Shelf guard, alarm setting removed** — `settings delete global
alarm_manager_constants`, everything else identical.

**B. Home on Fire 1.5.2** — service `io.github.toolicious.homeonfire/.HijackService`,
Shelf's guard disabled so only one redirector is bound, target `tv.shelf.home`.

## Results

| Run | A | A′ | B |
|---|---|---|---|
| 1 | 1291 ms | 3981 ms | 6307 ms |
| 2 | 1233 ms | 1703 ms | 6750 ms |
| 3 | 1384 ms | — | 6255 ms |
| repeat | 1074 ms | — | — |
| repeat | 1416 ms | — | — |

A: median 1291 ms · B: median 6307 ms · difference ≈ **5.0 s**.

## Per-run evidence

### A (Shelf guard, `min_futurity=0`) — `logs/shelf-1.log`

```
21:08:28.747  am_pause_activity   org.xbmc.kodi/.Main, userLeaving=true
21:08:28.8xx  am_resume_activity  com.amazon.tv.launcher/.ui.HomeActivity_vNext
21:08:29.693  am_resume_activity  tv.shelf.home/.Home
21:08:30.099  Displayed           tv.shelf.home/.Home: +390ms
```

`HOME → on screen = 1352 ms` in this run; the table uses the same computation, so
individual runs differ slightly from the median.

### B (Home on Fire) — `logs/hof-1.log`

```
21:13:38.112  am_pause_activity   org.xbmc.kodi/.Main, userLeaving=true
21:13:38.215  am_resume_activity  com.amazon.tv.launcher/.ui.HomeActivity_vNext
21:13:39.535  HomeOnFire          Redirected Home (from org.xbmc.kodi). Launched tv.shelf.home
21:13:39.741  HomeOnFire          Mask shown for deferred launch of tv.shelf.home
21:13:43.581  HomeOnFire          Target tv.shelf.home appeared 4044ms after the launch, cls=android.widget.FrameLayout
21:13:44.419  Displayed           tv.shelf.home/.Home: +1s284ms
```

Note `cls=android.widget.FrameLayout`: that is not Shelf's launcher window. Home on
Fire's readiness check matched a generic frame and declared success ~0.8 s before the
launcher was displayed. One run (`hof-2`) ended with
`Mask teardown cap reached, fading without a confirmed content window`.

### A′ (no `min_futurity`) — `logs/shelf-noalarm-1.log`

Alarms are held for the default 5 s lead time, so the launch lands late and
inconsistently: 3981 ms and 1703 ms across two runs. Restoring the setting returned the
next two runs to 1074 / 1416 ms.

## Limits of this data

- Single device, single build, one day.
- `input keyevent 3`, not a physical remote press. The activity transitions should be
  identical, but the input path is not; treat absolute numbers as ±100 ms.
- Warm app caches throughout. Cold starts are slower for both.
- Three runs per configuration is enough to show a 5 s difference, not enough for
  tight statistics.
