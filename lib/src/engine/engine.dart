import 'dart:io';

import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/engine/address_matcher.dart';
import 'package:address_verify/src/engine/confidence_engine.dart';
import 'package:address_verify/src/engine/default_collaborators.dart';
import 'package:address_verify/src/engine/file_handler.dart';
import 'package:address_verify/src/engine/location_service.dart';
import 'package:address_verify/src/engine/name_matcher.dart';
import 'package:address_verify/src/models/address.dart';
import 'package:address_verify/src/models/result.dart';
import 'package:address_verify/src/models/signals.dart';
import 'package:address_verify/src/ocr/ocr_provider.dart';
import 'package:file_picker/file_picker.dart';

/// Headless pre-screening engine.
///
/// Run the full pipeline via [verify] or call the granular helpers
/// ([extractText], [matchAddress], [matchName]) when building a custom UI.
class AddressVerifyEngine {
  /// Creates an [AddressVerifyEngine] bound to [config].
  ///
  /// Collaborators ([fileHandler], [locationService], [ocrProviderOverride],
  /// [tempDirectory]) are injectable for tests; production callers can rely
  /// on the defaults.
  AddressVerifyEngine(
    this.config, {
    FileHandler? fileHandler,
    LocationService? locationService,
    OcrProvider? ocrProviderOverride,
    Directory? tempDirectory,
    AddressMatcher addressMatcher = const AddressMatcher(),
    NameMatcher nameMatcher = const NameMatcher(),
    DefaultCollaborators defaults = const DefaultCollaborators(),
  })  : _fileHandler = fileHandler ?? defaults.fileHandler(config),
        _locationService = locationService ?? defaults.locationService(),
        _ocrProviderOverride = ocrProviderOverride,
        _defaults = defaults,
        _tempDirectory = tempDirectory,
        _addressMatcher = addressMatcher,
        _nameMatcher = nameMatcher,
        _confidenceEngine = ConfidenceEngine(weights: config.signalWeights);

  /// Configuration this engine was constructed with.
  final AddressVerifyConfig config;

  final FileHandler _fileHandler;
  final LocationService _locationService;
  final OcrProvider? _ocrProviderOverride;
  final DefaultCollaborators _defaults;
  final Directory? _tempDirectory;
  final AddressMatcher _addressMatcher;
  final NameMatcher _nameMatcher;
  final ConfidenceEngine _confidenceEngine;

  static const int _maxPdfPages = 3;
  static const int _sparseOcrThreshold = 20;
  static const double _addressMismatchFloor = 0.3;
  static const double _lowOcrConfidenceFloor = 0.5;
  static const double _mockedLocationPenalty = 0.3;

  /// Full pipeline: validate -> OCR -> match -> fuse -> package.
  ///
  /// [fullName] is required iff `config.matchName == true`.
  Future<AddressVerifyResult> verify({
    required PlatformFile file,
    required TypedAddress typedAddress,
    required DocumentType documentType,
    String? fullName,
  }) async {
    _requireKnownDocumentType(documentType);
    _requireNameWhenEnabled(fullName);

    final prepared = _fileHandler.validate(file);
    final ocrText = await _runOcr(prepared);

    final addressMatch = _addressMatcher.match(typedAddress, ocrText.text);

    NameMatch? nameMatch;
    if (config.matchName) {
      nameMatch = _nameMatcher.match(fullName!, ocrText.text);
    }

    _LocationSignal? locationSignal;
    DeviceLocation? location;
    if (config.detectLocation) {
      location = await _locationService.current();
      locationSignal = _scoreLocation(location, typedAddress);
    }

    final fused = _confidenceEngine.fuse(
      signals: _buildSignals(
        addressMatch: addressMatch,
        nameMatch: nameMatch,
        locationSignal: locationSignal,
      ),
      matchThreshold: config.matchThreshold,
    );

    final flags = _collectFlags(
      addressMatch: addressMatch,
      nameMatch: nameMatch,
      locationSignal: locationSignal,
      location: location,
      meanOcrConfidence: ocrText.meanConfidence,
    );

    final document = await _fileHandler.prepareForReturn(
      bytes: prepared.bytes,
      mimeType: prepared.mimeType,
      returnMode: config.returnMode,
      tmpDir: _tempDirectory ?? Directory.systemTemp,
      originalName: prepared.originalName,
    );

    return AddressVerifyResult(
      confidence: fused.confidence,
      verdict: fused.verdict,
      documentType: documentType,
      document: document,
      extractedText: ocrText.text,
      typedAddress: typedAddress,
      breakdown: fused.breakdown,
      flags: flags,
    );
  }

  /// Extracts raw OCR text from [file].
  Future<String> extractText(PlatformFile file) async {
    final prepared = _fileHandler.validate(file);
    final result = await _runOcr(prepared);
    return result.text;
  }

  /// Scores [typed] against previously-extracted [ocrText].
  AddressMatch matchAddress(TypedAddress typed, String ocrText) =>
      _addressMatcher.match(typed, ocrText);

  /// Scores [fullName] against previously-extracted [ocrText].
  NameMatch matchName(String fullName, String ocrText) =>
      _nameMatcher.match(fullName, ocrText);

  void _requireKnownDocumentType(DocumentType documentType) {
    final known = config.documentTypes.any((d) => d.id == documentType.id);
    if (!known) {
      throw ArgumentError.value(
        documentType.id,
        'documentType',
        'is not in config.documentTypes',
      );
    }
  }

  void _requireNameWhenEnabled(String? fullName) {
    if (!config.matchName) return;
    if (fullName == null || fullName.trim().isEmpty) {
      throw ArgumentError.value(
        fullName,
        'fullName',
        'is required when config.matchName is true',
      );
    }
  }

  Future<OcrResult> _runOcr(PreparedFile prepared) async {
    final provider = _ocrProviderOverride ??
        config.ocrProvider ??
        _defaults.ocrProvider(config);

    switch (prepared.format) {
      case FileFormat.pdf:
        return _runPdfOcr(prepared, provider);
      case FileFormat.png:
      case FileFormat.jpg:
        return provider.extract(prepared.bytes);
    }
  }

  Future<OcrResult> _runPdfOcr(
    PreparedFile prepared,
    OcrProvider provider,
  ) async {
    final firstPages =
        await _fileHandler.rasterizePdf(prepared, maxPages: 1);
    if (firstPages.isEmpty) {
      return const OcrResult(text: '');
    }
    final first = await provider.extract(firstPages.first);
    if (first.text.length >= _sparseOcrThreshold) {
      return first;
    }

    final allPages =
        await _fileHandler.rasterizePdf(prepared, maxPages: _maxPdfPages);
    final texts = <String>[first.text];
    final confidences = <double>[
      if (first.meanConfidence != null) first.meanConfidence!,
    ];
    for (var i = 1; i < allPages.length && i < _maxPdfPages; i++) {
      final r = await provider.extract(allPages[i]);
      texts.add(r.text);
      if (r.meanConfidence != null) confidences.add(r.meanConfidence!);
    }
    final mean = confidences.isEmpty
        ? null
        : confidences.reduce((a, b) => a + b) / confidences.length;
    return OcrResult(text: texts.join('\n').trim(), meanConfidence: mean);
  }

  _LocationSignal _scoreLocation(
    DeviceLocation location,
    TypedAddress typed,
  ) {
    final claimed = typed.country.toUpperCase();
    final resolved = location.countryCode?.toUpperCase();
    final mismatch = resolved == null || resolved != claimed;
    final base = mismatch ? 0.0 : 1.0;
    final adjusted = location.isMocked ? base * _mockedLocationPenalty : base;
    final detail = StringBuffer()
      ..write('claimed=$claimed ')
      ..write('resolved=${resolved ?? "unknown"}');
    if (location.isMocked) detail.write(' (mocked x0.3)');
    return _LocationSignal(
      score: adjusted,
      mismatch: mismatch,
      detail: detail.toString(),
    );
  }

  List<SignalScore> _buildSignals({
    required AddressMatch addressMatch,
    required NameMatch? nameMatch,
    required _LocationSignal? locationSignal,
  }) {
    final signals = <SignalScore>[
      SignalScore(
        name: 'address',
        score: addressMatch.score,
        weight: config.signalWeights.address,
        detail: addressMatch.detail,
      ),
    ];
    if (nameMatch != null) {
      signals.add(
        SignalScore(
          name: 'name',
          score: nameMatch.score,
          weight: config.signalWeights.name,
          detail: nameMatch.detail,
        ),
      );
    }
    if (locationSignal != null) {
      signals.add(
        SignalScore(
          name: 'location',
          score: locationSignal.score,
          weight: config.signalWeights.location,
          detail: locationSignal.detail,
        ),
      );
    }
    return signals;
  }

  List<VerifyFlag> _collectFlags({
    required AddressMatch addressMatch,
    required NameMatch? nameMatch,
    required _LocationSignal? locationSignal,
    required DeviceLocation? location,
    required double? meanOcrConfidence,
  }) {
    final flags = <VerifyFlag>[];
    if (addressMatch.score < _addressMismatchFloor) {
      flags.add(VerifyFlag.addressMismatch);
    }
    if (nameMatch != null && nameMatch.score == 0) {
      flags.add(VerifyFlag.nameNotFound);
    }
    if (locationSignal != null && locationSignal.mismatch) {
      flags.add(VerifyFlag.locationMismatch);
    }
    if (location != null && location.isMocked) {
      flags.add(VerifyFlag.mockedLocation);
    }
    if (meanOcrConfidence != null &&
        meanOcrConfidence < _lowOcrConfidenceFloor) {
      flags.add(VerifyFlag.lowOcrConfidence);
    }
    return flags;
  }
}

class _LocationSignal {
  const _LocationSignal({
    required this.score,
    required this.mismatch,
    required this.detail,
  });

  final double score;
  final bool mismatch;
  final String detail;
}
