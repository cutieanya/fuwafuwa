import 'package:flutter/material.dart';
import 'chat_list_screen.dart'; // 作成したファイルをインポート

void main() {
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
      home: const ChatListScreen(),
    );
  }
}