class MapReportMarker {
  const MapReportMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.color,
    required this.userId,
    this.issue = '',
    this.isOwner = false,
    this.isUser = false,
  });

  final String id;
  final String issue;
  final bool isOwner;
  final double latitude;
  final double longitude;
  final String status;
  final String color;
  final dynamic userId;
  final bool isUser;

  factory MapReportMarker.fromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse(json['lat']?.toString() ?? '');
    final longitude = double.tryParse(json['lng']?.toString() ?? '');
    if (json['Rid'] == null ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid map marker');
    }
    return MapReportMarker(
      id: json['Rid'].toString(),
      issue: json['issue']?.toString() ?? '',
      isOwner: json['isOwner'] == true,
      latitude: latitude,
      longitude: longitude,
      status: json['status']?.toString() ?? '',
      color: json['color']?.toString() ?? 'blue',
      userId: json['userID'],
      isUser: json['isUser'] == true,
    );
  }

  /// Google Maps standard-marker hues, independent of the old CSS colors.
  double get markerHue => switch (status) {
    'Resolved' => 120,
    'In Progress' => 210,
    'Verification pending' => 270,
    'Invalid Report' => 0,
    _ => 30,
  };

  Map<String, dynamic> toJson() => {
    'Rid': id,
    'lat': latitude,
    'lng': longitude,
    'status': status,
    'color': color,
    'userID': userId,
    'isUser': isUser,
  };

  static List<MapReportMarker> visibleFor(
    List<MapReportMarker> markers, {
    String? filter,
    String? userId,
  }) {
    final filtered = filter == null
        ? markers.where((marker) => marker.status != 'Invalid Report')
        : filter == 'My reports'
        ? markers.where(
            (marker) =>
                marker.isOwner ||
                (userId != null && marker.userId?.toString() == userId),
          )
        : markers.where((marker) => marker.status == filter);
    return filtered.toList();
  }

  static List<MapReportMarker> parseList(dynamic value) {
    if (value is! List) throw const FormatException('Markers are not an array');
    return value.map((item) {
      if (item is! Map) throw const FormatException('Invalid marker response');
      return MapReportMarker.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }
}

class MapReportDetails {
  const MapReportDetails({
    required this.issue,
    required this.description,
    required this.imageUrl,
    required this.createdAt,
    required this.status,
    required this.canResolve,
  });

  final String issue;
  final String description;
  final String imageUrl;
  final String createdAt;
  final String status;
  final bool canResolve;

  factory MapReportDetails.fromJson(
    Map<String, dynamic> json, {
    required bool canResolve,
  }) {
    return MapReportDetails(
      issue: json['issue']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageURL']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      canResolve: canResolve,
    );
  }
}
