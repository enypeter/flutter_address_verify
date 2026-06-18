import 'package:address_verify/address_verify.dart';

/// A single golden case: a typed address paired with the OCR text that a real
/// utility bill / bank statement might surface, and the expected confidence
/// envelope after fusion.
///
/// `minConfidence` / `maxConfidence` are inclusive bounds. `verdict` is the
/// expected mapping for the canonical config (matchThreshold 0.75, address-only
/// signal, matchName=false, detectLocation=false).
class GoldenAddressCase {
  /// Creates a [GoldenAddressCase].
  const GoldenAddressCase({
    required this.label,
    required this.typed,
    required this.ocr,
    required this.minConfidence,
    required this.maxConfidence,
    required this.verdict,
  });

  /// Human-readable label printed when the case fails.
  final String label;

  /// The address the user typed in the form.
  final TypedAddress typed;

  /// What an OCR pass over the proof-of-address document yielded.
  final String ocr;

  /// Inclusive lower bound on the expected fused confidence.
  final double minConfidence;

  /// Inclusive upper bound on the expected fused confidence.
  final double maxConfidence;

  /// Expected verdict at the default `matchThreshold = 0.75`.
  final MatchVerdict verdict;
}

/// Messy, informal Nigerian/African-format address goldens. Postal codes are
/// often absent in this style; the matcher must lean on the street + city
/// signal instead.
///
/// Bounds were calibrated against the v1 algorithm: Jaccard (0.4) + critical
/// (0.6). Cases that include noisy doc-template tokens (issuer name, customer
/// fields, etc.) intentionally sit just inside the `strong`/`partial` bands so
/// regressions in the noise-tolerance of the matcher trip the test.
const List<GoldenAddressCase> africanAddressGoldens = <GoldenAddressCase>[
  GoldenAddressCase(
    label: 'Lagos compound address with abbreviation variants',
    typed: TypedAddress(
      line1: '24B Adeola Odeku Street',
      city: 'Victoria Island',
      state: 'Lagos',
      country: 'NG',
    ),
    ocr: '24b Adeola Odeku St Victoria Island Lagos',
    minConfidence: 0.95,
    maxConfidence: 1,
    verdict: MatchVerdict.strong,
  ),
  GoldenAddressCase(
    label: 'Abuja government estate, noisy bill header, no postcode',
    typed: TypedAddress(
      line1: 'Plot 142 Aminu Kano Crescent',
      city: 'Wuse 2',
      state: 'FCT',
      country: 'NG',
    ),
    ocr: '''
Federal Capital Territory Water Board
Plot 142 Aminu Kano Crescent
Wuse 2, FCT Abuja
''',
    minConfidence: 0.78,
    maxConfidence: 0.95,
    verdict: MatchVerdict.strong,
  ),
  GoldenAddressCase(
    label: 'Accra street + city only, no house number tokens',
    typed: TypedAddress(
      line1: '7 Liberation Road',
      city: 'Accra',
      country: 'GH',
    ),
    ocr: 'Liberation Rd Accra',
    minConfidence: 0.85,
    maxConfidence: 1,
    verdict: MatchVerdict.strong,
  ),
  GoldenAddressCase(
    label: 'Nairobi reordered tokens with abbreviation',
    typed: TypedAddress(
      line1: 'Riverside Drive',
      line2: 'Apartment 4B',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'KE',
    ),
    ocr: 'Riverside Dr Apt 4B Nairobi County',
    minConfidence: 0.85,
    maxConfidence: 1,
    verdict: MatchVerdict.strong,
  ),
  GoldenAddressCase(
    label: 'Ibadan messy informal landmark address',
    typed: TypedAddress(
      line1: 'Block 5 Bodija Estate',
      city: 'Ibadan',
      state: 'Oyo',
      country: 'NG',
    ),
    ocr: '''
Water Corp Oyo State
Block 5 Bodija Estate, Ibadan, Oyo
''',
    minConfidence: 0.78,
    maxConfidence: 1,
    verdict: MatchVerdict.strong,
  ),
  GoldenAddressCase(
    label: 'Kumasi partial match - city body present, house number missing',
    typed: TypedAddress(
      line1: '15 Adum High Street',
      city: 'Kumasi',
      country: 'GH',
    ),
    ocr: '''
Water Utility
Adum High Street, Kumasi, Ashanti
''',
    minConfidence: 0.5,
    maxConfidence: 0.75,
    verdict: MatchVerdict.partial,
  ),
];
