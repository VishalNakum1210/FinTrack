import 'money.dart';
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

    final List<Map<String, dynamic>> chronological = [];
    for (final r in records) {
      final copy = Map<String, dynamic>.from(r);
      copy["_parsedDate"] =
          (r["_parsedDate"] as DateTime?) ?? DateHelper.parse(r["Date"]);
      chronological.add(copy);
    }

    chronological.sort((a, b) {
      final DateTime? dateA = a["_parsedDate"] as DateTime?;
      final DateTime? dateB = b["_parsedDate"] as DateTime?;
      if (dateA != null && dateB != null) {
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
      final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
      return tA.compareTo(tB);
    });

    int running = 0;
    for (final item in chronological) {
      final method = (item["Payment_Mode"] ?? "").toString();
      final isIncome = ["Add CASH", "Add Online"].contains(method);
      final rawAmt = item["Amount"];
      final int amt = Money.paise(rawAmt);
      if (isIncome) {
        running += amt;
      } else {
        running -= amt;
      }
      item["_runningBalance"] = running / 100;
    }

    return chronological;
  }
}
