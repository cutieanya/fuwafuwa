import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fuwafuwa/features/auth/view/first_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:fuwafuwa/features/chat/views/bottom_bar.dart';
//import 'package:fuwafuwa/ui/home_page.dart';

// ★ 追加：DriftのローカルDBを初期化
import 'data/local_db/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // DBを初期化
  final _ = LocalDb.instance;

  runApp(const MyApp()); // ← これが動く
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuwafuwa Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            // ログイン済み
            return const RootShell();
          } else {
            // 未ログイン
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
