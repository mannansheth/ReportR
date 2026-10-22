import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'general_translations.dart';
import 'report_form_translations.dart';
import 'report_translations.dart';
import 'community_submission_translations.dart';
import 'community_analytics_translations.dart';
import 'community_reports_translations.dart';

/// Translates product labels at presentation time. API values and user content
/// remain unchanged, including selected categories and report descriptions.
class UiStrings {
  const UiStrings(this.languageCode);
  factory UiStrings.of(BuildContext context) =>
      UiStrings(Localizations.localeOf(context).languageCode);
  final String languageCode;
  Map<String, String> get _messages => {
    ...?generalTranslations[languageCode],
    for (final entry in reportFormTranslations.entries)
      entry.key: entry.value[languageCode == 'mr' ? 1 : 0],
    for (final entry in reportTranslations.entries)
      entry.key: entry.value[languageCode == 'mr' ? 1 : 0],
    for (final entry in communitySubmissionTranslations.entries)
      entry.key: entry.value[languageCode == 'mr' ? 1 : 0],
    for (final entry in communityAnalyticsTranslations.entries)
      entry.key: entry.value[languageCode == 'mr' ? 1 : 0],
    for (final entry in communityReportsTranslations.entries)
      entry.key: entry.value[languageCode == 'mr' ? 1 : 0],
  };
  String text(String source) {
    if (languageCode != 'hi' && languageCode != 'mr') return source;
    final messages = _messages;
    final direct = messages[source];
    if (direct != null) return direct;
    final clean = source.replaceFirst(
      RegExp(
        r'^(?:Exception|StateError|Bad state|FormatException|ApiClientException):\s*',
      ),
      '',
    );
    if (messages.containsKey(clean)) return messages[clean]!;
    if (clean.endsWith('.') &&
        messages.containsKey(clean.substring(0, clean.length - 1))) {
      return messages[clean.substring(0, clean.length - 1)]!;
    }
    final requestError = RegExp(
      r'^Request failed \((\d+)\)\. Please try again\.$',
    ).firstMatch(clean);
    if (requestError != null) {
      return format('Request failed ({code}). Please try again.', {
        'code': requestError[1],
      });
    }
    final transition = RegExp(
      r'^Cannot move report from (.+) to (.+)$',
    ).firstMatch(clean);
    if (transition != null) {
      return format('Cannot move report from {from} to {to}', {
        'from': status(transition[1]!),
        'to': status(transition[2]!),
      });
    }
    final lower = clean.toLowerCase();
    if (lower.contains('connection') ||
        lower.contains('socketexception') ||
        lower.contains('network request') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return messages['Unable to connect. Check your internet connection and try again.']!;
    }
    if (lower.contains('authentication required') ||
        lower.contains('token expired') ||
        lower.contains('invalid token') ||
        lower.contains('unauthorized')) {
      return messages['Your session has expired. Please sign in again.']!;
    }
    return source;
  }

  String format(String source, Map<String, Object?> values) {
    var result = text(source);
    for (final entry in values.entries) {
      result = result.replaceAll(
        '{${entry.key}}',
        entry.value?.toString() ?? '',
      );
    }
    return result;
  }

  String status(String canonical) => text(canonical);
  String category(String canonical) => canonical
      .split(',')
      .map((part) {
        final value = part.trim().replaceAll(RegExp(r'\s+'), ' ');
        final match = _messages.keys
            .where((key) => key.toLowerCase() == value.toLowerCase())
            .firstOrNull;
        return text(match ?? value);
      })
      .join(', ');
  String date(DateTime value, {String pattern = 'd MMM yyyy'}) =>
      DateFormat(pattern, languageCode).format(value.toLocal());
  String dateString(String value, {String pattern = 'd MMM yyyy, h:mm a'}) {
    final dateTime = DateTime.tryParse(value);
    return dateTime == null ? value : date(dateTime, pattern: pattern);
  }
}
