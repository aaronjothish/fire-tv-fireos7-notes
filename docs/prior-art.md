# Prior art, in detail

Collected 2026-10-21. The point of this page is that the ground was not empty: if you
find this repo via a search, follow one of these instead if it fits you better.

## Home on Fire (June 2026) — the turnkey answer

- https://github.com/toolicious/home-on-fire (GPL-3.0)
- XDA: https://xdaforums.com/t/app-firetv-noroot-home-on-fire-use-any-launcher-as-your-fire-tv-home-home-button-boot-fire-os-8-7.4791567/
- 284 replies, ~282k views, in **Fire TV General** — the same subforum this repo's
  write-up was originally posted to.

Standalone APK that watches for Amazon's home window and launches your target. Boot
launch, long-press escape to Amazon home, custom button mapping, no `INTERNET`
permission. Verified on Fire OS 7.7.1.4–7.7.1.5 and on 8.x.

It states plainly that Fire OS 7 holds Home-triggered launches for up to 5 s and that it
hides this behind a loading animation. I measured that at **6.3 s** end to end on
7.7.1.7 (see `bench/RESULTS.md`).

**Use it if:** you are on Fire OS 8 (no delay there), or you want one app and don't mind
the wait, or you want the escape gestures.

## dumbtv (October 2026) — the deepest write-up

- https://github.com/humblemuzzu/dumbtv

Broad TV debloat project; the Fire OS launcher section documents the same build
(7.7.1.7) on a Fire TV Edition TV. Its `docs/HOW-IT-WORKS.md` covers:

- `set-home-activity` printing Success and doing nothing;
- HOME being handled before any accessibility key filter;
- `APP_SWITCH_DELAY_TIME` holding launches for 5 s after HOME, and starting via an
  `AlarmManager` `PendingIntent` to escape it;
- `alarm_manager_constants min_futurity=0` as the setting that makes those alarms fire
  immediately;
- an overlay window to cover Amazon's home before it draws;
- protected packages handled with app-ops and network policy instead of `pm disable`;
- OTA endpoints pointed at `127.0.0.1` with an on-device DNS filter.

If you want a maintained tool rather than a set of commands to copy, start here.

**Correction it forced on this repo:** the claim "an update can undo all this, nothing
you can do about it from adb" was wrong. OTA packages cannot be disabled, but their
endpoints can be poisoned from ADB.

## webserver-x.de (September 2026)

- https://webserver-x.de/20260913/fire-tv-stick-alternative-launcher-home-button-without-root/

Different mechanism again: `UsageStats` polled every 350 ms, no accessibility service at
all. Tested on a 2018 Stick 4K / Fire OS 6.7.1.1. Also documents that Amazon's
HOME-pressed broadcast is signature-protected, which is why renaming the old APK does
not help.

## fire-tv-toolkit (September 2026)

- https://github.com/jeremykenedy/fire-tv-toolkit/blob/main/docs/LAUNCHER.md

A `Home Redirect` helper (`com.jeremykenedy.firetv.homeredirect`) that watches for
Amazon's home coming to the front and opens the chosen launcher over it, plus a
screensaver picker. States the key point in one line: Fire OS "does not hand the Home
key to accessibility services".

## cleanyourtv (October 2026) — the one with the reach

- https://github.com/Gathin23/cleanyourtv
- Created 2026-10-17, ~18k stars within four days.

Mainly Android TV / Google TV, with Fire OS 6 and 8 device lists; replaces the stock
home screen by disabling it, and rolls back if Home does not land on the new launcher.
Its `docs/TROUBLESHOOTING.md` documents the same class of failure from the other side:
`set-home-activity` can print `Success` while HOME still resolves to the stock launcher,
per-app `android:priority` on a HOME filter is ignored for apps that are not on the
system image, and `pm disable-user` on a stock component is refused with a
`SecurityException`.

Its approach depends on being able to disable the stock launcher, which is exactly what
Fire OS 7.7 will not allow — hence the redirect problem this repo covers.

## Launcher Manager

- https://xdaforums.com/t/app-firetv-noroot-launcher-manager-change-launcher-without-root.4176349

The big thread everyone used to follow. Its own notice now says it does not work on
Fire TV Fire OS 7 **PS7706 or newer**, or Fire OS 8 RS8153 or newer. That threshold is
the line this device (PS7717) is past.

## dknos / firetv-projectivy-fire-os-8

- https://github.com/dknos/firetv-projectivy-fire-os-8

Fire OS 8.1.6.6 recipe. Useful for the list of things that silently do nothing — logcat
watchers, Projectivy's accessibility service, `pm disable-user` on the launcher — and
for what to enable in Projectivy instead.

## What is genuinely not covered elsewhere

Checked 2026-10-21 with GitHub code search, issue search, and web search:

| Query | Result |
|---|---|
| `AmazonInputSwitchService`, code search | 21 hits — every one a ROM dump or a logcat capture |
| `AmazonInputSwitchService`, issues/PRs | 4 hits — none about launchers except this repo's own Shelf report |
| `AmazonInputSwitchService`, web | nothing on the Home key |

So the narrow, defensible claims are:

- **The name of the component:** `AmazonInputSwitchService`. Everyone else stops at
  "Fire OS handles it before the accessibility filter". This repo names it, and says
  plainly that the causal link is inferred rather than decompiled.
- **The AFTSSS / Fire TV Stick 3rd gen datapoint** on PS7717/5741.
- **A same-device, same-day comparison** of the alarm-based and normal-launch redirects
  (1.29 s vs 6.31 s), and the demonstration that deleting `min_futurity=0` collapses
  the fast path (1.7–4.0 s).

Everything else here — the failure of `set-home-activity`, the protected packages, the
5 s app-switch lock, the alarm workaround — is somebody else's earlier finding, credited
above.
