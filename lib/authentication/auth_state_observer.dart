import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';

/// Clears visible private data when Firebase signs out or replaces an account.
class AuthStateObserver extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const AuthStateObserver({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  @override
  State<AuthStateObserver> createState() => _AuthStateObserverState();
}

class _AuthStateObserverState extends State<AuthStateObserver>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _subscription;
  String? _uid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _subscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (!mounted) return;
      final previous = _uid;
      _uid = user?.uid;
      if (previous != null && previous != _uid) {
        context.read<UserProvider>().clearUser();
        context.read<ExpenseProvider>().clearExpenses();
        context.read<FriendProvider>().clearFriends();
        unawaited(SessionManager.clearSession().catchError((_) {}));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              (_) => false,
            );
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshUser());
  }

  Future<void> _refreshUser() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } on FirebaseAuthException catch (error) {
      if ([
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
      ].contains(error.code)) {
        await FirebaseAuth.instance.signOut();
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
