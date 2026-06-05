#!/bin/bash
set -e

DEVELOP_DIR="/home/ubuntu/develop"
mkdir -p "$DEVELOP_DIR/jdk17"
mkdir -p "$DEVELOP_DIR/android-sdk"

echo "=== Downloading OpenJDK 17 ==="
curl -L -o "$DEVELOP_DIR/jdk17.tar.gz" "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"

echo "=== Extracting OpenJDK 17 ==="
tar -C "$DEVELOP_DIR/jdk17" -xf "$DEVELOP_DIR/jdk17.tar.gz"
rm "$DEVELOP_DIR/jdk17.tar.gz"

# Find JDK path
JDK_PATH=$(find "$DEVELOP_DIR/jdk17" -maxdepth 1 -type d -name "jdk-*" | head -n 1)
echo "JDK path is: $JDK_PATH"

export JAVA_HOME="$JDK_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

echo "=== Checking Java version ==="
java -version

echo "=== Downloading Android Command Line Tools ==="
curl -L -o "$DEVELOP_DIR/commandlinetools.zip" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

echo "=== Extracting Android Command Line Tools ==="
mkdir -p "$DEVELOP_DIR/android-sdk/cmdline-tools"
unzip -q "$DEVELOP_DIR/commandlinetools.zip" -d "$DEVELOP_DIR/android-sdk/cmdline-tools"
rm "$DEVELOP_DIR/commandlinetools.zip"

# Move extracted folder to 'latest'
mv "$DEVELOP_DIR/android-sdk/cmdline-tools/cmdline-tools" "$DEVELOP_DIR/android-sdk/cmdline-tools/latest"

echo "=== Installing SDK packages using sdkmanager ==="
SDKMANAGER="$DEVELOP_DIR/android-sdk/cmdline-tools/latest/bin/sdkmanager"

# Install platform-tools, platform SDKs, and build tools
yes | "$SDKMANAGER" --sdk_root="$DEVELOP_DIR/android-sdk" \
  "platform-tools" \
  "platforms;android-34" \
  "platforms;android-35" \
  "build-tools;34.0.0" \
  "build-tools;35.0.0"

echo "=== Accepting all licenses ==="
yes | "$SDKMANAGER" --sdk_root="$DEVELOP_DIR/android-sdk" --licenses

echo "=== Configuring Flutter ==="
flutter config --android-sdk "$DEVELOP_DIR/android-sdk"
flutter config --jdk-dir "$JDK_PATH"

echo "=== Running Flutter Doctor ==="
flutter doctor

echo "=== Setup complete! ==="
