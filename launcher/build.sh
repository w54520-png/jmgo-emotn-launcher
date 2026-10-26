#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$ROOT_DIR/.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
PLATFORM="${ANDROID_PLATFORM:-$SDK_ROOT/platforms/android-37.0}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$SDK_ROOT/build-tools/36.0.0}"
OUT="$ROOT_DIR/build"

[ -x "$BUILD_TOOLS/aapt2" ] || { echo "missing aapt2: $BUILD_TOOLS/aapt2" >&2; exit 1; }
[ -f "$PLATFORM/android.jar" ] || { echo "missing android.jar: $PLATFORM/android.jar" >&2; exit 1; }

mkdir -p "$OUT/res" "$OUT/gen" "$OUT/classes" "$OUT/dex"
find "$OUT/res" -type f -delete
find "$OUT/gen" -type f -delete
find "$OUT/classes" -type f -delete
find "$OUT/dex" -type f -delete
rm -f "$OUT"/*.apk "$OUT"/*.zip "$OUT"/*.keystore

"$BUILD_TOOLS/aapt2" compile --dir "$ROOT_DIR/res" -o "$OUT/resources.zip"
"$BUILD_TOOLS/aapt2" link \
  -I "$PLATFORM/android.jar" \
  --manifest "$ROOT_DIR/AndroidManifest.xml" \
  --java "$OUT/gen" \
  --min-sdk-version 23 \
  --target-sdk-version 30 \
  --version-code 1 \
  --version-name 1.0 \
  -o "$OUT/unsigned.apk" \
  "$OUT/resources.zip"

find "$OUT/gen" -name 'R.java' -print > "$OUT/sources.list"
find "$ROOT_DIR/src" -name '*.java' -print >> "$OUT/sources.list"
javac -source 8 -target 8 -encoding UTF-8 -cp "$PLATFORM/android.jar" -d "$OUT/classes" @"$OUT/sources.list"

classes=()
while IFS= read -r -d '' class_file; do classes+=("$class_file"); done < <(find "$OUT/classes" -name '*.class' -print0)
"$BUILD_TOOLS/d8" --lib "$PLATFORM/android.jar" --min-api 23 --output "$OUT/dex" "${classes[@]}"

cp "$OUT/unsigned.apk" "$OUT/unsigned-aligned.apk"
"$BUILD_TOOLS/zipalign" -f 4 "$OUT/unsigned-aligned.apk" "$OUT/aligned.apk"
keytool -genkeypair -v \
  -keystore "$OUT/debug.keystore" \
  -storepass android \
  -keypass android \
  -alias androiddebugkey \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname 'CN=Android Debug,O=Android,C=US' >/dev/null 2>&1

"$BUILD_TOOLS/apksigner" sign \
  --ks "$OUT/debug.keystore" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$OUT/projector-launcher.apk" \
  "$OUT/aligned.apk"
"$BUILD_TOOLS/apksigner" verify --verbose "$OUT/projector-launcher.apk"
cp "$OUT/projector-launcher.apk" "$SKILL_DIR/assets/projector-launcher.apk"
printf 'built %s (%s bytes)\n' "$SKILL_DIR/assets/projector-launcher.apk" "$(wc -c < "$SKILL_DIR/assets/projector-launcher.apk" | tr -d ' ')"
