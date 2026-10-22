# Migration Parity Status

Checked against the current React Native source and the Flutter implementation on 2026-09-17. This is a parity status, not a redesign specification.

## Completed parity

- Android startup, secure `userDetails` session restoration, OTP request/verification, FCM token persistence, notification channel, foreground notification display, and background handler are implemented.
- The five-tab shell uses the RN order and default Home/Camera tab. `IndexedStack` preserves tab state.
- Camera capture, camera switching, flash, zoom, lifecycle disposal, document-style image selection, base64 conversion, MIME handling, EXIF GPS fallback, foreground location permission, reverse geocoding, prediction sorting, and prediction error states are implemented.
- Report metadata preserves RN field names, the `Rid_<year><uuid first four>` ID format, location JSON shape, ISO creation date, local `reports/<reportID>/` storage, `image.jpeg`, optional `audio.m4a`, `data.json`, `report.pdf`, and `pendingReports`.
- Audio recording is persisted with the existing `audio.m4a` local contract. The existing RN transcription endpoint is now also called with field `audio`, filename `recording.m4a`, MIME `audio/m4a`, and a two-minute timeout.
- PDF generation and multipart submission preserve the actual backend route `/api/user/submitReport`, field names, filenames, and MIME types. The existing report-raised notification route `/api/user/sendNotification` is called non-blockingly after successful submission.
- Leaflet remains a WebView using the RN HTML/OSM tiles. The `mapReady`, `markerClick`, `loadMarkers`, and `setView` bridge protocol, invalid-report filtering, 5-second active polling, marker details, and 200 m Haversine check are implemented.
- The RN nearby-report lookup is now performed when the Flutter report form opens. It uses `POST /api/reports/getReportByLocation` and shows an advisory warning without blocking report creation.
- English, Hindi, Marathi localization infrastructure and the `user-language` preference are present.

## Partially migrated

- Map marker loading and report upload are implemented but have not been validated end-to-end against a running backend and emulator in this pass.
- FCM delivery, OTP delivery, transcription, Cloudinary upload, backend verification, and notification receipt remain dependent on external services and were not live-validated here.
- Flutter has functional report preparation/submission and retry retention, but it does not reproduce the RN PDF sharing/download modal.
- Flutter records, saves, and transcribes audio, but does not reproduce the RN audio playback/progress controls.
- The map shows the RN report detail fields and the 200 m eligibility message. The RN star-based `ResolutionReviewModal` is local feedback only and has no backend persistence; Flutter does not reproduce that local modal.

## RN-incomplete functionality

- RN Reports and Analytics tabs are placeholders with no report-list or analytics API flow. Flutter keeps them as placeholders.
- RN map search is rendered but has no search behavior.
- RN resolution review only displays a thank-you flow; it does not submit a resolution or rating to the backend.
- RN FCM token refresh references an undefined `setFcmToken`; Flutter fixes persistence locally but no backend token-update endpoint exists.
- RN iOS login uses a local session shortcut and optional biometrics rather than the Android OTP/FCM flow. No verified Flutter iOS Firebase/APNs contract is present.

## Remaining migration gaps

- Add the existing RN PDF share/download interaction if that user workflow is required for Android parity.
- Add audio playback, pause, progress, and delete controls if recording review is required for parity.
- Perform live WebView marker/detail validation with the backend and a device.
- Confirm the backend's external transcription, AI verification, Cloudinary, and Firebase notification integrations in a real environment.
- Decide whether the RN local resolution-review feedback should remain retired or become a real backend-backed product feature.

## Future product-building backlog

- Implement a real Reports list/detail workflow; RN has no usable implementation to migrate.
- Implement Analytics; RN has no usable implementation to migrate.
- Add offline synchronization only after a product and conflict model is defined; no usable RN worker exists.
- Add notification inbox/history, real map search, resolution workflows, and richer account settings as new product features rather than migration work.
- Define and verify a proper iOS authentication/FCM/APNs product flow.

## Validation status

### Automated validation

- `flutter analyze`: passed with no issues.
- `flutter test --dart-define=FLUTTER_TEST=true`: passed. The define is required by the existing camera test guard to avoid physical camera initialization.
- `flutter build apk --debug`: passed.
- Focused tests cover authentication, prediction parsing, report contracts/storage, marker parsing/filtering, and Haversine distance.

### Emulator/device validation

- The earlier parity automation did not include an emulator run; current emulator results are recorded in **Live Validation Results** below.

### Live backend validation

- The earlier parity automation did not include live backend flows; current host reachability and remaining live blockers are recorded in **Live Validation Results** below.

### Unverified behavior

- Full `.env` request use from the Flutter UI remains unverified; host-side cleartext HTTP reachability is recorded below.
- Android release signing/configuration was not inspected beyond the existing debug-build configuration.

## Live Validation Results

### Device/emulator

- Passed: Android emulator `emulator-5554`, Generic Medium Phone API 36.0, package `com.reportr.frontend`.
- Passed: `flutter run -d emulator-5554 --no-resident` built, installed, launched, and attached successfully.
- Passed: Debug APK installation succeeded with ADB.

### Backend configuration

- The app package contains the configured `.env` asset with the local development URL. The URL was not logged with credentials or tokens.
- Passed with limitation: host-side HTTP access to `http://172.30.160.1:5000/` returned `200` and `{"Hello":"Working"}`. A complete request from the running Flutter UI was not executed because real OTP/device interaction was not completed.

### Flows tested

- Passed: Firebase native initialization completed without a crash.
- Passed: Flutter engine startup and app launch completed.
- Passed: Android notification permission request appeared and returned to the app.
- Passed: Application package and main activity were correct.
- Passed: Camera, microphone, fine/coarse location, notification, and internet permissions were present in the installed manifest. Runtime camera, microphone, and location grants were not exercised.
- Not tested: real OTP delivery and verification.
- Not tested: camera capture, document selection, prediction request, reverse geocoding, audio recording, transcription, PDF generation, multipart upload, post-upload notification, map WebView rendering, marker API loading, marker selection, and polling disposal.

### Fixes made during live validation

- No new code fix was required from the emulator startup run. The app reached runtime permission handling and produced no fatal Flutter or Android exception in the observed startup logs.

### Remaining blockers

- No real OTP credentials or test account were used, so authentication and all authenticated flows remain live-unverified.
- Runtime camera, microphone, and location interactions require manual emulator permission grants and were not completed in this run.
- FCM delivery and backend-side transcription, AI verification, Cloudinary upload, and notification delivery require external service validation.
- The emulator reported no network time, but this did not prevent app launch; backend HTTP reachability was verified separately from the host.

### Items not testable in the current environment

- Firebase push delivery and OTP reception.
- Complete report submission against real AI/Cloudinary/database services.
- Leaflet tile loading and JavaScript bridge behavior in the live WebView.
- End-to-end retry/pending-report cleanup after a real failed and successful upload.


## Authentication Validation

- **Test method:** Real Flutter UI on `emulator-5554`, using a synthetic phone number and the existing production OTP routes. No backend code or auth contract was changed. The OTP was read from the existing local test database only to complete emulator validation before expiry.
- **OTP sending:** **Passed.** Flutter sent the existing request shape to `POST /api/user/sendOTP`; the UI transitioned to OTP entry and the backend returned success.
- **OTP delivery:** **Passed with limitation.** The emulator received an FCM OTP notification during direct backend validation. The complete notification-to-UI timing was not reliable for every attempt, so delivery should be retested with a stable test account.
- **OTP verification:** **Passed.** A fresh OTP entered through the Flutter UI reached `POST /api/user/verifyOTP` and opened the authenticated Home shell.
- **Session persistence:** **Passed.** After force-stopping and relaunching the app, Flutter restored the secure `userDetails` session and showed Home/Camera.
- **FCM:** Firebase initialization, token persistence, notification permission handling, and at least one emulator notification delivery passed. Token refresh and background interaction were not separately exercised.
- **Production safety:** No fixed OTP, mock route, or production bypass was added. The backend has no existing development OTP mode.

## End-to-End Report Validation

| Stage | Status | Result |
|---|---|---|
| App launch and environment loading | Passed | Flutter launched with the configured backend URL visible in the login UI. |
| Authentication and session restoration | Passed | Real synthetic OTP flow and restart restoration passed. |
| Camera capture | Blocked by environment | The emulator reported `Camera is unavailable.`; the Flutter UI remained stable. |
| Image selection | Not tested | Not reached after camera availability check. |
| Prediction request/display | Not tested | Requires a real image and backend AI request. |
| Location/reverse geocoding | Not tested | Runtime location permission/GPS was not completed. |
| Audio recording | Not tested | No microphone interaction was performed. |
| Transcription | Not tested | Requires a real recording and external transcription service. |
| PDF generation | Not tested | Requires completing the report form. |
| Multipart upload | Not tested | Requires a completed report and external verification/Cloudinary services. |
| Notification after submission | Not tested | The API is implemented but report submission was not reached. |
| Pending-report cleanup/retry | Not tested | Requires a real upload success/failure cycle. |

## Map Validation

- **Map tab/lifecycle:** The authenticated Map tab was opened on the emulator. Android WebView native initialization completed without a fatal exception.
- **Backend marker endpoint:** `GET /api/reports/getAllReports` was reachable and returned six marker records from the development backend.
- **WebView/Leaflet rendering:** **Passed with limitation.** The WebView/Chromium implementation initialized and produced no Flutter/Android fatal error. Tile rendering and JavaScript marker interaction were not visually confirmed through the available automation.
- **Markers:** Not fully tested. Live response availability passed; marker rendering/click handling remains unverified.
- **Nearby-report lookup:** Not tested from the Flutter form. The backend route is reachable in the migrated code but requires opening the report form with a location.
- **Polling/disposal:** Not directly observed in runtime. Unit/lifecycle code remains covered by the existing implementation, but no live timer/disposal trace was collected.

## Remaining Blockers

- The available emulator has no usable camera device, blocking the report journey after authentication.
- Runtime location and microphone flows still need explicit emulator interaction or mocked hardware input.
- Prediction, transcription, AI verification, Cloudinary upload, and final report submission require completing the image/report flow and depend on external services.
- Visual Leaflet tiles, marker clicks, and map polling need manual confirmation after the report workflow blocker is removed.
- No application code fix was required from this validation run.

## Camera-Workaround Validation (2026-10-01)

This section supersedes the earlier report-flow statuses above for the current emulator run. The existing camera path was not changed. Because the emulator camera was unavailable, the debug APK exposed a clearly labeled `Select test image (debug only)` action in the camera-unavailable state. It calls the existing `FilePicker` and then the unchanged image, EXIF/location, prediction, report, PDF, and upload pipeline. This control is compiled only for debug builds and is not a production image source.

### Authentication

- **Passed:** Existing Flutter OTP request, FCM OTP delivery, OTP verification, secure session persistence, force-stop/relaunch restoration, and Firebase initialization were previously live-validated on `emulator-5554`.

### Image capture

- **Blocked by environment:** The emulator reports `Camera is unavailable.` The app remains usable and exposes the debug-only picker fallback in debug builds.

### Image selection

- **Passed:** Android DocumentsUI opened from the Flutter camera screen and selected a real emulator PNG. The image was read through `MediaService`, persisted into the report directory as `image.jpeg`, and continued through the normal pipeline.

### Prediction

- **Passed with limitation:** The real `/api/getPredictions` request completed against the configured development backend and the UI displayed an empty prediction result (`No civic issues detected.`). This validates request/response handling and the empty-state path, but not a non-empty prediction or bounding-box rendering.

### Location

- **Passed:** Android foreground location permission was granted for the emulator test. The actual current emulator coordinate `37.4219983, -122.084` was used and reverse geocoded to the emulator's test address. No real user location was used.

### Audio/transcription

- **Not tested:** The report was completed without audio. Microphone recording, the `POST /api/transcribeDescription` call, and transcription failure/recovery remain unverified on this emulator.

### PDF

- **Passed:** The actual `PdfService` generated `report.pdf` from the live report form. The local directory contained `image.jpeg`, `data.json`, and `report.pdf`; the report ID and metadata were persisted.

### Upload

- **Passed with limitation:** The real `POST /api/user/submitReport` flow returned to Home and cleared the `pendingReports` entry. The backend `GET /api/reports/getAllReports` subsequently contained the synthetic report with its submitted coordinates and `Invalid Report` status. The backend's external verification classified the emulator screenshot as invalid; that is an expected backend result, not a Flutter transport failure. A successful valid-report classification was not tested.

### Pending reports

- **Passed with limitation:** After the observed successful upload, `pendingReports` was `[]`. A forced network/upload failure followed by manual retry was not run, so retention across a failed attempt remains unverified in the emulator.

### Map

- **WebView:** **Passed with limitation.** The authenticated Map tab opened and Android WebView/Chromium initialized without a fatal exception.
- **Tiles:** **Not tested.** OpenStreetMap tile pixels were not visually confirmed through the available automation.
- **Markers:** **Passed with limitation.** The backend marker endpoint returned records, including the newly submitted synthetic record, but marker pixels were not visually confirmed.
- **Marker interaction:** **Not tested.** No live marker tap/detail interaction was confirmed.
- **Nearby lookup:** **Passed with limitation.** The live report form reached the location-aware form and the app's nearby lookup was advisory/non-blocking; a nearby match dialog was not observed.
- **Polling lifecycle:** **Not tested.** No live timer trace was collected after leaving the tab, although the implementation cancels active polling with the screen lifecycle.

### Validation commands

- **Passed:** `flutter analyze`.
- **Passed:** `flutter test --dart-define=FLUTTER_TEST=true` with all 24 tests passing.
- **Passed:** `flutter build apk --debug`.
- **Passed:** Debug APK installation and launch on `emulator-5554`.

### Remaining blockers

- Camera hardware remains unavailable on this emulator; camera capture itself is not validated.
- Microphone/transcription, non-empty AI predictions/bounding boxes, valid-report backend classification, upload-failure retry, and visual Leaflet interactions still need a device/backend setup that supports them.
- No production code path or backend contract was bypassed by the debug-only picker.
