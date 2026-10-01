import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fin_track/services/minimum_version_policy.dart';

void main() {
  for (final code in ['permission-denied', 'PERMISSION_DENIED']) {
    test(
      'Firebase $code is configuration failure, not lost connection',
      () async {
        await expectLater(
          MinimumVersionPolicy.resolve(
            remote: () async => throw FirebaseException(
              plugin: 'firebase_database',
              code: code,
            ),
            cached: () async => null,
            cache: (_) async {},
          ),
          throwsA(
            isA<VersionPolicyException>().having(
              (error) => error.failure,
              'failure',
              VersionPolicyFailure.permissionDenied,
            ),
          ),
        );
      },
    );
  }

  test('timeout is a connection failure', () async {
    await expectLater(
      MinimumVersionPolicy.resolve(
        remote: () async => throw TimeoutException('Version check timed out'),
        cached: () async => null,
        cache: (_) async {},
      ),
      throwsA(
        isA<VersionPolicyException>().having(
          (error) => error.failure,
          'failure',
          VersionPolicyFailure.connection,
        ),
      ),
    );
  });

  test(
    'invalid remote version is not cached or called an internet outage',
    () async {
      var cacheWrites = 0;
      await expectLater(
        MinimumVersionPolicy.resolve(
          remote: () async => 'invalid',
          cached: () async => null,
          cache: (_) async {
            cacheWrites++;
          },
        ),
        throwsA(
          isA<VersionPolicyException>().having(
            (error) => error.failure,
            'failure',
            VersionPolicyFailure.invalidConfiguration,
          ),
        ),
      );
      expect(cacheWrites, 0);
    },
  );

  test('cache-read failure preserves permission-denied diagnosis', () async {
    await expectLater(
      MinimumVersionPolicy.resolve(
        remote: () async => throw FirebaseException(
          plugin: 'firebase_database',
          code: 'permission-denied',
        ),
        cached: () async => throw StateError('Storage unavailable'),
        cache: (_) async {},
      ),
      throwsA(
        isA<VersionPolicyException>().having(
          (error) => error.failure,
          'failure',
          VersionPolicyFailure.permissionDenied,
        ),
      ),
    );
  });

  test('permission failure still enforces the last verified policy', () async {
    final minimum = await MinimumVersionPolicy.resolve(
      remote: () async => throw FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      ),
      cached: () async => '2.3.0',
      cache: (_) async {},
    );
    expect(MinimumVersionPolicy.isLower('2.2.0', minimum), isTrue);
  });

  test('unknown errors never instruct users to fix their internet', () {
    final failure = VersionPolicyException.from(StateError('Unknown error'));
    expect(failure.failure, VersionPolicyFailure.unavailable);
    expect(failure.title, 'Version check unavailable');
    expect(failure.description, isNot(contains('internet')));
  });
}
