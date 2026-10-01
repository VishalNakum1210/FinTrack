import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

enum VersionPolicyFailure {
  connection,
  permissionDenied,
  invalidConfiguration,
  unavailable,
}

class VersionPolicyException extends StateError {
  final VersionPolicyFailure failure;

  VersionPolicyException(this.failure) : super('Version policy unavailable');

  factory VersionPolicyException.from(Object error) {
    if (error is VersionPolicyException) return error;
    if (error is TimeoutException) {
      return VersionPolicyException(VersionPolicyFailure.connection);
    }
    if (error is FirebaseException) {
      final code = error.code.toLowerCase().replaceAll('_', '-');
      if (code == 'permission-denied') {
        return VersionPolicyException(VersionPolicyFailure.permissionDenied);
      }
      if (const {
        'network-error',
        'network-request-failed',
        'unavailable',
        'disconnected',
      }.contains(code)) {
        return VersionPolicyException(VersionPolicyFailure.connection);
      }
    }
    return VersionPolicyException(VersionPolicyFailure.unavailable);
  }

  String get title => switch (failure) {
    VersionPolicyFailure.connection => 'Connection required',
    VersionPolicyFailure.permissionDenied ||
    VersionPolicyFailure.invalidConfiguration => 'App configuration issue',
    VersionPolicyFailure.unavailable => 'Version check unavailable',
  };

  String get description => switch (failure) {
    VersionPolicyFailure.connection =>
      'Unable to check the supported app version. Check your internet connection and retry.',
    VersionPolicyFailure.permissionDenied =>
      'The server denied access to the app version setting. The app administrator must correct its Firebase permissions. Your internet connection may be working normally.',
    VersionPolicyFailure.invalidConfiguration =>
      'The server returned an invalid app version setting. The app administrator must correct it before you can continue.',
    VersionPolicyFailure.unavailable =>
      'Unable to verify the supported app version. Please retry. If this continues, contact the app administrator.',
  };
}

/// A failed refresh must still enforce the last verified policy. On the first
/// launch, an unavailable policy is retried instead of silently bypassed.
class MinimumVersionPolicy {
  static bool valid(String? version) =>
      version != null && RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);

  static bool isLower(String current, String minimum) {
    if (!valid(current) || !valid(minimum)) {
      throw ArgumentError('Invalid version');
    }
    final c = current.split('.').map(int.parse).toList();
    final m = minimum.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (c[i] != m[i]) return c[i] < m[i];
    }
    return false;
  }

  static Future<String> resolve({
    required Future<String> Function() remote,
    required Future<String?> Function() cached,
    required Future<void> Function(String) cache,
  }) async {
    try {
      final minimum = await remote();
      if (!valid(minimum)) {
        throw VersionPolicyException(VersionPolicyFailure.invalidConfiguration);
      }
      try {
        await cache(minimum);
      } catch (_) {}
      return minimum;
    } catch (error) {
      String? previous;
      try {
        previous = await cached();
      } catch (_) {
        // Cache failure must not hide the actual remote failure or bypass it.
      }
      if (valid(previous)) return previous!;
      throw VersionPolicyException.from(error);
    }
  }
}
