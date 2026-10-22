// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authWelcome => 'Welcome to ReportR';

  @override
  String get authSubtitle => 'Report civic issues in your area';

  @override
  String get loginNotImplemented =>
      'Sign in with the existing OTP flow. Temporary development tools are available below.';

  @override
  String get enterName => 'Name';

  @override
  String get enterPhone => 'Phone number';

  @override
  String get enterOtp => 'OTP';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get verifyOtp => 'Verify OTP';

  @override
  String get otpSent => 'OTP sent';

  @override
  String get loginSuccess => 'Signed in';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get invalidPhone => 'Enter a valid name and phone number.';

  @override
  String get invalidOtp => 'Enter the OTP.';

  @override
  String get pushTokenUnavailable =>
      'Push notification token is not available yet.';

  @override
  String get editLoginDetails => 'Edit name or phone';

  @override
  String get ok => 'Continue';

  @override
  String get devOnlyTools => 'Dev-only tools';

  @override
  String get devOnlyDescription =>
      'Temporary local-session actions for migration testing.';

  @override
  String get createDummySession => 'Create dev dummy session';

  @override
  String get clearDummySession => 'Clear dev session';

  @override
  String backendBaseUrlLabel(Object url) {
    return 'Backend base URL: $url';
  }

  @override
  String get notConfigured => 'not configured';

  @override
  String get systemLanguage => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageMarathi => 'Marathi';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get navMap => 'Map';

  @override
  String get navReports => 'Reports';

  @override
  String get navHome => 'Home';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navProfile => 'Profile';

  @override
  String get homePlaceholderTitle => 'Home / Camera';

  @override
  String get homePlaceholderBody =>
      'Camera and report creation will be migrated in a later phase.';

  @override
  String get mapPlaceholderTitle => 'Map';

  @override
  String get mapPlaceholderBody =>
      'Leaflet map migration is intentionally deferred.';

  @override
  String get reportsPlaceholderTitle => 'Reports';

  @override
  String get reportsPlaceholderBody =>
      'Report list functionality is not part of this foundation phase.';

  @override
  String get analyticsPlaceholderTitle => 'Analytics';

  @override
  String get analyticsPlaceholderBody =>
      'Analytics remains a placeholder, matching the current app.';

  @override
  String get profilePlaceholderTitle => 'Profile';

  @override
  String signedInAs(Object name) {
    return 'Signed in as $name';
  }

  @override
  String sessionId(Object id) {
    return 'Session ID: $id';
  }

  @override
  String phoneNumberValue(Object number) {
    return 'Phone Number: $number';
  }

  @override
  String stateCounter(int count) {
    return 'State counter: $count';
  }

  @override
  String get impactTitle => 'Your community impact';

  @override
  String get impactSubtitle =>
      'Track the issues you raise and the progress toward resolution.';

  @override
  String get impactSubmitted => 'Submitted';

  @override
  String get impactResolved => 'Resolved';

  @override
  String get impactActive => 'Active';

  @override
  String get impactInvalid => 'Invalid';

  @override
  String get impactResolutionRate => 'Resolution rate';

  @override
  String get impactActivity => 'Reporting activity';

  @override
  String get impactActivitySubtitle =>
      'Reports submitted over the last six months';

  @override
  String get impactStatus => 'Report status';

  @override
  String get impactStatusSubtitle => 'Current progress across your reports';

  @override
  String get impactEmpty =>
      'No reports yet. Submit your first issue from Home.';

  @override
  String get impactIssues => 'Issues reported';

  @override
  String get impactIssuesSubtitle =>
      'Categories based on your submitted reports';

  @override
  String get impactCategoriesEmpty =>
      'Your issue breakdown will appear after you submit a report.';

  @override
  String get impactRefresh => 'Pull down to refresh';

  @override
  String get pageRetry => 'Try again';

  @override
  String get profileEditName => 'Edit your name';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileNameValidation => 'Enter at least two characters';

  @override
  String get profileSave => 'Save';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileSignOutQuestion => 'Sign out?';

  @override
  String get profileSignOutExplanation =>
      'Your submitted reports are saved to your account. You can sign back in with your phone number.';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignIn => 'Sign in to view your profile.';

  @override
  String get profileAccountDetails => 'Account details';

  @override
  String get profileVerifiedPhone => 'Phone number';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profileAppLanguage => 'App language';

  @override
  String get profileTipsTitle => 'Make your report count';

  @override
  String get profileTips =>
      'Capture a clear photo of the issue, confirm its location, and describe what needs attention. Follow progress in Reports and see your impact in Analytics.';

  @override
  String get profileTagline => 'ReportR · Better communities, together';

  @override
  String get impactRaised => 'Issue raised';

  @override
  String get impactVerification => 'Verification pending';

  @override
  String get impactProgress => 'In progress';
}
