import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<Locale?>(
        value: controller.locale,
        hint: Text(l10n.systemLanguage),
        onChanged: controller.setLocale,
        items: [
          DropdownMenuItem<Locale?>(value: null, child: Text(l10n.systemLanguage)),
          DropdownMenuItem<Locale?>(value: const Locale('en'), child: Text(l10n.languageEnglish)),
          DropdownMenuItem<Locale?>(value: const Locale('hi'), child: Text(l10n.languageHindi)),
          DropdownMenuItem<Locale?>(value: const Locale('mr'), child: Text(l10n.languageMarathi)),
        ],
      ),
    );
  }
}
