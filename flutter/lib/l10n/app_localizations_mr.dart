// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get authWelcome => 'ReportR मध्ये आपले स्वागत आहे';

  @override
  String get authSubtitle => 'आपल्या क्षेत्रातील नागरी समस्यांचा अहवाल द्या';

  @override
  String get loginNotImplemented =>
      'विद्यमान OTP प्रक्रियेद्वारे साइन इन करा. तात्पुरती डेवलपमेंट साधने खाली उपलब्ध आहेत.';

  @override
  String get enterName => 'नाव';

  @override
  String get enterPhone => 'फोन नंबर';

  @override
  String get enterOtp => 'OTP';

  @override
  String get sendOtp => 'OTP पाठवा';

  @override
  String get verifyOtp => 'OTP पडताळा';

  @override
  String get otpSent => 'OTP पाठवला';

  @override
  String get loginSuccess => 'साइन इन झाले';

  @override
  String get loginFailed => 'लॉगिन अयशस्वी';

  @override
  String get invalidPhone => 'वैध नाव आणि फोन नंबर भरा.';

  @override
  String get invalidOtp => 'OTP भरा.';

  @override
  String get pushTokenUnavailable => 'पुश नोटिफिकेशन टोकन अजून उपलब्ध नाही.';

  @override
  String get editLoginDetails => 'नाव किंवा फोन बदला';

  @override
  String get ok => 'सुरू ठेवा';

  @override
  String get devOnlyTools => 'फक्त डेवलपमेंट साधने';

  @override
  String get devOnlyDescription =>
      'माइग्रेशन टेस्टिंगसाठी तात्पुरत्या लोकल-सेशन कृती.';

  @override
  String get createDummySession => 'डेव डमी सेशन तयार करा';

  @override
  String get clearDummySession => 'डेव सेशन हटवा';

  @override
  String backendBaseUrlLabel(Object url) {
    return 'बॅकएंड बेस URL: $url';
  }

  @override
  String get notConfigured => 'कॉन्फिगर केलेले नाही';

  @override
  String get systemLanguage => 'सिस्टम';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageMarathi => 'मराठी';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get navMap => 'नकाशा';

  @override
  String get navReports => 'अहवाल';

  @override
  String get navHome => 'होम';

  @override
  String get navAnalytics => 'अॅनालिटिक्स';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get homePlaceholderTitle => 'होम / कॅमेरा';

  @override
  String get homePlaceholderBody =>
      'कॅमेरा आणि अहवाल तयार करणे पुढील टप्प्यात माइग्रेट होईल.';

  @override
  String get mapPlaceholderTitle => 'नकाशा';

  @override
  String get mapPlaceholderBody =>
      'Leaflet नकाशा माइग्रेशन सध्या मुद्दाम पुढे ढकलले आहे.';

  @override
  String get reportsPlaceholderTitle => 'अहवाल';

  @override
  String get reportsPlaceholderBody =>
      'अहवाल यादी या फाउंडेशन टप्प्याचा भाग नाही.';

  @override
  String get analyticsPlaceholderTitle => 'अॅनालिटिक्स';

  @override
  String get analyticsPlaceholderBody =>
      'अॅनालिटिक्स सध्या विद्यमान अॅपप्रमाणे placeholder आहे.';

  @override
  String get profilePlaceholderTitle => 'प्रोफाइल';

  @override
  String signedInAs(Object name) {
    return '$name म्हणून साइन इन';
  }

  @override
  String sessionId(Object id) {
    return 'सेशन ID: $id';
  }

  @override
  String phoneNumberValue(Object number) {
    return 'फोन नंबर: $number';
  }

  @override
  String stateCounter(int count) {
    return 'स्टेट काउंटर: $count';
  }

  @override
  String get impactTitle => 'समुदायातील तुमचे योगदान';

  @override
  String get impactSubtitle =>
      'तुमच्या तक्रारी आणि त्यांच्या निराकरणाची प्रगती पाहा.';

  @override
  String get impactSubmitted => 'सादर केलेले';

  @override
  String get impactResolved => 'निराकरण झालेले';

  @override
  String get impactActive => 'सक्रिय';

  @override
  String get impactInvalid => 'अवैध';

  @override
  String get impactResolutionRate => 'निराकरण दर';

  @override
  String get impactActivity => 'अहवालांची हालचाल';

  @override
  String get impactActivitySubtitle => 'मागील सहा महिन्यांत सादर केलेले अहवाल';

  @override
  String get impactStatus => 'अहवालाची स्थिती';

  @override
  String get impactStatusSubtitle => 'तुमच्या अहवालांची सध्याची प्रगती';

  @override
  String get impactEmpty =>
      'अद्याप अहवाल नाहीत. होमवरून पहिली तक्रार सादर करा.';

  @override
  String get impactIssues => 'नोंदवलेल्या समस्या';

  @override
  String get impactIssuesSubtitle => 'तुमच्या अहवालांवर आधारित श्रेणी';

  @override
  String get impactCategoriesEmpty =>
      'अहवाल सादर केल्यावर समस्यांचे विश्लेषण दिसेल.';

  @override
  String get impactRefresh => 'ताजे करण्यासाठी खाली ओढा';

  @override
  String get pageRetry => 'पुन्हा प्रयत्न करा';

  @override
  String get profileEditName => 'तुमचे नाव बदला';

  @override
  String get profileFullName => 'पूर्ण नाव';

  @override
  String get profileNameValidation => 'किमान दोन अक्षरे लिहा';

  @override
  String get profileSave => 'जतन करा';

  @override
  String get profileCancel => 'रद्द करा';

  @override
  String get profileUpdated => 'प्रोफाइल अद्ययावत झाली';

  @override
  String get profileSignOutQuestion => 'साइन आउट करायचे?';

  @override
  String get profileSignOutExplanation =>
      'तुमचे अहवाल तुमच्या खात्यात जतन आहेत. फोन नंबर वापरून पुन्हा साइन इन करू शकता.';

  @override
  String get profileSignOut => 'साइन आउट';

  @override
  String get profileSignIn => 'प्रोफाइल पाहण्यासाठी साइन इन करा.';

  @override
  String get profileAccountDetails => 'खात्याचे तपशील';

  @override
  String get profileVerifiedPhone => 'फोन नंबर';

  @override
  String get profilePreferences => 'प्राधान्ये';

  @override
  String get profileAppLanguage => 'अ‍ॅपची भाषा';

  @override
  String get profileTipsTitle => 'तुमचा अहवाल प्रभावी करा';

  @override
  String get profileTips =>
      'समस्येचा स्पष्ट फोटो घ्या, ठिकाणाची खात्री करा आणि आवश्यक तपशील लिहा. अहवालांमध्ये प्रगती आणि विश्लेषणात तुमचे योगदान पाहा.';

  @override
  String get profileTagline => 'ReportR · एकत्रितपणे उत्तम समुदाय';

  @override
  String get impactRaised => 'तक्रार नोंदवली';

  @override
  String get impactVerification => 'पडताळणी प्रलंबित';

  @override
  String get impactProgress => 'काम सुरू';
}
