# Server setup

Goal: a working Android + React Native toolchain on a headless Linux server, mostly
without sudo, without disturbing anything else running on the box.

## 1. Survey before installing anything

```bash
ls -l /dev/kvm; id                    # need kvm group (or rw on /dev/kvm) for a fast emulator
nproc; free -h; df -h /               # SDK+NDK+image ≈ 6–8 GB, node_modules ≈ 0.5 GB, Gradle cache 3–5 GB
for t in java node npm watchman git docker adb tailscale ufw; do command -v $t || echo "missing $t"; done
sudo -n true                          # passwordless sudo? if not, ask the user before any system change
nvidia-smi -L; ls /dev/dri            # GPU? Almost always "no" on rented servers
sudo ufw status verbose               # shared box: note existing rules, never reset them
ss -tlnp                              # what ports are taken (another tenant may already use 8090…)
```

Write down: KVM yes/no, GPU yes/no, free disk, whether sudo needs a password, and who else
uses the machine. Decisions follow from these.

- No KVM → emulator is unusable; use Redroid in Docker or only the physical phone.
- Low disk (< 25 GB free) → install one system image only, one NDK, and remove what fails.
- Password sudo → do user-space installs; ask for sudo only for apt packages and Tailscale.
  Use it as `echo "$PW" | sudo -S -p '' …`, never write it to a file or memory, and suggest
  the user rotate it afterwards if they pasted it into chat.

## 2. JDK 17 (user space)

```bash
mkdir -p ~/opt && cd ~/opt
curl -fsSL -o jdk17.tar.gz "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
tar xzf jdk17.tar.gz && rm jdk17.tar.gz && ls   # e.g. jdk-17.0.20.1+1
```

## 3. Android SDK (user space)

```bash
mkdir -p ~/Android/Sdk/cmdline-tools && cd ~/Android/Sdk/cmdline-tools
curl -fsSL -o clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q clt.zip && mv cmdline-tools latest && rm clt.zip
```

Environment (append to `~/.bashrc`, and keep a copy as the project's `scripts/env.sh`):

```bash
export JAVA_HOME="$HOME/opt/jdk-17.0.20.1+1"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

Pick versions from what is actually available, not from memory:

```bash
yes | sdkmanager --licenses >/dev/null
sdkmanager --list > /tmp/sdk.txt
grep -oE "platforms;android-[0-9.]+" /tmp/sdk.txt | sort -uV | tail
grep -oE "system-images;android-[0-9.]+;google_apis(_playstore)?;x86_64" /tmp/sdk.txt | sort -u
```

**NDK: install the exact version React Native pins**, otherwise Gradle silently downloads
another one (disk!):

```bash
grep -rhoE 'ndkVersion\s*=\s*"[0-9.]+"' node_modules/react-native/gradle/libs.versions.toml   # after npm install
```

If the app isn't scaffolded yet, install the RN-default for the current release (27.1.x for
RN 0.8x) and verify once `node_modules` exists.

```bash
sdkmanager --install "platform-tools" "platforms;android-37.0" "build-tools;37.0.0" \
  "ndk;27.1.12297006" "cmake;3.22.1" "emulator" "system-images;android-36;google_apis_playstore;x86_64"
```

Image choice: see `emulator-and-viewing.md` — on a GPU-less server only API 36 rendered.
`google_apis_playstore` (4 KB pages) is simpler than the `ps16k` variants.

### Platform naming vs AGP

Newer SDK platforms install as `platforms/android-37.0`. AGP 8.12 with
`compileSdkVersion 37` looks for hash `android-37` and fails:
`Failed to find target with hash string 'android-37'`. Alias it:

```bash
cd ~/Android/Sdk/platforms && mkdir android-37
for f in android-37.0/*; do n=$(basename $f); case $n in package.xml|source.properties) ;; *) ln -s ../android-37.0/$n android-37/$n;; esac; done
sed 's/AndroidVersion.ApiLevel=37.0/AndroidVersion.ApiLevel=37/' android-37.0/source.properties > android-37/source.properties
sed -e 's|platforms;android-37.0|platforms;android-37|' -e 's|<api-level>37.0</api-level>|<api-level>37</api-level>|' android-37.0/package.xml > android-37/package.xml
```

This lives outside the repo; note it in the project's CLAUDE.md so a new machine repeats it
(or until Expo ships a newer AGP).

## 4. Other tools

- **Watchman**: `sudo apt-get install -y watchman` (Ubuntu 22.04 ships 4.9.0; fine for Metro).
  GitHub releases may not carry Linux binaries.
- **Node LTS** usually present; Expo needs ≥ 20.
- **Python venv** for the helper services: `python3 -m venv ~/opt/emu-stream-venv`.

## 5. User services and lingering

Long-running dev processes (emulator, live view, Metro, proxy) run as **user systemd units**
in `~/.config/systemd/user/`, enabled, with lingering on so they survive logout and reboot:

```bash
loginctl show-user $USER -p Linger      # want Linger=yes (enable: sudo loginctl enable-linger $USER)
systemctl --user daemon-reload && systemctl --user enable --now <unit>
journalctl --user -u <unit> -n 50 --no-pager
```

Templates: `scripts/systemd/`. Use `%h` for the home dir inside `[Service]`; `systemd-run`
does **not** expand `%h` in `--working-directory` (fails with status 200/CHDIR).

## 6. Disk hygiene

- Remove system images that turn out not to work (`sdkmanager --uninstall …`, then delete
  empty leftover directories).
- Gitignore `android/`, `ios/` (Expo regenerates them), `modules/*/android/build/`, `.cxx/`.
- Check `df -h /` after each large install and report it to the user.
