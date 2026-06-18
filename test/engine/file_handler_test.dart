import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/file_handler.dart';
import 'package:address_verify/src/engine/pdf_rasterizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal 1x1 transparent PNG bytes — small but a real, decodable image so
/// MIME / extension sniffing has something to work with.
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

class _FakePdfRasterizer implements PdfRasterizer {
  _FakePdfRasterizer({this.pages});
  final List<Uint8List>? pages;
  int calls = 0;
  int? lastMaxPages;

  @override
  Future<List<Uint8List>> rasterize(
    Uint8List pdfBytes, {
    required int maxPages,
  }) async {
    calls++;
    lastMaxPages = maxPages;
    return pages ?? [Uint8List.fromList(<int>[1, 2, 3, 4])];
  }
}

PlatformFile _bytesFile({
  required String name,
  required Uint8List bytes,
}) {
  return PlatformFile(name: name, size: bytes.lengthInBytes, bytes: bytes);
}

void main() {
  const config = AddressVerifyConfig(
    documentTypes: [DocumentType(id: 'utility_bill', label: 'Utility Bill')],
  );

  group('FileHandler.validate', () {
    test('accepts a PNG under the size limit', () {
      final handler = FileHandler(config: config);
      final prepared = handler.validate(
        _bytesFile(name: 'doc.png', bytes: _onePixelPng),
      );
      expect(prepared.format, FileFormat.png);
      expect(prepared.mimeType, 'image/png');
      expect(prepared.sizeBytes, _onePixelPng.lengthInBytes);
      expect(prepared.originalName, 'doc.png');
    });

    test('JPG and JPEG extensions both map to FileFormat.jpg', () {
      final handler = FileHandler(config: config);
      final a = handler.validate(
        _bytesFile(name: 'doc.jpg', bytes: _onePixelPng),
      );
      final b = handler.validate(
        _bytesFile(name: 'doc.jpeg', bytes: _onePixelPng),
      );
      expect(a.format, FileFormat.jpg);
      expect(b.format, FileFormat.jpg);
      expect(a.mimeType, 'image/jpeg');
    });

    test('rejects an unsupported extension with UnsupportedFileException', () {
      final handler = FileHandler(config: config);
      expect(
        () => handler.validate(
          _bytesFile(name: 'doc.xyz', bytes: _onePixelPng),
        ),
        throwsA(isA<UnsupportedFileException>()),
      );
    });

    test('rejects a disallowed format with UnsupportedFileException', () {
      // PDF is supported by default; build a config that only allows PNG.
      const restricted = AddressVerifyConfig(
        documentTypes: [DocumentType(id: 'utility_bill', label: 'Utility')],
        allowedFormats: [FileFormat.png],
      );
      final handler = FileHandler(config: restricted);
      expect(
        () => handler.validate(
          PlatformFile(name: 'doc.pdf', size: 4, bytes: Uint8List(4)),
        ),
        throwsA(isA<UnsupportedFileException>()),
      );
    });

    test('rejects oversize bytes with FileTooLargeException', () {
      // 1 MB cap; supply 1 MB + 1 byte of data.
      const small = AddressVerifyConfig(
        documentTypes: [DocumentType(id: 'utility_bill', label: 'Utility')],
        maxFileSizeMb: 1,
      );
      final handler = FileHandler(config: small);
      final big = Uint8List(1024 * 1024 + 1);
      expect(
        () => handler.validate(
          PlatformFile(name: 'doc.png', size: big.length, bytes: big),
        ),
        throwsA(isA<FileTooLargeException>()),
      );
    });

    test('reads bytes from disk when PlatformFile carries only a path',
        () async {
      final tmp = Directory.systemTemp.createTempSync('av_test_');
      try {
        final f = File('${tmp.path}/disk.png')..writeAsBytesSync(_onePixelPng);
        final handler = FileHandler(config: config);
        final prepared = handler.validate(
          PlatformFile(
            name: 'disk.png',
            size: _onePixelPng.length,
            path: f.path,
          ),
        );
        expect(prepared.sizeBytes, _onePixelPng.length);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('throws when PlatformFile has neither bytes nor a path', () {
      final handler = FileHandler(config: config);
      expect(
        () => handler.validate(PlatformFile(name: 'lost.png', size: 0)),
        throwsA(isA<UnsupportedFileException>()),
      );
    });
  });

  group('FileHandler.rasterizePdf', () {
    test('delegates to the injected PdfRasterizer', () async {
      final fake = _FakePdfRasterizer(
        pages: [Uint8List.fromList(<int>[9, 9, 9])],
      );
      final handler = FileHandler(config: config, pdfRasterizer: fake);
      final prepared = handler.validate(
        PlatformFile(
          name: 'doc.pdf',
          size: 4,
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
      );
      final pages = await handler.rasterizePdf(prepared, maxPages: 1);
      expect(pages, hasLength(1));
      expect(pages.first, isNotEmpty);
      expect(fake.calls, 1);
      expect(fake.lastMaxPages, 1);
    });

    test('throws StateError when called on a non-PDF prepared file', () async {
      final handler = FileHandler(config: config);
      final prepared = handler.validate(
        _bytesFile(name: 'doc.png', bytes: _onePixelPng),
      );
      await expectLater(
        () => handler.rasterizePdf(prepared, maxPages: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('UnconfiguredPdfRasterizer fails fast with OcrUnavailableException',
        () async {
      // Use the default rasterizer wiring.
      final handler = FileHandler(config: config);
      final prepared = handler.validate(
        PlatformFile(
          name: 'doc.pdf',
          size: 4,
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
      );
      await expectLater(
        () => handler.rasterizePdf(prepared, maxPages: 1),
        throwsA(isA<OcrUnavailableException>()),
      );
    });
  });

  group('FileHandler.prepareForReturn', () {
    test('returnMode.path populates path and leaves base64 null', () async {
      final handler = FileHandler(config: config);
      final tmp = Directory.systemTemp.createTempSync('av_path_');
      try {
        final doc = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/png',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: 'doc.png',
        );
        expect(doc.base64, isNull);
        expect(doc.path, isNotNull);
        expect(File(doc.path!).existsSync(), isTrue);
        expect(doc.mimeType, 'image/png');
        expect(doc.sizeBytes, _onePixelPng.length);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('returnMode.base64 populates base64 and leaves path null', () async {
      final handler = FileHandler(config: config);
      final tmp = Directory.systemTemp.createTempSync('av_b64_');
      try {
        final doc = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/png',
          returnMode: ReturnMode.base64,
          tmpDir: tmp,
          originalName: 'doc.png',
        );
        expect(doc.path, isNull);
        expect(doc.base64, isNotNull);
        expect(base64Decode(doc.base64!), _onePixelPng);
        expect(doc.mimeType, 'image/png');
        expect(doc.sizeBytes, _onePixelPng.length);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('returnMode.path creates the tmp dir if missing', () async {
      final handler = FileHandler(config: config);
      final tmp = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}av_missing_'
        '${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        expect(tmp.existsSync(), isFalse);
        final doc = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/png',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: 'doc.png',
        );
        expect(File(doc.path!).existsSync(), isTrue);
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    });

    test('sanitizes original file names and falls back when name is unsafe',
        () async {
      final handler = FileHandler(config: config);
      final tmp = Directory.systemTemp.createTempSync('av_sanitize_');
      try {
        final doc = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/png',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: '../../etc/passwd', // contains "/" which is stripped
        );
        // The "/" characters become underscores; no traversal in the path.
        expect(doc.path!.contains('/etc/passwd'), isFalse);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('falls back to a typed default name when the original is empty',
        () async {
      final handler = FileHandler(config: config);
      final tmp = Directory.systemTemp.createTempSync('av_default_name_');
      try {
        final docPdf = await handler.prepareForReturn(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'application/pdf',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: '',
        );
        expect(docPdf.path, endsWith('document.pdf'));

        final docPng = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/png',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: '',
        );
        expect(docPng.path, endsWith('document.png'));

        final docJpeg = await handler.prepareForReturn(
          bytes: _onePixelPng,
          mimeType: 'image/jpeg',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: '',
        );
        expect(docJpeg.path, endsWith('document.jpg'));

        final docOther = await handler.prepareForReturn(
          bytes: Uint8List.fromList(<int>[0]),
          mimeType: 'application/octet-stream',
          returnMode: ReturnMode.path,
          tmpDir: tmp,
          originalName: '',
        );
        expect(docOther.path, endsWith('document.bin'));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });
}
