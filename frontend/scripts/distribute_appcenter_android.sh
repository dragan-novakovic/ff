#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v appcenter >/dev/null 2>&1; then
  echo "appcenter CLI is not installed. Run: npm install -g appcenter-cli" >&2
  exit 1
fi

: "${APPCENTER_APP:?Set APPCENTER_APP to your App Center app name, for example owner/ff-android.}"
: "${FF_API_BASE_URL:?Set FF_API_BASE_URL to a gateway URL reachable by testers.}"

APPCENTER_GROUP="${APPCENTER_GROUP:-Collaborators}"
BUILD_NAME="${BUILD_NAME:-$(awk '/^version:/ { print $2 }' pubspec.yaml | cut -d+ -f1)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s)}"
RELEASE_NOTES="${RELEASE_NOTES:-Local Android build ${BUILD_NAME}+${BUILD_NUMBER}}"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

flutter pub get
flutter test --no-pub

flutter build apk --release --no-pub \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=FF_API_BASE_URL="$FF_API_BASE_URL"

appcenter distribute release \
  --app "$APPCENTER_APP" \
  --group "$APPCENTER_GROUP" \
  --file "$APK_PATH" \
  --release-notes "$RELEASE_NOTES"
