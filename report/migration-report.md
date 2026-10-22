# React Native/Expo to Flutter Migration Audit

Audit date: 2026-09-03
Repository: `C:\Users\Admin\Desktop\college\sem7\sih2025`

This audit is based on source and configuration inspection only. I did not modify application source files. The only filesystem change made for this task was creating this requested report at `report/migration-report.md`.

## 1. Repository Overview

The repository contains a compact civic issue reporting application named ReportR.

Top-level structure:

- `frontend/`: React Native application built with Expo. This is the part targeted for replacement with Flutter/Dart.
- `backend/`: Node.js/Express API server. It handles login/OTP, report submission, report retrieval, AI issue detection/verification, audio transcription, media upload, MySQL access, and push notification sending.
- Root `package.json`: currently only declares `piexifjs`. It does not orchestrate the frontend/backend.
- `.expo/`: local Expo state.
- `node_modules/`, `frontend/node_modules/`, `backend/node_modules/`: installed dependencies.

The app appears to be a mobile-first civic issue reporting tool:

1. User logs in with name and phone number.
2. On Android, the backend sends an OTP through Firebase Cloud Messaging.
3. User captures or picks an image of a civic issue.
4. The app gets GPS coordinates from image EXIF if available, otherwise from device location.
5. The backend calls Gemini to detect likely civic issues and bounding boxes.
6. The user fills/accepts issue details, optionally records an audio description.
7. Audio can be transcribed by the backend using AssemblyAI after ffmpeg conversion.
8. The frontend generates a local PDF report from a bundled template.
9. The report, image, optional audio, and PDF are uploaded to the backend.
10. The backend verifies the issue with Gemini, uploads files to Cloudinary, and stores metadata in MySQL.
11. The map screen polls backend report markers and displays them through Leaflet inside a React Native WebView.
12. Nearby users can view report details and see a local resolution feedback modal if within 200 meters.

The backend/database can mostly remain as-is for a Flutter migration because the frontend communicates with it over HTTP/JSON and multipart form upload. The main migration effort is rebuilding the mobile client, replacing Expo/RN-native modules, and preserving subtle client-side behavior around notifications, local files, PDF creation, WebView map messaging, and local persistence.

## 2. Application Functionality

### Authentication and Session

Implemented in:

- `frontend/App.js`
- `frontend/pages/LoginScreen.jsx`
- `backend/services/userRoutes.js`
- `backend/services/firebaseMessaging.js`

Current behavior:

- `LoginScreen` collects `name`, `phone`, and then `otp` on Android.
- Android obtains an FCM token in `App.js` using `@react-native-firebase/messaging`, stores it in AsyncStorage under `token`, and sends it to `/api/user/sendOTP`.
- The backend stores OTPs in MySQL table `otps` and sends the OTP as an FCM push notification.
- `/api/user/verifyOTP` verifies phone/OTP/name, inserts a row into `users`, deletes the OTP, and returns the created user ID.
- The frontend stores `userDetails` in Expo SecureStore as JSON `{ id, name, number }`.
- Existing Android users are auto-routed to `Home` if `userDetails` exists.
- iOS code path is different: existing users are prompted for biometric auth if hardware/enrollment exists, but new iOS login bypasses backend OTP entirely and stores a local user with `id: Date.now()`.

Dependencies:

- Frontend: `expo-secure-store`, `@react-native-async-storage/async-storage`, `expo-local-authentication`, `@react-native-firebase/messaging`, `expo-notifications`, `axios`.
- Backend: MySQL, Firebase Admin SDK.

Migration assessment:

- Requires adaptation.
- Flutter can reuse the backend OTP APIs, but the current iOS behavior is not equivalent to Android and may not map cleanly to a production Flutter app.
- Use Flutter secure storage for `userDetails`, shared preferences or secure storage for language/token, `local_auth` for biometrics, and `firebase_messaging` for FCM.

Risks:

- OTP is delivered through push notifications, not SMS. Login depends on FCM token availability.
- Backend `/sendOTP` requires both `phone` and `token`; iOS currently bypasses this.
- `App.js` references `Alert` and `setFcmToken` without importing/defining them in that scope, which suggests notification token refresh may be broken.
- Recreating this exactly in Flutter requires deciding whether to preserve the Android/iOS behavioral split or normalize it.

### Report Capture and Issue Detection

Implemented in:

- `frontend/pages/CameraScreen.jsx`
- `frontend/component/CameraPage/CameraUI.jsx`
- `frontend/component/CameraPage/ImagePreview.jsx`
- `frontend/services/gemini.js`
- `backend/server.js`
- `backend/services/IssueDetection.js`

Current behavior:

- Camera permissions are requested via `expo-camera`.
- `CameraUI` uses `CameraView`, pinch gesture zoom, slider zoom, front/back camera switch, flash toggle, and document/image picker.
- Captured photos include base64 data via `takePictureAsync({ base64: true })`.
- Picked images are copied into Expo FileSystem cache and read as base64.
- `piexifjs` attempts to parse EXIF GPS from picked JPEGs. EXIF coordinates are normalized in `frontend/helpers/ExifHelper.js`.
- If EXIF GPS is available, that location is used. Otherwise the app asks for foreground location and reverse-geocodes it with Expo Location.
- Base64 image and MIME type are sent to backend `/api/getPredictions`.
- Backend uses Gemini `gemini-2.5-flash-preview-05-20` to return civic issue detections as JSON, including `issue`, `probability`, `description`, and `bounding_box`.
- The frontend overlays bounding boxes on the preview by scaling Gemini's 1000x1000 normalized coordinates to the rendered image size.
- Predicted issue labels become tappable category chips.

Dependencies:

- Frontend: `expo-camera`, `expo-document-picker`, `expo-file-system/legacy`, `expo-location`, `piexifjs`, `react-native-gesture-handler`, `react-native-reanimated`, `@react-native-community/slider`.
- Backend: Gemini API key, Node `fetch`, Express JSON body limit.

Migration assessment:

- Requires adaptation, but no backend rewrite is needed for parity.
- Flutter equivalents: `camera`, `image_picker` or `file_picker`, `geolocator`/`geocoding`, EXIF parser package, gesture detector, slider, custom overlay painter/widgets, `dio` or `http`.

Risks:

- Current upload to `/api/getPredictions` sends large base64 JSON payloads. Flutter must preserve body size and MIME handling.
- EXIF parsing currently assumes JPEG data URI loading through `piexifjs`; Flutter EXIF packages may return GPS data in different formats.
- Bounding box overlay assumes `bounding_box` order `[ymin, xmin, ymax, xmax]` on a 1000-grid and uses the rendered image layout, not the original image dimensions.
- `CameraScreen` imports `Camera` for permissions and `CameraView` in a child for preview/capture. Flutter's permission/camera lifecycle differs.

### Report Form, Audio, Transcription, Local Drafts, PDF, Upload

Implemented in:

- `frontend/component/CameraPage/ReportForm.jsx`
- `frontend/services/transcription.js`
- `frontend/services/pdfGeneration.js`
- `frontend/services/templates/pdfTemplate.js`
- `frontend/services/templates/FontTemplate.js`
- `frontend/services/gemini.js`
- `frontend/services/messagingService.js`
- `backend/server.js`
- `backend/services/Transcribe.js`
- `backend/services/userRoutes.js`
- `backend/services/IssueVerification.js`
- `backend/services/UploadToCloudinary.js`

Current behavior:

- Form fields include location, name, phone, category, and optional description.
- Name/phone/user ID are read from SecureStore `userDetails`; fields are displayed as non-editable.
- Report ID is generated client-side as `Rid_${year}${first4OfUuidWithoutDashes}`.
- Before submission, the app queries `/api/reports/getReportByLocation` to alert if a nearby report exists.
- `createAndStoreReportData` always writes local report data under Expo document directory: `reports/{reportID}/image.jpeg`, optional `audio.m4a`, and `data.json`.
- It also appends `reportID` to AsyncStorage key `pendingReports`.
- There is no active sync worker in the inspected source. Pending reports are stored, but automatic later sync is not implemented in this repo.
- The frontend generates a PDF locally using `pdf-lib` and an embedded base64 PDF template.
- The generated PDF is saved under the same local report folder as `report.pdf`.
- The app sends an immediate "report raised" notification request to `/api/user/sendNotification`.
- Then it calls `/api/user/submitReport` with multipart form data: report fields, image, optional audio, optional PDF.
- Backend verifies the submitted image against the user category with Gemini.
- Backend maps verification score to status:
  - `score > 60`: `Issue Raised`
  - `score > 5`: `Verification pending`
  - otherwise: `Invalid Report`
- Backend uploads media to Cloudinary under `reportr/reports/{Rid}`.
- Backend inserts report metadata into MySQL table `reports`.
- Backend sends follow-up FCM notifications for verified or invalid reports.
- The frontend shows a modal offering to share/save the generated PDF, even if upload fails.

Dependencies:

- Frontend: `expo-av`, `expo-file-system/legacy`, `expo-sharing`, `pdf-lib`, `@pdf-lib/fontkit` declared but not used in current PDF generation, `react-native-uuid`, SecureStore, AsyncStorage.
- Backend: `multer` memory storage, `fluent-ffmpeg`, local ffmpeg availability, AssemblyAI, Gemini, Cloudinary, Firebase Admin, MySQL.

Migration assessment:

- Significant adaptation on the frontend.
- Backend endpoints can be reused as-is if Flutter sends the same multipart fields and file names/types.
- Flutter equivalents: `record` or `flutter_sound`/`just_audio` for audio, `path_provider` for local folders, `share_plus`, `pdf` or Syncfusion/other PDF library, `uuid`, `dio` multipart upload.

Risks:

- Offline behavior is only partial. The app stores pending report IDs locally but has no inspected background sync implementation.
- Report ID generation is client-side and collision-resistant only to a small 4-character UUID slice plus year.
- `submitReport` in `ReportForm` is called without `await`, so frontend success UI can appear before upload actually completes.
- On upload failure, the PDF/draft exists locally, but there is no recovery queue processor.
- Backend transcription writes to a fixed `temp.mp3` and deletes it from `server.js`, which is race-prone under concurrent requests.
- Backend `server.js` calls `fs.unlinkSync("temp.mp3")` even on errors; if the file is missing, the error handler can throw again.
- PDF generation currently strips non-ASCII text, which affects Hindi/Marathi/user-entered local language content. A Flutter rewrite must decide whether to preserve that limitation or implement proper font embedding.
- `FontTemplate.js` exists and contains a large font base64, but current `pdfGeneration.js` does not use it.

### Map, Report Discovery, and Resolution Review

Implemented in:

- `frontend/pages/MapScreen.jsx`
- `frontend/assets/leaflet.html`
- `frontend/services/mapServices.js`
- `frontend/helpers/MapHelper.js`
- `frontend/component/maps/CustomDropdown.jsx`
- `frontend/component/maps/AnimatedButton.jsx`
- `frontend/component/maps/ResolutionReviewModal.jsx`
- `backend/services/reportRoutes.js`

Current behavior:

- Map screen loads bundled `leaflet.html` through Expo Asset and FileSystem, then renders it in `react-native-webview`.
- The HTML pulls Leaflet CSS/JS and `leaflet.heat` from `https://unpkg.com`, so the map is not fully offline.
- React Native posts marker arrays to the WebView via `postMessage`.
- Leaflet creates custom div markers and a heat layer.
- Marker clicks post `{ type: "markerClick", Rid, lat, lng, color }` back to React Native.
- React Native fetches `/api/reports/getReportData`, calculates whether the user is within 200 meters, and shows report details in a modal.
- User location is requested via Expo Location.
- Reports are polled every 5 seconds when the tab index is map.
- Filters include "My reports", `Resolved`, `In Progress`, `Issue Raised`, `Verification pending`, and `Invalid Report`.
- Default map excludes `Invalid Report`.
- The "Is this issue resolved?" button appears when user is within 200 meters.
- `ResolutionReviewModal` collects local star rating/feedback and only shows an alert; it does not update backend state.

Dependencies:

- Frontend: `react-native-webview`, `expo-asset`, `expo-file-system/legacy`, `expo-location`, SecureStore, external Leaflet CDN, OpenStreetMap tiles.
- Backend: report list/detail/location routes, JSON `location` field in DB.

Migration assessment:

- Requires adaptation.
- Two practical Flutter paths:
  - Rebuild as native Flutter map using `flutter_map` plus OpenStreetMap/heatmap/marker layers.
  - Keep the Leaflet HTML approach in a Flutter WebView and reimplement the JS bridge.
- A native Flutter map is cleaner long-term but has more UI migration work. WebView reuse is closer to parity but preserves external CDN/runtime bridge coupling.

Risks:

- Current WebView bridge includes `window.ReactNativeWebView.onMessage`, `document.addEventListener("message")`, and `window.addEventListener("message")`; Flutter WebView uses a different JavaScript channel model.
- Leaflet and heatmap scripts are CDN-loaded, so network availability affects map rendering even when the app has local HTML.
- Polling every 5 seconds can duplicate user-location markers because there is a separate effect that appends `userLoc` to markers.
- Filter labels are hardcoded English strings, while some translations define status labels. Backend also returns English status strings. Flutter localization must preserve backend status matching or introduce a mapping layer.
- Search bar is visual only; no search behavior is implemented.

### Localization

Implemented in:

- `frontend/i18n/index.js`
- `frontend/i18n/locales/en.json`
- `frontend/i18n/locales/hi.json`
- `frontend/i18n/locales/mr.json`
- `frontend/component/LanguageSwitcher.jsx`

Current behavior:

- Uses `i18next` and `react-i18next`.
- Detects saved language from AsyncStorage key `user-language`.
- Falls back to device locale via `expo-localization`.
- Supported languages in detector: English, Hindi, Marathi.
- Language switcher currently exposes English and Hindi; Marathi is commented out.
- UI strings are partly translated; some strings remain hardcoded English in map filter/resolution modal/submit button.

Dependencies:

- Frontend: `i18next`, `react-i18next`, `expo-localization`, AsyncStorage.

Migration assessment:

- Straightforward to reproduce conceptually.
- Flutter can use `intl`, ARB files, or JSON-based localization.
- Existing translation text can be reused conceptually, but JSON shape may need conversion.

Risks:

- Some locale files contain mojibake/encoding artifacts in rendered source comments or emoji/star strings.
- Backend status values and frontend filter labels are English business values, not locale-independent codes.
- PDF generation currently removes non-ASCII, so localized report PDFs are not truly supported despite localized app UI.

### Placeholder or Dead/Inactive Areas

Observed files/features:

- `frontend/pages/Profile.jsx` is empty.
- `frontend/pages/Login.jsx` is a simple inactive/legacy login screen; `App.js` imports it but the stack uses `LoginScreen`.
- Main tab placeholders exist for Reports, Analytics, and Profile in `frontend/pages/MainApp.jsx`.
- Floating robot and notification icon buttons in `MainApp` have no behavior attached.
- `frontend/config.json` appears to be an older Expo config; active Expo entry is `frontend/app.json`.
- `frontend/assets/templates/PendingReport.pdf` exists, while current PDF generation uses embedded `PDFTEMPLATE` from `frontend/services/templates/pdfTemplate.js`.
- `FontTemplate.js` and `@pdf-lib/fontkit` are present but not actively used by `pdfGeneration.js`.
- Root `package.json` only includes `piexifjs`; the active apps have their own package manifests.

Migration assessment:

- Do not migrate inactive files unless product requirements say otherwise.
- Preserve visible placeholders only if parity is required for the current UI.

## 3. Frontend Architecture

Entry and navigation:

- `frontend/index.js` registers `App` through Expo.
- `frontend/App.js` wraps the app with `SafeAreaProvider`, `GestureHandlerRootView`, `NavigationContainer`, and a native stack navigator.
- Stack screens:
  - `Login`: `LoginScreen`
  - `Home`: `MainApp`
- `MainApp` implements a hidden-tab `TabView` plus `react-native-paper` `BottomNavigation.Bar`.
- Default selected tab index is `2`, the camera/report home tab.

State and persistence:

- Most state is local React state, with no global store.
- Durable client state is split between:
  - SecureStore: `userDetails`
  - AsyncStorage: FCM `token`, `user-language`, `pendingReports`
  - Expo FileSystem document directory: report folders and generated PDFs

Service layer:

- `frontend/services/gemini.js` is misnamed: it does not call Gemini directly; it calls backend endpoints for prediction and report submission.
- `frontend/services/mapServices.js` wraps report map APIs and normalizes the backend URL with a trailing slash.
- `frontend/services/messagingService.js` calls backend notification endpoint.
- `frontend/services/transcription.js` uploads audio to backend.
- `frontend/services/pdfGeneration.js` owns local PDF creation.

UI architecture:

- Component boundaries are simple and screen-specific.
- There is no central typed API model, no schema validation, and no central error handling.
- Business rules such as "within 200 meters can resolve", report ID format, status filter labels, pending report storage, and PDF field coordinates live in frontend components/services.

Flutter implications:

- A direct Flutter rewrite can use a lightweight architecture without needing to replicate a complex state management system.
- However, several business behaviors are embedded in UI components and must be deliberately extracted into Flutter services/models to avoid losing them.

## 4. External and Internal Dependencies

Important frontend dependencies:

- Expo/RN runtime: `expo`, `react-native`, `react`, `react-native-web`.
- Navigation/UI: React Navigation stack, TabView, React Native Paper bottom navigation, Expo vector icons, LinearGradient.
- Native/device: camera, audio, location, document picker, file system, sharing, secure store, local authentication, notifications, Firebase messaging.
- WebView map: `react-native-webview`, Leaflet/leaflet.heat CDN, OpenStreetMap tiles.
- Data/API: `axios`.
- PDF/media: `pdf-lib`, embedded PDF template, image base64 handling.
- EXIF: `piexifjs`; `exifreader` is declared but not observed as used.
- Localization: `i18next`, `react-i18next`, `expo-localization`.

Important backend dependencies:

- Express 5, CORS, dotenv.
- MySQL through `mysql2/promise`.
- Multipart uploads through `multer` memory storage.
- Cloudinary uploads.
- Firebase Admin SDK with service account JSON.
- Gemini API for detection and verification.
- AssemblyAI for transcription.
- `fluent-ffmpeg` for audio conversion.
- `jsonwebtoken`, `node-fetch`, `uuid`, and `fs` dependency are declared but not observed as materially used in active routes, except Node built-in `fs` imports.

Secrets/configuration:

- Backend reads environment variables for `PORT`, MySQL connection, Cloudinary credentials, Gemini API key, and AssemblyAI API key.
- Backend includes a Firebase service account file path `backend/firebase-service-key.json`. This is sensitive and should not be embedded in a mobile app.
- Frontend reads `EXPO_PUBLIC_BACKEND_URL`.
- Frontend contains `google-services.json` for Android package `com.reportr.frontend` and Firebase project metadata. A Flutter Android app will need corresponding Firebase configuration and package/application ID alignment.

## 5. Frontend to Backend Boundary

The current frontend/backend contract is small and reusable:

- `POST /api/user/sendOTP`
  - JSON: `{ name, phone, token }`
  - Requires push token in backend code.
  - Stores OTP and sends FCM push with OTP.

- `POST /api/user/verifyOTP`
  - JSON: `{ name, phone, otp, token }`
  - Creates a `users` row and returns `{ success, user: { id, name, phone } }`.

- `POST /api/user/sendNotification`
  - JSON: `{ Rid, name, userId }`
  - Looks up user's stored FCM token and sends push.

- `POST /api/user/submitReport`
  - Multipart fields: `reportID`, `userID`, `name`, `number`, `category`, `description`, `location`, `createdDate`.
  - Multipart files: `image`, optional `audio`, optional `pdf`.
  - Verifies issue, uploads media, inserts DB row.

- `POST /api/transcribeDescription`
  - Multipart file: `audio`.
  - Returns `{ success: true, result: { text, confidence, duration } }` on success.

- `POST /api/getPredictions`
  - JSON: `{ base64Image, mimeType }`
  - Returns array of predicted issues.

- `GET /api/reports/getAllReports`
  - Returns marker data `{ Rid, lat, lng, status, color, userID }[]`.

- `POST /api/reports/getReportData`
  - JSON: `{ Rid }`
  - Returns `{ issue, description, imageURL, createdAt, status }`.

- `POST /api/reports/getReportByLocation`
  - JSON: `{ lat, lng }`
  - Returns nearby report rows.

What can remain unchanged:

- API routes can remain unchanged if Flutter preserves payload shapes.
- MySQL and Cloudinary storage can remain unchanged.
- Gemini/AssemblyAI calls can remain backend-only.
- Firebase Admin notification sending can remain backend-only.

Backend assumptions the Flutter app must preserve:

- `location` is JSON-stringified by the client and contains at least `lat` and `lng`.
- Report status values are English strings.
- Image upload field must exist as `image`.
- Audio type is currently sent as `audio/m4a`; backend converts received buffer to MP3 for AssemblyAI transcription.
- Frontend is expected to generate and upload the PDF; backend does not generate PDF.

## 6. Platform / Native Dependencies

React Native/Expo-specific areas to replace:

- Expo app config/build: `frontend/app.json`, `frontend/eas.json`, `frontend/metro.config.js`.
- Expo runtime entry: `frontend/index.js`.
- Expo camera: camera permissions, `CameraView`, `takePictureAsync`, zoom/flash/facing.
- Expo location: foreground permission, GPS, reverse geocoding.
- Expo document picker and file system legacy API.
- Expo Asset loading of `leaflet.html`.
- Expo AV audio recording/playback.
- Expo SecureStore and AsyncStorage.
- Expo Sharing.
- Expo Notifications plus Android notification channel setup.
- React Native Firebase Messaging.
- React Native WebView bridge.
- React Native Reanimated/Animated/Gesture Handler.
- React Navigation/TabView/React Native Paper.
- Expo vector icons.

Platform-specific behavior:

- Android:
  - FCM token acquisition and notification permission handling.
  - Android 13+ `POST_NOTIFICATIONS` permission.
  - Notification channel `default`.
  - `CameraUI` passes `useCamera2Api={true}`.
- iOS:
  - Existing-user biometric authentication.
  - New-user login bypasses backend OTP.
  - Audio mode allows recording and silent mode playback.
- Both:
  - Camera, microphone, location, file access, sharing, WebView, and push notification permissions.

Flutter architecture differences likely to matter:

- Flutter's Firebase Messaging setup requires native Android/iOS config, background handler registration, APNs handling for iOS, and initialization before use.
- Flutter WebView JS channels differ from `window.ReactNativeWebView`.
- Flutter local file paths and URI handling differ from Expo's `file://` conventions, especially for multipart upload and sharing.
- Flutter camera plugins have different lifecycle requirements when app goes background/foreground.
- Flutter PDF generation libraries have different coordinate/font/image APIs; exact template parity may take manual calibration.

## 7. Migration Assessment

### Straightforward to Reproduce

- Basic screen navigation and bottom tabs.
- Login UI layout and local session check.
- REST/JSON API calls.
- Multipart report upload, if payload fields are preserved.
- Language switcher concept and existing translation content.
- Haversine distance helper.
- Static image assets and branding.
- Placeholder Reports/Analytics/Profile tabs.

### Requires Some Adaptation

- FCM token acquisition and notification handling.
- Secure local storage split between secure and non-secure data.
- Camera capture, zoom, flash, front/back switching.
- Location permission, reverse geocoding, and EXIF fallback.
- Image picker/document picker behavior.
- Audio recording/playback and transcription upload.
- Leaflet-in-WebView map parity.
- PDF generation from an existing template.
- Generated report local directory layout.

### Requires Significant Redesign or Careful Product Decision

- Offline/pending report behavior. Current app stores pending data but does not implement automatic sync.
- iOS authentication parity. Current iOS login bypasses backend OTP for new users.
- Map implementation choice: reuse Leaflet through WebView versus rebuild with native Flutter map widgets.
- Localized PDF support. Current PDF text cleaning removes non-ASCII.
- Resolution workflow. Current review modal is UI-only and does not update backend.
- Push-notification-based OTP. It is unusual and fragile compared with SMS/email OTP.

### Uncertain / Needs Investigation

- Actual database schema, indexes, constraints, and production data volume; no migrations/schema files were present.
- Whether there is another admin/municipal backend outside this repo that updates report statuses to `In Progress` or `Resolved`.
- Whether hidden Expo native generated folders exist elsewhere; this repo does not show committed `android/` or `ios/` folders.
- Whether Firebase service account and Google services configuration are development-only or production.
- Whether any intended background sync exists outside this repository.

## 8. Reuse vs Rewrite

Can keep as-is:

- `backend/` API server, with caveats about concurrency/error hardening.
- MySQL database, assuming schema supports current fields.
- Cloudinary storage model and folder convention.
- Firebase Admin notification sending, if Flutter app registers compatible FCM tokens.
- Gemini and AssemblyAI backend integrations.
- Existing HTTP endpoint shapes.
- Static image assets, PDF template asset, and font assets, subject to license/format checks.

Can reuse conceptually:

- Report submission flow and data model.
- Client-side issue prediction UX.
- EXIF-first location strategy.
- Local report folder structure.
- Pending report storage concept.
- PDF field mapping and report layout.
- Map marker colors/status definitions.
- 200-meter resolution eligibility rule.
- Translation strings.
- Bottom-tab app structure.

Must rebuild in Flutter:

- All React Native components and screens.
- Navigation and tab UI.
- Camera UI and image preview overlay.
- Audio recorder/player UI.
- Local file system handling.
- Secure/session storage implementation.
- PDF generation implementation.
- Push notification setup and foreground/background behavior.
- WebView bridge or native map.
- Localization runtime.
- Expo/EAS build configuration into Flutter Android/iOS build configuration.

Should not migrate unless needed:

- Inactive `frontend/pages/Login.jsx`.
- Empty `frontend/pages/Profile.jsx`.
- Old `frontend/config.json`, unless later confirmed active.
- Unused/dead dependencies such as `exifreader`, `jsonwebtoken`, `node-fetch`, and current unused font embedding support.

## 9. Migration Risks

Highest-risk items:

- Push OTP via FCM: Flutter must obtain/store tokens before login, and backend currently rejects `/sendOTP` without token.
- iOS login behavior: current code does not use backend OTP for new iOS users, so parity versus intended behavior must be clarified.
- WebView map bridge: Leaflet HTML can be reused only after replacing React Native message bridge with Flutter JavaScript channels.
- Offline claims: user-facing text says reports sync later, but no sync implementation was found.
- PDF parity: coordinates, template dimensions, image placement, and non-ASCII text handling are brittle.
- Multipart URI handling: Flutter file uploads must match backend field names and content types exactly.
- Backend transcription temp file: fixed `temp.mp3` is unsafe for concurrent use and can break under simultaneous Flutter clients too.
- Missing DB schema: migration testing requires a real schema or schema dump.
- Status labels as business logic: frontend filters match English strings directly from backend.
- Secrets hygiene: backend service account file exists in repo; Flutter must not embed backend secrets.

Additional edge cases:

- Report submission currently may show success before upload completes because `submitReport` is not awaited.
- Nearby duplicate check uses a very tight lat/lng bounding box (`0.0001`) rather than actual distance.
- Map polling can create duplicate user markers.
- Search field on map is non-functional.
- Resolution feedback does not persist.
- Gemini JSON parsing assumes perfect JSON from model output.
- Frontend uses `process.env.EXPO_PUBLIC_BACKEND_URL`; Flutter needs equivalent environment/flavor configuration.

## 10. Recommended Migration Strategy

1. Freeze and document the current backend contract.
   - Write request/response examples for every route listed above.
   - Export or document MySQL schema for `users`, `otps`, and `reports`.
   - Decide whether Flutter must preserve current bugs/quirks or intended behavior.

2. Build a Flutter skeleton with native configuration first.
   - App ID should align with Firebase configuration or a new Firebase app should be created.
   - Add environment/flavor handling for backend base URL.
   - Add secure storage, localization, navigation, and bottom tabs.

3. Migrate authentication and notifications.
   - Implement Firebase Messaging token registration.
   - Confirm Android notification permission/channel behavior.
   - Decide and implement iOS login behavior.
   - Validate OTP flow against the existing backend before adding report features.

4. Migrate report capture.
   - Camera capture, gallery/file image selection, EXIF GPS extraction, current location fallback, reverse geocoding.
   - Integrate `/api/getPredictions`.
   - Rebuild bounding box overlay and category chip selection.

5. Migrate report form, audio, and upload.
   - Audio recording/playback.
   - `/api/transcribeDescription`.
   - Local report storage.
   - PDF generation and sharing.
   - `/api/user/submitReport` multipart upload.
   - Explicitly decide whether to implement missing pending-report sync now or preserve current partial behavior.

6. Migrate map.
   - Choose WebView Leaflet parity or native Flutter map.
   - Implement marker polling, filters, detail modal, distance check, target-current-location behavior, and heatmap.
   - If using WebView, port `leaflet.html` bridge carefully.
   - If using native map, replace Leaflet heat layer with a Flutter heatmap equivalent.

7. Migrate polish and placeholders.
   - Static assets, language switcher, tab icons, placeholder reports/analytics/profile, floating action buttons if still required.

8. Stabilize with integration tests/manual test scripts.
   - Login OTP.
   - Existing session.
   - Camera permission denial.
   - Picked image with and without EXIF.
   - Prediction empty/non-empty.
   - Audio transcription timeout/failure.
   - Report upload success/failure.
   - PDF share.
   - Map marker click and filter.
   - FCM foreground/background notifications.

## 11. Overall Assessment

Overall migration difficulty: medium-high.

The UI itself is not large, but the frontend owns many native/device responsibilities: camera, GPS, EXIF, audio, secure storage, notifications, WebView maps, local files, PDF generation, and multipart uploads. Rebuilding screens in Flutter is straightforward; reproducing behavior at the native integration boundaries is the real effort.

Biggest technical risks:

- FCM/OTP login behavior, especially iOS parity.
- Camera/image/EXIF/location flow.
- PDF generation parity and multilingual text support.
- WebView Leaflet bridge or native map replacement.
- Partial offline/pending-report behavior.
- Backend temp-file concurrency in transcription.
- Lack of database schema/migrations.

Approximate relative effort:

- Backend reuse/API validation: low to medium.
- Flutter app foundation/auth/notifications: medium.
- Camera/report form/audio/PDF/upload: high.
- Map/report review: medium to high depending on WebView versus native map.
- Cleanup/product decisions around offline sync, iOS auth, and resolution workflow: potentially high if moving beyond current parity.

Things that could significantly change the estimate:

- Requirement for true offline sync.
- Requirement for production-grade iOS OTP instead of current local bypass.
- Requirement to replace WebView Leaflet with a fully native Flutter map.
- Requirement for localized PDFs with Hindi/Marathi text.
- Existing external systems that update report statuses but are not present in this repository.
- Production database schema constraints not visible in this repo.

Recommended next investigations:

- Obtain database schema and representative non-sensitive sample rows.
- Confirm intended login model for iOS and Android.
- Confirm whether pending report sync is required for migration parity.
- Confirm whether map must work offline or without CDN dependencies.
- Confirm whether PDF output must support Indian language text.
- Audit backend secrets handling and remove service-account/private credentials from source control in a separate security task.
