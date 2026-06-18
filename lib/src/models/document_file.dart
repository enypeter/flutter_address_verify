/// The captured proof-of-address artifact returned alongside a result.
///
/// Exactly one of [path] and [base64] is non-null, determined by
/// `AddressVerifyConfig.returnMode`.
class DocumentFile {
  /// Creates a [DocumentFile]. Exactly one of [path] / [base64] must be set.
  const DocumentFile({
    required this.mimeType,
    required this.sizeBytes,
    this.path,
    this.base64,
  });

  /// On-disk path to the captured file. Set when return mode is `path`.
  final String? path;

  /// Base64-encoded file contents. Set when return mode is `base64`.
  final String? base64;

  /// MIME type of the captured file.
  final String mimeType;

  /// Size of the captured file in bytes.
  final int sizeBytes;
}
