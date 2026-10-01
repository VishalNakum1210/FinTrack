import 'package:flutter/foundation.dart';
import 'package:fin_track/authentication/auth_state_observer.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/splash/splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

Future<void> initializeServices() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10485760);
  }
}

class BootstrapApp extends StatefulWidget {
  final Future<void> Function()? initialize;
  const BootstrapApp({super.key, this.initialize});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<void> _ready;

  Future<void> _startInitialization() {
    final future = Future<void>.sync(widget.initialize ?? initializeServices);
    // A retry can fail before FutureBuilder subscribes on the next frame.
    // Handle that window without hiding the error from FutureBuilder itself.
    future.ignore();
    return future;
  }

  @override
  void initState() {
    super.initState();
    _ready = _startInitialization();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const MyApp();
      }
      return MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'FinTrack could not start. Check your connection and try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _ready = _startInitialization();
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class MyApp extends StatelessWidget {
  static final _navigatorKey = GlobalKey<NavigatorState>();
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
      ],
      child: AuthStateObserver(
        navigatorKey: _navigatorKey,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: "FinTrack",
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: GoogleFonts.poppins().fontFamily),
          home: const SplashPage(),
        ),
      ),
    );
  }
}
