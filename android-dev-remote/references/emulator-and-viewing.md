# Emulator on a GPU-less server, and watching it live

## Create and run

```bash
avdmanager list device -c | grep -E '^pixel_[6-9]'          # pixel_8 may not exist; pixel_7 does
echo no | avdmanager create avd -n app-36 -k "system-images;android-36;google_apis_playstore;x86_64" -d pixel_7 --force
emulator -avd app-36 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot -grpc 8554
adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done
```

Run it as a user service (`scripts/systemd/emulator.service`). Boot ≈ 20 s with KVM.

### KVM permission under systemd

`ProbeKVM: This user doesn't have permissions to use KVM` inside the service, even though
your shell has the `kvm` group: the lingering `systemd --user` manager started before the
user was added to `kvm` (`cat /proc/$(pgrep -u $USER -f 'systemd --user')/status | grep Groups`).
Don't restart `user@UID.service` (kills every user process). Wrap the command:

```ini
ExecStart=/usr/bin/sg kvm -c "%h/Android/Sdk/emulator/emulator -avd app-36 -no-window …"
```

## The GPU problem (most important)

Without a GPU the emulator renders in software (SwiftShader / lavapipe / llvmpipe). With the
**API 36.1 and 37.0 images**, anything that reads a graphics buffer back from the host
aborts in the guest mapper:

```
Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma   (mapper.ranchu.so, readFromHost)
```

Consequences: `adb exec-out screencap` returns that text instead of a PNG; scrcpy capture
crashes SurfaceFlinger; and SurfaceFlinger's own RegionSampling thread crashes it
periodically (system_server restarts, `Can't find service: window`, a stuck loading shape).

What did **not** help (don't repeat): `-gpu swiftshader_indirect`, `-gpu angle_indirect`
(rejected → auto), `-gpu host` under Xvfb with Mesa llvmpipe, `-gpu guest` (image doesn't
support guest rendering), `-feature -GLDMA,-GLDMA2,-GLDirectMem`, `-feature GLAsyncSwap`,
canary emulator 37.3.2. Note `LOG_ALWAYS_FATAL_IF(cond)` prints the condition that was
**true**: the guest requires DMA readback the host doesn't offer.

What works: **the `android-36` image** (not 36.1). Screencap, scrcpy-style capture and the
system UI are all stable. Keep compileSdk/targetSdk at the newest; run on 36; test
newest-API behaviour on the physical phone.

Diagnose quickly on a new box:

```bash
adb exec-out screencap -p > /tmp/s.png; file /tmp/s.png     # "PNG image data" good, "ASCII text" bad
adb logcat -d -b crash | grep -c hasReadColorBufferDma         # 0 is good
```

## Screenshots Claude can trust

- Guest: `adb exec-out screencap -p > shot.png` (only on a working image).
- Host-side, independent of the guest UI: `adb emu screenrecord screenshot <dir>` (writes
  `Screenshot_<ts>.png`; works even when guest capture is broken). `scripts/shot` wraps it.
- Text instead of pixels (cheaper, exact):
  `adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml | grep -oE 'text="[^"]+"'`

## Live view for the user: gRPC bridge (`scripts/emulator-stream/`)

ws-scrcpy (NetrisTV) was the first try. It ships an old scrcpy server
(`NoSuchMethodException … IClipboard…addPrimaryClipChangedListener` on new Android) and its
capture triggered the SurfaceFlinger crash above. Dropped.

The emulator itself exposes gRPC (`-grpc 8554`, localhost, no JWT when the port is given):
`EmulatorController.streamScreenshot(ImageFormat)` pushes PNG frames from the host
renderer (only when the screen changes), and `sendTouch` injects touches in device pixels
(pressure 0 = up). The bridge (`server.py`) forwards frames over a WebSocket to a canvas
page (`index.html`) and sends taps back; Back/Home/Recents go through `adb shell input
keyevent`.

```bash
python3 -m venv ~/opt/emu-stream-venv && ~/opt/emu-stream-venv/bin/pip install -r scripts/emulator-stream/requirements.txt
scripts/emulator-stream/gen-stubs.sh ~/opt/emu-stream-venv/bin/python     # stubs from the SDK's own proto
STREAM_HOST=<tailnet-ip> STREAM_PORT=8887 ~/opt/emu-stream-venv/bin/python scripts/emulator-stream/server.py
```

Set `DEVICE_WIDTH/HEIGHT` in `index.html` to the AVD resolution (Pixel 7: 1080×2400).
Generated `*_pb2*.py` stay out of git.

## Seeding test media

Never use personal photos. Generate fixtures (`test-fixtures/make_scan_fixtures.py` pattern:
deterministic PNGs at fixed size via zlib level 0, a byte-identical copy, a same-size
different file, a chat-folder copy, a 120 MB random `.mp4`), then:

```bash
adb push fixtures/DCIM /sdcard/ && adb push fixtures/WhatsApp /sdcard/
adb shell content call --uri content://media --method scan_volume --arg external_primary
adb shell content query --uri content://media/external/file --projection _display_name:_size:media_type:relative_path:date_modified
adb shell "touch -d '2026-05-01 10:00:00' '/sdcard/WhatsApp/Media/WhatsApp Images/x.png'"   # then rescan to age a file
```

`content query --where` with `LIKE` breaks on adb quoting; query everything and `grep`.

## Expo dev-tools gear

Dev builds float a draggable "Tools" gear at top right; it covers headers' right-hand
icons. Drag it (`adb shell input swipe 970 245 970 1500 800`) before tapping what's
underneath. It does not exist in release builds.
