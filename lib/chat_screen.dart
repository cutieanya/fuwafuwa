import 'package:flutter/material.dart';
import 'chat_bubble.dart'; // 吹き出し（チャットメッセージ）のカスタムウィジェット
// チャット画面のステートフルウィジェット
class ChatScreen extends StatefulWidget {
  final String threadId; // スレッド（会話）ID
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // メッセージを保持するリスト（text・time・isMeで構成）
  final List<Map<String, dynamic>> _messages = [];

  // 入力欄のコントローラ
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    // スレッドIDに応じた初期メッセージ（ダミー）をセットしてる
    if (widget.threadId == '0') {
      _messages.addAll([
        {'text': '今日の進捗どう？', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '1') {
      _messages.addAll([
        {'text': '例の件、承知しました。', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '2') {
      _messages.addAll([
        {'text': '次の勉強会は来週です！', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '3') {
      _messages.addAll([
        {'text': 'すずはです', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '4') {
      _messages.addAll([
        {'text': '中田です', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '5') {
      _messages.addAll([
        {'text': 'ほのかです', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    } else if (widget.threadId == '6' || widget.threadId == '7') {
      _messages.addAll([
        {'text': 'もりこです', 'time': DateTime(2024, 8, 7, 17, 2), 'isMe': false},
      ]);
    }
  }

  // 送信ボタンを押したときの処理
  void _handleSend() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'text': _controller.text.trim(),     // 入力内容
        'time': DateTime.now(),              // 現在時刻
        'isMe': true,                        // 自分が送信したメッセージ
      });
      _controller.clear(); // 入力欄をクリア
    });
  }

  @override
  Widget build(BuildContext context) {
    // 日時順にメッセージをソート（昇順）
    final sortedMessages = [..._messages]..sort((a, b) {
      final aTime = a['time'] as DateTime;
      final bTime = b['time'] as DateTime;
      return aTime.compareTo(bTime);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('スレッド ${widget.threadId}'), // スレッドIDをタイトルに表示
      ),
      body: Column(
        children: [
          // メッセージ表示エリア（上下にスクロール可能）
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedMessages.length,
              itemBuilder: (context, index) {
                final msg = sortedMessages[index];
                return ChatBubble(
                  text: msg['text'] as String,       // 本文
                  time: msg['time'] as DateTime,     // 時刻
                  isMe: msg['isMe'] as bool,         // 送信者かどうか
                );
              },
            ),
          ),

          // 入力欄と送信ボタン
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 入力欄（角丸デザイン＋影付き）
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline, // 複数行入力を有効に
                      textInputAction: TextInputAction.newline,
                      minLines: 1, // 最小1行
                      maxLines: 5, // 最大5行まで → 超えたらTextField内でスクロール
                      decoration: InputDecoration(
                        hintText: 'メッセージを入力',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 送信ボタン（紙飛行機アイコン）
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
