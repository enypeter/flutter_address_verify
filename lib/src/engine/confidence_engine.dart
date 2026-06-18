import 'package:address_verify/src/models/result.dart';
import 'package:address_verify/src/models/signals.dart';

/// Pure-Dart signal-fusion engine. No Flutter or plugin imports allowed.
class ConfidenceEngine {
  /// Creates a [ConfidenceEngine] with the supplied [weights].
  const ConfidenceEngine({required this.weights});

  /// Configured base weights; the engine re-normalizes over present signals.
  final SignalWeights weights;

  /// Fuses the supplied [signals] into a single confidence + verdict.
  ///
  /// Each input [SignalScore.weight] is treated as the configured base weight
  /// for that signal. Absent signals must be omitted from the input list; they
  /// are not treated as zero. The output [SignalScore.weight] is the value
  /// actually applied after re-normalization so the present weights sum to 1.
  FusedConfidence fuse({
    required List<SignalScore> signals,
    required double matchThreshold,
  }) {
    if (signals.isEmpty) {
      return const FusedConfidence(
        confidence: 0,
        verdict: MatchVerdict.weak,
        breakdown: ConfidenceBreakdown(signals: <SignalScore>[]),
      );
    }

    final totalWeight = signals.fold<double>(
      0,
      (sum, s) => sum + s.weight,
    );

    // Degenerate guard: caller passed all-zero weights. Treat as equal weight
    // so we still produce a meaningful average instead of dividing by zero.
    final useEqualFallback = totalWeight <= 0;
    final effectiveTotal = useEqualFallback
        ? signals.length.toDouble()
        : totalWeight;

    var weightedSum = 0.0;
    final rescaled = <SignalScore>[];
    for (final s in signals) {
      final base = useEqualFallback ? 1.0 : s.weight;
      final applied = base / effectiveTotal;
      weightedSum += s.score * applied;
      rescaled.add(
        SignalScore(
          name: s.name,
          score: s.score,
          weight: applied,
          detail: s.detail,
        ),
      );
    }

    final confidence = weightedSum.clamp(0.0, 1.0);
    return FusedConfidence(
      confidence: confidence,
      verdict: _verdictFor(confidence, matchThreshold),
      breakdown: ConfidenceBreakdown(signals: rescaled),
    );
  }

  static MatchVerdict _verdictFor(double confidence, double matchThreshold) {
    if (confidence >= matchThreshold) return MatchVerdict.strong;
    if (confidence >= matchThreshold * 0.66) return MatchVerdict.partial;
    return MatchVerdict.weak;
  }
}

/// Output of [ConfidenceEngine.fuse]: the fused score plus its verdict and
/// the re-normalized breakdown.
class FusedConfidence {
  /// Creates a [FusedConfidence].
  const FusedConfidence({
    required this.confidence,
    required this.verdict,
    required this.breakdown,
  });

  /// Fused confidence in the range `0.0..1.0`.
  final double confidence;

  /// Verdict derived from [confidence] and the configured threshold.
  final MatchVerdict verdict;

  /// Per-signal breakdown with re-normalized weights.
  final ConfidenceBreakdown breakdown;
}
