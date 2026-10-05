# The user's physical phone

The emulator is for fast UI iteration; the phone is the truth for anything touching
hardware (encoders, camera media, real galleries, OEM behaviour, the newest API level).

## 1. Join the tailnet

User installs the Tailscale app and signs in to the same tailnet. Confirm with
`tailscale status` (shows `<name> android`) and `tailscale ping`.

## 2. First install without adb: a download page

```bash
mkdir -p ~/opt/app-download && cp android/app/build/outputs/apk/debug/app-debug.apk ~/opt/app-download/app-dev.apk
systemd-run --user --unit=app-download --working-directory=$HOME/opt/app-download \
  /usr/bin/python3 -m http.server 8888 --bind "$(tailscale ip -4)"
```

Add an `index.html` with a download button and the instruction "open the app from its
icon". **Don't offer an `app://expo-development-client/?url=…` deep link** in the page:
browser intents carry the BROWSABLE category, which crashes expo-dev-launcher 57.0.x
(see expo-react-native.md) unless patched.

The user must allow the browser to install unknown apps; Play Protect may warn on an
unsigned debug build ("Install anyway").

A truncated download looks like `Connection reset by peer` in the http.server log;
"App not installed" or "problem parsing" on the phone means re-download.

## 3. Wireless debugging over Tailscale (do this early)

Android only lets the user *enable* Wireless debugging on Wi-Fi, but adbd then listens on
every interface, including the Tailscale one, so the server connects through the tailnet
from anywhere.

Steps for the user (Samsung wording; others similar):

1. Settings → About phone → Software information → tap **Build number** 7×.
2. Settings → Developer options → **Wireless debugging**: toggle on, then **tap the words**
   to open its screen (the switch alone doesn't), accept "allow on this network".
3. Tap **Pair device with pairing code**; send Claude the 6-digit code and the popup's
   port. Then send the port shown on the main Wireless debugging screen.

```bash
adb pair <phone-tailnet-ip>:<pairing-port> <code>      # one-time; remembered by both sides
adb connect <phone-tailnet-ip>:<connect-port>
adb -s <ip:port> shell getprop ro.product.model        # SM-M156B etc.
```

The connect port changes whenever wireless debugging restarts (toggle, reboot, network
change); pairing survives. Connections also drop on network blips: `adb connect` again.

Warn the user: banking and payment apps often refuse to run or crash while Developer
options / wireless debugging are on. Turn it off when not developing.

## 4. Metro over a slow link

Symptoms of a bundle that can't arrive: stuck "Reloading…" banner, white screen, logcat
full of harmless `ReactNoCrashSoftException … context is not ready`, and no
`ReactNativeJS: Running "main"` line.

Root cause: the dev client requests the bundle with `Accept: multipart/mixed` (to show
progress) and Metro does **not** gzip multipart responses: 4.2 MB raw vs 0.72 MB gzipped
for a small app. At 45–100 KB/s that's 100 s+, past the client's patience.

Fix (`scripts/metro-proxy/proxy.py` + `scripts/dev`):

- Metro runs on a free internal port (e.g. 18081).
- The proxy listens on `127.0.0.1` and the tailnet IP at 8081, rewrites `Accept: */*` on
  `*.bundle` requests so Metro gzips, streams everything else (incl. HMR/inspector
  WebSockets) untouched.
- `EXPO_PACKAGER_PROXY_URL=http://<tailnet-ip>:8081` makes the manifest advertise the
  proxy; `REACT_NATIVE_PACKAGER_HOSTNAME=<tailnet-ip>` for the host. Expo hard-codes the
  manifest port from Metro's port otherwise, so a proxy on another port isn't enough.
- The emulator uses `adb reverse tcp:8081 tcp:8081` → the same proxy.

Result: first load ≈ 15 s instead of never; Fast Refresh deltas are KBs.

## 5. Installing native builds on the phone

Debug APKs store dex and `.so` **uncompressed** (`unzip -lv` shows `Stored`), so they're
~130 MB even for one ABI. Compress for transport:

```bash
ABIS=arm64-v8a scripts/apk --no-install
scripts/phone-install <ip:port> android/app/build/outputs/apk/debug/app-debug.apk
# = gzip -6 (≈40 MB) → adb push → gunzip on device (/system/bin/gunzip) → pm install -r
```

It installs as an update; app data, permissions and saved state survive. 87–200 s on the
slow link. Batch native changes to keep this rare.

## 6. Reading the phone from the server

```bash
adb -s <s> shell run-as <package> cat shared_prefs/<file>.xml     # app's own prefs (debug builds)
adb -s <s> shell run-as <package> cat files/<log>.jsonl
adb -s <s> shell dumpsys package <package> | grep -E 'granted=|lastUpdateTime'
adb -s <s> shell "dumpsys power | grep mWakefulness"               # Dozing/Asleep = screen off
adb -s <s> exec-out screencap -p > phone.png                      # all black = screen off/locked
```

When the phone is locked, Android blocks background network and screenshots show the lock
screen: ask the user to unlock and leave the screen up ("reply 'on screen'"), then read it
with `uiautomator dump`. Don't launch activities on the user's phone without reason; they
may be using it.

## 7. Samsung specifics seen

- logcat ring buffer is busy (≈270 k lines per 90 min); app lines rotate out fast. Grab
  logs right after reproducing, filter by `--pid=$(pidof <pkg>)` or tag.
- Other apps' crashes show up in grep (e.g. a banking app's `FATAL EXCEPTION`); check
  `Process:` before chasing.
