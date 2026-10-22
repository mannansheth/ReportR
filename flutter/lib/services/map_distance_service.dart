import 'dart:math' as math;

class MapDistance {
  const MapDistance._();

  static double meters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const radius = 6371000.0;
    double radians(double value) => value * math.pi / 180;
    final dLatitude = radians(latitude2 - latitude1);
    final dLongitude = radians(longitude2 - longitude1);
    final a = math.pow(math.sin(dLatitude / 2), 2) +
        math.cos(radians(latitude1)) *
            math.cos(radians(latitude2)) *
            math.pow(math.sin(dLongitude / 2), 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
