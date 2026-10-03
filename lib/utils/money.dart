/// Exact monetary arithmetic in paise. Convert to rupees only at presentation
/// boundaries; database strings remain compatible with existing statements.
class Money {
  static const int maxPaise = 99999999999999;
  // Exact integer range shared by Dart native and JavaScript builds.
  static const int maxAggregatePaise = 9007199254740991;
  static final _decimalPattern = RegExp(r'^-?\d{1,12}(?:\.\d{1,2})?$');

  static int? tryPaise(dynamic value) => _parse(value, maxPaise, 12);

  static int? tryAggregatePaise(dynamic value) =>
      _parse(value, maxAggregatePaise, 14);

  static int _parseAggregate(dynamic value) =>
      tryAggregatePaise(value) ?? (throw RangeError('Invalid monetary total'));

  static int? _parse(dynamic value, int maximum, int digits) {
    if (value is num && !value.isFinite) return null;
    final String text;
    if (value is num) {
      text = value.toStringAsFixed(2);
    } else {
      text = value?.toString().replaceAll(',', '').trim() ?? '';
    }
    final pattern = digits == 12
        ? _decimalPattern
        : RegExp(r'^-?\d{1,14}(?:\.\d{1,2})?$');
    if (!pattern.hasMatch(text)) return null;
    final negative = text.startsWith('-');
    final parts = (negative ? text.substring(1) : text).split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    if (whole > maximum ~/ 100 ||
        (whole == maximum ~/ 100 && fraction > maximum % 100)) {
      return null;
    }
    final result = whole * 100 + fraction;
    return negative ? -result : result;
  }

  static int paise(dynamic value) => tryPaise(value) ?? 0;
  static double rupees(dynamic value) => paise(value) / 100;
  static String decimal(int paise) {
    final absolute = paise.abs();
    return '${paise < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  static bool positive(dynamic value) => (tryPaise(value) ?? 0) > 0;
  static int sumPaise(Iterable<dynamic> values) {
    final total = values.fold<BigInt>(
      BigInt.zero,
      (sum, value) => sum + BigInt.from(_parseAggregate(value)),
    );
    if (total.abs() > BigInt.from(maxAggregatePaise)) {
      throw RangeError('Monetary total exceeds the supported exact range');
    }
    return total.toInt();
  }

  static double sum(Iterable<dynamic> values) => sumPaise(values) / 100;

  static List<int> split(int totalPaise, int count) {
    if (totalPaise < 0 || count <= 0) throw ArgumentError('Invalid split');
    return List.generate(
      count,
      (i) => totalPaise ~/ count + (i < totalPaise % count ? 1 : 0),
    );
  }
}
