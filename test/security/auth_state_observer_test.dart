import 'dart:async';
import 'package:fin_track/authentication/auth_state_observer.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  // Create the future in the widget test's async zone when reload is called.
  late final reloadResult = Completer<void>();
  int reloadCalls = 0;
  @override
  Future<void> reload() {
    reloadCalls++;
    return reloadResult.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
  int signOutCalls = 0;
  final changes = StreamController<User?>.broadcast(sync: true);
  void change(User? user) {
    currentUser = user;
    changes.add(user);
  }

  @override
  Stream<User?> userChanges() => changes.stream;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    change(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _User first;
  late _Auth auth;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    first = _User('first');
    auth = _Auth(first);
  });
  tearDown(() => auth.changes.close());

  Future<void> mount(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => FriendProvider()),
        ],
        child: AuthStateObserver(
          navigatorKey: navigator,
          auth: auth,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Private screen')),
          ),
        ),
      ),
    );
  }

  testWidgets('account replacement never signs out the replacement', (
    tester,
  ) async {
    await mount(tester);
    const storage = FlutterSecureStorage();
    const newSession = '{"uid":"second","phone":"9876543211","name":"Second"}';
    await storage.write(key: 'session_profile_v2', value: newSession);
    auth.change(_User('second'));
    await tester.pumpAndSettle();
    expect(auth.currentUser?.uid, 'second');
    expect(auth.signOutCalls, 0);
    expect(await storage.read(key: 'session_profile_v2'), newSession);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deferred sign-out navigation cannot replace a new session', (
    tester,
  ) async {
    await mount(tester);
    auth.change(null);
    auth.change(_User('second'));
    await tester.pumpAndSettle();
    expect(find.text('Private screen'), findsOneWidget);
    expect(auth.signOutCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale reload failure cannot sign out the current user', (
    tester,
  ) async {
    await mount(tester);
    final observer =
        tester.state(find.byType(AuthStateObserver)) as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(first.reloadCalls, 1);
    auth.change(_User('second'));
    first.reloadResult.completeError(
      FirebaseAuthException(code: 'user-disabled'),
    );
    await tester.pumpAndSettle();
    expect(auth.currentUser?.uid, 'second');
    expect(auth.signOutCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled current account still signs out', (tester) async {
    await mount(tester);
    final observer =
        tester.state(find.byType(AuthStateObserver)) as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(first.reloadCalls, 1);
    first.reloadResult.completeError(
      FirebaseAuthException(code: 'user-disabled'),
    );
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(auth.signOutCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
