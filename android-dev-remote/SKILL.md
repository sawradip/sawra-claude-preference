---
name: android-dev-remote
description: Playbook for building Android apps (React Native/Expo + Kotlin native modules) with Claude Code on a headless SSH server, reached over a Tailscale tailnet, testing on a software-rendered emulator and on the user's real phone. Covers server toolchain setup without sudo, a GPU-less emulator that actually renders, a live in-browser view of the emulator, hot reload to a phone over a slow link, wireless adb over Tailscale, native rebuild/installs, Expo module pitfalls, and how Claude verifies its own work (screenshots, UI dumps, logcat, tcpdump). Use when starting or continuing mobile app work on a remote server, setting up an Android dev environment, debugging the emulator/phone/Metro connection, or when the user mentions Expo, React Native, adb, emulator, Tailscale, hot reload, or installing a dev build on their phone.
---

# Android development on a remote server, over Tailscale, with a real phone

Distilled from building the Optimal app (Expo SDK 57, RN 0.86, Kotlin Expo module) on a
shared Hetzner box with no GPU, a user in a different country on a ~220 ms / 0.1–0.5 MB/s
link, and a Samsung phone. Every rule below cost real time to learn. Read the matching
reference file before doing that phase; don't rediscover these the hard way.

## The setup at a glance

```
user's laptop/phone browser ──tailnet──▶ server :8887  live emulator view (gRPC frames → WebSocket)
user's phone (Tailscale app) ──tailnet──▶ server :8081  metro-proxy (gzip) ──▶ Metro :18081
server ──tailnet──▶ phone :<port>   wireless adb (install builds, read logs, screenshots)
server ──adb reverse──▶ emulator    same Metro via localhost:8081
Claude Code (on the server) drives everything with adb, screenshots and logcat
```

Everything listens on the Tailscale IP or localhost. Nothing is opened publicly.

## Order of work (each step links its reference)

1. **Survey the box first** — KVM, GPU, disk, sudo, existing firewall, other tenants.
   `references/server-setup.md`
2. **Toolchain in user space** — JDK 17, SDK cmdline-tools, platform, build-tools, the NDK
   React Native pins, emulator. Env in `~/.bashrc` and `scripts/env.sh`.
3. **Emulator as a user systemd service** — the image that works without a GPU, `sg kvm`.
   `references/emulator-and-viewing.md`
4. **Tailscale** — install, user approves login link, bind dev services to the tailnet IP.
   `references/tailscale-and-network.md`
5. **Live view** — the gRPC→WebSocket bridge, not ws-scrcpy. `scripts/emulator-stream/`
6. **Scaffold the app** — Expo dev build, SDK levels, blocked permissions, local Kotlin
   module. `references/expo-react-native.md`
7. **Metro behind the gzip proxy** so phones on slow links can load the bundle.
   `scripts/metro-proxy/`, `scripts/dev`
8. **Phone** — Tailscale app, wireless debugging paired over the tailnet, compressed APK
   installs. `references/phone.md`
9. **Verify like a tester** — screenshots, UI dumps, taps, logcat, tcpdump.
   `references/verification.md`

## The daily loop

- **JS/TS change** → save → Fast Refresh on emulator and phone in 1–2 s. No reinstall.
- **Native change** (Kotlin, new native dependency, permissions, app.json plugins) →
  `ABIS=x86_64 scripts/apk` for the emulator, then `ABIS=arm64-v8a scripts/apk --no-install`
  and `scripts/phone-install <serial> <apk>` for the phone. Batch native changes: each
  phone install is ~40 MB compressed over a slow link.
- After each meaningful step: typecheck, unit tests, look at the screen yourself, commit.

## Hard-won rules

1. **No GPU ⇒ use the API 36 system image.** API 36.1 and 37.0 images crash SurfaceFlinger
   (`Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma`) under every software
   renderer, every flag combination, stable and canary emulators. Keep compileSdk/targetSdk
   at the latest; just *run* on 36. Retry newer images only after emulator updates.
2. **Live view = emulator gRPC `streamScreenshot`, not scrcpy.** Host-side frames bypass the
   broken guest readback; ws-scrcpy's bundled scrcpy server also fails on new Android.
3. **The lingering user systemd manager may predate your group membership.** If the
   emulator says it lacks KVM permission under systemd, wrap it in `sg kvm -c "…"` rather
   than restarting `user@UID` (that kills the user's other processes).
4. **Shared servers: never reset the firewall.** Read `ufw status` first; bind to the
   tailnet IP and rely on the existing default-deny.
5. **Phones on slow links: Metro must gzip the bundle.** The dev client asks for
   `Accept: multipart/mixed` (progress UI) and Metro then skips compression: 4.2 MB vs
   0.72 MB. Front Metro with the proxy and set `EXPO_PACKAGER_PROXY_URL`.
6. **Debug APKs are ~130 MB because dex and .so are stored uncompressed.** Building for one
   ABI barely helps. Gzip the APK (~40 MB), push, `gunzip` on the phone, `pm install -r`.
7. **Wireless debugging works across the tailnet** even though Android enables it only on
   Wi-Fi: pair and connect to the phone's Tailscale IP with the ports from the screen.
8. **Load native modules with `requireOptionalNativeModule` and call new functions with
   `?.()`**, so a JS change can never crash a phone still running an older APK.
9. **Never do multi-file renames in separate steps.** Fast Refresh delivers the half-done
   state and the phone keeps showing "failed to compile". Write the importer first, then
   delete; or do it in one command.
10. **Never install with `--legacy-peer-deps`.** It silently removes auto-installed peers
   (Babel preset, Reanimated…). Fix the conflict (`npx expo install <pkg>` to pin), and
   check that a clean `npm ci` works before committing.
11. **Patch dependencies with `git apply` on postinstall** (`scripts/apply-patches`), and
   exclude `build/`, `.gradle/`, `.cxx/` when generating the patch.
12. **`pkill -f <pattern>` can kill your own shell** when the pattern appears in the
   command line (exit 144). Kill by PID from `ss -tlnp`/`pgrep -x`.
13. **AGP may not know new platform names** (`android-37.0`): alias the platform directory
   as `android-37` with edited `package.xml`/`source.properties`.
14. **`create-expo-module --local <path>` nests under `modules/` again**; move it up. Remove
   the template's Expo LICENSE. Ignore `modules/*/android/build/`.
15. **Trash is not free space.** `MediaStore.createTrashRequest` keeps files 30 days; say
   "in trash, frees X by <date>", not "freed".

## Troubleshooting index

| Symptom | Cause | Fix — see |
|---|---|---|
| `adb exec-out screencap` returns ASCII "Assertion failed …" | GPU-less emulator, image too new | API 36 image — emulator-and-viewing |
| Browser stream black, SurfaceFlinger restarts | same | same |
| Emulator service: "doesn't have permissions to use KVM" | user manager lacks kvm group | `sg kvm` — emulator-and-viewing |
| Phone stuck on "Reloading…", white screen | bundle too slow, uncompressed | metro-proxy — phone |
| "There was a problem loading the project" NPE `categories.addAll` | expo-dev-launcher bug on BROWSABLE intents | patch / open from app icon — expo-react-native |
| Phone shows "failed to compile" after edits | half-applied rename via Fast Refresh | Tools → Reload — rule 9 |
| `Failed to find target with hash string 'android-37'` | AGP vs new platform naming | rule 13 — server-setup |
| Unit tests: `Method … not mocked` for Uri/JSONObject | Android framework in JVM tests | strings for URIs, `org.json:json` test dep — expo-react-native |
| `npm ci` ERESOLVE | a peer pulled a mismatched react-dom etc. | pin with `npx expo install` |
| adb device "not found" mid-session | wireless debugging dropped | `adb connect` again; port changes if toggled — phone |
| No app traffic reaches server, but ping works | app failed before networking (read the error screen with `uiautomator dump`) | verification |

## Quickstart for a new project

```bash
K=~/.claude/skills/android-dev-remote/scripts
mkdir -p scripts tools
cp $K/{env.sh,emulator,shot,dev,apk,phone-install,apply-patches} scripts/
cp -r $K/emulator-stream $K/metro-proxy tools/
printf '\ntools/emulator-stream/*_pb2*.py\n__pycache__/\nmodules/*/android/build/\n' >> .gitignore
# units: copy $K/systemd/*.service to ~/.config/systemd/user/, fill <AVD> <TAILNET_IP> <PROJECT_DIR>
```

Then set `"postinstall": "scripts/apply-patches"` in package.json once a patch exists.

## Files in this skill

| Path | Use |
|---|---|
| `references/server-setup.md` | survey, JDK/SDK/NDK, platform alias, user services, disk |
| `references/emulator-and-viewing.md` | GPU-less image choice, screenshots, gRPC live view, fixtures |
| `references/tailscale-and-network.md` | login, binding, firewall etiquette, ports, measuring, tcpdump |
| `references/phone.md` | download page, wireless adb over the tailnet, slow-link Metro, compressed installs |
| `references/expo-react-native.md` | scaffold, deps, patches, Kotlin module patterns, unit tests, Fast Refresh discipline |
| `references/verification.md` | how to check work on devices, logs, shell hygiene, reporting |
| `scripts/` | env, emulator control, screenshot, Metro, APK build, phone install, patches |
| `scripts/emulator-stream/` | gRPC → WebSocket live emulator view (`?w=&h=` for device size) |
| `scripts/metro-proxy/` | gzip-friendly proxy in front of Metro |
| `scripts/systemd/` | user unit templates for emulator, live view, Metro, proxy |

## What to keep in the project repo

Copy what the project needs from `scripts/` (they take parameters; nothing is
project-specific) and record in the project's CLAUDE.md: the emulator image, ports, the
Tailscale IP, the phone's serial, and which services run. Keep secrets (sudo password,
pairing codes) out of files and memory.
