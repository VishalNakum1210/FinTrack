import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fin_track/get_information/session_manager.dart';

/// A create-once server marker makes uncertain commits safe to acknowledge
/// without replaying their record payload over subsequent edits/deletions.
class RetrySafeWriter {
  static final instance = RetrySafeWriter(
    commit: (updates) => FirebaseDatabase.instance.ref().update(updates),
    nextId: () => FirebaseDatabase.instance.ref().push().key!,
    read: (key) => const FlutterSecureStorage().read(key: key),
    save: (key, value) =>
        const FlutterSecureStorage().write(key: key, value: value),
    remove: (key) => const FlutterSecureStorage().delete(key: key),
    confirmed: (user, id) async {
      try {
        return (await FirebaseDatabase.instance
                .ref('WriteOperations/$user/$id')
                .get())
            .exists;
      } catch (_) {
        return false;
      }
    },
  );
  final Future<void> Function(Map<String, Object?>) commit;
  final String Function() nextId;
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) save;
  final Future<void> Function(String) remove;
  final Future<bool> Function(String, String) confirmed;
  final Duration acknowledgementTimeout;
  final Set<String> _active = {};
  final Map<String, String> _acknowledged = {};
  bool lastWritePending = false;
  String? _failure;
  String get failureMessage =>
      _failure ??
      (lastWritePending
          ? 'Still syncing. Your save is pending; retry the same form when connected.'
          : 'Unable to save. Check your connection and retry.');

  static String newIntent() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(18, (_) => random.nextInt(256)));
  }

  RetrySafeWriter({
    required this.commit,
    required this.nextId,
    required this.read,
    required this.save,
    required this.remove,
    required this.confirmed,
    this.acknowledgementTimeout = const Duration(seconds: 15),
  });

  Future<bool> write(
    String user,
    String operation,
    Object payload,
    Map<String, Object?> Function(String) build, {
    String? intentId,
  }) async {
    final key = _journalKey(user, operation, payload, intentId);
    final alias = _journalKey(user, operation, payload, null);
    final payloadHash = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    lastWritePending = false;
    _failure = null;
    if (!_active.add(alias)) {
      lastWritePending = true;
      return false;
    }
    final task = _dispatch(user, key, alias, payloadHash, build, intentId);
    try {
      return await task.timeout(acknowledgementTimeout);
    } on TimeoutException {
      // The original task continues with the same ID, and remains locked until
      // its acknowledgement arrives. A timeout is NOT a cancellation.
      lastWritePending = true;
      return false;
    }
  }

  String _journalKey(
    String user,
    String operation,
    Object payload,
    String? intentId,
  ) {
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode(
              intentId == null
                  ? [SessionManager.authenticatedUid, user, operation, payload]
                  : [
                      SessionManager.authenticatedUid,
                      user,
                      operation,
                      intentId,
                    ],
            ),
          ),
        )
        .toString();
    return 'pending_write_$fingerprint';
  }

  Future<bool> isAcknowledged(
    String user,
    String operation,
    String intentId,
  ) async {
    final key = _journalKey(user, operation, const [], intentId);
    if (_acknowledged.containsKey(key)) return true;
    try {
      final stored = await read(key);
      if (stored == null || !stored.startsWith('{')) return false;
      final state = jsonDecode(stored) as Map<String, dynamic>;
      return state['done'] == true ||
          await confirmed(
            user,
            state['id'] as String,
          ).timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _dispatch(
    String user,
    String key,
    String alias,
    String payloadHash,
    Map<String, Object?> Function(String) build,
    String? intentId,
  ) async {
    String? id;
    try {
      var stored = await read(key);
      bool fromAnotherIntent = false;
      if (stored == null && alias != key && !_acknowledged.containsKey(alias)) {
        final pending = await read(alias);
        if (pending != null &&
            pending.startsWith('{') &&
            (jsonDecode(pending) as Map)['done'] != true) {
          stored = pending;
          fromAnotherIntent = true;
        }
      }
      String? previous;
      bool done = false;
      Map<String, Object?>? originalUpdates;
      if (stored != null) {
        // Decode retained string-only IDs as well as structured journals.
        if (stored.startsWith('{')) {
          final state = jsonDecode(stored) as Map<String, dynamic>;
          if (state['payloadHash'] != null &&
              state['payloadHash'] != payloadHash) {
            _failure =
                'The earlier save used different details. Keep them unchanged to retry, or open a new form for another transaction.';
            return false;
          }
          previous = state['id'] as String;
          done = state['done'] == true;
          if (state['updates'] is Map) {
            originalUpdates = Map<String, Object?>.from(
              state['updates'] as Map,
            );
          }
        } else {
          previous = stored;
        }
      }
      done = done || _acknowledged.containsKey(key);
      if (done && intentId != null) return true;
      id = done ? nextId() : (previous ?? nextId());
      final updates = !done && originalUpdates != null
          ? originalUpdates
          : build(id);
      if (previous != null && !done && await confirmed(user, id)) {
        if (fromAnotherIntent) {
          await _acknowledge(alias, alias, id, null, payloadHash);
          _failure =
              'Your earlier matching transaction is already saved. Check the ledger before submitting a new transaction.';
          return false; // Never count an old receipt as a new intentional purchase.
        }
        await _acknowledge(key, alias, id, intentId, payloadHash);
        return true;
      }
      final pending = jsonEncode({
        'id': id,
        'done': false,
        'updates': updates,
        'payloadHash': payloadHash,
      });
      await save(key, pending);
      if (alias != key) await save(alias, pending);
      try {
        await commit({
          ...updates,
          'WriteOperations/$user/$id': {'timestamp': ServerValue.timestamp},
        });
      } catch (err) {
        // A replay is rejected by the immutable server marker. Read it instead
        // of replacing existing records (which may since have been edited).
        try {
          if (await confirmed(user, id)) {
            await _acknowledge(key, alias, id, intentId, payloadHash);
            return true;
          }
        } catch (_) {}

        // Fallback: If WriteOperations is denied (e.g. server rules not yet updated),
        // commit core transaction updates directly so user data is not lost.
        try {
          await commit(updates);
        } catch (coreErr) {
          final errorStr = coreErr.toString().toLowerCase();
          if (errorStr.contains('permission-denied') ||
              errorStr.contains('permission_denied') ||
              errorStr.contains('permission denied')) {
            _failure =
                'Permission denied. Please verify your account sign-in or database rules.';
          } else {
            _failure = null;
          }
          return false;
        }
      }
      await _acknowledge(key, alias, id, intentId, payloadHash);
      return true;
    } catch (_) {
      return false;
    } finally {
      _active.remove(alias);
    }
  }

  Future<void> _acknowledge(
    String key,
    String alias,
    String id,
    String? intentId,
    String payloadHash,
  ) async {
    _acknowledged[key] = id;
    _acknowledged[alias] = id;
    while (_acknowledged.length > 512) {
      _acknowledged.remove(_acknowledged.keys.first);
    }
    try {
      // Persist acknowledgement BEFORE attempting optional cleanup.
      final done = jsonEncode({
        'id': id,
        'done': true,
        'payloadHash': payloadHash,
      });
      await save(key, done).timeout(const Duration(seconds: 3));
      if (alias != key) {
        await save(alias, done).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      // Keep the in-memory acknowledgement; the server marker is authoritative
      // if local storage is unavailable or the process restarts.
    }
    if (alias != key || intentId == null) {
      try {
        await remove(alias).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }
}
