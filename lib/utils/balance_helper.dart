import 'package:fin_track/utils/date_helper.dart';

/// Helper to compute running balances across financial transactions.
class BalanceHelper {
  /// Computes cumulative running balance for a list of transaction records.
  /// Records are sorted chronologically (oldest to newest) and each record map
  /// has '_runningBalance' populated.
  /// Returns the chronologically sorted list with running balances.
  static List<Map<String, dynamic>> computeRunningBalances(
    List<Map<String, dynamic>> records,
  ) {
    if (records.isEmpty) return [];

    final chronological = List<Map<String, dynamic>>.from(records);
    chronological.sort((a, b) {
      final DateTime? dateA =
          (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
      final DateTime? dateB =
          (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);
      int cmp = 0;
      if (dateA != null && dateB != null) {
        cmp = dateA.compareTo(dateB);
      } else if (dateA != null) {
        cmp = -1;
      } else if (dateB != null) {
        cmp = 1;
      }
      if (cmp != 0) return cmp;
      final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
      final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
      return tA.compareTo(tB);
    });

    double running = 0.0;
    for (final item in chronological) {
      final method = (item["Payment_Mode"] ?? "").toString();
      final isIncome = ["Add CASH", "Add Online"].contains(method);
      final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
      if (isIncome) {
        running += amt;
      } else {
        running -= amt;
      }
      item["_runningBalance"] = running;
    }

    return chronological;
  }
}
