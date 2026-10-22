import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads native configuration before creating a platform map view. An unset
/// native SDK key must not instantiate GoogleMap (especially on iOS).
class GoogleMapsConfigService {
  const GoogleMapsConfigService();
  static const channel = MethodChannel('reportr/maps_config');

  Future<bool> isConfigured() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      return await channel.invokeMethod<bool>('isConfigured') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
