// root_shell.dart
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'chatlist_beta.dart';
import 'package:fuwafuwa/features/home/views/home_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 1; // 0:Home, 1:Messages(中央), 2:Profile

  final _pages = const [
    HomeScreen(),
    ChatBetaScreen(), // ← あなたのPullDownReveal画面
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: 64,
        items: [
          Icon(
            Icons.home_outlined,
            size: 28,
            color: _index == 0 ? Colors.black : Colors.white,
          ),
          Icon(
            Icons.chat_bubble_outline,
            size: 28,
            color: _index == 1 ? Colors.black : Colors.white,
          ),
          Icon(
            Icons.person_outline,
            size: 28,
            color: _index == 2 ? Colors.black : Colors.white,
          ),
        ],
        onTap: (i) => setState(() => _index = i),
        color: Colors.black, // バー色
        buttonBackgroundColor: Colors.white, // 選択されたアイコンの背景色（白）
        backgroundColor: Colors.white, // 背景は透過
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 260),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'プロフィール画面',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('ここにプロフィール画面の内容を追加できます'),
        ],
      ),
    ),
  );
}
