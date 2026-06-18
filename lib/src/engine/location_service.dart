import 'package:address_verify/src/engine/geo_provider.dart';

/// A resolved device location reading used for the location cross-reference
/// signal. Decoupled from any platform plugin so logic stays testable.
class DeviceLocation {
  /// Creates a [DeviceLocation].
  const DeviceLocation({
    required this.isMocked,
    required this.latitude,
    required this.longitude,
    this.countryCode,
  });

  /// ISO 3166-1 alpha-2 country code resolved from device GPS, or `null` when
  /// the resolver could not produce one with confidence.
  final String? countryCode;

  /// `true` when the OS reports the underlying GPS reading as mocked.
  final bool isMocked;

  /// Decimal latitude of the underlying reading.
  final double latitude;

  /// Decimal longitude of the underlying reading.
  final double longitude;
}

/// Pluggable location backend.
///
/// The default implementation delegates to a [GeoPositionProvider] +
/// [CountryResolver] pair so the engine stays independent of any platform
/// plugin.
// ignore: one_member_abstracts
abstract class LocationService {
  /// Resolves the device's current country and mocked-location status.
  ///
  /// Throws `LocationPermissionDeniedException` when the user denied access.
  Future<DeviceLocation> current();
}

/// Default [LocationService] composed from injected position + country
/// resolvers. Pure orchestration; Agent 3 supplies the underlying plugin
/// implementations.
class DefaultLocationService implements LocationService {
  /// Creates a [DefaultLocationService].
  DefaultLocationService({
    GeoPositionProvider? positionProvider,
    CountryResolver? countryResolver,
  })  : positionProvider =
            positionProvider ?? const UnconfiguredGeoPositionProvider(),
        countryResolver = countryResolver ?? const NullCountryResolver();

  /// Position source.
  final GeoPositionProvider positionProvider;

  /// lat/lon -> country resolver.
  final CountryResolver countryResolver;

  @override
  Future<DeviceLocation> current() async {
    final position = await positionProvider.current();
    final country = await countryResolver.resolveCountryCode(
      position.latitude,
      position.longitude,
    );
    return DeviceLocation(
      countryCode: country,
      isMocked: position.isMocked,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
