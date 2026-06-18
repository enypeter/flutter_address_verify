import 'package:address_verify/src/engine/geo_provider.dart';
import 'package:geocoding/geocoding.dart';

/// [CountryResolver] backed by the `geocoding` plugin.
///
/// Performs reverse geocoding to extract an ISO 3166-1 alpha-2 country
/// code. Returns `null` on any failure or empty result so the engine can
/// still surface a deterministic `locationMismatch` flag rather than crash
/// the whole pipeline on a transient geocoder error.
class GeocodingCountryResolver implements CountryResolver {
  /// Creates a [GeocodingCountryResolver].
  const GeocodingCountryResolver();

  @override
  Future<String?> resolveCountryCode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      for (final p in placemarks) {
        final code = p.isoCountryCode;
        if (code != null && code.trim().isNotEmpty) {
          return code.trim().toUpperCase();
        }
      }
      return null;
    } on Object {
      return null;
    }
  }
}
