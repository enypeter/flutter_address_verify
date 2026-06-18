/// Tunable weights for the per-signal weighted-average confidence fusion.
class SignalWeights {
  /// Creates a [SignalWeights] with the defaults documented in the spec.
  const SignalWeights({
    this.address = 0.45,
    this.name = 0.25,
    this.location = 0.30,
  });

  /// Weight applied to the address-match signal.
  final double address;

  /// Weight applied to the name-on-document signal.
  final double name;

  /// Weight applied to the GPS-country signal.
  final double location;
}

/// One scored signal in a [ConfidenceBreakdown].
class SignalScore {
  /// Creates a [SignalScore].
  const SignalScore({
    required this.name,
    required this.score,
    required this.weight,
    this.detail,
  });

  /// Stable signal identifier: `address`, `name`, or `location`.
  final String name;

  /// Raw signal score in the range `0.0..1.0`.
  final double score;

  /// Re-normalized weight actually applied during fusion.
  final double weight;

  /// Optional human-readable explanation of the score.
  final String? detail;
}

/// Per-signal explanation of how the fused confidence was reached.
class ConfidenceBreakdown {
  /// Creates a [ConfidenceBreakdown] from the [signals] that were present.
  const ConfidenceBreakdown({required this.signals});

  /// Signals that contributed to the fused score (absent signals are omitted).
  final List<SignalScore> signals;
}

/// Discrete advisory flags surfaced alongside a result.
enum VerifyFlag {
  /// Address signal scored below the strong-match floor.
  addressMismatch,

  /// `matchName` was on but no plausible match for the supplied name was found.
  nameNotFound,

  /// GPS-derived country differs from the typed country.
  locationMismatch,

  /// The OS reported the GPS reading as mocked.
  mockedLocation,

  /// OCR returned text but with low mean confidence.
  lowOcrConfidence,
}
