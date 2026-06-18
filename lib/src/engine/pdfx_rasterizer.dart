import 'dart:typed_data';

import 'package:address_verify/src/engine/pdf_rasterizer.dart';
import 'package:address_verify/src/exceptions.dart';
import 'package:pdfx/pdfx.dart';

/// [PdfRasterizer] backed by the `pdfx` plugin.
///
/// Rasterizes each requested page at an OCR-friendly resolution (~1500 px
/// wide, preserving aspect ratio) and returns PNG bytes. Throws
/// [OcrUnavailableException] on any render failure so callers see a
/// consistent error surface for "we could not get pixels into the OCR
/// pipeline".
class PdfxRasterizer implements PdfRasterizer {
  /// Creates a [PdfxRasterizer].
  const PdfxRasterizer({this.targetWidthPx = 1500});

  /// Target rendered width in pixels. Page height scales proportionally.
  final int targetWidthPx;

  @override
  Future<List<Uint8List>> rasterize(
    Uint8List pdfBytes, {
    required int maxPages,
  }) async {
    if (maxPages <= 0) return const [];
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(pdfBytes);
      final pageCount =
          document.pagesCount < maxPages ? document.pagesCount : maxPages;
      final out = <Uint8List>[];
      for (var i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        try {
          final scale = targetWidthPx / page.width;
          final renderWidth = targetWidthPx.toDouble();
          final renderHeight = page.height * scale;
          final image = await page.render(
            width: renderWidth,
            height: renderHeight,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) out.add(image.bytes);
        } finally {
          await page.close();
        }
      }
      return out;
    } on Object catch (error) {
      throw OcrUnavailableException('PDF rasterization failed: $error');
    } finally {
      await document?.close();
    }
  }
}
