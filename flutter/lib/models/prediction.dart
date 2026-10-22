class Prediction {
  const Prediction({
    required this.issue,
    required this.probability,
    required this.description,
    required this.boundingBox,
  });

  final String issue;
  final double probability;
  final String description;
  final List<double> boundingBox;

  String get issueKey => normalizeIssue(issue);
  String get displayTitle => issue.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeIssue(String title) =>
      title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// One selectable category per title, retaining the strongest detection.
  /// The original list is kept separately so every object still gets a box.
  static List<Prediction> uniqueIssues(List<Prediction> predictions) {
    final byIssue = <String, Prediction>{};
    for (final prediction in predictions) {
      if (prediction.issueKey.isEmpty) continue;
      final existing = byIssue[prediction.issueKey];
      if (existing == null || prediction.probability > existing.probability) {
        byIssue[prediction.issueKey] = prediction;
      }
    }
    return byIssue.values.toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));
  }

  factory Prediction.fromJson(Map<String, dynamic> json) {
    final box = json['bounding_box'];
    if (json['issue'] is! String ||
        json['probability'] is! num ||
        json['description'] is! String ||
        box is! List ||
        box.length != 4 ||
        box.any((value) => value is! num)) {
      throw const FormatException('Invalid prediction object');
    }
    return Prediction(
      issue: json['issue'] as String,
      probability: (json['probability'] as num).toDouble(),
      description: json['description'] as String,
      boundingBox: box
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
    );
  }

  static List<Prediction> parseList(dynamic value) {
    if (value is! List) {
      throw const FormatException('Prediction response is not an array');
    }
    final result = value
        .whereType<Map>()
        .map((item) => Prediction.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (result.length != value.length) {
      throw const FormatException('Invalid prediction response');
    }
    result.sort((a, b) => b.probability.compareTo(a.probability));
    return result;
  }
}
