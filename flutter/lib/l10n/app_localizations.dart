import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ReportR'**
  String get authWelcome;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report civic issues in your area'**
  String get authSubtitle;

  /// No description provided for @loginNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the existing OTP flow. Temporary development tools are available below.'**
  String get loginNotImplemented;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get enterName;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get enterPhone;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get enterOtp;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent'**
  String get otpSent;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get loginSuccess;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name and phone number.'**
  String get invalidPhone;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP.'**
  String get invalidOtp;

  /// No description provided for @pushTokenUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Push notification token is not available yet.'**
  String get pushTokenUnavailable;

  /// No description provided for @editLoginDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit name or phone'**
  String get editLoginDetails;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get ok;

  /// No description provided for @devOnlyTools.
  ///
  /// In en, this message translates to:
  /// **'Dev-only tools'**
  String get devOnlyTools;

  /// No description provided for @devOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Temporary local-session actions for migration testing.'**
  String get devOnlyDescription;

  /// No description provided for @createDummySession.
  ///
  /// In en, this message translates to:
  /// **'Create dev dummy session'**
  String get createDummySession;

  /// No description provided for @clearDummySession.
  ///
  /// In en, this message translates to:
  /// **'Clear dev session'**
  String get clearDummySession;

  /// No description provided for @backendBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend base URL: {url}'**
  String backendBaseUrlLabel(Object url);

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'not configured'**
  String get notConfigured;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageMarathi.
  ///
  /// In en, this message translates to:
  /// **'Marathi'**
  String get languageMarathi;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @homePlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Home / Camera'**
  String get homePlaceholderTitle;

  /// No description provided for @homePlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Camera and report creation will be migrated in a later phase.'**
  String get homePlaceholderBody;

  /// No description provided for @mapPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapPlaceholderTitle;

  /// No description provided for @mapPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Leaflet map migration is intentionally deferred.'**
  String get mapPlaceholderBody;

  /// No description provided for @reportsPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsPlaceholderTitle;

  /// No description provided for @reportsPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Report list functionality is not part of this foundation phase.'**
  String get reportsPlaceholderBody;

  /// No description provided for @analyticsPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsPlaceholderTitle;

  /// No description provided for @analyticsPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Analytics remains a placeholder, matching the current app.'**
  String get analyticsPlaceholderBody;

  /// No description provided for @profilePlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profilePlaceholderTitle;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(Object name);

  /// No description provided for @sessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID: {id}'**
  String sessionId(Object id);

  /// No description provided for @phoneNumberValue.
  ///
  /// In en, this message translates to:
  /// **'Phone Number: {number}'**
  String phoneNumberValue(Object number);

  /// No description provided for @stateCounter.
  ///
  /// In en, this message translates to:
  /// **'State counter: {count}'**
  String stateCounter(int count);

  /// No description provided for @impactTitle.
  ///
  /// In en, this message translates to:
  /// **'Your community impact'**
  String get impactTitle;

  /// No description provided for @impactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track the issues you raise and the progress toward resolution.'**
  String get impactSubtitle;

  /// No description provided for @impactSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get impactSubmitted;

  /// No description provided for @impactResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get impactResolved;

  /// No description provided for @impactActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get impactActive;

  /// No description provided for @impactInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get impactInvalid;

  /// No description provided for @impactResolutionRate.
  ///
  /// In en, this message translates to:
  /// **'Resolution rate'**
  String get impactResolutionRate;

  /// No description provided for @impactActivity.
  ///
  /// In en, this message translates to:
  /// **'Reporting activity'**
  String get impactActivity;

  /// No description provided for @impactActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reports submitted over the last six months'**
  String get impactActivitySubtitle;

  /// No description provided for @impactStatus.
  ///
  /// In en, this message translates to:
  /// **'Report status'**
  String get impactStatus;

  /// No description provided for @impactStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current progress across your reports'**
  String get impactStatusSubtitle;

  /// No description provided for @impactEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports yet. Submit your first issue from Home.'**
  String get impactEmpty;

  /// No description provided for @impactIssues.
  ///
  /// In en, this message translates to:
  /// **'Issues reported'**
  String get impactIssues;

  /// No description provided for @impactIssuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Categories based on your submitted reports'**
  String get impactIssuesSubtitle;

  /// No description provided for @impactCategoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your issue breakdown will appear after you submit a report.'**
  String get impactCategoriesEmpty;

  /// No description provided for @impactRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get impactRefresh;

  /// No description provided for @pageRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pageRetry;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get profileEditName;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// No description provided for @profileNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two characters'**
  String get profileNameValidation;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileSignOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get profileSignOutQuestion;

  /// No description provided for @profileSignOutExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your submitted reports are saved to your account. You can sign back in with your phone number.'**
  String get profileSignOutExplanation;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile.'**
  String get profileSignIn;

  /// No description provided for @profileAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get profileAccountDetails;

  /// No description provided for @profileVerifiedPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profileVerifiedPhone;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferences;

  /// No description provided for @profileAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profileAppLanguage;

  /// No description provided for @profileTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Make your report count'**
  String get profileTipsTitle;

  /// No description provided for @profileTips.
  ///
  /// In en, this message translates to:
  /// **'Capture a clear photo of the issue, confirm its location, and describe what needs attention. Follow progress in Reports and see your impact in Analytics.'**
  String get profileTips;

  /// No description provided for @profileTagline.
  ///
  /// In en, this message translates to:
  /// **'ReportR · Better communities, together'**
  String get profileTagline;

  /// No description provided for @impactRaised.
  ///
  /// In en, this message translates to:
  /// **'Issue raised'**
  String get impactRaised;

  /// No description provided for @impactVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get impactVerification;

  /// No description provided for @impactProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get impactProgress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
