# ReportR

ReportR is a civic issue reporting app. The mobile client is built with Flutter, and the API is a Node.js and Express backend backed by MySQL.

## Repository layout

- `flutter/` — Flutter mobile app, Android/iOS projects, assets, localization, and tests.
- `backend/` — Express API, MySQL access, report and community endpoints, media handling, and migrations.
- `report/` — project documentation.
- `doc_report/` — report source material and generated project report.

## Requirements

- Flutter SDK compatible with `flutter/pubspec.yaml` and Android tooling for device builds.
- Node.js and npm.
- MySQL, with a database configured for ReportR.
- A Firebase Android configuration for push notifications, a Firebase Admin service account for backend notifications, and restricted Google Maps API keys for map tiles.
- Optional service credentials for Gemini issue analysis, AssemblyAI transcription, and Cloudinary media storage.

The npm and Flutter lockfiles are committed to pin dependency versions. Installed dependency and build-cache directories are ignored and should not be committed.

## Configure the backend

From the repository root in PowerShell:

```powershell
Copy-Item backend/.env.example backend/.env
cd backend
npm.cmd ci
npm.cmd run start:local
```

Set the MySQL credentials and service keys in `backend/.env`. Keep `backend/firebase-service-key.json` beside `backend/server.js` for Firebase Admin notifications. That service account file and `.env` are local credentials and are ignored by Git. The local startup script listens on port `5002` by default; `http://127.0.0.1:5002/` should return `{"Hello":"Working"}` when the server is running.

Download fresh Firebase client configuration from Firebase Console for the app. For Android, place `google-services.json` at `flutter/android/app/google-services.json`; for iOS, place `GoogleService-Info.plist` at `flutter/ios/Runner/GoogleService-Info.plist`. These project-specific files are ignored by Git. Restrict their API keys to the intended app and required APIs, and do not reuse a key that has been exposed publicly.

The project migration scripts are under `backend/scripts/`. Review the applicable SQL files in `backend/migrations/` and the instructions in `backend/COMMUNITY.md` before applying database migrations.

## Run the Flutter app

Copy `flutter/.env.example` to `flutter/.env`, then set `BACKEND_BASE_URL` to the API address reachable from the device. For an Android phone connected over USB, start the backend and run:

```powershell
adb devices
adb reverse tcp:5002 tcp:5002
cd flutter
flutter pub get
flutter run -d YOUR_DEVICE_ID
```

The app uses `http://127.0.0.1:5002/` through the USB reverse by default. Configure the Google Maps Android key in `flutter/android/app/src/main/AndroidManifest.xml`; restrict it to the app package and signing certificate, and enable the Maps SDK. See [Flutter setup notes](flutter/README.md) for Firebase, Maps, and device details.

See the [USB startup guide](startup.md) for the complete local startup sequence.

## Before pushing

Copy the `.env.example` files for local configuration and keep real credentials out of Git. Google Maps and Firebase client configuration are embedded in mobile apps; restrict API keys to the intended app and APIs. Review `git status` and `git diff` before committing so that only intended source files and documentation are included.
