#!/bin/bash
# HOME redirect benchmark. Metric: HOME press (Kodi pauses with userLeaving=true)
# -> the replacement launcher's first frame ("Displayed <target>").
# Stimulus identical for every config: `input keyevent 3` from inside Kodi.
set -u
ADB="${ADB:-/opt/homebrew/bin/adb}"
SERIAL="${SERIAL:-192.168.178.24:5555}"
D() { "$ADB" -s "$SERIAL" "$@"; }

LABEL="${1:?usage: bench.sh <label> [runs]}"
RUNS="${2:-3}"
DIR="$(cd "$(dirname "$0")" && pwd)"

for i in $(seq 1 "$RUNS"); do
  D shell am force-stop org.xbmc.kodi
  D shell am start -n org.xbmc.kodi/.Splash >/dev/null 2>&1
  sleep 6
  D shell logcat -b all -c
  D shell input keyevent 3
  sleep 12                     # must outlast the 5 s app-switch lock
  D shell logcat -b all -d -v time > "$DIR/bench-$LABEL-$i.log" 2>/dev/null
done

python3 - "$LABEL" "$DIR" "$RUNS" <<'PY'
import re, sys, os

label, d, runs = sys.argv[1], sys.argv[2], int(sys.argv[3])
TS = re.compile(r"^\d\d-\d\d (\d\d):(\d\d):(\d\d)\.(\d\d\d)")
TARGET = "tv.shelf.home"

def ms(m):
    h, mi, s, frac = m.groups()
    return ((int(h) * 3600 + int(mi) * 60 + int(s)) * 1000) + int(frac)

for i in range(1, runs + 1):
    f = os.path.join(d, f"bench-{label}-{i}.log")
    if not os.path.exists(f):
        continue
    press = amazon = shown = None
    for line in open(f, errors="ignore"):
        m = TS.match(line)
        if not m:
            continue
        t = ms(m)
        if press is None and "am_pause_activity" in line and "org.xbmc.kodi" in line:
            press = t
        elif amazon is None and "am_resume_activity" in line and "com.amazon.tv.launcher" in line:
            amazon = t
        elif shown is None and "Displayed " + TARGET in line:
            shown = t
    if press is None or shown is None:
        print(f"{label} run {i}: INCOMPLETE (press={press}, displayed={shown})")
        continue
    flash = f" | amazon home visible {amazon - press}ms" if amazon else " | amazon home never resumed"
    print(f"{label} run {i}: HOME -> launcher on screen {shown - press}ms{flash}")
PY
