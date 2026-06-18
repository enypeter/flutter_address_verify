/// A user-typed claimed address that the OCR text will be cross-referenced
/// against during pre-screening.
class TypedAddress {
  /// Creates a [TypedAddress].
  const TypedAddress({
    required this.line1,
    required this.city,
    required this.country,
    this.line2,
    this.state,
    this.postalCode,
  });

  /// Primary street/line of the claimed address.
  final String line1;

  /// Optional second address line (apartment, suite, etc.).
  final String? line2;

  /// City / locality.
  final String city;

  /// State / region / province, if applicable.
  final String? state;

  /// Postal or ZIP code, if applicable.
  final String? postalCode;

  /// ISO 3166-1 alpha-2 country code (e.g. `NG`).
  final String country;
}

/// Best-effort structured parse of an address that the engine extracted from
/// OCR text. Any field may be `null` when parsing is uncertain.
class ExtractedAddress {
  /// Creates an [ExtractedAddress].
  const ExtractedAddress({
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  /// Parsed first address line, if found.
  final String? line1;

  /// Parsed second address line, if found.
  final String? line2;

  /// Parsed city, if found.
  final String? city;

  /// Parsed state/region, if found.
  final String? state;

  /// Parsed postal code, if found.
  final String? postalCode;

  /// Parsed ISO country code, if confidently inferred.
  final String? country;
}
