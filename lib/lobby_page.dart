import 'package:flutter/material.dart';
import 'package:fuwafuwa/chat_list_screen.dart';
import 'package:fuwafuwa/sign_up_page.dart';
import 'package:fuwafuwa/google_sign_in_page.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignUpPage()),
              );
            },
            child: const Text('新規登録'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignUpPage()),
              );
            },
            child: const Text('ログイン'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
            child: const Text('チャット画面に遷移'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignInTest()),
              );
            },
            child: const Text('Googleでログイン'),
          ),
        ],
      ),
    );
  }
}
