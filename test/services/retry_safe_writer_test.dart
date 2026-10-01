import 'dart:async';
import 'package:fin_track/services/retry_safe_writer.dart';
import 'package:flutter_test/flutter_test.dart';

class WriterFixture {
  final journal = <String, String>{};
  final database = <String, Object?>{};
  int generated = 0, calls = 0;
  bool loseAcknowledgement = false, failCleanup = false, failJournal = false;
  Completer<void>? gate;
  RetrySafeWriter writer({Duration timeout = const Duration(seconds: 15)}) =>
      RetrySafeWriter(
        commit: (updates) async {
          calls++;
          if (gate != null) await gate!.future;
          final marker = updates.keys.singleWhere(
            (k) => k.startsWith('WriteOperations/'),
          );
          if (database.containsKey(marker)) {
            throw StateError('Marker is immutable');
          }
          database.addAll(updates);
          if (loseAcknowledgement) throw StateError('Acknowledgement lost');
        },
        confirmed: (user, id) async =>
            database.containsKey('WriteOperations/$user/$id'),
        nextId: () => 'op-${++generated}',
        read: (key) async => journal[key],
        save: (key, value) async {
          if (failJournal) throw StateError('Storage unavailable');
          journal[key] = value;
        },
        remove: (key) async {
          if (failCleanup) throw StateError('Cleanup unavailable');
          journal.remove(key);
        },
        acknowledgementTimeout: timeout,
      );
  Map<String, Object?> build(String id) => {
    'Expenses/user/$id': {'Amount': '0.49'},
  };
  int get recordCount =>
      database.keys.where((k) => k.startsWith('Expenses/')).length;
}

void main() {
  test(
    'lost acknowledgement is reconciled against the server marker',
    () async {
      final f = WriterFixture()..loseAcknowledgement = true;
      expect(
        await f.writer().write('user', 'expense', ['.49'], f.build),
        isTrue,
      );
      expect(f.recordCount, 1);
      expect(f.generated, 1);
    },
  );
  test('journal cleanup failure does not merge distinct purchases', () async {
    final f = WriterFixture()..failCleanup = true;
    final writer = f.writer();
    expect(await writer.write('user', 'expense', ['.49'], f.build), isTrue);
    expect(await writer.write('user', 'expense', ['.49'], f.build), isTrue);
    expect(f.recordCount, 2);
  });
  test(
    'one acknowledged form intent remains idempotent across restart',
    () async {
      final f = WriterFixture()..failCleanup = true;
      expect(
        await f.writer().write(
          'user',
          'expense',
          ['.49'],
          f.build,
          intentId: 'form-1',
        ),
        isTrue,
      );
      expect(
        await f.writer().write(
          'user',
          'expense',
          ['.49'],
          f.build,
          intentId: 'form-1',
        ),
        isTrue,
      );
      expect(
        await f.writer().write(
          'user',
          'expense',
          ['.49'],
          f.build,
          intentId: 'form-2',
        ),
        isTrue,
      );
      expect(f.recordCount, 2);
    },
  );
  test(
    'retries never overwrite an edited or deleted committed record',
    () async {
      final f = WriterFixture();
      final writer = f.writer();
      expect(
        await writer.write('user', 'expense', [], f.build, intentId: 'form'),
        isTrue,
      );
      f.database['Expenses/user/op-1'] = {'Amount': '0.70'};
      expect(
        await f.writer().write(
          'user',
          'expense',
          [],
          f.build,
          intentId: 'form',
        ),
        isTrue,
      );
      expect((f.database['Expenses/user/op-1'] as Map)['Amount'], '0.70');
      f.database.remove('Expenses/user/op-1');
      expect(
        await f.writer().write(
          'user',
          'expense',
          [],
          f.build,
          intentId: 'form',
        ),
        isTrue,
      );
      expect(f.recordCount, 0);
    },
  );
  test(
    'unmarked uncertain journal is reconciled without a second dispatch',
    () async {
      final f = WriterFixture();
      final writer = f.writer();
      // Keep a pending journal to simulate death between commit and local acknowledgement.
      String? journalKey;
      final original = RetrySafeWriter(
        commit: (updates) async {
          f.database.addAll(updates);
          throw StateError('Lost');
        },
        confirmed: (_, _) async => false,
        nextId: () => 'op-1',
        read: (key) async => f.journal[key],
        save: (key, value) async {
          journalKey = key;
          f.journal[key] = value;
        },
        remove: (key) async {
          if (f.failJournal) throw StateError('Cleanup unavailable');
          f.journal.remove(key);
        },
      );
      expect(await original.write('user', 'expense', [], f.build), isFalse);
      f.database['Expenses/user/op-1'] = {'Amount': '0.70'};
      expect(journalKey, isNotNull);
      expect(await writer.write('user', 'expense', [], f.build), isTrue);
      expect(f.calls, 0);
      expect((f.database['Expenses/user/op-1'] as Map)['Amount'], '0.70');
    },
  );
  test(
    'timeout unlocks UI but does not dispatch a duplicate pending save',
    () async {
      final f = WriterFixture()..gate = Completer<void>();
      final writer = f.writer(timeout: const Duration(milliseconds: 10));
      expect(
        await writer.write('user', 'expense', [], f.build, intentId: 'form'),
        isFalse,
      );
      expect(writer.lastWritePending, isTrue);
      expect(
        await writer.write('user', 'expense', [], f.build, intentId: 'form'),
        isFalse,
      );
      expect(f.calls, 1);
      f.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        await writer.write('user', 'expense', [], f.build, intentId: 'form'),
        isTrue,
      );
      expect(f.recordCount, 1);
    },
  );
  test('unavailable durable journal fails closed before dispatch', () async {
    final f = WriterFixture()..failJournal = true;
    expect(await f.writer().write('user', 'expense', [], f.build), isFalse);
    expect(f.calls, 0);
  });
  test('intent tokens distinguish independently opened identical forms', () {
    expect(RetrySafeWriter.newIntent(), isNot(RetrySafeWriter.newIntent()));
  });
  test(
    'reopened form reports an existing uncertain receipt rather than counting it as new',
    () async {
      final f = WriterFixture();
      final uncertain = RetrySafeWriter(
        commit: (updates) async {
          f.database.addAll(updates);
          throw StateError('Lost');
        },
        confirmed: (_, _) async => false,
        nextId: () => 'op-1',
        read: (key) async => f.journal[key],
        save: (key, value) async {
          f.journal[key] = value;
        },
        remove: (key) async {
          f.journal.remove(key);
        },
      );
      expect(
        await uncertain.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'before-restart',
        ),
        isFalse,
      );
      final resumed = f.writer();
      expect(
        await resumed.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'after-restart',
        ),
        isFalse,
      );
      expect(resumed.failureMessage, contains('already saved'));
      expect(f.recordCount, 1);
      expect(f.calls, 0);
    },
  );
  test(
    'changed form details cannot silently reuse an earlier acknowledged save',
    () async {
      final f = WriterFixture();
      final writer = f.writer();
      expect(
        await writer.write(
          'user',
          'expense',
          ['old'],
          f.build,
          intentId: 'form',
        ),
        isTrue,
      );
      expect(
        await writer.write(
          'user',
          'expense',
          ['changed'],
          f.build,
          intentId: 'form',
        ),
        isFalse,
      );
      expect(writer.failureMessage, contains('different details'));
      expect(f.recordCount, 1);
      expect(await writer.isAcknowledged('user', 'expense', 'form'), isTrue);
    },
  );
  test(
    'a never-committed pending payload resumes with the original ID after restart',
    () async {
      final f = WriterFixture();
      final offline = RetrySafeWriter(
        commit: (_) async => throw StateError('Offline'),
        confirmed: (_, _) async => false,
        nextId: () => 'op-1',
        read: (key) async => f.journal[key],
        save: (key, value) async {
          f.journal[key] = value;
        },
        remove: (key) async {
          f.journal.remove(key);
        },
      );
      expect(
        await offline.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'old-form',
        ),
        isFalse,
      );
      expect(
        await f.writer().write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'reopened-form',
        ),
        isTrue,
      );
      expect(f.recordCount, 1);
      expect(f.database.containsKey('Expenses/user/op-1'), isTrue);
      expect(f.generated, 0);
    },
  );
  test(
    'failed acknowledgement persistence does not silently merge a new purchase after restart',
    () async {
      final f = WriterFixture()..generated = 1;
      final original = RetrySafeWriter(
        commit: (updates) async {
          f.database.addAll(updates);
          f.failJournal = true;
        },
        confirmed: (user, id) async =>
            f.database.containsKey('WriteOperations/$user/$id'),
        nextId: () => 'op-1',
        read: (key) async => f.journal[key],
        save: (key, value) async {
          if (f.failJournal) throw StateError('Storage unavailable');
          f.journal[key] = value;
        },
        remove: (key) async {
          if (f.failJournal) throw StateError('Cleanup unavailable');
          f.journal.remove(key);
        },
      );
      expect(
        await original.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'original',
        ),
        isTrue,
      );
      f.failJournal = false;
      final reopened = f.writer();
      expect(
        await reopened.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'new-purchase',
        ),
        isFalse,
      );
      expect(reopened.failureMessage, contains('already saved'));
      expect(f.recordCount, 1);
      expect(
        await reopened.write(
          'user',
          'expense',
          ['same'],
          f.build,
          intentId: 'new-purchase',
        ),
        isTrue,
      );
      expect(f.recordCount, 2);
    },
  );
}
