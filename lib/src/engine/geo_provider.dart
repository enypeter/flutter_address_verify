import 'package:address_verify/src/exceptions.dart';

/// Raw position reading used by [GeoPositionProvider]. Decoupled from the
/// `geolocator` plugin so engine logic stays testable.
class GeoPosition {
  /// Creates a [GeoPosition].
  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.isMocked,
  });

  /// Decimal latitude.
  final double latitude;

  /// Decimal longitude.
  final double longitude;

  /// `true` when the OS reports the underlying reading as mocked.
  final bool isMocked;
}

/// Internal seam for obtaining a current device position.
///
/// Agent 3 supplies a real impl wrapping `geolocator`; the default
/// [UnconfiguredGeoPositionProvider] throws so callers know to wire one in.
// ignore: one_member_abstracts
abstract class GeoPositionProvider {
  /// Returns the current device position, or throws
  /// [LocationPermissionDeniedException] when access is unavailable.
  Future<GeoPosition> current();
}

/// Default [GeoPositionProvider] used when nothing else is wired in.
///
/// Agent 3 supplies the real impl; until then, any location signal request
/// fails fast with a clear message.
class UnconfiguredGeoPositionProvider implements GeoPositionProvider {
  /// Creates an [UnconfiguredGeoPositionProvider].
  const UnconfiguredGeoPositionProvider();

  @override
  Future<GeoPosition> current() {
    throw const LocationPermissionDeniedException(
      'Location not configured. '
      'Inject a GeoPositionProvider (Agent 3 supplies the impl).',
    );
  }
}

/// Internal seam for resolving a lat/lon to an ISO 3166-1 alpha-2 country
/// code. Agent 3 may back this with platform geocoding; the default returns
/// `null` so v1 logic still surfaces a `locationMismatch` flag
/// deterministically when the resolution is uncertain.
// ignore: one_member_abstracts
abstract class CountryResolver {
  /// Returns an ISO alpha-2 country code, or `null` when uncertain.
  Future<String?> resolveCountryCode(double latitude, double longitude);
}

/// Default [CountryResolver]: always returns `null`.
class NullCountryResolver implements CountryResolver {
  /// Creates a [NullCountryResolver].
  const NullCountryResolver();

  @override
  Future<String?> resolveCountryCode(double latitude, double longitude) async =>
      null;
}
