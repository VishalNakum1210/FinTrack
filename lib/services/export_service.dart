import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static final DateFormat _exportDateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  // ==========================================
  // 1. PASSBOOK EXPORT (PDF)
  // ==========================================
  static Future<void> exportPassbookPdf({
    required String userName,
    required String phoneNumber,
    required List<Map<String, dynamic>> records,
    required int totalIncome,
    required int totalExpense,
    required int currentBalance,
    required int cashBalance,
    required int onlineBalance,
    String filterCategory = "All",
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('8BC24A');
    final darkGreen = PdfColor.fromHex('33691E');
    final lightGrey = PdfColor.fromHex('F5F7FA');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "FinTrack",
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: darkGreen,
                        ),
                      ),
                      pw.Text(
                        "Smart Expense & Ledger Statement",
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Generated On:",
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        _exportDateFormatter.format(DateTime.now()),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // User Info & Filter Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Account Holder: $userName",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.Text(
                        "Phone: $phoneNumber",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Filter Applied: $filterCategory",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: darkGreen),
                      ),
                      pw.Text(
                        "Total Records: ${records.length}",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Financial Summary Cards
            pw.Row(
              children: [
                _buildSummaryBox("Total Income", _currencyFormatter.format(totalIncome), PdfColors.green700),
                pw.SizedBox(width: 8),
                _buildSummaryBox("Total Expense", _currencyFormatter.format(totalExpense), PdfColors.red700),
                pw.SizedBox(width: 8),
                _buildSummaryBox("Net Balance", _currencyFormatter.format(currentBalance), darkGreen),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _buildSummaryBox("Cash Balance", _currencyFormatter.format(cashBalance), PdfColors.orange800),
                pw.SizedBox(width: 8),
                _buildSummaryBox("Online Balance", _currencyFormatter.format(onlineBalance), PdfColors.blue800),
              ],
            ),
            pw.SizedBox(height: 20),

            // Transaction Table
            pw.Text(
              "Transaction Details",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkGreen),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['#', 'Date', 'Category', 'Description', 'Mode', 'Amount'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: darkGreen),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              data: List<List<dynamic>>.generate(records.length, (index) {
                final item = records[index];
                final isIncome = ["Add CASH", "Add Online"].contains(item["Payment_Mode"]?.toString() ?? "");
                final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
                final formattedAmt = "${isIncome ? '+' : '-'}${_currencyFormatter.format(amt)}";

                return [
                  (index + 1).toString(),
                  item["Date"]?.toString() ?? "-",
                  item["Category"]?.toString() ?? "Other",
                  item["Description"]?.toString() ?? "-",
                  item["Payment_Mode"]?.toString() ?? "-",
                  formattedAmt,
                ];
              }),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'FinTrack_Passbook_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ==========================================
  // 2. PASSBOOK EXPORT (CSV / Excel)
  // ==========================================
  static Future<void> exportPassbookCsv({
    required String userName,
    required List<Map<String, dynamic>> records,
  }) async {
    List<List<dynamic>> csvRows = [
      ["FinTrack Expense Statement"],
      ["Account Holder", userName],
      ["Export Date", _exportDateFormatter.format(DateTime.now())],
      [],
      ["#", "Date", "Category", "Description", "Payment Mode", "Type", "Amount (INR)"],
    ];

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final mode = item["Payment_Mode"]?.toString() ?? "";
      final isIncome = ["Add CASH", "Add Online"].contains(mode);
      final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;

      csvRows.add([
        i + 1,
        item["Date"]?.toString() ?? "",
        item["Category"]?.toString() ?? "Other",
        item["Description"]?.toString() ?? "",
        mode,
        isIncome ? "Income" : "Expense",
        amt,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(csvRows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/FinTrack_Statement_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'FinTrack Expense Statement for $userName',
    );
  }

  // ==========================================
  // 3. FRIEND LEDGER EXPORT (PDF)
  // ==========================================
  static Future<void> exportFriendLedgerPdf({
    required String userName,
    required String friendName,
    required String friendNumber,
    required int totalGet,
    required int totalGive,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();
    final darkGreen = PdfColor.fromHex('33691E');
    final netDue = totalGet - totalGive;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "FinTrack Friend Ledger",
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: darkGreen),
                  ),
                  pw.Text(
                    _exportDateFormatter.format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Divider(color: darkGreen, thickness: 1.5),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("User: $userName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Friend: $friendName ($friendNumber)"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Total To Receive: ${_currencyFormatter.format(totalGet)}", style: const pw.TextStyle(color: PdfColors.green700)),
                      pw.Text("Total To Pay: ${_currencyFormatter.format(totalGive)}", style: const pw.TextStyle(color: PdfColors.red700)),
                      pw.Text("Net Balance: ${_currencyFormatter.format(netDue)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: netDue >= 0 ? PdfColors.green800 : PdfColors.red800)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text("Ledger History", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkGreen)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Date', 'Type', 'Description', 'Mode', 'Amount'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: darkGreen),
              data: List<List<dynamic>>.generate(records.length, (index) {
                final r = records[index];
                final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
                return [
                  (index + 1).toString(),
                  r["Date"]?.toString() ?? "-",
                  r["Type"]?.toString() ?? "-",
                  r["Description"]?.toString() ?? "-",
                  r["Payment_Mode"]?.toString() ?? "-",
                  _currencyFormatter.format(amt),
                ];
              }),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'FinTrack_Ledger_${friendName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ==========================================
  // 4. FRIEND LEDGER EXPORT (CSV)
  // ==========================================
  static Future<void> exportFriendLedgerCsv({
    required String userName,
    required String friendName,
    required String friendNumber,
    required List<Map<String, dynamic>> records,
  }) async {
    List<List<dynamic>> csvRows = [
      ["FinTrack Friend Ledger"],
      ["Account Holder", userName],
      ["Friend Name", friendName],
      ["Friend Phone", friendNumber],
      ["Export Date", _exportDateFormatter.format(DateTime.now())],
      [],
      ["#", "Date", "Transaction Type", "Description", "Payment Mode", "Amount (INR)"],
    ];

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
      csvRows.add([
        i + 1,
        r["Date"]?.toString() ?? "",
        r["Type"]?.toString() ?? "",
        r["Description"]?.toString() ?? "",
        r["Payment_Mode"]?.toString() ?? "",
        amt,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(csvRows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/FinTrack_Ledger_${friendName.replaceAll(' ', '_')}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'FinTrack Friend Ledger for $friendName',
    );
  }

  static pw.Widget _buildSummaryBox(String label, String value, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}