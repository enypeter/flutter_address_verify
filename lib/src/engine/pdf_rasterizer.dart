import 'dart:typed_data';

import 'package:address_verify/src/exceptions.dart';

/// Internal seam for PDF -> raster bytes conversion.
///
/// Agent 3 supplies a real implementation backed by `pdfx`; the default
/// [UnconfiguredPdfRasterizer] keeps the non-PDF paths working today without
/// pulling a Flutter plugin into the pure engine.
// ignore: one_member_abstracts
abstract class PdfRasterizer {
  /// Rasterizes up to [maxPages] of [pdfBytes] into image bytes (PNG or JPEG;
  /// the OCR provider does not care which).
  Future<List<Uint8List>> rasterize(
    Uint8List pdfBytes, {
    required int maxPages,
  });
}

/// Default [PdfRasterizer] used when nothing else is wired in.
///
/// Agent 3 supplies the real impl; until then, any PDF path explicitly fails
/// with a clear message instead of silently returning empty bytes.
class UnconfiguredPdfRasterizer implements PdfRasterizer {
  /// Creates an [UnconfiguredPdfRasterizer].
  const UnconfiguredPdfRasterizer();

  @override
  Future<List<Uint8List>> rasterize(
    Uint8List pdfBytes, {
    required int maxPages,
  }) {
    throw const OcrUnavailableException(
      'PDF rasterization not configured. '
      'Inject a PdfRasterizer (Agent 3 supplies the impl).',
    );
  }
}
