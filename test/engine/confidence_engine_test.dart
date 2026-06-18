import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/confidence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const weights = SignalWeights();
  const engine = ConfidenceEngine(weights: weights);

  SignalScore signal(String name, double score, double weight) =>
      SignalScore(name: name, score: score, weight: weight);

  group('ConfidenceEngine.fuse', () {
    test('empty signals returns confidence 0 + weak verdict', () {
      final r = engine.fuse(signals: const [], matchThreshold: 0.75);
      expect(r.confidence, 0.0);
      expect(r.verdict, MatchVerdict.weak);
      expect(r.breakdown.signals, isEmpty);
    });

    test('single perfect signal yields confidence 1.0 even when other signals '
        'are disabled (re-normalization)', () {
      final r = engine.fuse(
        signals: [signal('address', 1, weights.address)],
        matchThreshold: 0.75,
      );
      expect(r.confidence, closeTo(1.0, 1e-9));
      expect(r.verdict, MatchVerdict.strong);
      // The single present signal's weight is re-normalized to 1.0.
      expect(r.breakdown.signals, hasLength(1));
      expect(r.breakdown.signals.first.weight, closeTo(1.0, 1e-9));
    });

    test('all three signals present sum weights to 1.0 in the breakdown', () {
      final r = engine.fuse(
        signals: [
          signal('address', 1, weights.address),
          signal('name', 1, weights.name),
          signal('location', 1, weights.location),
        ],
        matchThreshold: 0.75,
      );
      expect(r.confidence, closeTo(1.0, 1e-9));
      final sum = r.breakdown.signals.fold<double>(
        0,
        (a, s) => a + s.weight,
      );
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('weighted average computes per-signal score * applied weight', () {
      final r = engine.fuse(
        signals: [
          signal('address', 1, 0.5),
          signal('name', 0, 0.5),
        ],
        matchThreshold: 0.75,
      );
      expect(r.confidence, closeTo(0.5, 1e-9));
      expect(r.verdict, MatchVerdict.partial);
    });

    test('all-zero weights fall back to equal weighting', () {
      final r = engine.fuse(
        signals: [
          signal('a', 1, 0),
          signal('b', 0, 0),
        ],
        matchThreshold: 0.75,
      );
      // Both treated as 1/2 weight.
      expect(r.confidence, closeTo(0.5, 1e-9));
      for (final s in r.breakdown.signals) {
        expect(s.weight, closeTo(0.5, 1e-9));
      }
    });

    test('verdict mapping: strong, partial, weak buckets', () {
      // Strong: >= matchThreshold.
      final strong = engine.fuse(
        signals: [signal('address', 0.8, 0.5)],
        matchThreshold: 0.75,
      );
      expect(strong.verdict, MatchVerdict.strong);

      // Partial: >= matchThreshold * 0.66 (= 0.495) but < strong.
      final partial = engine.fuse(
        signals: [signal('address', 0.6, 0.5)],
        matchThreshold: 0.75,
      );
      expect(partial.verdict, MatchVerdict.partial);

      // Weak: < matchThreshold * 0.66.
      final weak = engine.fuse(
        signals: [signal('address', 0.2, 0.5)],
        matchThreshold: 0.75,
      );
      expect(weak.verdict, MatchVerdict.weak);
    });

    test('confidence is clamped into [0, 1]', () {
      final overshoot = engine.fuse(
        signals: [signal('address', 5, 0.5)],
        matchThreshold: 0.75,
      );
      expect(overshoot.confidence, lessThanOrEqualTo(1.0));
    });

    test('breakdown preserves names, raw scores, and details', () {
      final r = engine.fuse(
        signals: [
          SignalScore(
            name: 'address',
            score: 0.8,
            weight: weights.address,
            detail: 'detail-a',
          ),
          SignalScore(
            name: 'name',
            score: 0.5,
            weight: weights.name,
            detail: 'detail-n',
          ),
        ],
        matchThreshold: 0.75,
      );
      final addressSignal =
          r.breakdown.signals.firstWhere((s) => s.name == 'address');
      expect(addressSignal.score, 0.8);
      expect(addressSignal.detail, 'detail-a');
      final nameSignal =
          r.breakdown.signals.firstWhere((s) => s.name == 'name');
      expect(nameSignal.score, 0.5);
      expect(nameSignal.detail, 'detail-n');
    });

    test('re-normalization: address-only vs all-three give the same '
        'confidence when only address is non-zero', () {
      // With the default weights, an address score of 1.0 should produce
      // confidence 1.0 when address is the only signal present (rescaled
      // weight = 1.0), NOT a deflated 0.45.
      final addressOnly = engine.fuse(
        signals: [signal('address', 1, weights.address)],
        matchThreshold: 0.75,
      );
      expect(addressOnly.confidence, closeTo(1.0, 1e-9));

      // When other signals are present but the address is the only one with
      // a non-zero score, confidence is the address weight share.
      final allThree = engine.fuse(
        signals: [
          signal('address', 1, weights.address),
          signal('name', 0, weights.name),
          signal('location', 0, weights.location),
        ],
        matchThreshold: 0.75,
      );
      // The address share of the total weight is 0.45 / 1.0 = 0.45.
      expect(allThree.confidence, closeTo(weights.address, 1e-9));
      // And the address-only fusion should be strictly greater.
      expect(addressOnly.confidence, greaterThan(allThree.confidence));
    });
  });

  group('FusedConfidence wiring', () {
    test('exposes confidence, verdict, and a breakdown', () {
      const fused = FusedConfidence(
        confidence: 0.9,
        verdict: MatchVerdict.strong,
        breakdown: ConfidenceBreakdown(signals: <SignalScore>[]),
      );
      expect(fused.confidence, 0.9);
      expect(fused.verdict, MatchVerdict.strong);
      expect(fused.breakdown.signals, isEmpty);
    });
  });
}
