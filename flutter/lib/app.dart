import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/constants.dart';
import 'core/storage/preferences_service.dart';
import 'l10n/app_localizations.dart';
import 'models/user_session.dart';
import 'screens/home/main_shell.dart';
import 'screens/authority/authority_shell.dart';
import 'screens/login/login_screen.dart';
import 'services/auth_service.dart';
import 'services/session_service.dart';
import 'widgets/brand.dart';

class AppController extends ChangeNotifier {
  AppController({
    required SessionService sessionService,
    required PreferencesService preferencesService,
    required this.authService,
    this.refreshPushToken,
  }) : _sessionService = sessionService,
       _preferencesService = preferencesService;

  final SessionService _sessionService;
  final PreferencesService _preferencesService;
  final AuthService authService;
  final Future<String?> Function()? refreshPushToken;
  UserSession? _session;
  String? _authToken;
  Locale? _locale;
  bool _isLoading = true;

  UserSession? get session => _session;
  String? get authToken => _authToken;
  Locale? get locale => _locale;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _session != null;
  String? get fcmToken => _preferencesService.token;
  PreferencesService get preferencesService => _preferencesService;

  Future<void> load() async {
    _locale = _localeFromCode(_preferencesService.userLanguage);
    _session = await _sessionService.readSession();
    _authToken = await _sessionService.readAuthToken();
    if (_session != null && (_authToken == null || _authToken!.isEmpty)) {
      await _sessionService.clearSession();
      _session = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSession(UserSession session, {String? authToken}) async {
    await _sessionService.saveSession(session);
    if (authToken != null && authToken.isNotEmpty) {
      await _sessionService.saveAuthToken(authToken);
      _authToken = authToken;
    }
    _session = session;
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _sessionService.clearSession();
    await _sessionService.clearAuthToken();
    _session = null;
    _authToken = null;
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    if (locale == null) {
      await _preferencesService.clearUserLanguage();
    } else {
      await _preferencesService.setUserLanguage(locale.languageCode);
    }
    notifyListeners();
  }

  Locale? _localeFromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    if (!AppConstants.supportedLanguageCodes.contains(code)) return null;
    return Locale(code);
  }
}

class ReportRApp extends StatelessWidget {
  const ReportRApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (controller.locale != null) return controller.locale;
            final languageCode = deviceLocale?.languageCode;
            if (languageCode != null &&
                AppConstants.supportedLanguageCodes.contains(languageCode)) {
              return Locale(languageCode);
            }
            return const Locale('en');
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.primaryColor,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF5F7FA),
              foregroundColor: AppConstants.primaryColor,
              elevation: 0,
              centerTitle: false,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            useMaterial3: true,
          ),
          home: controller.isLoading
              ? const BrandStartupScreen()
              : controller.isLoggedIn
              ? controller.session!.isAuthority
                    ? AuthorityShell(
                        session: controller.session!,
                        authToken: controller.authToken ?? '',
                        controller: controller,
                      )
                    : MainShell(controller: controller)
              : LoginScreen(controller: controller),
        );
      },
    );
  }
}
