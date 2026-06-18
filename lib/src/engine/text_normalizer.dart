/// Pure-Dart text normalization helpers shared by address/name matchers.
///
/// Rules (per Section 4 of the spec):
///  - lowercase
///  - strip punctuation matching `[.,#-/]`
///  - collapse internal whitespace
///  - expand a small bidirectional abbreviation table on a per-token basis
///  - drop tokens shorter than 2 chars and pure stopwords
///
// TODO(future): make the abbreviation table caller-overridable. v1 ships a
// fixed const map; later versions will accept additions through config.
class TextNormalizer {
  TextNormalizer._();

  /// Bidirectional abbreviation table. Keys map to their long form; the
  /// reverse mapping is materialized in [_reverse].
  static const Map<String, String> _abbreviations = <String, String>{
    'st': 'street',
    'rd': 'road',
    'ave': 'avenue',
    'blvd': 'boulevard',
    'dr': 'drive',
    'ln': 'lane',
    'apt': 'apartment',
    'ste': 'suite',
  };

  static final Map<String, String> _reverse = <String, String>{
    for (final e in _abbreviations.entries) e.value: e.key,
  };

  static const Set<String> _stopwords = <String>{'the', 'of', 'and'};

  static final RegExp _punct = RegExp(r'[.,#\-/]');
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _streetNumber = RegExp(r'^\d+[a-z]?$');

  /// Lowercases [input], strips punctuation, and collapses whitespace. The
  /// returned string still contains spaces; call [tokens] for the token list.
  static String normalize(String input) {
    final lowered = input.toLowerCase();
    final stripped = lowered.replaceAll(_punct, ' ');
    return stripped.replaceAll(_whitespace, ' ').trim();
  }

  /// Tokenizes [input] using [normalize], drops stopwords + sub-2-char tokens,
  /// and expands abbreviations bidirectionally so equivalent forms collide in
  /// downstream set operations.
  static List<String> tokens(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return const <String>[];
    final out = <String>[];
    for (final raw in normalized.split(' ')) {
      if (raw.length < 2) continue;
      if (_stopwords.contains(raw)) continue;
      out.addAll(_expand(raw));
    }
    return out;
  }

  /// Same as [tokens] but materialized as a set.
  static Set<String> tokenSet(String input) => tokens(input).toSet();

  /// `true` when [token] looks like a street/house number (e.g. `12`, `12a`).
  static bool isStreetNumber(String token) => _streetNumber.hasMatch(token);

  static Iterable<String> _expand(String token) sync* {
    yield token;
    final long = _abbreviations[token];
    if (long != null) yield long;
    final short = _reverse[token];
    if (short != null) yield short;
  }
}
