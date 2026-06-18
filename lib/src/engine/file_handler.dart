import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/engine/pdf_rasterizer.dart';
import 'package:address_verify/src/exceptions.dart';
import 'package:address_verify/src/models/document_file.dart';
import 'package:file_picker/file_picker.dart';

/// Output of [FileHandler.validate]: validated bytes + metadata, ready for
/// either direct OCR (images) or PDF rasterization.
class PreparedFile {
  /// Creates a [PreparedFile].
  const PreparedFile({
    required this.bytes,
    required this.mimeType,
    required this.format,
    required this.sizeBytes,
    required this.originalName,
  });

  /// Raw file bytes (PDF document or single image).
  final Uint8List bytes;

  /// Sniffed MIME type derived from extension.
  final String mimeType;

  /// Validated file format.
  final FileFormat format;

  /// Size of [bytes] in bytes; equal to `bytes.length`.
  final int sizeBytes;

  /// Original file name (used for the temp-dir copy on `ReturnMode.path`).
  final String originalName;
}

/// Handles validation, PDF rasterization, and result packaging for uploaded
/// proof-of-address files.
class FileHandler {
  /// Creates a [FileHandler] bound to [config].
  FileHandler({
    required this.config,
    PdfRasterizer? pdfRasterizer,
  }) : pdfRasterizer = pdfRasterizer ?? const UnconfiguredPdfRasterizer();

  /// Config used to validate allowed formats / sizes and choose return mode.
  final AddressVerifyConfig config;

  /// Internal PDF rasterizer. Defaults to a stub that throws; a real
  /// platform-backed impl is supplied via constructor injection.
  final PdfRasterizer pdfRasterizer;

  /// Validates [file] against [config] and returns a [PreparedFile].
  ///
  /// Throws [UnsupportedFileException] / [FileTooLargeException] on rejection.
  PreparedFile validate(PlatformFile file) {
    final format = _formatFor(file);
    if (!config.allowedFormats.contains(format)) {
      throw UnsupportedFileException(
        'Format ${file.extension} is not in allowedFormats.',
      );
    }

    final bytes = _bytesOf(file);
    final maxBytes = config.maxFileSizeMb * 1024 * 1024;
    if (bytes.lengthInBytes > maxBytes) {
      throw FileTooLargeException(
        'File is ${bytes.lengthInBytes} bytes; '
        'maximum is $maxBytes (${config.maxFileSizeMb} MB).',
      );
    }

    return PreparedFile(
      bytes: bytes,
      mimeType: _mimeFor(format),
      format: format,
      sizeBytes: bytes.lengthInBytes,
      originalName: file.name,
    );
  }

  /// Rasterizes [prepared] up to [maxPages] pages. Caller decides how many
  /// to OCR; the engine starts with 1 and expands to 3 when page-1 OCR is
  /// sparse.
  Future<List<Uint8List>> rasterizePdf(
    PreparedFile prepared, {
    required int maxPages,
  }) {
    if (prepared.format != FileFormat.pdf) {
      throw StateError('rasterizePdf called on non-PDF file');
    }
    return pdfRasterizer.rasterize(prepared.bytes, maxPages: maxPages);
  }

  /// Packages [bytes] for the caller per [returnMode]. For `path` mode, the
  /// bytes are written to a fresh file inside [tmpDir]. Exactly one of
  /// `path` / `base64` is set on the returned [DocumentFile].
  Future<DocumentFile> prepareForReturn({
    required Uint8List bytes,
    required String mimeType,
    required ReturnMode returnMode,
    required Directory tmpDir,
    required String originalName,
  }) async {
    switch (returnMode) {
      case ReturnMode.path:
        if (!tmpDir.existsSync()) {
          await tmpDir.create(recursive: true);
        }
        final safeName = _sanitizeFileName(originalName, mimeType);
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final outPath = '${tmpDir.path}${Platform.pathSeparator}'
            'address_verify_${stamp}_$safeName';
        final out = File(outPath);
        await out.writeAsBytes(bytes, flush: true);
        final doc = DocumentFile(
          path: outPath,
          mimeType: mimeType,
          sizeBytes: bytes.lengthInBytes,
        );
        _assertExactlyOne(doc);
        return doc;
      case ReturnMode.base64:
        final doc = DocumentFile(
          base64: base64Encode(bytes),
          mimeType: mimeType,
          sizeBytes: bytes.lengthInBytes,
        );
        _assertExactlyOne(doc);
        return doc;
    }
  }

  FileFormat _formatFor(PlatformFile file) {
    final ext = file.extension?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return FileFormat.pdf;
      case 'png':
        return FileFormat.png;
      case 'jpg':
      case 'jpeg':
        return FileFormat.jpg;
      default:
        throw UnsupportedFileException(
          'Unrecognized file extension: ${file.extension}',
        );
    }
  }

  String _mimeFor(FileFormat format) {
    switch (format) {
      case FileFormat.pdf:
        return 'application/pdf';
      case FileFormat.png:
        return 'image/png';
      case FileFormat.jpg:
        return 'image/jpeg';
    }
  }

  Uint8List _bytesOf(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final path = file.path;
    if (path != null) {
      return File(path).readAsBytesSync();
    }
    throw const UnsupportedFileException(
      'PlatformFile has neither bytes nor a path.',
    );
  }

  String _sanitizeFileName(String name, String mimeType) {
    final cleaned = name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    if (cleaned.isEmpty) {
      switch (mimeType) {
        case 'application/pdf':
          return 'document.pdf';
        case 'image/png':
          return 'document.png';
        case 'image/jpeg':
          return 'document.jpg';
        default:
          return 'document.bin';
      }
    }
    return cleaned;
  }

  void _assertExactlyOne(DocumentFile doc) {
    final pathSet = doc.path != null;
    final b64Set = doc.base64 != null;
    assert(
      pathSet ^ b64Set,
      'DocumentFile must have exactly one of path/base64 set.',
    );
  }
}
