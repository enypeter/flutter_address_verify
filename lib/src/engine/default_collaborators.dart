import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/engine/file_handler.dart';
import 'package:address_verify/src/engine/geocoding_country_resolver.dart';
import 'package:address_verify/src/engine/geolocator_position_provider.dart';
import 'package:address_verify/src/engine/location_service.dart';
import 'package:address_verify/src/engine/pdfx_rasterizer.dart';
import 'package:address_verify/src/ocr/mlkit_ocr_provider.dart';
import 'package:address_verify/src/ocr/ocr_provider.dart';

/// Small factory that produces the real plugin-backed collaborators.
///
/// Kept in its own file so `engine.dart` does not have to import any
/// platform plugins directly. Tests substitute their own collaborators via
/// `AddressVerifyEngine`'s constructor seams and never hit this code.
class DefaultCollaborators {
  /// Creates a [DefaultCollaborators].
  const DefaultCollaborators();

  /// Default file handler with a real `pdfx`-backed rasterizer.
  FileHandler fileHandler(AddressVerifyConfig config) => FileHandler(
        config: config,
        pdfRasterizer: const PdfxRasterizer(),
      );

  /// Default location service with `geolocator` + `geocoding` defaults.
  LocationService locationService() => DefaultLocationService(
        positionProvider: const GeolocatorPositionProvider(),
        countryResolver: const GeocodingCountryResolver(),
      );

  /// Default OCR provider honoring `config.ocrLanguage`.
  OcrProvider ocrProvider(AddressVerifyConfig config) =>
      MlKitOcrProvider(language: config.ocrLanguage);
}
