# Source from project scripts: JDK 17 and the Android SDK installed in user space.
JAVA_HOME="${JAVA_HOME:-$(ls -d "$HOME"/opt/jdk-17* 2>/dev/null | sort -V | tail -1)}"
export JAVA_HOME
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
