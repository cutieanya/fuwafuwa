// smoke_test_curved.dart
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class CurvedSmokeTest extends StatefulWidget {
  const CurvedSmokeTest({super.key});
  @override
  State<CurvedSmokeTest> createState() => _CurvedSmokeTestState();
}

class _CurvedSmokeTestState extends State<CurvedSmokeTest> {
  int _index = 1;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(color: Colors.grey[100]),

      // ← ここで“黒い土台”を敷く
      bottomNavigationBar: Container(
        child: CurvedNavigationBar(
          index: _index,
          height: 64,
          items: [
            Icon(
              _index == 0 ? Icons.home : Icons.home_outlined,
              size: 28,
              color: _index == 0 ? Colors.black : Colors.white,
            ),
            Icon(
              _index == 1 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 28,
              color: _index == 1 ? Colors.black : Colors.white,
            ),
            Icon(
              _index == 2 ? Icons.person : Icons.person_outline,
              size: 28,
              color: _index == 2 ? Colors.black : Colors.white,
            ),
          ],
          onTap: (i) => setState(() => _index = i),

          buttonBackgroundColor: Colors.white, // 選択丸 = 白
          backgroundColor: Colors.black, // ★ パッケージ背景は“透明”に
          animationCurve: Curves.easeOutCubic,
          animationDuration: const Duration(milliseconds: 600),
        ),
      ),
    );
  }
}
