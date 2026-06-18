import 'dart:io';
import 'dart:typed_data';

import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/file_handler.dart';
import 'package:address_verify/src/engine/location_service.dart';
import 'package:address_verify/src/engine/pdf_rasterizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../goldens/african_addresses.dart';

/// Minimal valid 1x1 PNG bytes for tests that need realistic image input.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _FakeOcrProvider implements OcrProvider {
  _FakeOcrProvider({
    required this.responses,
    this.confidence,
  });

  /// Successive responses returned by [extract]. The last entry is reused for
  /// any subsequent calls so single-response setups stay terse.
  final List<String> responses;
  final double? confidence;

  int calls = 0;
  final List<Uint8List> seenBytes = <Uint8List>[];

  @override
  Future<OcrResult> extract(Uint8List imageBytes) async {
    seenBytes.add(imageBytes);
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return OcrResult(text: responses[index], meanConfidence: confidence);
  }
}

class _FakePdfRasterizer implements PdfRasterizer {
  _FakePdfRasterizer({required this.pages});
  final List<Uint8List> pages;
  int calls = 0;

  @override
  Future<List<Uint8List>> rasterize(
    Uint8List pdfBytes, {
    required int maxPages,
  }) async {
    calls++;
    final n = pages.length < maxPages ? pages.length : maxPages;
    return pages.sublist(0, n);
  }
}

class _FakeLocationService implements LocationService {
  _FakeLocationService(this._location);
  final DeviceLocation _location;

  @override
  Future<DeviceLocation> current() async => _location;
}

class _ThrowingLocationService implements LocationService {
  @override
  Future<DeviceLocation> current() {
    throw const LocationPermissionDeniedException('denied for testing');
  }
}

PlatformFile _pngFile() => PlatformFile(
      name: 'doc.png',
      size: _onePixelPng.lengthInBytes,
      bytes: _onePixelPng,
    );

PlatformFile _pdfFile() => PlatformFile(
      name: 'doc.pdf',
      size: 4,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );

const _typed = TypedAddress(
  line1: '123 Main Street',
  city: 'Lagos',
  country: 'NG',
);

const _docType = DocumentType(id: 'utility_bill', label: 'Utility Bill');

void main() {
  group('AddressVerifyEngine.verify (image, image-only OCR)', () {
    test('exact image match yields strong verdict and full confidence',
        () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.confidence, closeTo(1.0, 1e-9));
      expect(r.verdict, MatchVerdict.strong);
      expect(r.flags, isNot(contains(VerifyFlag.addressMismatch)));
      expect(r.documentType.id, _docType.id);
      expect(r.extractedText, contains('Main'));
      expect(r.typedAddress, _typed);
      // address-only signal: breakdown length is 1.
      expect(r.breakdown.signals, hasLength(1));
      expect(r.breakdown.signals.first.weight, closeTo(1.0, 1e-9));
    });

    test('strong address mismatch raises addressMismatch flag and weak verdict',
        () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['totally unrelated water utility statement footer'],
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.confidence, lessThan(0.3));
      expect(r.verdict, MatchVerdict.weak);
      expect(r.flags, contains(VerifyFlag.addressMismatch));
    });

    test('matchName=true with name absent raises nameNotFound flag', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
        fullName: 'Ada Lovelace',
      );
      expect(r.flags, contains(VerifyFlag.nameNotFound));
      // breakdown includes address + name.
      expect(
        r.breakdown.signals.map((s) => s.name),
        containsAll(<String>['address', 'name']),
      );
    });

    test('matchName=true requires fullName argument', () async {
      const config = AddressVerifyConfig(documentTypes: [_docType]);
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(responses: ['foo']),
      );
      await expectLater(
        () => engine.verify(
          file: _pngFile(),
          typedAddress: _typed,
          documentType: _docType,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('documentType must be in config.documentTypes', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(responses: ['x']),
      );
      await expectLater(
        () => engine.verify(
          file: _pngFile(),
          typedAddress: _typed,
          documentType: const DocumentType(id: 'unknown', label: 'Unknown'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uses config.ocrProvider when no override is supplied', () async {
      final ocr = _FakeOcrProvider(responses: ['123 Main Street Lagos']);
      final config = AddressVerifyConfig(
        documentTypes: const [_docType],
        matchName: false,
        ocrProvider: ocr,
      );
      final engine = AddressVerifyEngine(config);
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.confidence, greaterThan(0.9));
      expect(ocr.calls, 1);
    });
  });

  group('AddressVerifyEngine.verify with optional signals', () {
    test('re-normalization: a perfect address match keeps confidence at 1.0 '
        'whether or not other signals are present', () async {
      // Construct a typed address whose tokens are a strict subset of the
      // OCR token set; then we can compare cases with and without the
      // matchName/detectLocation toggles using the same OCR.
      const typed = TypedAddress(
        line1: 'Ada Lovelace Main Street',
        city: 'Lagos',
        country: 'NG',
      );
      const ocr = 'Ada Lovelace Main Street Lagos';

      // Case A: address only. Expect 1.0 — re-normalization scales the
      // address weight up to 1.0 since it is the only present signal.
      const cfgAddressOnly = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final eA = AddressVerifyEngine(
        cfgAddressOnly,
        ocrProviderOverride: _FakeOcrProvider(responses: [ocr]),
      );
      final rA = await eA.verify(
        file: _pngFile(),
        typedAddress: typed,
        documentType: _docType,
      );
      expect(rA.confidence, closeTo(1.0, 1e-9));
      expect(rA.verdict, MatchVerdict.strong);
      expect(rA.breakdown.signals, hasLength(1));
      expect(rA.breakdown.signals.first.weight, closeTo(1.0, 1e-9));

      // Case B: address + name + location all perfect. Expect the same 1.0;
      // re-normalization does not deflate the score, weights sum to 1.0.
      const cfgAll = AddressVerifyConfig(
        documentTypes: [_docType],
        detectLocation: true,
      );
      final eB = AddressVerifyEngine(
        cfgAll,
        ocrProviderOverride: _FakeOcrProvider(responses: [ocr]),
        locationService: _FakeLocationService(
          const DeviceLocation(
            latitude: 0,
            longitude: 0,
            countryCode: 'NG',
            isMocked: false,
          ),
        ),
      );
      final rB = await eB.verify(
        file: _pngFile(),
        typedAddress: typed,
        documentType: _docType,
        fullName: 'Ada Lovelace',
      );
      expect(rB.confidence, closeTo(1.0, 1e-9));
      expect(rB.confidence, closeTo(rA.confidence, 1e-9));
      // Re-normalized weights sum to 1.0 across all present signals.
      final sum = rB.breakdown.signals.fold<double>(
        0,
        (a, s) => a + s.weight,
      );
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('country match: location signal scores 1.0', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
        detectLocation: true,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
        locationService: _FakeLocationService(
          const DeviceLocation(
            latitude: 6.5,
            longitude: 3.4,
            countryCode: 'NG',
            isMocked: false,
          ),
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      final locSignal =
          r.breakdown.signals.firstWhere((s) => s.name == 'location');
      expect(locSignal.score, 1.0);
      expect(r.flags, isNot(contains(VerifyFlag.locationMismatch)));
      expect(r.flags, isNot(contains(VerifyFlag.mockedLocation)));
    });

    test('country mismatch: location signal 0 + locationMismatch flag',
        () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
        detectLocation: true,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
        locationService: _FakeLocationService(
          const DeviceLocation(
            latitude: 0,
            longitude: 0,
            countryCode: 'GB',
            isMocked: false,
          ),
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      final locSignal =
          r.breakdown.signals.firstWhere((s) => s.name == 'location');
      expect(locSignal.score, 0.0);
      expect(r.flags, contains(VerifyFlag.locationMismatch));
    });

    test('null resolved country counts as a mismatch', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
        detectLocation: true,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
        locationService: _FakeLocationService(
          const DeviceLocation(
            latitude: 0,
            longitude: 0,
            isMocked: false,
          ),
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.flags, contains(VerifyFlag.locationMismatch));
    });

    test('isMocked=true multiplies location score by 0.3 and flags', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
        detectLocation: true,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
        locationService: _FakeLocationService(
          const DeviceLocation(
            latitude: 0,
            longitude: 0,
            countryCode: 'NG',
            isMocked: true,
          ),
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      final locSignal =
          r.breakdown.signals.firstWhere((s) => s.name == 'location');
      expect(locSignal.score, closeTo(0.3, 1e-9));
      expect(r.flags, contains(VerifyFlag.mockedLocation));
    });

    test('lowOcrConfidence flag is added when mean confidence is below floor',
        () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
          confidence: 0.2,
        ),
      );
      final r = await engine.verify(
        file: _pngFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.flags, contains(VerifyFlag.lowOcrConfidence));
    });

    test('location service errors propagate as exceptions', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
        detectLocation: true,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
        locationService: _ThrowingLocationService(),
      );
      await expectLater(
        () => engine.verify(
          file: _pngFile(),
          typedAddress: _typed,
          documentType: _docType,
        ),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });
  });

  group('AddressVerifyEngine.verify (PDF)', () {
    test('rasterizes a single page and OCRs it when text is dense', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final rasterizer = _FakePdfRasterizer(
        pages: [Uint8List.fromList(List<int>.filled(64, 1))],
      );
      final ocr = _FakeOcrProvider(
        // dense (length >= sparseOcrThreshold).
        responses: ['123 Main Street Lagos plus more dense text'],
      );
      final engine = AddressVerifyEngine(
        config,
        fileHandler: FileHandler(config: config, pdfRasterizer: rasterizer),
        ocrProviderOverride: ocr,
      );
      final r = await engine.verify(
        file: _pdfFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.confidence, greaterThan(0.7));
      // First call rasterized 1 page; OCR ran once.
      expect(rasterizer.calls, 1);
      expect(ocr.calls, 1);
      expect(ocr.seenBytes, hasLength(1));
      expect(ocr.seenBytes.first, isNotEmpty);
    });

    test('expands to up to 3 pages when page 1 OCR is sparse', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final rasterizer = _FakePdfRasterizer(
        pages: List.generate(
          3,
          (i) => Uint8List.fromList(List<int>.filled(8, i + 1)),
        ),
      );
      // Page 1: sparse (< 20 chars). Pages 2 & 3: enough to find the address.
      final ocr = _FakeOcrProvider(
        responses: [
          'short',
          'Main Street',
          '123 Lagos',
        ],
      );
      final engine = AddressVerifyEngine(
        config,
        fileHandler: FileHandler(config: config, pdfRasterizer: rasterizer),
        ocrProviderOverride: ocr,
      );
      final r = await engine.verify(
        file: _pdfFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      // OCR ran across all rasterized pages: page 1 then pages 1..3.
      expect(rasterizer.calls, 2);
      expect(ocr.calls, greaterThanOrEqualTo(3));
      expect(r.extractedText, contains('Lagos'));
    });

    test('jpg image format takes the image OCR branch', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(
          responses: ['123 Main Street Lagos'],
        ),
      );
      final r = await engine.verify(
        file: PlatformFile(
          name: 'doc.jpg',
          size: _onePixelPng.lengthInBytes,
          bytes: _onePixelPng,
        ),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.confidence, greaterThan(0.9));
      expect(r.document.mimeType, 'image/jpeg');
    });

    test('mean OCR confidence aggregates across rasterized pages', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final rasterizer = _FakePdfRasterizer(
        pages: List.generate(
          3,
          (i) => Uint8List.fromList(List<int>.filled(8, i + 1)),
        ),
      );
      // Page 1 sparse, pages 2 & 3 supply OCR confidences that should be
      // averaged into the final mean.
      final ocr = _FakeOcrProvider(
        responses: ['short', 'Main Street', '123 Lagos'],
        confidence: 0.6,
      );
      final engine = AddressVerifyEngine(
        config,
        fileHandler: FileHandler(config: config, pdfRasterizer: rasterizer),
        ocrProviderOverride: ocr,
      );
      final r = await engine.verify(
        file: _pdfFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      // Mean OCR confidence > 0.5 floor => no lowOcrConfidence flag.
      expect(r.flags, isNot(contains(VerifyFlag.lowOcrConfidence)));
    });

    test('empty rasterized output returns empty OCR text without crashing',
        () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        fileHandler: FileHandler(
          config: config,
          pdfRasterizer: _FakePdfRasterizer(pages: const []),
        ),
        ocrProviderOverride: _FakeOcrProvider(responses: const ['']),
      );
      final r = await engine.verify(
        file: _pdfFile(),
        typedAddress: _typed,
        documentType: _docType,
      );
      expect(r.extractedText, isEmpty);
    });
  });

  group('Document packaging (returnMode)', () {
    test('returnMode.path populates document.path and leaves base64 null',
        () async {
      final tmp = Directory.systemTemp.createTempSync('av_eng_path_');
      try {
        const config = AddressVerifyConfig(
          documentTypes: [_docType],
          matchName: false,
        );
        final engine = AddressVerifyEngine(
          config,
          ocrProviderOverride:
              _FakeOcrProvider(responses: ['123 Main Street Lagos']),
          tempDirectory: tmp,
        );
        final r = await engine.verify(
          file: _pngFile(),
          typedAddress: _typed,
          documentType: _docType,
        );
        expect(r.document.path, isNotNull);
        expect(r.document.base64, isNull);
        expect(r.document.mimeType, 'image/png');
        expect(r.document.sizeBytes, _onePixelPng.lengthInBytes);
        expect(File(r.document.path!).existsSync(), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('returnMode.base64 populates document.base64 and leaves path null',
        () async {
      final tmp = Directory.systemTemp.createTempSync('av_eng_b64_');
      try {
        const config = AddressVerifyConfig(
          documentTypes: [_docType],
          matchName: false,
          returnMode: ReturnMode.base64,
        );
        final engine = AddressVerifyEngine(
          config,
          ocrProviderOverride:
              _FakeOcrProvider(responses: ['123 Main Street Lagos']),
          tempDirectory: tmp,
        );
        final r = await engine.verify(
          file: _pngFile(),
          typedAddress: _typed,
          documentType: _docType,
        );
        expect(r.document.path, isNull);
        expect(r.document.base64, isNotNull);
        expect(r.document.mimeType, 'image/png');
        expect(r.document.sizeBytes, _onePixelPng.lengthInBytes);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('AddressVerifyEngine granular helpers', () {
    test('extractText reads OCR for an image', () async {
      const config = AddressVerifyConfig(
        documentTypes: [_docType],
        matchName: false,
      );
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(responses: ['raw ocr text']),
      );
      final text = await engine.extractText(_pngFile());
      expect(text, 'raw ocr text');
    });

    test('matchAddress and matchName forward to the underlying matchers', () {
      const config = AddressVerifyConfig(documentTypes: [_docType]);
      final engine = AddressVerifyEngine(
        config,
        ocrProviderOverride: _FakeOcrProvider(responses: ['x']),
      );
      final am = engine.matchAddress(_typed, '123 Main Street Lagos');
      expect(am.score, closeTo(1.0, 1e-9));
      final nm = engine.matchName('Ada Lovelace', 'Ada Lovelace bill');
      expect(nm.score, 1.0);
    });
  });

  group('Golden integration: end-to-end fusion stays in expected bands', () {
    test('every African-format golden lands in its band when fed as OCR text',
        () async {
      for (final c in africanAddressGoldens) {
        const config = AddressVerifyConfig(
          documentTypes: [_docType],
          matchName: false,
        );
        final engine = AddressVerifyEngine(
          config,
          ocrProviderOverride: _FakeOcrProvider(responses: [c.ocr]),
        );
        final r = await engine.verify(
          file: _pngFile(),
          typedAddress: c.typed,
          documentType: _docType,
        );
        expect(
          r.confidence,
          inInclusiveRange(c.minConfidence, c.maxConfidence),
          reason: 'golden "${c.label}" landed at ${r.confidence}, '
              'expected [${c.minConfidence}, ${c.maxConfidence}]',
        );
        expect(
          r.verdict,
          c.verdict,
          reason: 'golden "${c.label}" verdict mismatch '
              '(confidence ${r.confidence})',
        );
      }
    });
  });
}
