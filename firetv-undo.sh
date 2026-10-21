#!/usr/bin/env bash
# Undo everything applied to the Fire TV Stick (192.168.178.24).
# See https://github.com/aaronjothish/fire-tv-fireos7-notes
# Usage: bash firetv-undo.sh
set -e
IP=192.168.178.24:5555
adb connect $IP >/dev/null 2>&1 || true
S() { adb -s $IP shell "$@" </dev/null; }

echo "== 1. handing HOME back to Amazon =="
S settings put secure enabled_accessibility_services '""'
S settings put secure accessibility_enabled 0
S appops set tv.shelf.home SYSTEM_ALERT_WINDOW default || true
S settings delete global alarm_manager_constants || true
S am start -a android.intent.action.MAIN -c android.intent.category.HOME || true

echo "== 2. re-enabling disabled packages =="
S pm enable com.amazon.hybridadidservice || true
S pm enable com.amazon.media.recommendations || true
S pm enable com.amazon.tv.acr || true
S pm enable com.amazon.perfc || true
S pm enable com.amazon.perfcollection || true
S pm enable com.amazon.wirelessmetrics.service || true
S pm enable com.amazon.dp.logger || true
S pm enable com.amazon.tv.notificationcenter || true
S pm enable com.amazon.tv.support || true
S pm enable com.amazon.tv.releasenotes || true
S pm enable com.amazon.bueller.music || true
S pm enable com.amazon.bueller.photos || true
S pm enable com.amazon.minitv.android.app || true
S pm enable com.amazon.tv.livetv || true
S pm enable com.amazon.shoptv.firetv.client || true
S pm enable com.amazon.storm.lightning.tutorial || true
S pm enable com.amazon.tmm.tutorial || true
S pm enable com.amazon.tv.forcedotaupdater.v2 || true

echo "== 3. reinstalling uninstalled packages =="
S cmd package install-existing com.amazon.gamehub || true
S cmd package install-existing com.amazon.shoptv.client || true

echo "== 4. optional: remove the redirector apps entirely =="
# left installed on purpose so HOME keeps working; uncomment to remove
# S pm uninstall io.github.toolicious.homeonfire
# S pm uninstall tv.shelf.home
# S pm uninstall com.spocky.projengmenu

echo "== done. HOME is back on Amazon's launcher =="
