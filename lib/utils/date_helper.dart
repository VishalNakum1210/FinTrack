import 'package:intl/intl.dart';

/// Optimized, high-performance date parser and formatter for FinTrack.
/// Avoids throwing expensive FormatExceptions in tight loops/sorts.
class DateHelper {
  static final DateFormat _displayFormat = DateFormat('d MMM yyyy');
  static final DateFormat _statementFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _slashFormat = DateFormat('d/M/yyyy');
  static final DateFormat _dashFormat = DateFormat('d-M-yyyy');

  /// Efficiently parses date strings of various common formats without loop exceptions
  static DateTime? parse(dynamic dateVal) {
    if (dateVal == null) return null;
    final str = dateVal.toString().trim();
    if (str.isEmpty || str == "-") return null;

    // 1. Fast path: ISO-8601 (e.g. 2026-08-28, 2026-08-28T...)
    final iso = DateTime.tryParse(str);
    if (iso != null) return iso;

    // 2. Fast path: day/month/year (e.g. 28/8/2026 or 28/08/2026)
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null && y > 1900 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
      try {
        return _slashFormat.parse(str);
      } catch (_) {}
    }

    // 3. Fast path: day-month-year (e.g. 28-8-2026 or 28-08-2026)
    if (str.contains('-')) {
      final parts = str.split('-');
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          // If first part is 4-digit year
          if (p0 > 1900 && p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
            return DateTime(p0, p1, p2);
          }
          // If third part is 4-digit year (d-m-yyyy)
          if (p2 > 1900 && p1 >= 1 && p1 <= 12 && p0 >= 1 && p0 <= 31) {
            return DateTime(p2, p1, p0);
          }
        }
      }
      try {
        return _dashFormat.parse(str);
      } catch (_) {}
    }

    // 4. Fallback for text month formats (e.g. "28 Aug 2026")
    try {
      return DateFormat('d MMM yyyy').parse(str);
    } catch (_) {}

    return null;
  }

  /// Formats date for UI cards and list headers
  static String formatDisplay(dynamic dateVal) {
    if (dateVal == null) return "";
    final parsed = parse(dateVal);
    if (parsed != null) {
      return _displayFormat.format(parsed);
    }
    return dateVal.toString().trim();
  }

  /// Formats date for month-year group headers
  static String formatMonthYear(DateTime dt) {
    return _monthYearFormat.format(dt);
  }

  /// Formats date for PDF statement timestamp
  static String formatStatementDate(DateTime dt) {
    return _statementFormat.format(dt);
  }
}
