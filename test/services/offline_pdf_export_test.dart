import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fin_track/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// The plugin exposes its platform interface here, rather than via printing.dart.
import 'package:printing/src/interface.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('PDF exports must work without network access');
  }
}

class _CapturePrinting extends PrintingPlatform {
  final documents = <Uint8List>[];

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    documents.add(await onLayout(format));
    return false; // Simulate cancelling; no actual printer is contacted.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all four PDF exports embed local fonts with network disabled',
    () async {
      final previousPrinting = PrintingPlatform.instance;
      final capture = _CapturePrinting();
      PrintingPlatform.instance = capture;
      addTearDown(() => PrintingPlatform.instance = previousPrinting);
      final offline = _NoNetwork();
      final records = <Map<String, dynamic>>[
        {
          'Amount': '10.01',
          'Description': 'Lunch हिन्दी',
          'Category': 'Food',
          'Date': '22/10/2026',
          'Payment_Mode': 'Spent Cash',
          'Type': 'Give Money To Friend',
        },
      ];
      await HttpOverrides.runWithHttpOverrides(() async {
        await ExportService.exportPassbookPdf(
          userName: 'QA हिन्दी',
          phoneNumber: '9000000000',
          records: records,
          totalIncome: 0,
          totalExpense: 10.01,
          currentBalance: -10.01,
          addCash: 0,
          spentCash: 10.01,
          addOnline: 0,
          spentOnline: 0,
        );
        await ExportService.exportFriendLedgerPdf(
          userName: 'QA हिन्दी',
          friendName: 'Friend',
          friendNumber: '9000000001',
          totalGet: 10.01,
          totalGive: 0,
          records: records,
        );
        await ExportService.exportAllFriendsPdf(
          userName: 'QA हिन्दी',
          totalGet: 10.01,
          totalGive: 0,
          friends: [
            {
              'friend_name': 'Friend',
              'friend_number': '9000000001',
              'total_get': 10.01,
              'total_give': 0,
            },
          ],
        );
        await ExportService.exportReportPdf(
          userName: 'QA हिन्दी',
          phoneNumber: '9000000000',
          records: records,
          totalIncome: 0,
          totalExpense: 10.01,
          currentBalance: -10.01,
          addCash: 0,
          spentCash: 10.01,
          addOnline: 0,
          spentOnline: 0,
          friendGet: 10.01,
          friendGive: 0,
          categoryTotals: {'Food': 10.01},
        );
      }, offline);
      expect(offline.attempts, 0);
      expect(capture.documents, hasLength(4));
      for (final bytes in capture.documents) {
        final pdf = latin1.decode(bytes);
        expect(pdf, startsWith('%PDF-'));
        expect(pdf, contains('/FontFile2'));
        expect(bytes.length, greaterThan(5000));
      }
    },
  );
}
