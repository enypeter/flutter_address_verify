import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/address_matcher.dart';
import 'package:address_verify/src/engine/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../goldens/african_addresses.dart';

void main() {
  const matcher = AddressMatcher();

  group('AddressMatcher.match', () {
    test('exact address match scores 1.0 with no missing tokens', () {
      const typed = TypedAddress(
        line1: '123 Main Street',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr = '123 Main Street Lagos';
      final result = matcher.match(typed, ocr);
      expect(result.score, closeTo(1.0, 1e-9));
      expect(result.missingTokens, isEmpty);
      expect(result.matchedTokens, isNotEmpty);
      expect(result.detail, isNotNull);
      expect(result.detail, contains('jaccard'));
      expect(result.detail, contains('critical'));
    });

    test('abbreviation variants still produce a strong score', () {
      const typed = TypedAddress(
        line1: '123 Main Street',
        city: 'Lagos',
        country: 'NG',
      );
      // Note "St" vs "Street": the bidirectional abbreviation expansion
      // should make these equivalent for set operations.
      const ocr = '123 Main St Lagos';
      final result = matcher.match(typed, ocr);
      expect(result.score, greaterThanOrEqualTo(0.95));
    });

    test('reordered tokens still produce a strong score', () {
      const typed = TypedAddress(
        line1: '24B Adeola Odeku Street',
        city: 'Victoria Island',
        state: 'Lagos',
        country: 'NG',
      );
      const ocr = 'Lagos Victoria Island 24b Adeola Odeku St';
      final result = matcher.match(typed, ocr);
      expect(result.score, greaterThanOrEqualTo(0.95));
    });

    test('completely different OCR text scores below the mismatch floor', () {
      const typed = TypedAddress(
        line1: '123 Main Street',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr =
          'completely unrelated electricity bill issued by some other utility';
      final result = matcher.match(typed, ocr);
      expect(result.score, lessThan(0.3));
      expect(result.missingTokens, isNotEmpty);
    });

    test('empty typed address yields a zero score with explanation', () {
      // We can not construct a totally empty TypedAddress (line1 and city are
      // required), but we can give it whitespace-only fields to drive the
      // empty-tokens branch.
      const typed = TypedAddress(
        line1: '   ',
        city: '   ',
        country: 'NG',
      );
      final result = matcher.match(typed, 'whatever the document says');
      expect(result.score, 0);
      expect(result.detail, contains('empty'));
      expect(result.matchedTokens, isEmpty);
      expect(result.missingTokens, isEmpty);
    });

    test('empty OCR text scores zero on a populated typed address', () {
      const typed = TypedAddress(
        line1: '123 Main Street',
        city: 'Lagos',
        country: 'NG',
      );
      final result = matcher.match(typed, '');
      expect(result.score, 0);
      expect(result.missingTokens, isNotEmpty);
    });

    test('jaccard and critical halves are blended in the documented ratio',
        () {
      // Construct a case where critical tokens (line1 + city) match in full
      // but the typed-token set is a strict subset of OCR so Jaccard is < 1.
      const typed = TypedAddress(
        line1: '10 Elm Road',
        city: 'Accra',
        country: 'GH',
      );
      const ocr = '10 Elm Road Accra plus extra unrelated padding tokens';
      final result = matcher.match(typed, ocr);
      // Critical is 1.0, Jaccard < 1.0, so score sits between the two.
      expect(result.score, greaterThan(0.6));
      expect(result.score, lessThan(1.0));
    });

    test('handles every messy African-format golden in the expected band',
        () {
      for (final c in africanAddressGoldens) {
        final r = matcher.match(c.typed, c.ocr);
        expect(
          r.score,
          inInclusiveRange(c.minConfidence, c.maxConfidence),
          reason: 'golden "${c.label}" produced score ${r.score}, '
              'expected [${c.minConfidence}, ${c.maxConfidence}]. '
              'detail=${r.detail}',
        );
      }
    });

    test('matchedTokens are sorted and reflect the intersection', () {
      const typed = TypedAddress(
        line1: 'Beta Alpha Avenue',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr = 'Alpha Avenue Lagos extra';
      final result = matcher.match(typed, ocr);
      // Sorted ascending and contains tokens from the intersection.
      final sorted = List<String>.from(result.matchedTokens)..sort();
      expect(result.matchedTokens, sorted);
      expect(result.matchedTokens, contains('alpha'));
      expect(result.matchedTokens, contains('lagos'));
    });

    test('missingTokens lists typed tokens absent from OCR, sorted', () {
      const typed = TypedAddress(
        line1: '99 Zeta Lane',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr = 'Lagos';
      final result = matcher.match(typed, ocr);
      final sorted = List<String>.from(result.missingTokens)..sort();
      expect(result.missingTokens, sorted);
      expect(result.missingTokens, contains('99'));
    });
  });

  group('TextNormalizer (indirect verification through AddressMatcher)', () {
    test('punctuation in addresses does not break tokenization', () {
      // The spec strips `[.,#-/]` to whitespace, so "12-A" tokenizes as "12"
      // (the trailing single-char "a" is dropped) — the score still clears
      // the partial floor because the "Main Street" body matches.
      const typed = TypedAddress(
        line1: '12-A, Main St.',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr = '12 Main Street Lagos';
      final r = matcher.match(typed, ocr);
      expect(r.score, greaterThanOrEqualTo(0.85));
    });

    test('isStreetNumber recognizes house numbers but not arbitrary text', () {
      expect(TextNormalizer.isStreetNumber('12'), isTrue);
      expect(TextNormalizer.isStreetNumber('12a'), isTrue);
      expect(TextNormalizer.isStreetNumber('main'), isFalse);
      expect(TextNormalizer.isStreetNumber('a12'), isFalse);
    });

    test('normalize lowercases and collapses whitespace', () {
      expect(
        TextNormalizer.normalize('  ABC   Def\nGHI  '),
        'abc def ghi',
      );
    });

    test('tokens drops stopwords and sub-2-char fragments', () {
      final tokens = TextNormalizer.tokens('The Office of A Street');
      // "the" and "of" are stopwords; "a" is < 2 chars; "street" expands to
      // include "st".
      expect(tokens, isNot(contains('the')));
      expect(tokens, isNot(contains('of')));
      expect(tokens, isNot(contains('a')));
      expect(tokens, contains('office'));
      expect(tokens, contains('street'));
      expect(tokens, contains('st'));
    });

    test('tokens returns const empty for an entirely empty/blank input', () {
      expect(TextNormalizer.tokens(''), isEmpty);
      expect(TextNormalizer.tokens('   '), isEmpty);
    });

    test('tokenSet matches tokens but de-duplicated', () {
      final tokens = TextNormalizer.tokens('Lagos Lagos Lagos');
      final set = TextNormalizer.tokenSet('Lagos Lagos Lagos');
      expect(tokens, contains('lagos'));
      expect(set, contains('lagos'));
      expect(set.length, lessThanOrEqualTo(tokens.length));
    });
  });
}
