# ReportR Flutter app

Community features, resolution rules, privacy and validation are documented in [Community reporting](../report/COMMUNITY_FEATURES.md). See the [backend reference](../backend/COMMUNITY.md) for APIs and migrations.

## Android USB startup

From `backend`, run `npm.cmd run start:local` (port 5002). Keep MySQL running with the configured `reportr` database. In another terminal:

```powershell
adb reverse tcp:5002 tcp:5002
cd flutter
flutter pub get
flutter run -d YOUR_DEVICE_ID
```

Set `flutter/.env` to `BACKEND_BASE_URL=http://127.0.0.1:5002/`. Sign-in codes arrive as ReportR push notifications, not SMS.

## Google Maps key

Replace `YOUR_GOOGLE_MAPS_API_KEY` in:

- Android: `android/app/src/main/AndroidManifest.xml`, the `com.google.android.geo.API_KEY` metadata value.
- iOS: `ios/Runner/Info.plist`, the `GoogleMapsAPIKey` value.

Enable Maps SDK for Android (and Maps SDK for iOS if using iOS) in your Google Cloud project with billing configured. Use an Android-restricted key for package `com.reportr.frontend` and the appropriate signing certificate SHA-1. For the local debug certificate, run `android/gradlew.bat signingReport` from the Flutter directory. Rebuild the app after inserting the key; hot reload will not update native configuration.

The key is read natively before constructing the map. With the placeholder, reports remain browsable and the screen explains that the map preview is unavailable. Leaflet and its WebView dependency/assets have been removed. Google Maps requires Android 7/API 24 or later and iOS 15 or later.

Official setup: https://developers.google.com/maps/flutter-package/config

## Camera and predictions

After capture or photo selection, Gemini results open a full-screen image review. The entire image remains visible, and pinch zoom keeps bounding boxes aligned with the image. Numbered, colored boxes match unique floating issue options. Repeated detections of one title retain all object boxes but create one option. Multiple selected categories are saved together in the report, PDF, and upload. Continue collapses the image and opens editable report details; Review photo expands it again without losing selections or text.

## Validation

```powershell
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/prediction_review_test.dart -d YOUR_DEVICE_ID
```

Phone integration screenshots are saved in `build/phone-validation/`. These tests use a deterministic fixture image to check box placement, multiple selection, collapse/expand, and the native missing-key guard. They do not send reports. Live Google tiles require your real API key.

## Submission, languages and report PDFs

All product screens support English, Hindi, and Marathi, including validation, progress, filters, status history, PDF actions, and camera controls. Canonical API categories/status values and user-authored report text are preserved. New PDF copies use the selected language and retain Hindi/Marathi text with properly shaped glyphs.

Report creation has one **Submit report** action. It checks nearby duplicates, saves evidence locally for retry, creates the PDF, and uploads automatically. On success the modal offers **View PDF**, **Download PDF**, and **Share PDF**. Android saving uses the system file picker; sharing opens the native chooser without sending anything automatically. Personal reports, retained drafts, and authority details expose PDF actions. Public community reports exclude PDFs and recordings.

Cloudinary public delivery can deny PDF URLs. The authenticated backend endpoint `GET /api/reports/:reportId/pdf` serves a private archived copy or recovers the original through a server-signed download. Only the report owner and authority/admin accounts can access it. New uploads archive valid PDF bytes in the gitignored `backend/data/reports` directory. Keep that directory when deploying or moving the backend. Do not expose it as public static files.

Additional validation:

```powershell
# Backend, including private PDF/archive checks
npm.cmd test
node scripts/check-report-pdfs.js

# Flutter real device: local save, genuine PDF generation, mocked upload boundary,
# localized success modal, PDF rendering and reports-page reopening
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/submission_pdf_locales_test.dart -d YOUR_DEVICE_ID
```

The device tests do not submit fixture reports to the production backend or send files to contacts. `pdf_native_export_test.dart` additionally exercises native saving/sharing and requires an operator to select Save and dismiss the share chooser; the fixture source must be placed in the app cache as `qa-source.pdf` first. Generated QA PDFs live under `output/pdf` at the workspace root.
