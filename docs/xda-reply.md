# Reply posted to the XDA thread (since deleted)

**Status:** the thread this reply was written for was removed by a moderator on 2026-10-21
("Deleted as requested"). The material was then reposted as a standalone thread, rewritten
to lead with the prior art rather than the old claims:
https://xdaforums.com/t/fire-os-7-7-1-7-the-home-key-is-eaten-by-amazoninputswitchservice-and-two-working-redirects-measured-1-3s-vs-6-3s.4805824/

Kept here as the record of what the first version got wrong, and as a draft if the
material is ever posted again.

Plain text on purpose — XenForo does not render markdown reliably.

---

Correction to my own post, after being pointed at work I should have found first.

Two things above are wrong.

1) "Every guide out there is now wrong" — no. Home on Fire has been doing this since June, in this same subforum, 280k views: https://xdaforums.com/t/app-firetv-noroot-home-on-fire-use-any-launcher-as-your-fire-tv-home-home-button-boot-fire-os-8-7.4791567/ . It is a standalone app, no Shelf needed, and it also handles boot launch and an escape back to Amazon home. If you just want your launcher on the Home button, go use that instead of following my commands.

2) "An update can undo all this, nothing you can do about it from adb" — the pm part is true, the conclusion is not. dumbtv points the OTA endpoints at 127.0.0.1 with an on-device DNS filter, installed over adb: https://github.com/humblemuzzu/dumbtv . That is the actual mitigation. It also documents this exact 7.7.1.7 build on a Fire TV Edition TV, including the alarm trick I describe below.

What I did get right, and what I measured after the fact:

Shelf's guard reaches the launcher in about 1.3s. Home on Fire takes about 6.3s on Fire OS 7. Both measured the same way, same device, same day, HOME pressed inside Kodi, timing from the press to the launcher's first frame:

Shelf guard + min_futurity=0 .... 1291ms / 1233ms / 1384ms
Shelf guard, setting deleted .... 3981ms / 1703ms
Home on Fire 1.5.2 ............... 6307ms / 6750ms / 6255ms

The gap is not the apps, it is the launch path. Fire OS 7 holds app launches for up to 5 seconds after a HOME press (APP_SWITCH_DELAY_TIME). Shelf starts the target through an AlarmManager PendingIntent, which system_server sends and which is exempt from that lock, but only if alarm_manager_constants min_futurity=0 is set. Delete that setting and Shelf drops to 1.7-4s. Home on Fire does a normal activity launch, so it pays the 5s and covers it with its loading screen. That loading screen is not cosmetic.

So: on Fire OS 8 use Home on Fire, the delay does not exist there. On Fire OS 7, if you want it fast, Shelf's guard plus that one setting is about 5 seconds quicker, and that is the only real difference between the two.

One thing nobody else has written down, as far as I can find: the component that eats the Home key is AmazonInputSwitchService. It sits ahead of the accessibility input filter, which is why the filter binds, gets the capability, and then never sees HOME. D-pad keys do reach the filter. Test with a physical remote, not adb input keyevent, or you will misdiagnose it.

Also, a caution on the guard approach: mine was bound and enabled after the Stick sat idle for 20 minutes and simply missed a HOME press entirely. Starting any app fixed it. The guard is best-effort, not a system-level home replacement.

Rewritten notes, with the measurement script and the logs, are here: https://github.com/aaronjothish/fire-tv-fireos7-notes

Everything in the first post about set-home-activity, pm disable-user and the accessibility filter still stands, and the debloat commands are unchanged.
