import 'package:flutter/material.dart';

// チャット一覧画面のWidget
class ChatListScreen extends StatelessWidget {
  // コンストラクタ（おまじないのようなもの）
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffoldは画面の基本的な骨組みを提供してくれる便利なWidget
    return Scaffold(
      // appBerは画面上部のヘッダー部分
      appBar: AppBar(
        title: const Text('チャット'), // ヘッダーのタイトル
      ),
      // bodyは画面のメインコンテンツ部分
      body: ListView.builder(
        itemCount: 20, // とりあえず20件のダミーデータを表示
        itemBuilder: (context, index) {
          // ListTileはリストの1行を簡単に作れる便利なWidget
          return ListTile(
            // leadingは左端のアイコンなど
            leading: const CircleAvatar(
              backgroundImage: NetworkImage('https://placehold.jp/150x150.png'),
            ),
            // titleはメインのテキスト
            title: Text('相手の名前 ${index + 1}'),
            // subtitleはタイトルの下の補助的なテキスト
            subtitle: const Text('これが最後のメッセージです...'),
            // trailingは右端のアイコンやテキストなど
            trailing: const Text('12:34'),
            onTap: () {
              // タップされた時の処理を後で書く場所
              print('Tapped item ${index + 1}');
            },
          );
        },
      ),
    );
  }
}