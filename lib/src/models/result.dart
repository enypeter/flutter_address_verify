import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/models/address.dart';
import 'package:address_verify/src/models/document_file.dart';
import 'package:address_verify/src/models/signals.dart';

/// Coarse pre-screening verdict bucketing the fused confidence score.
enum MatchVerdict {
  /// Strong evidence the document corresponds to the claimed address.
  strong,

  /// Mixed evidence; partial alignment between signals.
  partial,

  /// Insufficient evidence; the user should be asked to retry or escalate.
  weak,
}

/// Output of a full pre-screening pass.
///
/// This is a confidence assessment, not a verification verdict.
class AddressVerifyResult {
  /// Creates an [AddressVerifyResult].
  const AddressVerifyResult({
    required this.confidence,
    required this.verdict,
    required this.documentType,
    required this.document,
    required this.extractedText,
    required this.typedAddress,
    required this.breakdown,
    required this.flags,
    this.extracted,
  });

  /// Fused confidence score in the range `0.0..1.0`.
  final double confidence;

  /// Coarse verdict mapped from [confidence].
  final MatchVerdict verdict;

  /// Document type chosen by the user when capturing the file.
  final DocumentType documentType;

  /// Captured document file (path or base64, per `ReturnMode`).
  final DocumentFile document;

  /// Raw OCR text extracted from the document.
  final String extractedText;

  /// Best-effort structured parse of the OCR text; may be `null`.
  final ExtractedAddress? extracted;

  /// The address the user typed and is being pre-screened against.
  final TypedAddress typedAddress;

  /// Per-signal score breakdown explaining how [confidence] was reached.
  final ConfidenceBreakdown breakdown;

  /// Advisory flags raised during pre-screening.
  final List<VerifyFlag> flags;
}
