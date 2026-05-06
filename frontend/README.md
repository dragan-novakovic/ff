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
