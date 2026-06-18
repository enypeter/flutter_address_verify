import 'package:address_verify/src/engine/text_normalizer.dart';
import 'package:address_verify/src/models/address.dart';

/// Structured result of an address fuzzy-match pass.
class AddressMatch {
  /// Creates an [AddressMatch].
  const AddressMatch({
    required this.score,
    required this.matchedTokens,
    required this.missingTokens,
    this.detail,
  });

  /// Composite score in the range `0.0..1.0`.
  final double score;

  /// Tokens from the typed address that were located in OCR text.
  final List<String> matchedTokens;

  /// Tokens from the typed address that could not be located.
  final List<String> missingTokens;

  /// Optional human-readable explanation suitable for `SignalScore.detail`.
  final String? detail;
}

/// Pure-Dart fuzzy address matcher. No Flutter or plugin imports allowed.
///
/// Scoring blends:
///  - Jaccard token overlap (weight 0.4) between the normalized typed address
///    tokens and the normalized OCR token set.
///  - Critical-token hit ratio (weight 0.6) over street-number tokens, the
///    `line1` body, and the `city` — the parts a reviewer cares about.
class AddressMatcher {
  /// Creates an [AddressMatcher].
  const AddressMatcher();

  static const double _jaccardWeight = 0.4;
  static const double _criticalWeight = 0.6;

  /// Scores [typed] against the raw OCR [ocrText] and returns a structured
  /// [AddressMatch].
  AddressMatch match(TypedAddress typed, String ocrText) {
    final typedTokens = _typedTokens(typed);
    final ocrTokens = TextNormalizer.tokenSet(ocrText);

    if (typedTokens.isEmpty) {
      return const AddressMatch(
        score: 0,
        matchedTokens: [],
        missingTokens: [],
        detail: 'typed address empty',
      );
    }

    final typedSet = typedTokens.toSet();
    final intersection = typedSet.intersection(ocrTokens);
    final union = typedSet.union(ocrTokens);
    final jaccard = union.isEmpty ? 0.0 : intersection.length / union.length;

    final critical = _criticalTokens(typed);
    final matchedCritical = critical.where(ocrTokens.contains).toList();
    final criticalScore = critical.isEmpty
        ? 0.0
        : matchedCritical.length / critical.length;

    final composite = (jaccard * _jaccardWeight) +
        (criticalScore * _criticalWeight);
    final score = composite.clamp(0.0, 1.0);

    final matched = intersection.toList()..sort();
    final missing = typedSet.difference(ocrTokens).toList()..sort();

    final detail = 'jaccard=${jaccard.toStringAsFixed(2)} '
        'critical=${matchedCritical.length}/${critical.length}';

    return AddressMatch(
      score: score,
      matchedTokens: matched,
      missingTokens: missing,
      detail: detail,
    );
  }

  List<String> _typedTokens(TypedAddress typed) {
    final buffer = StringBuffer()
      ..write(typed.line1)
      ..write(' ');
    if (typed.line2 != null) {
      buffer
        ..write(typed.line2)
        ..write(' ');
    }
    buffer
      ..write(typed.city)
      ..write(' ');
    if (typed.state != null) {
      buffer
        ..write(typed.state)
        ..write(' ');
    }
    if (typed.postalCode != null) {
      buffer.write(typed.postalCode);
    }
    return TextNormalizer.tokens(buffer.toString());
  }

  List<String> _criticalTokens(TypedAddress typed) {
    final out = <String>{};
    final line1Tokens = TextNormalizer.tokens(typed.line1);
    for (final t in line1Tokens) {
      out.add(t);
      if (TextNormalizer.isStreetNumber(t)) {
        // Already added; keep explicit for clarity.
        out.add(t);
      }
    }
    final cityTokens = TextNormalizer.tokens(typed.city);
    out.addAll(cityTokens);
    return out.toList();
  }
}
