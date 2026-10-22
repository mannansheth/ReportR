# Start ReportR on the USB-connected Android phone

1. Start local MySQL with the `reportr` database configured in `backend/.env`.
2. In terminal 1:

```powershell
cd backend
npm.cmd run start:local
```

The local script uses port 5002 to avoid the unrelated server on port 5000. Verify `http://127.0.0.1:5002/` returns `{"Hello":"Working"}`.

3. In terminal 2:

```powershell
adb devices
adb reverse tcp:5002 tcp:5002
cd flutter
flutter pub get
flutter run -d YOUR_DEVICE_ID
```

`flutter/.env` must contain `BACKEND_BASE_URL=http://127.0.0.1:5002/`. Repeat `adb reverse` after reconnecting the phone. Sign-in codes arrive through ReportR notifications on the device.

Google Maps: replace `YOUR_GOOGLE_MAPS_API_KEY` in `flutter/android/app/src/main/AndroidManifest.xml` and rebuild. Enable Maps SDK for Android in your Google Cloud project. Until a key is supplied, the map tab keeps its report list available and displays an explanatory empty map state. See `flutter/README.md` for key configuration and validation commands.
