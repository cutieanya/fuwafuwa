import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:fuwafuwa/features/auth/view/lobby_page.dart';
import 'package:fuwafuwa/features/auth/view/first_screen.dart';
// firebase firebaseCoreプラグインと以前に生成した構成ファイルをインポート
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:fuwafuwa/features/chat/views/bottom_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
      // ログイン状態に応じて初期画面を決定
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // ログイン状態を確認中
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasData) {
            // ログイン済み → RootShellを表示
            return const RootShell();
          } else {
            // 未ログイン → ログイン画面を表示
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
