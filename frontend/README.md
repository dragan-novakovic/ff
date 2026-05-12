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

## Android CI and internal testing

GitHub Actions builds a new Android version on every push with `.github/workflows/android-internal-testing.yml`.

The workflow:

- runs `flutter pub get` and `flutter test --no-pub`;
- builds both `app-release.apk` and `app-release.aab`;
- uses the semantic version from `pubspec.yaml` as `versionName`;
- uses `github.run_number` as `versionCode`, so every push gets a newer installable version;
- uploads the APK/AAB as GitHub Actions artifacts;
- publishes the AAB to the Google Play `internal` track when signing and Play secrets are configured.

Google Play Internal Testing has no per-build or per-tester fee. It requires a Google Play Console account, which has a one-time developer registration fee.

### Required GitHub secrets

Configure these repository secrets before expecting automatic Play distribution:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded Android upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Upload key alias |
| `ANDROID_KEY_PASSWORD` | Upload key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play service account JSON with release permissions |

Optional repository variables:

| Variable | Purpose |
|---|---|
| `ANDROID_PACKAGE_NAME` | Play package name; defaults to `com.example.ff` |
| `FF_API_BASE_URL` | Gateway URL compiled into CI Android builds |

Generate an upload key locally, then store only the base64 value in GitHub secrets:

```sh
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

base64 -w 0 upload-keystore.jks
```

Do not commit `upload-keystore.jks` or `key.properties`. `frontend/android/key.properties.example` shows the local file format when you need to test a signed release build outside CI.

### Tester distribution flow

1. Create the app in Google Play Console and set up the Internal testing track.
2. Add tester emails or a Google Group in the Internal testing testers list.
3. Create a service account, grant it release permissions for this app, and save the JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
4. Add the Android signing secrets above.
5. Push to the repository. The workflow builds a new version and uploads it to Internal testing.

Pull requests run the same build/test checks but do not publish to Play.
