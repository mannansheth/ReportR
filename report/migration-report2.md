 I revalidated the prior report against the current repository and did not modify files.

  Revalidation
  Most migration-significant claims in report/migration-report.md are confirmed.

  Confirmed:

  - Expo/RN frontend and Node/Express backend split: frontend/, backend/server.js.
  - Active app entry: frontend/index.js → frontend/App.js.
  - Auth stack: LoginScreen then MainApp: frontend/App.js.
  - Android-only FCM setup: frontend/App.js.
  - Android OTP through backend push notification: frontend/pages/LoginScreen.jsx, backend/services/userRoutes.js, backend/services/
    firebaseMessaging.js.

  - iOS new-login bypasses backend OTP and stores a local user ID: frontend/pages/LoginScreen.jsx.
  - Camera/image/location/prediction flow: frontend/pages/CameraScreen.jsx.
  - Report form/audio/PDF/upload flow: frontend/component/CameraPage/ReportForm.jsx.
  - Backend Gemini detection and verification: backend/services/IssueDetection.js, backend/services/IssueVerification.js.
  - Backend AssemblyAI transcription with ffmpeg and fixed temp.mp3: backend/services/Transcribe.js, backend/server.js.
  - Leaflet map in WebView with CDN scripts and RN bridge: frontend/pages/MapScreen.jsx, frontend/assets/leaflet.html.
  - No DB schema/migrations found; schema must be inferred from SQL.
  - Placeholder/dead areas: frontend/pages/Profile.jsx, inactive frontend/pages/Login.jsx, placeholder tabs in MainApp.

  Partially confirmed / refined:

  - “Send notification then submit report”: confirmed, but submitReport(...) is not awaited after sendNotification(...), so the success modal
    can appear before upload finishes.

  - “Offline draft behavior”: confirmed local draft storage exists, but there is no sync implementation. Treat “automatic sync” text as
    unimplemented UI copy.

  - “Language support”: detector supports en, hi, mr, but switcher exposes only en and hi. Some strings remain hardcoded English.
  - “PDF template asset”: active code uses frontend/services/templates/pdfTemplate.js, not frontend/assets/templates/PendingReport.pdf.

  Unclear:

  - Actual MySQL schema, constraints, indexes.
  - Whether another system updates statuses like Resolved / In Progress.
  - Whether iOS OTP bypass is intentional or a hack.
  - Whether the app must preserve partial offline behavior or implement real sync later.

  True Boundary
  Keep unchanged:

  - Node/Express backend routes.
  - MySQL database.
  - Gemini calls.
  - AssemblyAI transcription route.
  - Cloudinary uploads.
  - Firebase Admin push sending.

  Flutter/client owns:

  - UI/navigation.
  - FCM token acquisition and local notification display.
  - Session persistence.
  - Camera/image/file acquisition.
  - EXIF location extraction.
  - GPS/reverse geocoding.
  - Prediction request orchestration.
  - Audio recording/playback.
  - Local report folder/draft writing.
  - PDF generation.
  - Multipart upload.
  - Map UI/bridge/filtering/distance logic.

  Shared contract:

  - EXPO_PUBLIC_BACKEND_URL equivalent base URL.
  - Secure stored userDetails shape: { id, name, number }.
  - Async/local stored keys: token, user-language, pendingReports.
  - Report ID format: Rid_${year}${4-char-uuid-fragment}.
  - location multipart field is JSON string containing { lat, lng, loc }.
  - Multipart file field names: image, audio, pdf.
  - Status strings are backend English values.

  Flutter Architecture
  Use a simple layered Flutter app. Do not introduce Bloc/Riverpod unless complexity grows.

  Recommended structure:

  lib/
    main.dart
    app.dart
    config/
      app_config.dart
      constants.dart
    core/
      network/api_client.dart
      storage/secure_storage_service.dart
      storage/preferences_service.dart
      errors/api_error.dart
    models/
      user_session.dart
      report.dart
      report_marker.dart
      prediction.dart
      location_info.dart
    services/
      auth_service.dart
      notification_service.dart
      report_api_service.dart
      map_api_service.dart
      media_service.dart
      location_service.dart
      exif_service.dart
      audio_service.dart
      pdf_service.dart
      local_report_store.dart
    screens/
      login/login_screen.dart
      home/main_shell.dart
      camera/camera_screen.dart
      map/map_screen.dart
      reports/reports_placeholder_screen.dart
      analytics/analytics_placeholder_screen.dart
      profile/profile_placeholder_screen.dart
    widgets/
      language_switcher.dart
      app_bottom_nav.dart
      gradient_button.dart
      report_form.dart
      image_prediction_overlay.dart
      audio_recorder_control.dart
      map_filter_dropdown.dart
      report_detail_sheet.dart
      resolution_review_modal.dart
    l10n/
      app_en.arb
      app_hi.arb
      app_mr.arb
    assets/
      leaflet/leaflet.html

  State management:

  - StatefulWidget and ChangeNotifier are enough.
  - Use a small SessionController for boot/login/session state.
  - Use local state for camera/report/map screens.
  - Use IndexedStack for bottom tabs so map/camera state is not unnecessarily destroyed.

  Package Stack
  Use current maintained Flutter packages where they directly replace current behavior.

  - dio: replaces Axios. Best fit because the app needs JSON calls, multipart file upload, timeouts, and upload error handling. Current pub.dev
    metadata shows dio 5.11.0, active and widely used. Requires no special native config. Simpler alternative: http, but
    multipart/timeouts/interceptors are less ergonomic. Source: https://pub.dev/packages/dio

  - firebase_core, firebase_messaging: replaces @react-native-firebase/app and messaging. Required for push OTP and report notifications.
    Requires Android google-services.json, Gradle Firebase config, iOS APNs/Firebase config if iOS support is real. Current firebase_messaging
    16.6.0 is actively maintained by Firebase. Source: https://pub.dev/packages/firebase_messaging

  - flutter_local_notifications: replaces foreground local display via expo-notifications. Needed because Firebase foreground notifications are
    not automatically presented the same way. Requires Android notification channel and runtime permission handling. Source:
    https://pub.dev/packages/flutter_local_notifications

  - flutter_secure_storage: replaces Expo SecureStore for userDetails. Requires platform secure storage initialization; actively maintained.
    Source: https://pub.dev/packages/flutter_secure_storage

  - shared_preferences: replaces AsyncStorage for token, user-language, pendingReports. Good for simple key/value app state. Source:
    https://pub.dev/packages/shared_preferences/changelog

  - local_auth: replaces Expo LocalAuthentication. Needed only if preserving iOS existing-user biometric prompt.
  - camera: replaces Expo Camera. Current camera 0.12.0+2 is Flutter-maintained. Requires Android/iOS permissions and explicit lifecycle
    handling. Source: https://pub.dev/packages/camera

  - file_picker: closer to current expo-document-picker than image_picker because the current UI picks image documents. Use image_picker only
    if product wants gallery/camera semantics.

  - native_exif: recommended over pure Dart exif for GPS extraction because current target is Android/iOS and native_exif has direct
    getLatLong(). Limitation: mobile only, small ecosystem. Source: https://pub.dev/packages/native_exif

  - geolocator: replaces Expo Location current-position and distance helper if desired. Active, supports current position and distance.
    Requires Android/iOS location permissions. Source: https://pub.dev/packages/geolocator

  - geocoding: replaces Expo reverse geocode. Limitation: uses platform geocoding services and can hit rate limits / Google Play availability
    issues. Source: https://pub.dev/packages/geocoding

  - record: replaces Expo AV recording. Current package supports M4A/AAC style recording and permissions. Source:
    https://pub.dev/packages/record

  - just_audio: replaces Expo AV playback. Mature and appropriate for local audio preview. Source: https://pub.dev/packages/just_audio
  - path_provider: replaces Expo FileSystem document/cache directories.
  - share_plus: replaces Expo Sharing for generated PDF. Current package supports Android/iOS file sharing. Source:
    https://pub.dev/packages/share_plus

  - pdf: replaces pdf-lib. It can generate PDFs with images and TrueType fonts; use it to recreate the current report template. Source:
    https://pub.dev/packages/pdf

  - webview_flutter: recommended map implementation for first migration; replaces react-native-webview. Current webview_flutter 4.14.1 is
    Flutter-maintained. Requires JS channel changes. Source: https://pub.dev/packages/webview_flutter

  - uuid: replaces react-native-uuid.
  - flutter_svg is not required unless new vector assets are introduced.
  - Avoid flutter_map for the first migration despite being active, because the current Leaflet heatmap/custom marker behavior is already
    implemented and WebView reuse is lower risk for parity. flutter_map remains a later native-map option. Source for viability:
    https://pub.dev/packages/flutter_map

  Map Decision
  Recommendation: keep Leaflet in a Flutter WebView for first migration.

  Why:

  - Current behavior is already Leaflet-specific: custom div markers, Leaflet heat layer, OSM tile layer, click-to-post-message bridge.
  - The app does not use advanced native map features.
  - Rebuilding natively would require matching heatmap behavior and marker styling with extra packages or custom painters.
  - WebView migration is mostly bridge work, not feature reinterpretation.

  Flutter map design:

  - Place adapted leaflet.html under Flutter assets.
  - Load it with WebViewController.loadFlutterAsset(...) or loadHtmlString(...).
  - Replace window.ReactNativeWebView.postMessage(...) with a Flutter JavaScript channel, e.g. ReportMap.postMessage(...).
  - Send marker data from Dart by running JavaScript, e.g. receiveMessage({data: json}) or expose loadMarkers(json).
  - Preserve:
      - initial center [19.1760, 72.8577], zoom 12
      - OSM tile URL
      - marker color values from backend
      - user marker shape/color
      - heat layer excluding isUser
      - marker click fetches report detail
      - target button recenters to user location zoom 13
      - click recenters marker at zoom 16
      - 5-second polling while map tab is active
      - default exclusion of Invalid Report

  Do not implement search behavior unless explicitly added later; current search bar is visual only.

  FCM/Auth Migration Design
  Backend unchanged:

  - /api/user/sendOTP requires { phone, name, token }.
  - /api/user/verifyOTP requires { phone, otp, name, token }.
  - OTP is delivered by FCM, not SMS.
  - Backend stores token on users only after OTP verification.

  Flutter behavior:

  1. App startup calls WidgetsFlutterBinding.ensureInitialized() and Firebase.initializeApp().
  2. Request notification permission early enough to obtain FCM token before Android OTP request.
  3. On Android 13+, request POST_NOTIFICATIONS.
  4. Create local notification channel default, high importance, matching backend channelId: "default".
  5. Get FCM token with FirebaseMessaging.instance.getToken().
  6. Persist token in SharedPreferences key token.
  7. Listen for token refresh and update local key. Backend has no token-update endpoint, so changed tokens after login are a gap unless user
     re-verifies or backend is extended later.

  8. Foreground FCM messages trigger local notification display using flutter_local_notifications.
  9. Register background message handler at top level.
  10. Login screen:

  - If secure userDetails exists: Android navigates home; iOS optionally prompts biometric then navigates home.
  - Android new user sends OTP with persisted FCM token.
  - Verify OTP stores { id: user.id.toString(), name: user.name, number: user.phone }.
  - iOS new-user behavior is unresolved: current RN bypasses backend and stores { id: Date.now(), name, number }.

  Product decision:

  - Preserve iOS bypass for exact parity, or use backend OTP on iOS after configuring APNs/FCM. Do not silently change this.

  Report Creation Pipeline
  Flutter must reproduce this data path:

  1. User opens default Home tab, camera view.
  2. User captures image via camera or picks image file.
  3. Image becomes local file path plus base64.
  4. If picked image has EXIF GPS:
      - extract decimal lat/lng
      - reverse geocode

  5. Else:
      - request foreground location
      - get current position
      - reverse geocode

  6. Send prediction request:
      - POST /api/getPredictions
      - JSON { base64Image, mimeType }
      - expect Prediction[]
      - sort descending by probability

  7. Render preview:
      - image fill/crop behavior
      - boxes use [ymin, xmin, ymax, xmax] over 1000x1000 normalized grid

  8. User edits category and description.
  9. Optional audio:
      - record M4A/AAC file
      - upload to /api/transcribeDescription as multipart field audio, filename recording.m4a, MIME audio/m4a
      - set description from response.result.text
      - allow playback/pause/delete

  10. Generate reportID: same format Rid_${year}${uuidNoDashFirst4}.
  11. Build reportData:

  - reportID
  - userID
  - name
  - number
  - category
  - description
  - location: { lat, lng, loc }
  - createdDate: DateTime.now().toUtc().toIso8601String() equivalent to JS ISO

  12. Local storage:

  - app document directory reports/{reportID}/
  - copy image to image.jpeg
  - optional audio to audio.m4a
  - write data.json
  - append report ID to pendingReports

  13. Generate PDF:

  - save to reports/{reportID}/report.pdf
  - match template layout and field coordinates conceptually
  - include image at equivalent placement

  14. Submit:

  - first call /api/user/sendNotification with { Rid, name, userId }
  - then multipart POST /api/user/submitReport
  - fields exactly: reportID, userID, name, number, category, description, location as JSON string, createdDate
  - files exactly: image as report_image.jpg image/jpeg; optional audio as report_audio.m4a audio/m4a; optional pdf as report.pdf application/
    pdf

  15. Backend verifies image using Gemini, uploads to Cloudinary, inserts DB row, sends verified/invalid notification.
  16. Flutter shows PDF share/download modal whether online success or saved-draft failure, matching current visible behavior.

  Important compatibility choice:

  - The RN app does not await final submitReport; Flutter should decide whether parity means not awaiting or whether “intended behavior” means
    await and show failure correctly. I recommend awaiting it but preserving the same success/failure messages; call this out as a behavior
    fix.

  Hidden Migration Traps Ranked

  1. FCM-token-before-login dependency; no token means Android OTP cannot be requested.
  2. iOS auth inconsistency; current iOS users may not exist in backend.
  3. Multipart field names/MIME types; backend expects exact fields.
  4. File URI/path differences; Dio needs real file paths, not Expo URIs.
  5. PDF non-ASCII behavior; current PDF strips Indian-language text.
  6. Image orientation and EXIF GPS; Flutter camera/picker may rotate or strip metadata differently.
  7. Bounding boxes with cover scaling; naive scaling can visibly misplace boxes.
  8. Not awaiting report upload; Flutter may accidentally change UX/timing.
  9. Fixed backend temp.mp3; simultaneous transcriptions can fail.
  10. Map WebView bridge differences.
  11. Backend route error behavior can hang/return empty body.
  12. Status strings are English business values, not localization keys.
  13. pendingReports queue has no sync worker.
  14. Reverse geocoding rate limits/platform availability.
  15. Map polling duplicates/marker churn if state is not normalized.
  16. Report ID collision risk from only four UUID chars.
  17. Backend assumes req.files.image[0]; missing image crashes route.

  Do Not Migrate

  - frontend/pages/Login.jsx: inactive legacy screen.
  - frontend/pages/Profile.jsx: empty file; only migrate visible placeholder from MainApp.
  - frontend/config.json: obsolete Expo config.
  - RN/Expo build files: metro.config.js, eas.json, Expo plugins.
  - Unused dependencies: exifreader, expo-image-picker, expo-image-manipulator, expo-network, expo-device, expo-status-bar, backend
    jsonwebtoken, node-fetch, backend uuid.

  - mapItems in MapScreen: unused.
  - FontTemplate.js unless choosing to fix localized PDFs.
  - assets/templates/PendingReport.pdf unless using it as the Flutter PDF background instead of embedded JS base64.
  - Floating robot/bell buttons should be migrated only as inert visible controls if strict visual parity is required; they have no behavior.

  Migration Units

  1. App shell/config/localization/session
      - RN files: App.js, MainApp.jsx, i18n/*, assets.
      - Flutter files: main.dart, app.dart, main_shell.dart, l10n/*, storage services.
      - Packages: flutter_secure_storage, shared_preferences.
      - Done when startup routes existing session to Home and language switch works.
      - Difficulty: low-medium.

  2. Network contract/models
      - RN files: services/*.js, backend route files.
      - Flutter files: api_client.dart, model classes, API services.
      - Packages: dio.
      - Done when all endpoints have typed request/response methods and tolerate null/error bodies.
      - Difficulty: medium.

  3. Auth + FCM notifications
      - RN files: App.js, LoginScreen.jsx.
      - Backend: /sendOTP, /verifyOTP, /sendNotification.
      - Flutter files: auth_service.dart, notification_service.dart, login_screen.dart.
      - Packages: firebase_core, firebase_messaging, flutter_local_notifications, local_auth.
      - Done when Android OTP push arrives, verify stores session, foreground messages display.
      - Difficulty: high.

  4. Camera/image/location/prediction
      - RN files: CameraScreen.jsx, CameraUI.jsx, ImagePreview.jsx, ExifHelper.js.
      - Backend: /api/getPredictions.
      - Flutter files: camera_screen.dart, media_service.dart, location_service.dart, exif_service.dart, image_prediction_overlay.dart.
      - Packages: camera, file_picker, native_exif, geolocator, geocoding.
      - Done when capture/pick predicts issues and overlays boxes.
      - Difficulty: high.

  5. Report form/audio/transcription/local draft
      - RN files: ReportForm.jsx, transcription.js.
      - Backend: /api/transcribeDescription, /api/reports/getReportByLocation.
      - Flutter files: report_form.dart, audio_service.dart, local_report_store.dart.
      - Packages: record, just_audio, path_provider.
      - Done when M4A records, plays, transcribes, and local draft files are created.
      - Difficulty: high.

  6. PDF generation/share
      - RN files: pdfGeneration.js, pdfTemplate.js.
      - Flutter files: pdf_service.dart.
      - Packages: pdf, share_plus.
      - Done when generated PDF includes same fields/image and can be shared.
      - Difficulty: medium-high.

  7. Report upload/verification flow
      - RN files: gemini.js, messagingService.js, ReportForm.jsx.
      - Backend: /api/user/submitReport, /api/user/sendNotification.
      - Flutter files: report_api_service.dart, submit UI state.
      - Packages: dio.
      - Done when backend inserts report and Cloudinary URLs appear in DB/API response.
      - Difficulty: medium-high.

  8. Map/report review
      - RN files: MapScreen.jsx, leaflet.html, map components/helpers.
      - Backend: /getAllReports, /getReportData.
      - Flutter files: map_screen.dart, report_detail_sheet.dart, map_filter_dropdown.dart, adapted asset HTML.
      - Packages: webview_flutter, geolocator.
      - Done when markers/heatmap/filter/click/detail/current-location match.
      - Difficulty: medium-high.

  9. Placeholders/polish/manual regression
      - RN files: MainApp.jsx, SubmitButton.jsx, AnimatedIcon.jsx.
      - Flutter files: shared widgets/placeholders.
      - Done when visible tab structure and inert placeholders match current app.
      - Difficulty: low.

  Implementation Order

  1. App shell/config/localization/session.
  2. Network/models.
  3. FCM/auth.
  4. Camera/image/location/prediction.
  5. Report form/audio/transcription/local draft.
  6. PDF generation/share.
  7. Multipart report upload.
  8. Map/report review.
  9. Visual polish/placeholders.
  10. Full manual Android regression.

  This order avoids building report flows before the API/client models and session/token assumptions are settled.

  Acceptance Criteria

  - App shell: cold start shows login without session; existing secure userDetails navigates home; bottom tabs show map/reports/home/analytics/
    profile with home default.

  - Localization: saved language persists; device en/hi/mr fallback works; switcher exposes same languages as current UI unless decision
    changes.

  - Auth: Android obtains FCM token before OTP request; /sendOTP receives token; foreground OTP notification displays; valid OTP stores exact
    user JSON; invalid OTP shows backend message.

  - Notifications: default channel exists; foreground report notifications display; background handler does not crash.
  - Camera: permission denial shows denial UI; capture and pick both create a local image path and base64; zoom/flash/facing controls work.
  - Location: EXIF GPS takes priority; no EXIF uses current location; reverse-geocoded loc string follows current field order.
  - Prediction: backend response sorts by probability; empty response shows no-issues state; boxes align to visible image.
  - Audio: records M4A, stops cleanly, plays/pauses, deletes, uploads as audio/recording.m4a, applies transcript text.
  - Draft: creates reports/{Rid}/image.jpeg, optional audio.m4a, data.json, and appends pendingReports.
  - PDF: creates report.pdf, includes report ID/date/time/name/number/category/description/location/image, shares through platform sheet.
  - Submit: sends notification request, uploads exact multipart fields/files, handles backend success/failure, shows modal.
  - Map: loads map, polls every 5 seconds while active, filters by exact backend statuses, excludes invalid by default, marker click opens
    detail, current-location recenter works, can-resolve appears within 200m.

  - No-regression: backend files and DB API remain unchanged.

  Unresolved Decisions

  1. iOS login
      - Options: preserve local bypass; require backend OTP with iOS FCM/APNs.
      - Recommendation: preserve current behavior for parity, then fix later.
      - Consequence: preserving keeps migration smaller but iOS reports may reference non-DB user IDs.

  2. Report submit await behavior
      - Options: preserve non-awaited upload; await upload.
      - Recommendation: await upload as intended-behavior fix.
      - Consequence: user sees more accurate failures, but timing differs from current RN.

  3. PDF localization
      - Options: preserve ASCII-cleaning limitation; embed Devanagari font.
      - Recommendation: preserve for first parity unless localized PDFs are required.
      - Consequence: font support increases PDF work but fixes real Hindi/Marathi output.

  4. Map implementation
      - Options: WebView Leaflet; native flutter_map.
      - Recommendation: WebView Leaflet first.
      - Consequence: faster parity, but retains CDN/JS bridge dependency.

  5. Offline sync
      - Options: preserve local draft only; implement real sync.
      - Recommendation: preserve local draft only for first migration.
      - Consequence: matches repo, but user-facing “automatic sync” remains misleading.

  Final Blueprint
  Architecture: simple Flutter app with StatefulWidget/ChangeNotifier, typed services, manual models, IndexedStack tabs, client-owned native/
  media/PDF/map orchestration, backend unchanged.

  Package stack: dio, firebase_core, firebase_messaging, flutter_local_notifications, flutter_secure_storage, shared_preferences, local_auth,
  camera, file_picker, native_exif, geolocator, geocoding, record, just_audio, path_provider, share_plus, pdf, webview_flutter, uuid.

  Backend compatibility: keep all Node routes, MySQL tables, Cloudinary, Gemini, AssemblyAI, Firebase Admin unchanged. Flutter must match
  existing request shapes, field names, status strings, MIME types, and local data semantics.

  Major order: shell → network/models → auth/FCM → camera/location/prediction → form/audio/draft → PDF/share → upload → map → polish.

  Highest-risk areas: FCM OTP, iOS auth choice, multipart upload, EXIF/image orientation, PDF parity, WebView bridge, backend error tolerance.

  First implementation step: create Flutter skeleton with assets/l10n/config/session storage and an IndexedStack tab shell matching current
  navigation, without touching the existing frontend/ or backend/.

  Effort ranking low to high: placeholders/polish, shell/localization, network/models, PDF/share, report upload, map WebView, auth/FCM, camera/
  location/prediction, audio/transcription/draft/report pipeline.