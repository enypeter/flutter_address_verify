import 'package:address_verify/src/models/signals.dart';
import 'package:address_verify/src/ocr/ocr_provider.dart';
import 'package:address_verify/src/ui/theme.dart';

/// Supported document container formats for pre-screening uploads.
enum FileFormat {
  /// PDF. The first page (and up to 3 if sparse) is rasterized for OCR.
  pdf,

  /// PNG image.
  png,

  /// JPEG image.
  jpg,
}

/// How the captured document should be returned to the caller.
enum ReturnMode {
  /// Return an on-disk path to a temporary copy.
  path,

  /// Return a base64-encoded copy of the bytes.
  base64,
}

/// A developer-defined document type the user may select during capture.
class DocumentType {
  /// Creates a [DocumentType]. [id] should be stable across releases.
  const DocumentType({
    required this.id,
    required this.label,
    this.hint,
  });

  /// Stable, machine-readable identifier (e.g. `utility_bill`).
  final String id;

  /// Human-readable label shown to the user.
  final String label;

  /// Optional helper text describing what this document looks like.
  final String? hint;
}

/// Configuration for an `AddressVerifyEngine` or `AddressVerifyWidget`.
class AddressVerifyConfig {
  /// Creates an [AddressVerifyConfig].
  const AddressVerifyConfig({
    required this.documentTypes,
    this.allowedFormats = const [
      FileFormat.pdf,
      FileFormat.png,
      FileFormat.jpg,
    ],
    this.maxFileSizeMb = 10,
    this.returnMode = ReturnMode.path,
    this.detectLocation = false,
    this.matchName = true,
    this.signalWeights = const SignalWeights(),
    this.matchThreshold = 0.75,
    this.ocrLanguage = 'en',
    this.theme = const AddressVerifyTheme(),
    this.ocrProvider,
  });

  /// Document types the user can choose from. Must be non-empty.
  final List<DocumentType> documentTypes;

  /// File formats the engine will accept; others are rejected up front.
  final List<FileFormat> allowedFormats;

  /// Maximum file size, in megabytes. Default `10`.
  final int maxFileSizeMb;

  /// How the captured document should be packaged in the result.
  final ReturnMode returnMode;

  /// When `true`, the engine performs an opt-in GPS country cross-reference.
  final bool detectLocation;

  /// When `true`, the engine also scores the supplied full name against OCR.
  final bool matchName;

  /// Tunable weights for signal fusion.
  final SignalWeights signalWeights;

  /// Confidence threshold above which the verdict is `strong`. Default `0.75`.
  final double matchThreshold;

  /// BCP-47-ish OCR language hint passed to the OCR provider.
  final String ocrLanguage;

  /// Theme applied to `AddressVerifyWidget` and its sub-widgets.
  final AddressVerifyTheme theme;

  /// Optional OCR backend override. When `null` the default ML Kit provider
  /// is used.
  final OcrProvider? ocrProvider;
}
