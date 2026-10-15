import 'dart:async';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in ['expenses', 'friends']) {
    test(
      '$kind cannot attach a listener after logout during cancellation',
      () async {
        final cancelling = Completer<void>();
        final first = StreamController<DatabaseEvent>(
          onCancel: () => cancelling.future,
        );
        final requested = <String>[];
        Stream<DatabaseEvent> events(String phone) {
          requested.add(phone);
          return first.stream;
        }

        final expenses = kind == 'expenses'
            ? ExpenseProvider(expenseEvents: events)
            : null;
        final friends = kind == 'friends'
            ? FriendProvider(friendEvents: events)
            : null;
        Future<void> fetch(String phone) =>
            expenses?.fetchExpenses(phone) ?? friends!.fetchFriends(phone);
        void clear() => expenses != null
            ? expenses.clearExpenses()
            : friends!.clearFriends();
        void dispose() =>
            expenses != null ? expenses.dispose() : friends!.dispose();
        addTearDown(() async {
          dispose();
          await first.close();
        });

        await fetch('9876543210');
        final replacing = fetch('9876543211');
        clear();
        cancelling.complete();
        await replacing;
        expect(requested, ['9876543210']);
        expect(expenses?.isLoading ?? friends!.isLoading, isFalse);
      },
    );

    test(
      '$kind cannot notify or subscribe after disposal during cancellation',
      () async {
        final cancelling = Completer<void>();
        final first = StreamController<DatabaseEvent>(
          onCancel: () => cancelling.future,
        );
        var subscriptions = 0;
        Stream<DatabaseEvent> events(String phone) {
          subscriptions++;
          return first.stream;
        }

        final expenses = kind == 'expenses'
            ? ExpenseProvider(expenseEvents: events)
            : null;
        final friends = kind == 'friends'
            ? FriendProvider(friendEvents: events)
            : null;
        Future<void> fetch(String phone) =>
            expenses?.fetchExpenses(phone) ?? friends!.fetchFriends(phone);
        await fetch('9876543210');
        final replacing = fetch('9876543211');
        expenses?.dispose();
        friends?.dispose();
        cancelling.complete();
        await replacing;
        expect(subscriptions, 1);
        await first.close();
      },
    );
  }
}
