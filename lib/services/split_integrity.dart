import 'package:firebase_database/firebase_database.dart';

/// Internal links only: no new user-facing bill management workflow.
class SplitIntegrity {
  static String operationId(String key) {
    final branch = RegExp(r'^(.{20})_(?:expense_|debt_)?\d+$').firstMatch(key);
    return branch?.group(1) ?? key;
  }

  static List<String> linkedPaths(
    String phone,
    String key,
    Map expenses,
    Map friends, {
    String? splitId,
  }) {
    final id = splitId ?? operationId(key);
    final paths = <String>[];
    bool matches(dynamic recordKey, dynamic record) =>
        record is Map &&
        (record['split_id'] == id ||
            recordKey == id ||
            recordKey.toString().startsWith('${id}_expense_') ||
            recordKey.toString().startsWith('${id}_debt_') ||
            RegExp(
              '^${RegExp.escape(id)}_\\d+\$',
            ).hasMatch(recordKey.toString()));
    for (final entry in expenses.entries) {
      if (matches(entry.key, entry.value)) {
        paths.add('Expenses/$phone/${entry.key}');
      }
    }
    for (final friend in friends.entries) {
      if (friend.value is! Map) continue;
      final records = (friend.value as Map)['Records'];
      if (records is! Map) continue;
      for (final entry in records.entries) {
        if (matches(entry.key, entry.value)) {
          paths.add('Friends/$phone/${friend.key}/Records/${entry.key}');
        }
      }
    }
    // A standalone record is not a split, even when its key is a push key.
    return splitId != null || paths.length > 1 || operationId(key) != key
        ? paths
        : [];
  }

  static Future<List<String>> load(
    String phone,
    String key, {
    String? splitId,
  }) async {
    final snapshots = await Future.wait([
      FirebaseDatabase.instance.ref('Expenses/$phone').get(),
      FirebaseDatabase.instance.ref('Friends/$phone').get(),
    ]).timeout(const Duration(seconds: 15));
    return linkedPaths(
      phone,
      key,
      snapshots[0].value is Map ? snapshots[0].value as Map : {},
      snapshots[1].value is Map ? snapshots[1].value as Map : {},
      splitId: splitId,
    );
  }
}
