import 'package:flutter/material.dart';
import 'package:fuwafuwa/lobby_page.dart';
// firebase firebaseCoreプラグインと以前に生成した構成ファイルをインポート
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 最初に表示する画面として、さっき作ったChatListScreenを指定
      home: const LobbyPage(),
    );
  }
}
