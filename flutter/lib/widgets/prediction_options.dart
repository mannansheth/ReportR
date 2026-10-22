import 'package:flutter/material.dart';
import '../l10n/ui_strings.dart';

import '../models/prediction.dart';

/// The palette is shared by the options and the image boxes.
const predictionColors = [
  Color(0xFF5DE4C7),
  Color(0xFFFFCD70),
  Color(0xFF91BCFF),
  Color(0xFFF5A4EF),
  Color(0xFFFF9B8F),
  Color(0xFFB7E788),
];

class PredictionOptions extends StatelessWidget {
  const PredictionOptions({
    super.key,
    required this.predictions,
    required this.selectedIssues,
    required this.onToggle,
    this.enabled = true,
    this.dark = true,
  });

  final List<Prediction> predictions;
  final Set<String> selectedIssues;
  final ValueChanged<String> onToggle;
  final bool enabled;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final issues = Prediction.uniqueIssues(predictions);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: issues.asMap().entries.map((entry) {
        final prediction = entry.value;
        final selected = selectedIssues.contains(prediction.issueKey);
        final accent = predictionColors[entry.key % predictionColors.length];
        return Semantics(
          selected: selected,
          label: UiStrings.of(context).category(prediction.issue),
          button: true,
          child: Material(
            elevation: selected ? 5 : 2,
            shadowColor: Colors.black38,
            color: selected
                ? (dark
                      ? accent.withValues(alpha: 0.2)
                      : accent.withValues(alpha: 0.32))
                : (dark ? Color(0xEA192A37) : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: selected
                    ? accent
                    : (dark ? Colors.white30 : Color(0xFFCCD5E0)),
                width: selected ? 1.8 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => onToggle(prediction.issueKey) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.add_circle_outline,
                      color: selected
                          ? (dark ? accent : Color(0xFF12364B))
                          : (dark ? Colors.white70 : Color(0xFF526377)),
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        UiStrings.of(context).category(prediction.issue),
                        style: TextStyle(
                          color: dark ? Colors.white : Color(0xFF12364B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${(prediction.probability.clamp(0, 1) * 100).round()}%',
                      style: TextStyle(
                        color: dark ? Colors.white70 : Color(0xFF526377),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
