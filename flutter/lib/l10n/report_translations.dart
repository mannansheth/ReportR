/// Source string -> Hindi and Marathi. Report categories and canonical status
/// values remain unchanged in storage and API requests.
const Map<String, List<String>> reportTranslations = {
  'Unable to load audio. Please try again.': [
    'ऑडियो लोड नहीं कर सके। फिर कोशिश करें।',
    'ऑडिओ लोड करता आला नाही. पुन्हा प्रयत्न करा.',
  ],
  'Report PDF': ['रिपोर्ट PDF', 'अहवाल PDF'],
  'Open report PDF': ['रिपोर्ट PDF खोलें', 'अहवाल PDF उघडा'],
  'View, download or share your report document.': [
    'अपनी रिपोर्ट देखें, डाउनलोड करें या साझा करें।',
    'तुमचा अहवाल पाहा, डाउनलोड करा किंवा शेअर करा.',
  ],
  'My reports': ['मेरी रिपोर्ट', 'माझे अहवाल'],
  '{submitted} submitted · {resolved} resolved': [
    '{submitted} भेजी गई · {resolved} हल हुई',
    '{submitted} सादर · {resolved} निकाली',
  ],
  'Refresh reports': ['रिपोर्ट ताज़ा करें', 'अहवाल रिफ्रेश करा'],
  'Search category, location or report ID': [
    'श्रेणी, स्थान या रिपोर्ट ID खोजें',
    'प्रकार, ठिकाण किंवा अहवाल ID शोधा',
  ],
  'All': ['सभी', 'सर्व'],
  'Active': ['सक्रिय', 'सक्रिय'],
  'Retry': ['फिर कोशिश करें', 'पुन्हा प्रयत्न करा'],
  'Sending...': ['भेज रहे हैं...', 'पाठवत आहे...'],
  'Saved on this phone · awaiting submission': [
    'इस फ़ोन पर सुरक्षित · भेजना बाकी है',
    'या फोनवर जतन केले · सादर करणे बाकी',
  ],
  'Report submitted successfully.': [
    'रिपोर्ट सफलतापूर्वक भेजी गई।',
    'अहवाल यशस्वीरित्या सादर केला.',
  ],
  'Unable to submit. Your draft is saved.': [
    'रिपोर्ट नहीं भेज सके। आपका ड्राफ़्ट सुरक्षित है।',
    'सादर करता आले नाही. तुमचा मसुदा जतन केला आहे.',
  ],
  'Your reports start here': [
    'आपकी रिपोर्ट यहाँ से शुरू होती हैं',
    'तुमच्या अहवालांची सुरुवात येथे होते',
  ],
  'Capture or choose a photo from Home to report a civic issue. Track every update here after submitting.': [
    'नागरिक समस्या की रिपोर्ट करने के लिए होम से फ़ोटो लें या चुनें। भेजने के बाद हर अपडेट यहाँ देखें।',
    'नागरी समस्येचा अहवाल देण्यासाठी होमवरून फोटो काढा किंवा निवडा. सादर केल्यानंतर प्रत्येक अपडेट येथे पाहा.',
  ],
  'No reports match your search.': [
    'आपकी खोज से कोई रिपोर्ट नहीं मिली।',
    'तुमच्या शोधाशी जुळणारे अहवाल नाहीत.',
  ],
  'A signed-in user is required.': [
    'कृपया पहले साइन इन करें।',
    'कृपया आधी साइन इन करा.',
  ],
  'Coordinates unavailable': [
    'निर्देशांक उपलब्ध नहीं हैं',
    'स्थानाचे निर्देशांक उपलब्ध नाहीत',
  ],
  'Coordinates': ['निर्देशांक', 'निर्देशांक'],
  'Resolution update': ['समाधान का अपडेट', 'निराकरणाची माहिती'],
  'Updated by {name}': ['{name} ने अपडेट किया', '{name} यांनी अपडेट केले'],
  'Audio': ['ऑडियो', 'ऑडिओ'],
  'Available': ['उपलब्ध', 'उपलब्ध'],
  'Status history': ['स्थिति का इतिहास', 'स्थितीचा इतिहास'],
  'Status history is unavailable': [
    'स्थिति का इतिहास उपलब्ध नहीं है',
    'स्थितीचा इतिहास उपलब्ध नाही',
  ],
  'No status changes yet. Updates will appear here.': [
    'अभी स्थिति नहीं बदली है। अपडेट यहाँ दिखाई देंगे।',
    'अद्याप स्थिती बदललेली नाही. अपडेट येथे दिसतील.',
  ],
  'Not provided': ['नहीं दिया गया', 'दिलेली नाही'],
  'Unknown': ['अज्ञात', 'अज्ञात'],
  'Unable to open this file.': [
    'यह फ़ाइल नहीं खोल सके।',
    'ही फाइल उघडता आली नाही.',
  ],
  'Audio is unavailable.': ['ऑडियो उपलब्ध नहीं है।', 'ऑडिओ उपलब्ध नाही.'],
  'Play audio': ['ऑडियो चलाएँ', 'ऑडिओ ऐका'],
  'Pause audio': ['ऑडियो रोकें', 'ऑडिओ थांबवा'],
  'system': ['स्वचालित सिस्टम', 'स्वयंचलित प्रणाली'],
  'authority': ['प्राधिकरण', 'प्राधिकरण'],
  'citizen': ['नागरिक', 'नागरिक'],
  'Unable to load reports.': [
    'रिपोर्ट लोड नहीं कर सके।',
    'अहवाल लोड करता आले नाहीत.',
  ],
  'Unable to load report.': [
    'रिपोर्ट लोड नहीं कर सके।',
    'अहवाल लोड करता आला नाही.',
  ],
  'Unable to load report history.': [
    'रिपोर्ट का इतिहास लोड नहीं कर सके।',
    'अहवालाचा इतिहास लोड करता आला नाही.',
  ],
};
