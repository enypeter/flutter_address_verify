import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/geo_provider.dart';
import 'package:address_verify/src/engine/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGeoPositionProvider implements GeoPositionProvider {
  _FakeGeoPositionProvider(this._position);
  final GeoPosition _position;
  int calls = 0;

  @override
  Future<GeoPosition> current() async {
    calls++;
    return _position;
  }
}

class _ThrowingGeoPositionProvider implements GeoPositionProvider {
  @override
  Future<GeoPosition> current() {
    throw const LocationPermissionDeniedException('denied');
  }
}

class _FakeCountryResolver implements CountryResolver {
  _FakeCountryResolver(this._code);
  final String? _code;
  int calls = 0;
  double? lastLat;
  double? lastLon;

  @override
  Future<String?> resolveCountryCode(double latitude, double longitude) async {
    calls++;
    lastLat = latitude;
    lastLon = longitude;
    return _code;
  }
}

void main() {
  group('DefaultLocationService.current', () {
    test('combines a real position with a resolved country code', () async {
      final pos = _FakeGeoPositionProvider(
        const GeoPosition(latitude: 6.5, longitude: 3.4, isMocked: false),
      );
      final resolver = _FakeCountryResolver('NG');
      final service = DefaultLocationService(
        positionProvider: pos,
        countryResolver: resolver,
      );
      final loc = await service.current();
      expect(loc.countryCode, 'NG');
      expect(loc.latitude, 6.5);
      expect(loc.longitude, 3.4);
      expect(loc.isMocked, isFalse);
      expect(resolver.lastLat, 6.5);
      expect(resolver.lastLon, 3.4);
    });

    test('passes through isMocked from the underlying position', () async {
      final pos = _FakeGeoPositionProvider(
        const GeoPosition(latitude: 0, longitude: 0, isMocked: true),
      );
      final service = DefaultLocationService(
        positionProvider: pos,
        countryResolver: _FakeCountryResolver('NG'),
      );
      final loc = await service.current();
      expect(loc.isMocked, isTrue);
    });

    test('null country resolution propagates as null countryCode', () async {
      final service = DefaultLocationService(
        positionProvider: _FakeGeoPositionProvider(
          const GeoPosition(latitude: 0, longitude: 0, isMocked: false),
        ),
        countryResolver: _FakeCountryResolver(null),
      );
      final loc = await service.current();
      expect(loc.countryCode, isNull);
    });

    test('permission-denied position bubbles up as a domain exception',
        () async {
      final service = DefaultLocationService(
        positionProvider: _ThrowingGeoPositionProvider(),
        countryResolver: _FakeCountryResolver('NG'),
      );
      await expectLater(
        service.current(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('default constructor wires in unconfigured defaults', () async {
      // No collaborators supplied. The default position provider throws so the
      // engine fails fast when the developer enables `detectLocation` without
      // wiring in a real impl.
      final service = DefaultLocationService();
      await expectLater(
        service.current(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });
  });

  group('NullCountryResolver default', () {
    test('returns null for any lat/lon', () async {
      const resolver = NullCountryResolver();
      expect(await resolver.resolveCountryCode(0, 0), isNull);
      expect(await resolver.resolveCountryCode(6.5, 3.4), isNull);
    });
  });
}
