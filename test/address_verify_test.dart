import 'package:address_verify/address_verify.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public barrel exposes the frozen public surface', () {
    const config = AddressVerifyConfig(
      documentTypes: [DocumentType(id: 'utility_bill', label: 'Utility Bill')],
    );
    expect(config.matchThreshold, 0.75);
    expect(config.signalWeights.address, 0.45);
    expect(config.signalWeights.name, 0.25);
    expect(config.signalWeights.location, 0.30);
    expect(config.allowedFormats, contains(FileFormat.pdf));
    expect(config.returnMode, ReturnMode.path);
  });

  test('ExtractedAddress is a const value type with nullable fields', () {
    const extracted = ExtractedAddress(
      line1: '123 Main St',
      city: 'Lagos',
      country: 'NG',
    );
    expect(extracted.line1, '123 Main St');
    expect(extracted.city, 'Lagos');
    expect(extracted.country, 'NG');
    expect(extracted.line2, isNull);
    expect(extracted.state, isNull);
    expect(extracted.postalCode, isNull);
  });

  test('AddressVerifyException subtypes carry a message and toString '
      'including the runtime type', () {
    const e = UnsupportedFileException('bad');
    expect(e.message, 'bad');
    expect(e.toString(), contains('UnsupportedFileException'));
    expect(e.toString(), contains('bad'));
    const too = FileTooLargeException('big');
    expect(too.toString(), contains('FileTooLargeException'));
    const ocrErr = OcrUnavailableException('no ocr');
    expect(ocrErr.toString(), contains('OcrUnavailableException'));
    const locErr = LocationPermissionDeniedException('denied');
    expect(locErr.toString(), contains('LocationPermissionDeniedException'));
  });
}
