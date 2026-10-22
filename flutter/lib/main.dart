import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/preferences_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'widgets/brand.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReportRBootstrap());
}

Future<AppController> _initializeApp() async {
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final preferencesService = await PreferencesService.create();
  final notificationService = NotificationService(preferencesService);
  try {
    await notificationService.initialize().timeout(const Duration(seconds: 8));
  } catch (error) {
    debugPrint('Notifications unavailable: ${error.runtimeType}');
  }

  final sessionService = SessionService(SecureStorageService());
  final authService = AuthService(ApiClient());
  final controller = AppController(
    sessionService: sessionService,
    preferencesService: preferencesService,
    authService: authService,
    refreshPushToken: notificationService.refreshToken,
  );
  await controller.load();

  return controller;
}

class ReportRBootstrap extends StatefulWidget {
  const ReportRBootstrap({super.key, this.initialize});
  final Future<AppController> Function()? initialize;
  @override
  State<ReportRBootstrap> createState() => _ReportRBootstrapState();
}

class _ReportRBootstrapState extends State<ReportRBootstrap> {
  late Future<AppController> _startup;
  @override
  void initState() {
    super.initState();
    _startup = (widget.initialize ?? _initializeApp)();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return ReportRApp(controller: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: BrandStartupScreen(
          error: snapshot.hasError ? snapshot.error.toString() : null,
          onRetry: () => setState(
            () => _startup = (widget.initialize ?? _initializeApp)(),
          ),
        ),
      );
    },
  );
}
