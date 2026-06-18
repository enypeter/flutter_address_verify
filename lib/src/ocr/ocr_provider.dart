import 'dart:typed_data';

/// Result of an OCR pass over a single image.
class OcrResult {
  /// Creates an [OcrResult].
  const OcrResult({required this.text, this.meanConfidence});

  /// Raw text recognized in the image.
  final String text;

  /// Mean per-token confidence in the range `0.0..1.0`, if the provider
  /// exposes it. May be `null` when unavailable.
  final double? meanConfidence;
}

/// Pluggable OCR backend.
///
/// The default implementation uses Google ML Kit, but callers may inject a
/// custom provider (e.g. a server-backed one for testing).
// Kept as an abstract single-method interface intentionally: this is the
// public extension point documented in the spec.
// ignore: one_member_abstracts
abstract class OcrProvider {
  /// Extracts text from the supplied image bytes.
  Future<OcrResult> extract(Uint8List imageBytes);
}
