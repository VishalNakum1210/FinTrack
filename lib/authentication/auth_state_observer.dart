import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';

/// Clears visible private data when Firebase signs out or replaces an account.
class AuthStateObserver extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final FirebaseAuth? auth;
  const AuthStateObserver({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.auth,
  });
  @override
  State<AuthStateObserver> createState() => _AuthStateObserverState();
}

class _AuthStateObserverState extends State<AuthStateObserver>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _subscription;
  String? _uid;
  late final FirebaseAuth _auth;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = widget.auth ?? FirebaseAuth.instance;
    _uid = _auth.currentUser?.uid;
    _subscription = _auth.userChanges().listen((user) {
      if (!mounted) return;
      final previous = _uid;
      _uid = user?.uid;
      if (previous != null && previous != _uid) {
        context.read<UserProvider>().clearUser(previous);
        context.read<ExpenseProvider>().clearExpenses();
        context.read<FriendProvider>().clearFriends();
        // Explicit logout owns secure-storage cleanup. Calling clearSession
        // here can sign out a replacement user or erase their new session.
        if (_uid == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _uid == null) {
              widget.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                (_) => false,
              );
            }
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshUser());
  }

  Future<void> _refreshUser() async {
    final user = _auth.currentUser;
    try {
      await user?.reload();
    } on FirebaseAuthException catch (error) {
      if ([
            'user-disabled',
            'user-not-found',
            'invalid-user-token',
          ].contains(error.code) &&
          user != null &&
          _auth.currentUser?.uid == user.uid) {
        await _auth.signOut();
      }
    } catch (_) {
      /* Offline access remains available until auth can refresh. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
