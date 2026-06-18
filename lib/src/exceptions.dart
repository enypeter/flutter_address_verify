/// Base type for all `address_verify` domain exceptions.
abstract class AddressVerifyException implements Exception {
  /// Creates an [AddressVerifyException] with the given [message].
  const AddressVerifyException(this.message);

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when an uploaded file's format is not in the allowed format list.
class UnsupportedFileException extends AddressVerifyException {
  /// Creates an [UnsupportedFileException].
  const UnsupportedFileException(super.message);
}

/// Thrown when an uploaded file exceeds `AddressVerifyConfig.maxFileSizeMb`.
class FileTooLargeException extends AddressVerifyException {
  /// Creates a [FileTooLargeException].
  const FileTooLargeException(super.message);
}

/// Thrown when the configured OCR provider cannot run on the current device
/// (e.g. ML Kit model failed to load).
class OcrUnavailableException extends AddressVerifyException {
  /// Creates an [OcrUnavailableException].
  const OcrUnavailableException(super.message);
}

/// Thrown when location detection is enabled but the user denied permission
/// or location services are disabled.
class LocationPermissionDeniedException extends AddressVerifyException {
  /// Creates a [LocationPermissionDeniedException].
  const LocationPermissionDeniedException(super.message);
}
