import 'package:native_exif/native_exif.dart';

class ExifCoordinates {
  const ExifCoordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude != 0 &&
      longitude != 0 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

class ExifService {
  Future<ExifCoordinates?> readCoordinates(String path) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(path);
      final value = await exif.getLatLong();
      if (value == null) return null;
      final coordinates = ExifCoordinates(value.latitude, value.longitude);
      return coordinates.isValid ? coordinates : null;
    } catch (_) {
      return null;
    } finally {
      await exif?.close();
    }
  }

  static double dmsToDecimal({
    required double degrees,
    required double minutes,
    required double seconds,
    required String reference,
  }) {
    final value = degrees.abs() + minutes.abs() / 60 + seconds.abs() / 3600;
    return (reference == 'S' || reference == 'W') ? -value : value;
  }
}
