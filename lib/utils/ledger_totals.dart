import 'money.dart';

/// Records are the source of truth. Legacy total_get/total_give fields are
/// deliberately ignored, including when they disagree with the ledger.
class LedgerTotals {
  final int getPaise;
  final int givePaise;
  const LedgerTotals(this.getPaise, this.givePaise);
  double get totalGet => getPaise / 100;
  double get totalGive => givePaise / 100;

  factory LedgerTotals.fromRecords(Iterable<Map<String, dynamic>> records) {
    int get = 0, give = 0;
    for (final record in records) {
      final amount = Money.paise(record['Amount']);
      if (amount <= 0) continue;
      if (record['Type'] == 'Take Money From Friend') {
        give += amount;
      } else if (record['Type'] == 'Give Money To Friend') {
        get += amount;
      }
    }
    return LedgerTotals(get, give);
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> friend) {
    final raw = friend['Records'];
    final records = raw is Map
        ? raw.values.whereType<Map>().map((r) => Map<String, dynamic>.from(r))
        : <Map<String, dynamic>>[];
    final totals = LedgerTotals.fromRecords(records);
    return {
      ...friend,
      'total_get': totals.totalGet,
      'total_give': totals.totalGive,
      '_getPaise': totals.getPaise,
      '_givePaise': totals.givePaise,
    };
  }
}
