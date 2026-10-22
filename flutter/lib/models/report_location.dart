class ReportLocation {
  const ReportLocation({
    required this.latitude,
    required this.longitude,
    required this.readableLocation,
  });

  final double latitude;
  final double longitude;
  final String readableLocation;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'loc': readableLocation,
      };
}
