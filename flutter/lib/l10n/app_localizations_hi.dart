// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get authWelcome => 'ReportR में आपका स्वागत है';

  @override
  String get authSubtitle => 'अपने क्षेत्र में नागरिक समस्याओं की रिपोर्ट करें';

  @override
  String get loginNotImplemented =>
      'मौजूदा OTP प्रक्रिया से साइन इन करें। अस्थायी डेवलपमेंट टूल नीचे उपलब्ध हैं।';

  @override
  String get enterName => 'नाम';

  @override
  String get enterPhone => 'फोन नंबर';

  @override
  String get enterOtp => 'OTP';

  @override
  String get sendOtp => 'OTP भेजें';

  @override
  String get verifyOtp => 'OTP सत्यापित करें';

  @override
  String get otpSent => 'OTP भेजा गया';

  @override
  String get loginSuccess => 'साइन इन हो गया';

  @override
  String get loginFailed => 'लॉगिन विफल';

  @override
  String get invalidPhone => 'मान्य नाम और फोन नंबर दर्ज करें।';

  @override
  String get invalidOtp => 'OTP दर्ज करें।';

  @override
  String get pushTokenUnavailable => 'पुश नोटिफिकेशन टोकन अभी उपलब्ध नहीं है।';

  @override
  String get editLoginDetails => 'नाम या फोन बदलें';

  @override
  String get ok => 'जारी रखें';

  @override
  String get devOnlyTools => 'केवल डेवलपमेंट टूल';

  @override
  String get devOnlyDescription =>
      'माइग्रेशन टेस्टिंग के लिए अस्थायी लोकल-सेशन actions।';

  @override
  String get createDummySession => 'डेव डमी सेशन बनाएं';

  @override
  String get clearDummySession => 'डेव सेशन हटाएं';

  @override
  String backendBaseUrlLabel(Object url) {
    return 'बैकएंड बेस URL: $url';
  }

  @override
  String get notConfigured => 'कॉन्फ़िगर नहीं';

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
  String get navMap => 'मानचित्र';

  @override
  String get navReports => 'रिपोर्ट्स';

  @override
  String get navHome => 'होम';

  @override
  String get navAnalytics => 'एनालिटिक्स';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get homePlaceholderTitle => 'होम / कैमरा';

  @override
  String get homePlaceholderBody =>
      'कैमरा और रिपोर्ट बनाना अगले चरण में माइग्रेट होगा।';

  @override
  String get mapPlaceholderTitle => 'मानचित्र';

  @override
  String get mapPlaceholderBody =>
      'Leaflet मानचित्र माइग्रेशन अभी जानबूझकर रोका गया है।';

  @override
  String get reportsPlaceholderTitle => 'रिपोर्ट्स';

  @override
  String get reportsPlaceholderBody =>
      'रिपोर्ट सूची इस फाउंडेशन चरण का हिस्सा नहीं है।';

  @override
  String get analyticsPlaceholderTitle => 'एनालिटिक्स';

  @override
  String get analyticsPlaceholderBody =>
      'एनालिटिक्स अभी मौजूदा ऐप की तरह placeholder है।';

  @override
  String get profilePlaceholderTitle => 'प्रोफाइल';

  @override
  String signedInAs(Object name) {
    return '$name के रूप में साइन इन';
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
  String get impactTitle => 'समुदाय में आपका योगदान';

  @override
  String get impactSubtitle => 'अपनी शिकायतों और उनके समाधान की प्रगति देखें।';

  @override
  String get impactSubmitted => 'दर्ज की गई';

  @override
  String get impactResolved => 'हल हुई';

  @override
  String get impactActive => 'सक्रिय';

  @override
  String get impactInvalid => 'अमान्य';

  @override
  String get impactResolutionRate => 'समाधान दर';

  @override
  String get impactActivity => 'शिकायत गतिविधि';

  @override
  String get impactActivitySubtitle => 'पिछले छह महीनों में दर्ज शिकायतें';

  @override
  String get impactStatus => 'शिकायत की स्थिति';

  @override
  String get impactStatusSubtitle => 'आपकी शिकायतों की वर्तमान प्रगति';

  @override
  String get impactEmpty =>
      'अभी कोई शिकायत नहीं है। होम से अपनी पहली शिकायत दर्ज करें।';

  @override
  String get impactIssues => 'दर्ज समस्याएं';

  @override
  String get impactIssuesSubtitle => 'आपकी शिकायतों के आधार पर श्रेणियां';

  @override
  String get impactCategoriesEmpty =>
      'शिकायत दर्ज करने के बाद समस्याओं का विवरण दिखेगा।';

  @override
  String get impactRefresh => 'रिफ्रेश करने के लिए नीचे खींचें';

  @override
  String get pageRetry => 'फिर प्रयास करें';

  @override
  String get profileEditName => 'अपना नाम बदलें';

  @override
  String get profileFullName => 'पूरा नाम';

  @override
  String get profileNameValidation => 'कम से कम दो अक्षर दर्ज करें';

  @override
  String get profileSave => 'सहेजें';

  @override
  String get profileCancel => 'रद्द करें';

  @override
  String get profileUpdated => 'प्रोफाइल अपडेट हुई';

  @override
  String get profileSignOutQuestion => 'साइन आउट करें?';

  @override
  String get profileSignOutExplanation =>
      'आपकी शिकायतें आपके खाते में सुरक्षित हैं। आप अपने फोन नंबर से फिर साइन इन कर सकते हैं।';

  @override
  String get profileSignOut => 'साइन आउट';

  @override
  String get profileSignIn => 'अपनी प्रोफाइल देखने के लिए साइन इन करें।';

  @override
  String get profileAccountDetails => 'खाते का विवरण';

  @override
  String get profileVerifiedPhone => 'फोन नंबर';

  @override
  String get profilePreferences => 'पसंद';

  @override
  String get profileAppLanguage => 'ऐप की भाषा';

  @override
  String get profileTipsTitle => 'अपनी शिकायत प्रभावी बनाएं';

  @override
  String get profileTips =>
      'समस्या की स्पष्ट फोटो लें, स्थान की पुष्टि करें और जरूरी विवरण लिखें। शिकायतें में प्रगति और विश्लेषण में अपना योगदान देखें।';

  @override
  String get profileTagline => 'ReportR · साथ मिलकर बेहतर समुदाय';

  @override
  String get impactRaised => 'शिकायत दर्ज';

  @override
  String get impactVerification => 'सत्यापन बाकी';

  @override
  String get impactProgress => 'कार्य जारी';
}
