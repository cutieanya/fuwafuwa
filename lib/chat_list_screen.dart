import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'gmail_service.dart'; // ★追加：Gmail APIサービス

// チャット一覧画面のWidget
class ChatListScreen extends StatefulWidget { // ★Statefulに変更
  // コンストラクタ（おまじないのようなもの）
  const ChatListScreen({super.key});

  //★追加
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _service = GmailService(); // ★追加：Gmailサービスのインスタンス
  late Future<List<Map<String, dynamic>>> _futureChats; // ★追加：非同期で取得するチャットリスト
  @override
  void initState() {
    super.initState();
    // ★追加：起動時にGmailから取得（クエリを入れたい場合は fetchThreads(query: 'from:*@example.co.jp') など）
    _futureChats = _service.fetchThreads();
  }
//★追加ここまで

  @override
  Widget build(BuildContext context) {
    // Scaffoldは画面の基本的な骨組みを提供してくれる便利なWidget
    return Scaffold(
      // appBerは画面上部のヘッダー部分
      appBar: AppBar(
        title: const Text('チャット'), // ヘッダーのタイトル
      ),
        // bodyは画面のメインコンテンツ部分
      //★下にfuturebuilderを追加した
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureChats,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final maps = snapshot.data ?? [];
              if (maps.isEmpty) {
                return const Center(child: Text('データがありません'));
              }
              // ★追加：Map → 既存の Chat クラスに変換（UIコードはほぼそのまま使える）
              final chatList = maps.map(_mapToChat).toList();

              // bodyは画面のメインコンテンツ部分
      return ListView.builder(
        // itemCountをダミーデータの数に変更 →★ Gmail取得データの数に変更
        itemCount: chatList.length,
        itemBuilder: (context, index) {
          // リストからindex番目のチャットデータを取得
          final chat = chatList[index];

          // ListTileがそのデータを元に表示するように変更
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(chat.avatarUrl), // データからURLを取得
            ),
            title: Text(chat.name), // データから名前を取得
            subtitle: Text(chat.lastMessage), // データからメッセージを取得
            trailing: Text(chat.time), // データから時間を取得
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // ChatScreenを呼び出し、タップされたチャットの名前(chat.name)を渡す
                  builder: (context) => ChatScreen(threadId: chat.threadId),
                ),
              );
            },
          );
        },
      );
            },
        ),
    );
  }
// ★追加：サービス（Map） → 既存 Chat への変換
//   - サービス側のキー名が不足していても動くようにデフォルトを用意
Chat _mapToChat(Map<String, dynamic> m) {
  final threadId = (m['threadId'] ?? m['id'] ?? '').toString();

  // 差出人（from / counterpart）を優先して名前に
  final name = (m['counterpart'] ?? m['from'] ?? '(unknown)').toString();

  // 最後のメッセージは snippet があればそれを使う
  final lastMessage = (m['lastMessage'] ?? m['snippet'] ?? '(No message)').toString();

  // 時刻表示（"HH:mm" / "昨日" / "M/d" 等）。サービス側が time を用意していなければ空文字。
  final time = (m['time'] ?? '').toString();

  // アイコンはとりあえずダミー（あとでプロフィール画像に差し替え可能）
  const avatar = 'https://placehold.jp/150x150.png';

  return Chat(
    threadId: threadId,
    name: name,
    lastMessage: lastMessage,
    time: time,
    avatarUrl: avatar,
  );
}
}
// このコードをchat_list_screen.dartの一番下に追加

class Chat {
  final String threadId;
  final String name; // 相手の名前
  final String lastMessage; // 最後のメッセージ
  final String time; // 時間
  final String avatarUrl; // アイコン画像のURL

  // 設計図から実体を作るための部品
  Chat({
    required this.threadId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
  });
}