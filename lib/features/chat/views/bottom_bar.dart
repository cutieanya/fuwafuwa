import 'dart:async';

import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'package:fuwafuwa/features/home/views/home_screen.dart';
import 'package:fuwafuwa/features/chat/views/chatlist_beta.dart';
import 'package:fuwafuwa/features/user/profile_screen.dart';
import 'package:fuwafuwa/data/local_db/local_db.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 1; // 0:Home, 1:Messages(中央), 2:Profile

  // 未読総数の監視（簡易ポーリング）
  int _unreadTotal = 0;
  Timer? _unreadTimer;

  final _pages = const [HomeScreen(), ChatBetaScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    _startUnreadPolling();
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  void _startUnreadPolling() {
    _refreshUnreadTotal(); // 起動直後に1回
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshUnreadTotal();
    });
  }

  Future<void> _refreshUnreadTotal() async {
    final rows = await LocalDb.instance
        .customSelect(
          'SELECT COUNT(*) AS c FROM messages WHERE is_unread = 1 AND direction = 1;',
        )
        .get();
    final c = (rows.isNotEmpty ? rows.first.data['c'] : 0) as int? ?? 0;
    if (mounted && c != _unreadTotal) {
      setState(() => _unreadTotal = c);
    }
  }

  Widget _badgeableIcon(IconData icon, bool active, {bool showDot = false}) {
    final base = Icon(
      icon,
      size: 28,
      color: active ? Colors.black : Colors.white,
    );
    if (!showDot) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: 64,
        items: [
          _badgeableIcon(Icons.home_outlined, _index == 0),
          _badgeableIcon(
            Icons.chat_bubble_outline,
            _index == 1,
            showDot: _unreadTotal > 0, // 未読が1件以上で赤いドット
          ),
          _badgeableIcon(Icons.person_outline, _index == 2),
        ],
        onTap: (i) => setState(() => _index = i),
        color: Colors.black, // バー色
        buttonBackgroundColor: Colors.white, // 選択アイコン背景
        backgroundColor: Colors.white, // 背景
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 260),
      ),
    );
  }
}
