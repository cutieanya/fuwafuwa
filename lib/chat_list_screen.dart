import 'package:flutter/material.dart';

// このコードを class ChatListScreen extends StatelessWidget { のすぐ上に追加

// Chatクラスの設計図を元に、仮のデータリストを作成
final List<Chat> dummyChatList = [
  Chat(
    name: 'cutieanya',
    lastMessage: '今日の進捗どう？',
    time: '18:30',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: '田中さん',
    lastMessage: '例の件、承知しました。',
    time: '17:02',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: 'Flutter大好きクラブ',
    lastMessage: '次の勉強会は来週です！',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: '門田',
    lastMessage: 'すずはです',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: 'みき',
    lastMessage: '中田です',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: 'ほのか',
    lastMessage: 'ほのかです',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: '森コ',
    lastMessage: 'もりこです',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
  Chat(
    name: 'mndns232',
    lastMessage: 'もりこです',
    time: '昨日',
    avatarUrl: 'https://placehold.jp/150x150.png',
  ),
];
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
      // class ChatListScreenの中のbody:以降を書き換える

      // bodyは画面のメインコンテンツ部分
      body: ListView.builder(
        // itemCountをダミーデータの数に変更
        itemCount: dummyChatList.length,
        itemBuilder: (context, index) {
          // リストからindex番目のチャットデータを取得
          final chat = dummyChatList[index];

          // ListTileがそのデータを元に表示するように変更
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(chat.avatarUrl), // データからURLを取得
            ),
            title: Text(chat.name), // データから名前を取得
            subtitle: Text(chat.lastMessage), // データからメッセージを取得
            trailing: Text(chat.time), // データから時間を取得
            onTap: () {
              print('${chat.name} was tapped');
            },
          );
        },
      ),
    );
  }
}

// このコードをchat_list_screen.dartの一番下に追加

class Chat {
  final String name; // 相手の名前
  final String lastMessage; // 最後のメッセージ
  final String time; // 時間
  final String avatarUrl; // アイコン画像のURL

  // 設計図から実体を作るための部品
  Chat({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
  });
}