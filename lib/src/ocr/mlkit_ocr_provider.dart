import 'dart:io';
import 'dart:typed_data';

import 'package:address_verify/src/exceptions.dart';
import 'package:address_verify/src/ocr/ocr_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Default [OcrProvider] backed by `google_mlkit_text_recognition`.
///
/// This is the on-device OCR backend used when
/// `AddressVerifyConfig.ocrProvider` is `null`.
class MlKitOcrProvider implements OcrProvider {
  /// Creates an [MlKitOcrProvider] for the given [language] hint.
  const MlKitOcrProvider({this.language = 'en'});

  /// BCP-47-ish OCR language hint. Mapped coarsely onto ML Kit's
  /// [TextRecognitionScript] enum (it does not accept locale strings).
  final String language;

  @override
  Future<OcrResult> extract(Uint8List imageBytes) async {
    // ML Kit's `InputImage.fromBytes` requires platform-specific image
    // metadata (rotation, format, bytes-per-row). The path-based factory is
    // the only reliable way to hand it arbitrary PNG/JPEG bytes regardless
    // of the source (raw camera capture vs. PDF rasterization), so we stage
    // the bytes to a temp file and clean up after.
    final tempDir = Directory.systemTemp.createTempSync('address_verify_ocr_');
    final tempFile =
        File('${tempDir.path}${Platform.pathSeparator}frame.png');
    TextRecognizer? recognizer;
    try {
      await tempFile.writeAsBytes(imageBytes, flush: true);
      recognizer = TextRecognizer(script: _scriptFor(language));
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(tempFile.path),
      );
      final mean = _meanConfidence(recognized);
      return OcrResult(text: recognized.text, meanConfidence: mean);
    } on Object catch (error) {
      throw OcrUnavailableException(
        'ML Kit text recognition failed: $error',
      );
    } finally {
      await recognizer?.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } on FileSystemException {
          // best-effort cleanup; ignore.
        }
      }
    }
  }

  TextRecognitionScript _scriptFor(String lang) {
    final tag = lang.toLowerCase();
    if (tag.startsWith('zh')) return TextRecognitionScript.chinese;
    if (tag.startsWith('ja')) return TextRecognitionScript.japanese;
    if (tag.startsWith('ko')) return TextRecognitionScript.korean;
    if (tag.startsWith('hi') ||
        tag.startsWith('mr') ||
        tag.startsWith('ne') ||
        tag.startsWith('sa')) {
      return TextRecognitionScript.devanagiri;
    }
    return TextRecognitionScript.latin;
  }

  double? _meanConfidence(RecognizedText recognized) {
    final values = <double>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final c = line.confidence;
        if (c != null) values.add(c);
      }
    }
    if (values.isEmpty) return null;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }
}
