import 'package:address_verify/src/engine/geo_provider.dart';
import 'package:address_verify/src/exceptions.dart';
import 'package:geolocator/geolocator.dart';

/// [GeoPositionProvider] backed by the `geolocator` plugin.
///
/// Walks the standard permission flow (service-enabled check ->
/// `checkPermission` -> `requestPermission`) and translates any denial into
/// a [LocationPermissionDeniedException] so callers do not need to know the
/// plugin's enum.
class GeolocatorPositionProvider implements GeoPositionProvider {
  /// Creates a [GeolocatorPositionProvider].
  const GeolocatorPositionProvider();

  @override
  Future<GeoPosition> current() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationPermissionDeniedException(
        'Location services are disabled.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'Location permission denied.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      return GeoPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        // geolocator's Position.isMocked is reported by the OS on Android
        // and defaults to false on iOS (the iOS APIs do not expose a mock
        // flag for foreground readings).
        isMocked: position.isMocked,
      );
    } on Object catch (error) {
      throw LocationPermissionDeniedException(
        'Failed to read location: $error',
      );
    }
  }
}
