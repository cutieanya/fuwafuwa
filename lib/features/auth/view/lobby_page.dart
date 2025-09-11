// lobby_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../chat_list_screen.dart';
import '../../../sign_up_page.dart';
import 'google_sign_in_page.dart'; // ← Google ログイン画面（SignInTest を想定）

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('ようこそ'), centerTitle: true),
      body: StreamBuilder<User?>(
        // ★ ログイン状態をリアルタイム監視
        stream: auth.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 現在のサインイン状態
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      child: Text(
                        user?.email?.isNotEmpty == true
                            ? user!.email![0].toUpperCase()
                            : '👤',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user == null
                            ? '未ログイン'
                            : (user.email?.isNotEmpty == true
                                  ? 'ログイン中：${user.email}'
                                  : 'ログイン中（UID：${user.uid.substring(0, 6)}…）'),
                      ),
                    ),
                    if (user != null)
                      TextButton.icon(
                        onPressed: () async {
                          await auth.signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ログアウトしました')),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('ログアウト'),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // 新規登録
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    label: const Text('新規登録'), // ← label に統一
                  ),
                ),

                const SizedBox(height: 12),

                // Google でログイン
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInTest()),
                      );
                    },
                    label: const Text('Googleでログイン'), // ← label に統一
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // チャットへ（ログイン必須）
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: user == null
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatListScreen(),
                              ),
                            );
                          },
                    label: const Text('チャット画面に進む'), // ← label に統一
                  ),
                ),

                const SizedBox(height: 12),

                if (user == null)
                  const Text(
                    '※ チャット一覧はログイン後に表示できます。\nGoogle ログイン または 新規登録を実行してください。',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
