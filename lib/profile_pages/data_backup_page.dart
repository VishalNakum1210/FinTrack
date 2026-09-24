import 'dart:convert';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/widgets/export_statement_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class _BackupMetric {
  final String label;
  final String value;
  const _BackupMetric(this.label, this.value);
}

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key});

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  bool _isExporting = false;

  void _handleJsonBackup() {
    final user = context.read<UserProvider>();
    final expenses = context.read<ExpenseProvider>().records;
    final friends = context.read<FriendProvider>().friends;

    if (expenses.isEmpty && friends.isEmpty) {
      Fluttertoast.showToast(msg: "No financial records found to backup");
      return;
    }

    try {
      final userName = user.name.isNotEmpty ? user.name : "User";
      final phoneNumber = user.phoneNumber;
      final jsonString = ExportService.generateJsonBackupString(
        userName: userName,
        phoneNumber: phoneNumber,
        expenses: expenses,
        friends: friends,
      );

      final sizeKb = (utf8.encode(jsonString).length / 1024).toStringAsFixed(1);

      _showBackupActionModal(
        title: "JSON Cloud Backup",
        badge: "Google Drive Ready",
        badgeBg: const Color(0xFFEFF6FF),
        badgeColor: const Color(0xFF2563EB),
        metrics: [
          _BackupMetric("Synced Expenses", "${expenses.length}"),
          _BackupMetric("Friend Ledgers", "${friends.length}"),
          _BackupMetric("File Size", "$sizeKb KB"),
        ],
        shareLabel: "Save to Google Drive / Share File",
        shareIcon: Icons.add_to_drive_rounded,
        onShare: () async {
          Navigator.pop(context);
          setState(() => _isExporting = true);
          try {
            await ExportService.exportJsonBackup(
              userName: userName,
              phoneNumber: phoneNumber,
              expenses: expenses,
              friends: friends,
            );
            Fluttertoast.showToast(msg: "Select 'Save to Drive' to save to Google Drive");
          } catch (e) {
            Fluttertoast.showToast(msg: "Share failed: $e");
          } finally {
            if (mounted) setState(() => _isExporting = false);
          }
        },
        onCopy: () async {
          Navigator.pop(context);
          await Clipboard.setData(ClipboardData(text: jsonString));
          Fluttertoast.showToast(msg: "JSON Backup copied to clipboard!");
        },
        rawContent: jsonString,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Backup generation failed: $e");
    }
  }

  void _handleCsvExport() {
    final expenses = context.read<ExpenseProvider>().records;
    if (expenses.isEmpty) {
      Fluttertoast.showToast(msg: "No transactions to export");
      return;
    }

    try {
      final csvString = ExportService.generateCsvString(expenses: expenses);
      final sizeKb = (utf8.encode(csvString).length / 1024).toStringAsFixed(1);

      _showBackupActionModal(
        title: "Excel / CSV Spreadsheet",
        badge: "Sheets & Excel Ready",
        badgeBg: const Color(0xFFF0FDF4),
        badgeColor: const Color(0xFF16A34A),
        metrics: [
          _BackupMetric("Transactions", "${expenses.length}"),
          const _BackupMetric("Columns", "6 Columns"),
          _BackupMetric("File Size", "$sizeKb KB"),
        ],
        shareLabel: "Save to Google Drive / Share CSV",
        shareIcon: Icons.add_to_drive_rounded,
        onShare: () async {
          Navigator.pop(context);
          setState(() => _isExporting = true);
          try {
            await ExportService.exportCsvSpreadsheet(expenses: expenses);
            Fluttertoast.showToast(msg: "Select 'Save to Drive' to save to Google Drive");
          } catch (e) {
            Fluttertoast.showToast(msg: "CSV export failed: $e");
          } finally {
            if (mounted) setState(() => _isExporting = false);
          }
        },
        onCopy: () async {
          Navigator.pop(context);
          await Clipboard.setData(ClipboardData(text: csvString));
          Fluttertoast.showToast(msg: "CSV Spreadsheet copied to clipboard!");
        },
        rawContent: csvString,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "CSV export failed: $e");
    }
  }

  void _handlePdfStatement() {
    final user = context.read<UserProvider>();
    final expenses = context.read<ExpenseProvider>().records;

    if (expenses.isEmpty) {
      Fluttertoast.showToast(msg: "No transactions to export");
      return;
    }

    showExportStatementModal(
      context: context,
      userName: user.name.isNotEmpty ? user.name : "User",
      phoneNumber: user.phoneNumber,
      records: expenses,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseCount = context.watch<ExpenseProvider>().records.length;
    final friendCount = context.watch<FriendProvider>().friends.length;
    final isOffline = context.watch<FriendProvider>().isOffline;

    return Scaffold(
      backgroundColor: _canvasBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Curved Header
            _buildHeader(),

            // 2. Content
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Cloud Status Card
                    _buildCloudStatusCard(
                      expenseCount: expenseCount,
                      friendCount: friendCount,
                      isOffline: isOffline,
                    ),

                    const SizedBox(height: 16),

                    // Export Cards
                    _buildBackupCard(
                      icon: Icons.code_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: "Full JSON Cloud Backup",
                      subtitle:
                          "Archive all expenses and friend ledgers directly to Google Drive ('Save to Drive'), WhatsApp, or device storage.",
                      actionLabel: "Export JSON Backup",
                      onPressed: _isExporting ? null : _handleJsonBackup,
                    ),

                    const SizedBox(height: 12),

                    _buildBackupCard(
                      icon: Icons.table_chart_rounded,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      title: "Excel / CSV Spreadsheet",
                      subtitle:
                          "Save tabular transactions directly to Google Drive, Google Sheets, or open in Microsoft Excel.",
                      actionLabel: "Export CSV Sheet",
                      onPressed: _isExporting ? null : _handleCsvExport,
                    ),

                    const SizedBox(height: 12),

                    _buildBackupCard(
                      icon: Icons.picture_as_pdf_rounded,
                      iconBg: const Color(0xFFFEF2F2),
                      iconColor: const Color(0xFFDC2626),
                      title: "Official PDF Statement",
                      subtitle:
                          "Audit-ready multi-page statement with category breakdowns, monthly groupings, and summary analytics.",
                      actionLabel: "Generate PDF Statement",
                      onPressed: _isExporting ? null : _handlePdfStatement,
                    ),

                    const SizedBox(height: 20),

                    // Privacy Note
                    _buildSecurityNote(),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER
  // ===========================================================================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _darkGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cloud Backup & Export",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Safeguard, download & export your data",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. CLOUD STATUS CARD
  // ===========================================================================
  Widget _buildCloudStatusCard({
    required int expenseCount,
    required int friendCount,
    required bool isOffline,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOffline ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOffline ? "Cloud Sync Paused (Offline)" : "Cloud Sync Active",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isOffline ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Firebase RTDB",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _borderGrey),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: "Synced Expenses",
                  value: "$expenseCount",
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: _borderGrey),
              Expanded(
                child: _buildMetricTile(
                  label: "Friend Ledgers",
                  value: "$friendCount",
                  icon: Icons.people_alt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _darkGreen),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. BACKUP ACTION CARD
  // ===========================================================================
  Widget _buildBackupCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: _textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SECURITY NOTE
  // ===========================================================================
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: _textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Your backups contain your private financial data. Store shared files in a secure location.",
              style: TextStyle(
                fontSize: 11.5,
                color: _textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. BACKUP ACTIONS MODAL & PREVIEW
  // ===========================================================================
  void _showBackupActionModal({
    required String title,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    required List<_BackupMetric> metrics,
    required String shareLabel,
    required IconData shareIcon,
    required VoidCallback onShare,
    required VoidCallback onCopy,
    required String rawContent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Export your financial records securely. You can share the file, copy data to clipboard, or preview it directly.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: _textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Metrics container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderGrey),
                ),
                child: Row(
                  children: metrics.asMap().entries.map((entry) {
                    final index = entry.key;
                    final m = entry.value;
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: index < metrics.length - 1
                              ? const Border(right: BorderSide(color: _borderGrey))
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              m.value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Google Drive Tip Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_to_drive_rounded, size: 20, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tip: Tap below and select 'Save to Drive' to save directly to your Google Drive.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Primary Share Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: Icon(shareIcon, size: 18),
                  label: Text(
                    shareLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: badgeColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Secondary Copy to Clipboard Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    "Copy to Clipboard",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textDark,
                    side: const BorderSide(color: _borderGrey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tertiary Preview Button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPreviewDialog(title, rawContent);
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 16, color: _textMuted),
                  label: const Text(
                    "Preview Data",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreviewDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, size: 20, color: _darkGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "$title Preview",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF86EFAC),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              Fluttertoast.showToast(msg: "Copied to clipboard!");
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text("Copy All"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
