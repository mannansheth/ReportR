﻿import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/report_location.dart';

class LocationService {
  Future<ReportLocation> currentLocation() async {
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) {
      final requested = await Geolocator.requestPermission();
      if (requested != LocationPermission.always &&
          requested != LocationPermission.whileInUse) {
        throw const LocationException('Location permission was denied.');
      }
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location services are unavailable.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return fromCoordinates(position.latitude, position.longitude);
  }

  Future<ReportLocation> fromCoordinates(double latitude, double longitude) async {
    var readable = '';
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) readable = formatPlacemark(placemarks.first);
    } catch (_) {
      readable = '';
    }
    return ReportLocation(
      latitude: latitude,
      longitude: longitude,
      readableLocation: readable,
    );
  }

  static String formatPlacemark(Placemark place) {
    return [
      place.name,
      place.street,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
