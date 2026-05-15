# FF Frontend

Flutter app for the game frontend.

## Run as a web app

Start the backend identity service and gateway first, in separate terminals:

```sh
cd ../backend
dotnet run --project services/identity-service/Ff.Identity.Api --urls http://127.0.0.1:5125
```

```sh
cd ../backend
FF_IDENTITY_BASE_URL=http://127.0.0.1:5125 dotnet run --project services/gateway-service/Ff.Gateway.Api --urls http://127.0.0.1:5124
```

The identity service stores accounts in PostgreSQL. In development, the seeded test login is `demo@ff.local` / `secret`; override it with `FF_IDENTITY_SEED_EMAIL`, `FF_IDENTITY_SEED_PASSWORD`, and `FF_IDENTITY_SEED_USERNAME`.

Alternatively, run the full backend Docker stack:

```sh
cd ../backend
docker compose up --build
```

From this directory:

```sh
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Open the URL printed by Flutter, usually `http://127.0.0.1:8080`.

If Chrome or another browser device is configured in Flutter, this also works:

```sh
flutter run -d chrome
```

## Build for web

```sh
flutter build web
```

The production web build is written to `build/web`.

The frontend calls the gateway at `http://127.0.0.1:5124` by default. Override the gateway URL with:

```sh
flutter run -d web-server --dart-define=FF_API_BASE_URL=http://127.0.0.1:5124
```

## Android local App Center distribution

This repo does not use GitHub Actions for Android distribution. Build and distribute test APKs from your machine with the App Center CLI.

Install and log in once:

```sh
npm install -g appcenter-cli
appcenter login
```

Generate an upload key locally if you want release builds to keep the same signing identity:

```sh
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Copy `frontend/android/key.properties.example` to `frontend/android/key.properties` and point `storeFile` at your local keystore. Do not commit `upload-keystore.jks` or `key.properties`.

Distribute to an App Center group:

```sh
cd frontend
APPCENTER_APP=owner/ff-android \
APPCENTER_GROUP=Testers \
FF_API_BASE_URL=https://your-gateway.example.com \
scripts/distribute_appcenter_android.sh
```

The script runs `flutter pub get`, `flutter test --no-pub`, builds `app-release.apk`, and uploads it with `appcenter distribute release`. By default, it uses the version name from `pubspec.yaml` and a timestamp-based Android `versionCode` so each local upload is installable as a newer build.

Optional overrides:

| Variable | Purpose |
|---|---|
| `APPCENTER_APP` | Required App Center app in `owner/app-name` format |
| `APPCENTER_GROUP` | Distribution group; defaults to `Collaborators` |
| `BUILD_NAME` | Android `versionName`; defaults to the `pubspec.yaml` version name |
| `BUILD_NUMBER` | Android `versionCode`; defaults to the current Unix timestamp |
| `FF_API_BASE_URL` | Required gateway URL compiled into the APK; use a URL reachable by tester devices |
| `RELEASE_NOTES` | App Center release notes |

## Android E2E smoke tests

The repository uses Maestro for local black-box Android click-through tests.

Current smoke coverage:

- launches `com.example.ff`;
- verifies the login screen renders;
- taps and types into the email/password fields;
- verifies the demo-login button is visible;
- opens and closes the password reset dialog.

Run the same flow locally after installing Maestro and starting an Android emulator:

```sh
cd frontend
flutter build apk --debug --no-pub \
  --dart-define=FF_SHOW_DEMO_LOGIN=true \
  --dart-define=FF_API_BASE_URL=http://10.0.2.2:5124

adb install -r build/app/outputs/flutter-apk/app-debug.apk
cd ..
maestro test .maestro
```

Add deeper flows as backend-dependent scenarios become stable, for example demo login, dashboard navigation, battle contribution, market listing, and inbox messaging.
