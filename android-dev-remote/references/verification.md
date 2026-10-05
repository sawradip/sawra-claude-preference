# How Claude verifies its own work

The user often can't see what Claude sees. Check every user-visible change on a device
before reporting it done, and say exactly what was and wasn't verified.

## The loop for a UI change

1. `npx tsc --noEmit`.
2. Bring the screen up on the emulator (deep link, taps).
3. Screenshot and **look at it** against the design spec (spacing, copy, states).
4. Exercise the interaction (tap, toggle, drag, back) and assert the result as text:

```bash
adb shell uiautomator dump /sdcard/ui.xml >/dev/null; adb shell cat /sdcard/ui.xml | grep -oE 'text="[^"]+"'
adb shell cat /sdcard/ui.xml | grep -oE 'text="[^"]+"[^>]*bounds="[^"]+"'   # with tap targets
```

5. Commit with what was verified in the message.

## Driving the app

```bash
adb shell am force-stop <pkg>
adb shell am start -a android.intent.action.VIEW -d "<scheme>://expo-development-client/?url=http%3A%2F%2F<tailnet-ip>%3A8081"
for i in $(seq 1 40); do adb logcat -d -s ReactNativeJS:V | grep -q 'Running "main"' && break; sleep 2; done
adb shell input tap X Y          # device pixels
adb shell input swipe x1 y1 x2 y2 600
adb shell input text "What%sis%sthis?"     # %s = space
adb shell input keyevent KEYCODE_BACK
```

Screenshots shown to Claude are downscaled (e.g. 1080×2400 shown at 900×2000): multiply
displayed coordinates by the stated factor (1.2) before tapping. Prefer `bounds=` from the
UI dump when available.

System dialogs (permissions, trash/restore confirmation) are ordinary UI: dump them, tap
`Allow`/`Deny` by bounds. That makes end-to-end tests of OS flows possible.

## Logs

```bash
adb logcat -c                                     # before reproducing
adb logcat -d -s ReactNativeJS:V                  # JS console
adb logcat -d --pid=$(adb shell pidof <pkg>)      # everything from the app
adb logcat -d -b crash                            # native crashes, tombstone summaries
```

- Filter noise: `SoftException|onWindowFocusChange|VRI\[|BLAST|Insets|ImeTracker`.
- `ReactNoCrashSoftException … context is not ready` = JS bundle not loaded yet (a symptom).
- Expo's dev-launcher error screen is `DevLauncherErrorActivity`; its message is only on
  screen — read it with `uiautomator dump` while the user keeps it visible.
- Check `Process:` on any `FATAL EXCEPTION`; it may be another app.

## Engine/native assertions

Check native results directly instead of trusting the UI:

```bash
adb shell run-as <pkg> cat shared_prefs/<store>.xml | sed 's/&quot;/"/g'
adb shell run-as <pkg> cat files/actions.jsonl
adb shell ls -a "/sdcard/WhatsApp/Media/WhatsApp\ Images/"     # trashed files appear as .trashed-<expiry>-<name>
adb shell dumpsys package <pkg> | grep -E 'READ_MEDIA.*granted'
```

Write down the expected result before running (e.g. "6 items, 1 duplicate group, 12,420
bytes reclaimable, Sent/ excluded") and compare.

## Shell hygiene for the agent

- **`pkill -f pattern` matches the agent's own `bash -c` command line** when the pattern
  appears in it → exit 144, everything after it skipped. Kill by PID:
  `kill $(ss -tlnp | grep ':8082 ' | grep -oE 'pid=[0-9]+' | cut -d= -f2)`.
- Foreground `sleep` > a few seconds may be blocked; use `run_in_background` for builds
  and wait for the completion notification, or poll in an `until` loop.
- Long adb calls against a flaky phone: wrap in `timeout 20`.
- Builds: run `scripts/apk` in the background, grep the log for
  `BUILD (SUCCESSFUL|FAILED)|What went wrong|^e: `.
- Don't paste huge outputs; `tail`, `grep -c`, `wc -l`.

## Reporting

State what you checked and how ("installed on emulator; trashed 2 files via the system
dialog; Undo restored both under their original names; Sent/ untouched"), what you could
not check (device screen locked, scan duration not in the log), and anything you got wrong
on the way (e.g. a half-applied edit that reached the phone).
