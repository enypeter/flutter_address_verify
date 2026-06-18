import 'package:address_verify/src/engine/text_normalizer.dart';

/// Structured result of a name-on-document match pass.
class NameMatch {
  /// Creates a [NameMatch].
  const NameMatch({
    required this.score,
    required this.found,
    this.detail,
  });

  /// Score in the range `0.0..1.0`.
  final double score;

  /// `true` when a plausible match for the supplied name was located.
  final bool found;

  /// Optional human-readable explanation suitable for `SignalScore.detail`.
  final String? detail;
}

/// Pure-Dart name matcher. No Flutter or plugin imports allowed.
///
/// Score = (matched name tokens) / (total name tokens). Empty inputs and
/// pure-stopword names return zero with `found = false`.
class NameMatcher {
  /// Creates a [NameMatcher].
  const NameMatcher();

  /// Scores [fullName] against the raw OCR [ocrText].
  NameMatch match(String fullName, String ocrText) {
    if (fullName.trim().isEmpty) {
      return const NameMatch(score: 0, found: false, detail: 'name empty');
    }

    final nameTokens = TextNormalizer.tokens(fullName);
    if (nameTokens.isEmpty) {
      return const NameMatch(
        score: 0,
        found: false,
        detail: 'name has no scoreable tokens',
      );
    }

    final ocrTokens = TextNormalizer.tokenSet(ocrText);
    final matched = nameTokens.where(ocrTokens.contains).toList();
    final score = matched.length / nameTokens.length;
    final found = score > 0;

    final detail = found
        ? 'matched ${matched.length}/${nameTokens.length} name tokens'
        : 'name tokens not found in OCR text';

    return NameMatch(score: score, found: found, detail: detail);
  }
}
