import 'package:address_verify/src/engine/name_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matcher = NameMatcher();

  group('NameMatcher.match', () {
    test('all name tokens present in OCR returns score 1.0 and found=true',
        () {
      final r = matcher.match('Ada Lovelace', 'Customer: Ada Lovelace');
      expect(r.score, 1.0);
      expect(r.found, isTrue);
      expect(r.detail, isNotNull);
      expect(r.detail, contains('matched'));
    });

    test('partial match returns proportional score', () {
      final r = matcher.match('Ada Lovelace Byron', 'Customer: Ada Lovelace');
      // 2 / 3 name tokens found.
      expect(r.score, closeTo(2 / 3, 1e-9));
      expect(r.found, isTrue);
    });

    test('name absent from OCR scores 0 and found=false', () {
      final r = matcher.match('Ada Lovelace', 'totally unrelated document');
      expect(r.score, 0.0);
      expect(r.found, isFalse);
      expect(r.detail, isNotNull);
      expect(r.detail, contains('not found'));
    });

    test('empty fullName returns 0 with "name empty" detail', () {
      final r = matcher.match('', 'Customer: Ada Lovelace');
      expect(r.score, 0.0);
      expect(r.found, isFalse);
      expect(r.detail, 'name empty');
    });

    test('whitespace-only fullName returns 0', () {
      final r = matcher.match('   ', 'whatever');
      expect(r.score, 0);
      expect(r.found, isFalse);
    });

    test('pure-stopword name returns the "no scoreable tokens" branch', () {
      final r = matcher.match('the of and', 'Customer: The Of And');
      expect(r.score, 0);
      expect(r.found, isFalse);
      expect(r.detail, contains('no scoreable tokens'));
    });

    test('case-insensitive and punctuation-tolerant token matching', () {
      final r = matcher.match('ADA, LOVELACE.', 'ada Lovelace appears here');
      expect(r.score, 1.0);
      expect(r.found, isTrue);
    });
  });
}
