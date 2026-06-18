import 'package:address_verify/address_verify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddressVerifyWidget renders without crashing', (tester) async {
    const config = AddressVerifyConfig(
      documentTypes: [
        DocumentType(id: 'utility_bill', label: 'Utility Bill'),
        DocumentType(id: 'bank_statement', label: 'Bank Statement'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddressVerifyWidget(
            config: config,
            onComplete: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Address pre-screening'), findsOneWidget);
    expect(find.text('Utility Bill'), findsOneWidget);
    expect(find.text('Bank Statement'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
