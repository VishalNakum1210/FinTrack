import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fin_track/utils/date_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  // Theme Colors for PDF
  static final PdfColor _primaryGreen = PdfColor.fromHex('8BC24A');
  static final PdfColor _darkGreen = PdfColor.fromHex('33691E');
  static final PdfColor _headerBg = PdfColor.fromHex('2E7D32');
  static final PdfColor _lightGrey = PdfColor.fromHex('F5F7FA');
  static final PdfColor _borderGrey = PdfColor.fromHex('E0E0E0');
  static final PdfColor _incomeColor = PdfColor.fromHex('2E7D32');
  static final PdfColor _expenseColor = PdfColor.fromHex('C62828');

  /// Safely loads the FinTrack application logo for PDF rendering
  static Future<pw.ImageProvider?> _loadAppLogo() async {
    try {
      return await imageFromAssetBundle('assets/image/AccountApplicationLogo.jpg');
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/image/AccountApplicationLogo.jpg');
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  // ===========================================================================
  // ===========================================================================
  // 1. PASSBOOK STATEMENT EXPORT (PDF)
  // ===========================================================================
  static Future<void> exportPassbookPdf({
    required String userName,
    required String phoneNumber,
    required List<Map<String, dynamic>> records,
    required int totalIncome,
    required int totalExpense,
    required int currentBalance,
    required int addCash,
    required int spentCash,
    required int addOnline,
    required int spentOnline,
    String filterCategory = "All",
    DateTime? startDate,
    DateTime? endDate,
    bool includeCategoryBreakdown = true,
    bool includeRunningBalance = true,
    bool isShare = false,
    String? statementId,
  }) async {
    final pdf = pw.Document();
    final cashBalance = addCash - spentCash;
    final onlineBalance = addOnline - spentOnline;
    final effectiveStatementId = statementId ??
        "FT-${DateFormat('yyyyMMdd').format(DateTime.now())}-${(records.length * 79 + 101).toString().padLeft(4, '0')}";
    final periodStr = (startDate != null && endDate != null)
        ? "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}"
        : "All-Time Statement";

    // Compute running balance chronologically if requested
    if (includeRunningBalance && records.isNotEmpty) {
      final chronoList = List<Map<String, dynamic>>.from(records);
      chronoList.sort((a, b) {
        final dA = (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
        final dB = (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);
        if (dA != null && dB != null) {
          final c = dA.compareTo(dB);
          if (c != 0) return c;
        } else if (dA != null) {
          return -1;
        } else if (dB != null) {
          return 1;
        }
        final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
        final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
        return tA.compareTo(tB);
      });

      double bal = 0.0;
      for (final r in chronoList) {
        final mode = (r["Payment_Mode"] ?? "").toString();
        final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
        if (mode == "Add CASH" || mode == "Add Online") {
          bal += amt;
        } else {
          bal -= amt;
        }
        r["_pdfRunningBalance"] = bal;
      }
    }

    // Category breakdown totals
    final Map<String, double> catTotals = {};
    if (includeCategoryBreakdown) {
      for (final r in records) {
        final mode = (r["Payment_Mode"] ?? "").toString();
        final isIncome = mode == "Add CASH" || mode == "Add Online";
        if (!isIncome) {
          final cat = (r["Category"] ?? "General").toString();
          final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
          catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;
        }
      }
    }

    final logoImage = await _loadAppLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildPdfHeader("Official Financial Statement", logoImage: logoImage),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          return [
            // User & Filter Info
            _buildMetaInfoBox(
              userName: userName,
              phoneNumber: phoneNumber,
              filter: filterCategory,
              recordCount: records.length,
              statementId: effectiveStatementId,
              period: periodStr,
            ),
            pw.SizedBox(height: 12),

            // Section 1: Executive Financial Summary (3-Stat Grid)
            pw.Text(
              "Executive Financial Summary",
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen),
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                _buildStatBox("Total Credits (Inflow)", "+${_currencyFormatter.format(totalIncome)}", _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Total Debits (Outflow)", "-${_currencyFormatter.format(totalExpense)}", _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox(
                  "Closing Balance",
                  _currencyFormatter.format(currentBalance),
                  currentBalance >= 0 ? _darkGreen : _expenseColor,
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Section 2: Cash vs Online Breakdown
            pw.Text(
              "Cash & Online Account Breakdown",
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen),
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                _buildStatBox("Cash Added", _currencyFormatter.format(addCash), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Cash Expense", _currencyFormatter.format(spentCash), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Cash Balance", _currencyFormatter.format(cashBalance), cashBalance >= 0 ? PdfColors.orange900 : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _buildStatBox("Online Added", _currencyFormatter.format(addOnline), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Online Expense", _currencyFormatter.format(spentOnline), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Online Balance", _currencyFormatter.format(onlineBalance), onlineBalance >= 0 ? PdfColors.blue900 : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 14),

            // Optional Section 3: Category Summary Breakdown
            if (includeCategoryBreakdown && catTotals.isNotEmpty) ...[
              pw.Text(
                "Category Spending Distribution",
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Total Outflow', 'Share (%)'],
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: pw.BoxDecoration(color: _headerBg),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
                oddRowDecoration: pw.BoxDecoration(color: _lightGrey),
                data: (catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                    .take(8)
                    .map((e) {
                  final pct = totalExpense > 0 ? ((e.value / totalExpense) * 100).toStringAsFixed(1) : "0.0";
                  return [
                    _cleanPdfText(e.key, defaultVal: "General"),
                    _currencyFormatter.format(e.value),
                    "$pct %",
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 14),
            ],

            // Monthly Grouped Transaction Tables with Month Totals
            ..._buildMonthlyTransactionTables(records, includeRunningBalance: includeRunningBalance),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName = 'FinTrack_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    if (isShare) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    }
  }

  // ===========================================================================
  // 2. INDIVIDUAL FRIEND LEDGER EXPORT (PDF)
  // ===========================================================================
  static Future<void> exportFriendLedgerPdf({
    required String userName,
    required String friendName,
    required String friendNumber,
    required int totalGet,
    required int totalGive,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();
    final netDue = totalGet - totalGive;

    final logoImage = await _loadAppLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildPdfHeader("Friend Ledger Statement", logoImage: logoImage),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          return [
            // Ledger Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _lightGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _borderGrey),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Account: ${_cleanPdfText(userName, defaultVal: 'User')}", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 2),
                      pw.Text("Friend: ${_cleanPdfText(friendName, defaultVal: 'Friend')} (${_cleanPdfText(friendNumber, defaultVal: '')})", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Status: ${netDue >= 0 ? 'You will receive' : 'You will pay'}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: netDue >= 0 ? _incomeColor : _expenseColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _currencyFormatter.format(netDue.abs()),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: netDue >= 0 ? _incomeColor : _expenseColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Summary row
            pw.Row(
              children: [
                _buildStatBox("Money You Get", _currencyFormatter.format(totalGet), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Money You Give", _currencyFormatter.format(totalGive), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Net Balance", _currencyFormatter.format(netDue), netDue >= 0 ? _darkGreen : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              "Transaction History (${records.length})",
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _darkGreen),
            ),
            pw.SizedBox(height: 8),

            if (records.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text("No ledger transactions found with ${_cleanPdfText(friendName, defaultVal: 'Friend')}.", style: const pw.TextStyle(color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Date', 'Type', 'Description', 'Mode', 'Amount'],
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: pw.BoxDecoration(color: _headerBg),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
                oddRowDecoration: pw.BoxDecoration(color: _lightGrey),
                data: List<List<dynamic>>.generate(records.length, (index) {
                  final r = records[index];
                  final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
                  final type = r["Type"]?.toString() ?? "-";

                  return [
                    (index + 1).toString(),
                    _cleanPdfText(r["Date"]),
                    _cleanPdfText(type),
                    _cleanPdfText(r["Description"], maxLength: 80),
                    _cleanPdfText(r["Payment_Mode"]),
                    _currencyFormatter.format(amt),
                  ];
                }),
              ),
          ];
        },
      ),
    );

    final cleanFileName = _cleanPdfText(friendName, defaultVal: 'Friend').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'FinTrack_Ledger_$cleanFileName.pdf',
    );
  }

  // ===========================================================================
  // 3. ALL FRIENDS SUMMARY EXPORT (PDF)
  // ===========================================================================
  static Future<void> exportAllFriendsPdf({
    required String userName,
    required List<Map<String, dynamic>> friends,
    required int totalGet,
    required int totalGive,
  }) async {
    final pdf = pw.Document();
    final netDue = totalGet - totalGive;

    final logoImage = await _loadAppLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildPdfHeader("Friends Ledger Summary", logoImage: logoImage),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          return [
            // User Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _lightGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _borderGrey),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Account: ${_cleanPdfText(userName, defaultVal: 'User')}", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text("Total Friends: ${friends.length}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Net Ledger Balance: ${_currencyFormatter.format(netDue)}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: netDue >= 0 ? _incomeColor : _expenseColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Summary row
            pw.Row(
              children: [
                _buildStatBox("Total To Receive", _currencyFormatter.format(totalGet), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Total To Pay", _currencyFormatter.format(totalGive), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Net Settlement", _currencyFormatter.format(netDue), netDue >= 0 ? _darkGreen : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              "Friends Breakdown (${friends.length})",
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _darkGreen),
            ),
            pw.SizedBox(height: 8),

            if (friends.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text("No friends currently added to your ledger.", style: const pw.TextStyle(color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Friend Name', 'Phone Number', 'To Receive', 'To Pay', 'Net Due'],
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: pw.BoxDecoration(color: _headerBg),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
                oddRowDecoration: pw.BoxDecoration(color: _lightGrey),
                data: List<List<dynamic>>.generate(friends.length, (index) {
                  final f = friends[index];
                  final fGet = (double.tryParse(f["total_get"]?.toString() ?? '0') ?? 0.0).round();
                  final fGive = (double.tryParse(f["total_give"]?.toString() ?? '0') ?? 0.0).round();
                  final diff = fGet - fGive;

                  return [
                    (index + 1).toString(),
                    _cleanPdfText(f["friend_name"], defaultVal: 'Friend'),
                    _cleanPdfText(f["friend_number"], defaultVal: '-'),
                    _currencyFormatter.format(fGet),
                    _currencyFormatter.format(fGive),
                    "${diff >= 0 ? '+' : '-'}${_currencyFormatter.format(diff.abs())}",
                  ];
                }),
              ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'FinTrack_All_Friends_Summary.pdf',
    );
  }

  // ===========================================================================
  // 4. FINANCIAL REPORT STATEMENT (PDF)
  // ===========================================================================
  static Future<void> exportReportPdf({
    required String userName,
    required String phoneNumber,
    required int totalIncome,
    required int totalExpense,
    required int currentBalance,
    required int addCash,
    required int spentCash,
    required int addOnline,
    required int spentOnline,
    required int friendGet,
    required int friendGive,
    required Map<String, double> categoryTotals,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();
    final cashBalance = addCash - spentCash;
    final onlineBalance = addOnline - spentOnline;

    final logoImage = await _loadAppLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildPdfHeader("Comprehensive Financial Report", logoImage: logoImage),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          final savingsRate = totalIncome > 0 ? (((totalIncome - totalExpense) / totalIncome) * 100).clamp(0, 100).toStringAsFixed(1) : "0.0";

          return [
            // User info
            _buildMetaInfoBox(
              userName: userName,
              phoneNumber: phoneNumber,
              filter: "Full Financial Overview",
              recordCount: records.length,
            ),
            pw.SizedBox(height: 12),

            // Section 1: Key KPI Stats
            pw.Text("Overall Finances", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen)),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                _buildStatBox("Total Income", _currencyFormatter.format(totalIncome), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Total Expense", _currencyFormatter.format(totalExpense), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Net Savings ($savingsRate%)", _currencyFormatter.format(currentBalance), currentBalance >= 0 ? _darkGreen : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 10),

            // Section 2: Cash Account
            pw.Text("Cash Account Overview", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen)),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                _buildStatBox("Cash Added", _currencyFormatter.format(addCash), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Cash Expense", _currencyFormatter.format(spentCash), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Cash Balance", _currencyFormatter.format(cashBalance), cashBalance >= 0 ? PdfColors.orange900 : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 10),

            // Section 3: Online Account & Friends
            pw.Text("Online Account & Friend Dues", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _darkGreen)),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                _buildStatBox("Online Added", _currencyFormatter.format(addOnline), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Online Expense", _currencyFormatter.format(spentOnline), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Online Balance", _currencyFormatter.format(onlineBalance), onlineBalance >= 0 ? PdfColors.blue900 : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _buildStatBox("Friend Money To Get", _currencyFormatter.format(friendGet), _incomeColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Friend Money To Give", _currencyFormatter.format(friendGive), _expenseColor),
                pw.SizedBox(width: 8),
                _buildStatBox("Friend Net Balance", _currencyFormatter.format(friendGet - friendGive), (friendGet - friendGive) >= 0 ? _incomeColor : _expenseColor),
              ],
            ),
            pw.SizedBox(height: 18),

            // Category Spending Breakdown
            pw.Text("Top Expense Categories", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _darkGreen)),
            pw.SizedBox(height: 6),
            if (categoryTotals.isEmpty)
              pw.Text("No category expense data available.", style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Amount (INR)', 'Share of Total Expense'],
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: pw.BoxDecoration(color: _headerBg),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                oddRowDecoration: pw.BoxDecoration(color: _lightGrey),
                data: categoryTotals.entries.map((e) {
                  final pct = totalExpense > 0 ? ((e.value / totalExpense) * 100).toStringAsFixed(1) : "0.0";
                  return [
                    _cleanPdfText(e.key, defaultVal: "General"),
                    _currencyFormatter.format(e.value),
                    "$pct %",
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 18),

            // Monthly Grouped Transaction Tables with Month Totals
            ..._buildMonthlyTransactionTables(records),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'FinTrack_Financial_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ===========================================================================
  // MONTHLY GROUPING & MONTH TOTAL BUILDERS
  // ===========================================================================
  static Map<String, List<Map<String, dynamic>>> _groupByMonth(List<Map<String, dynamic>> records) {
    final Map<int, Map<String, dynamic>> sortedMonthMap = {};
    final List<Map<String, dynamic>> unparsedRecords = [];

    for (var r in records) {
      final parsed = DateHelper.parse(r["Date"]);
      if (parsed != null) {
        final sortKey = parsed.year * 100 + parsed.month;
        final displayName = DateFormat('MMMM yyyy').format(parsed);

        if (!sortedMonthMap.containsKey(sortKey)) {
          sortedMonthMap[sortKey] = {
            "name": displayName,
            "records": <Map<String, dynamic>>[],
          };
        }
        (sortedMonthMap[sortKey]!["records"] as List<Map<String, dynamic>>).add(r);
      } else {
        unparsedRecords.add(r);
      }
    }

    final sortedKeys = sortedMonthMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<String, List<Map<String, dynamic>>> result = {};

    for (var k in sortedKeys) {
      final name = sortedMonthMap[k]!["name"] as String;
      final list = sortedMonthMap[k]!["records"] as List<Map<String, dynamic>>;
      result[name] = list;
    }

    if (unparsedRecords.isNotEmpty) {
      result["Other Transactions"] = unparsedRecords;
    }

    return result;
  }

  static List<pw.Widget> _buildMonthlyTransactionTables(
    List<Map<String, dynamic>> records, {
    bool includeRunningBalance = false,
  }) {
    if (records.isEmpty) {
      return [
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          alignment: pw.Alignment.center,
          child: pw.Text("No transactions found for this period.", style: const pw.TextStyle(color: PdfColors.grey600)),
        ),
      ];
    }

    final monthlyGroups = _groupByMonth(records);
    final List<pw.Widget> widgets = [];
    int overallIndex = 1;

    for (var entry in monthlyGroups.entries) {
      final monthName = entry.key;
      final mRecords = entry.value;

      int mIncome = 0;
      int mExpense = 0;
      int mCashSpent = 0;
      int mOnlineSpent = 0;
      int mCashAdded = 0;
      int mOnlineAdded = 0;

      for (var r in mRecords) {
        final mode = (r["Payment_Mode"] ?? "").toString();
        final amt = (double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0).round();
        if (mode == "Add CASH") {
          mIncome += amt;
          mCashAdded += amt;
        } else if (mode == "Add Online") {
          mIncome += amt;
          mOnlineAdded += amt;
        } else if (mode == "Spent Cash") {
          mExpense += amt;
          mCashSpent += amt;
        } else if (mode == "Spent Online") {
          mExpense += amt;
          mOnlineSpent += amt;
        } else {
          mExpense += amt;
        }
      }

      final mNet = mIncome - mExpense;

      // 1. Month Header Banner
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _darkGreen,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                monthName,
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
              pw.Text(
                "${mRecords.length} Transactions",
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
              ),
            ],
          ),
        ),
      );

      // 2. Month Records Table
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: includeRunningBalance
              ? ['#', 'Date', 'Category', 'Description', 'Mode', 'Debit (-)', 'Credit (+)', 'Balance']
              : ['#', 'Date', 'Category', 'Description', 'Payment Mode', 'Amount'],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
          headerDecoration: pw.BoxDecoration(color: _headerBg),
          columnWidths: includeRunningBalance
              ? {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(55),
                  5: const pw.FixedColumnWidth(55),
                  6: const pw.FixedColumnWidth(55),
                  7: const pw.FixedColumnWidth(55),
                }
              : {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FixedColumnWidth(62),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(75),
                  5: const pw.FixedColumnWidth(75),
                },
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
          ),
          oddRowDecoration: pw.BoxDecoration(color: _lightGrey),
          data: List<List<dynamic>>.generate(mRecords.length, (i) {
            final item = mRecords[i];
            final mode = item["Payment_Mode"]?.toString() ?? "";
            final isIncome = mode == "Add CASH" || mode == "Add Online";
            final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;

            if (includeRunningBalance) {
              final debitStr = isIncome ? "-" : "-${_currencyFormatter.format(amt)}";
              final creditStr = isIncome ? "+${_currencyFormatter.format(amt)}" : "-";
              final runBal = item["_pdfRunningBalance"] as double?;
              final balStr = runBal != null ? _currencyFormatter.format(runBal) : "-";

              return [
                (overallIndex++).toString(),
                _cleanPdfText(item["Date"]),
                _cleanPdfText(item["Category"], defaultVal: "General"),
                _cleanPdfText(item["Description"], maxLength: 80),
                _cleanPdfText(mode.isEmpty ? "-" : mode),
                debitStr,
                creditStr,
                balStr,
              ];
            } else {
              final formattedAmt = "${isIncome ? '+' : '-'}${_currencyFormatter.format(amt)}";
              return [
                (overallIndex++).toString(),
                _cleanPdfText(item["Date"]),
                _cleanPdfText(item["Category"], defaultVal: "General"),
                _cleanPdfText(item["Description"], maxLength: 80),
                _cleanPdfText(mode.isEmpty ? "-" : mode),
                formattedAmt,
              ];
            }
          }),
        ),
      );

      // 3. Month Total Footer Box (Clean, Structured Responsive Card)
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _lightGrey,
            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(4)),
            border: pw.Border.all(color: _borderGrey, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Title & Net Balance
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "$monthName Monthly Summary",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkGreen),
                  ),
                  pw.Text(
                    "Month Net: ${mNet >= 0 ? '+' : '-'}${_currencyFormatter.format(mNet.abs())}",
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: mNet >= 0 ? _darkGreen : _expenseColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(color: _borderGrey, thickness: 0.5),
              pw.SizedBox(height: 4),

              // Bottom 3 Stat Columns
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Income Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Total Income", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          "+${_currencyFormatter.format(mIncome)}",
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _incomeColor),
                        ),
                        pw.Text("Cash: ${_currencyFormatter.format(mCashAdded)} | Online: ${_currencyFormatter.format(mOnlineAdded)}", style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Expense Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Total Expense", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          "-${_currencyFormatter.format(mExpense)}",
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _expenseColor),
                        ),
                        pw.Text("Cash: ${_currencyFormatter.format(mCashSpent)} | Online: ${_currencyFormatter.format(mOnlineSpent)}", style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Net Savings Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Month Savings", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          "${mNet >= 0 ? '+' : '-'}${_currencyFormatter.format(mNet.abs())}",
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: mNet >= 0 ? _darkGreen : _expenseColor,
                          ),
                        ),
                        pw.Text(
                          mIncome > 0 ? "${((mNet / mIncome) * 100).clamp(0, 100).toStringAsFixed(1)}% saved" : "0.0% saved",
                          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  // ===========================================================================
  // SHARED REUSABLE PDF COMPONENTS
  // ===========================================================================
  static pw.Widget _buildPdfHeader(String subtitle, {pw.ImageProvider? logoImage}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 26,
                        height: 26,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: _borderGrey, width: 0.5),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(logoImage, width: 26, height: 26, fit: pw.BoxFit.cover),
                        ),
                      )
                    else
                      pw.Container(
                        width: 24,
                        height: 24,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          color: _primaryGreen,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          "F",
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    pw.Text(
                      "FinTrack",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGreen,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "Smart",
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                    ),
                    pw.Container(
                      width: 2.5,
                      height: 2.5,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 5),
                      decoration: pw.BoxDecoration(
                        color: _primaryGreen,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Text(
                      "Transparent",
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                    ),
                    pw.Container(
                      width: 2.5,
                      height: 2.5,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 5),
                      decoration: pw.BoxDecoration(
                        color: _primaryGreen,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Text(
                      "Personal Financial Intelligence",
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Generated On", style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                pw.Text(
                  _exportDateFormatter.format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _primaryGreen, thickness: 1.5),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                "FinTrack",
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                width: 2.5,
                height: 2.5,
                margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                decoration: const pw.BoxDecoration(color: PdfColors.grey500, shape: pw.BoxShape.circle),
              ),
              pw.Text(
                "Personal Finance & Expense Intelligence",
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Text(
            "This is a computer-generated statement and requires no signature.",
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaInfoBox({
    required String userName,
    required String phoneNumber,
    required String filter,
    required int recordCount,
    String? statementId,
    String? period,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderGrey),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Account Holder: ${_cleanPdfText(userName, defaultVal: 'User')}",
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5),
              ),
              if (phoneNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  "Phone: ${_cleanPdfText(phoneNumber, defaultVal: '')}",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                "Filter Scope: ${_cleanPdfText(filter, defaultVal: 'All')}",
                style: pw.TextStyle(fontSize: 8.5, color: _darkGreen, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (statementId != null && statementId.isNotEmpty) ...[
                pw.Text(
                  "Ref ID: $statementId",
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.black),
                ),
                pw.SizedBox(height: 2),
              ],
              if (period != null && period.isNotEmpty) ...[
                pw.Text(
                  "Period: $period",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 2),
              ],
              pw.Text(
                "Total Records: $recordCount",
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderGrey),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMOJI & SPECIAL UNICODE SANITIZER (Prevents Missing Font Glyph Crashes)
  // ===========================================================================
  static String _cleanPdfText(dynamic value, {String defaultVal = "-", int? maxLength}) {
    if (value == null) return defaultVal;
    String str = value.toString();
    if (str.trim().isEmpty) return defaultVal;

    // Replace Rupee symbol with standard Rs.
    str = str.replaceAll('₹', 'Rs. ');

    // Replace bullet symbols with standard ASCII hyphen
    str = str.replaceAll('•', '-');

    // Strip out all emojis, surrogate pairs, and non-printable Unicode symbols
    // that standard PDF Type1 core fonts cannot render
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final codeUnit = str.codeUnitAt(i);

      // Check for surrogate pairs (emojis like 👟 U+1F45F, 🍷 U+1F377)
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
        if (i + 1 < str.length && str.codeUnitAt(i + 1) >= 0xDC00 && str.codeUnitAt(i + 1) <= 0xDFFF) {
          i++; // skip low surrogate
        }
        continue;
      } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
        continue;
      }

      // Allow ASCII printable (32 to 126), newline (10), tab (9), and standard Latin-1 (160 to 255)
      if ((codeUnit >= 32 && codeUnit <= 126) ||
          (codeUnit >= 160 && codeUnit <= 255) ||
          codeUnit == 10 ||
          codeUnit == 9) {
        buffer.writeCharCode(codeUnit);
      } else {
        buffer.write(' ');
      }
    }

    final cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return defaultVal;
    if (maxLength != null && cleaned.length > maxLength) {
      return "${cleaned.substring(0, maxLength - 3)}...";
    }
    return cleaned;
  }

  // ===========================================================================
  // 3. FULL JSON DATA BACKUP EXPORT
  // ===========================================================================

  /// Recursively cleans data structures to ensure everything is JSON encodable.
  /// Converts DateTime objects into ISO 8601 strings and non-primitive objects to string.
  static dynamic sanitizeForJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      final cleanMap = <String, dynamic>{};
      value.forEach((k, v) {
        cleanMap[k.toString()] = sanitizeForJson(v);
      });
      return cleanMap;
    }
    if (value is Iterable) {
      return value.map((item) => sanitizeForJson(item)).toList();
    }
    return value.toString();
  }

  /// Builds the complete FinTrack JSON backup data dictionary
  static Map<String, dynamic> buildBackupData({
    required String userName,
    required String phoneNumber,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> friends,
  }) {
    return {
      "app": "FinTrack",
      "version": "2.2.0",
      "exported_at": DateTime.now().toIso8601String(),
      "user": {
        "name": userName,
        "phone_number": phoneNumber,
      },
      "total_expenses_count": expenses.length,
      "total_friends_count": friends.length,
      "expenses": expenses.map((e) => sanitizeForJson(e)).toList(),
      "friends": friends.map((f) => sanitizeForJson(f)).toList(),
    };
  }

  /// Generates a formatted JSON string for backup export, guaranteed not to throw on complex types
  static String generateJsonBackupString({
    required String userName,
    required String phoneNumber,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> friends,
  }) {
    final exportData = buildBackupData(
      userName: userName,
      phoneNumber: phoneNumber,
      expenses: expenses,
      friends: friends,
    );

    final encoder = JsonEncoder.withIndent('  ', (nonEncodable) {
      if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
      return nonEncodable.toString();
    });

    return encoder.convert(exportData);
  }

  /// Exports the full JSON backup by writing to a temporary file and invoking the system share sheet.
  static Future<void> exportJsonBackup({
    required String userName,
    required String phoneNumber,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> friends,
  }) async {
    final jsonString = generateJsonBackupString(
      userName: userName,
      phoneNumber: phoneNumber,
      expenses: expenses,
      friends: friends,
    );
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final fileName = 'FinTrack_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: 'FinTrack Full Financial Backup',
        text: 'FinTrack personal data backup archive (JSON format).',
      ),
    );
  }

  // ===========================================================================
  // 4. CSV SPREADSHEET EXPORT
  // ===========================================================================

  /// Generates tabular CSV string from expense records
  static String generateCsvString({
    required List<Map<String, dynamic>> expenses,
  }) {
    final buffer = StringBuffer();
    // CSV Header row
    buffer.writeln("Date,Category,Payment Mode,Amount,Description,Running Balance");

    for (final record in expenses) {
      final date = '"${(record["Date"] ?? "").toString().replaceAll('"', '""')}"';
      final category = '"${(record["Category"] ?? "").toString().replaceAll('"', '""')}"';
      final mode = '"${(record["Payment_Mode"] ?? "").toString().replaceAll('"', '""')}"';
      final amount = record["Amount"] ?? "0";
      final desc = '"${(record["Description"] ?? "").toString().replaceAll('"', '""')}"';
      final running = record["_runningBalance"]?.toString() ?? "";
      buffer.writeln("$date,$category,$mode,$amount,$desc,$running");
    }

    return buffer.toString();
  }

  /// Exports the CSV spreadsheet by writing to a temporary file and invoking the system share sheet.
  static Future<void> exportCsvSpreadsheet({
    required List<Map<String, dynamic>> expenses,
  }) async {
    final csvString = generateCsvString(expenses: expenses);
    final bytes = Uint8List.fromList(utf8.encode(csvString));
    final fileName = 'FinTrack_Transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: fileName)],
        subject: 'FinTrack CSV Transactions',
        text: 'FinTrack exported transactions spreadsheet (Excel/CSV compatible).',
      ),
    );
  }
}