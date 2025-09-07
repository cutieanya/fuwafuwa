import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'gmail_service.dart';
import 'gmail_send_service.dart';
import 'chat_bubble.dart';

/// チャット画面（スレッドごと）
class ChatScreen extends StatefulWidget {
  final String threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// APIから取得するデータをまとめるためのヘルパークラス
class _ChatData {
  final String myEmail;
  final List<Map<String, dynamic>> messages;
  _ChatData({required this.myEmail, required this.messages});
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = GmailService();
  final _sendservice = GmailSendService();
  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.modify'],
  );
  late Future<_ChatData> _future;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // 画面の初期化時にAPIからデータをロードする
    _future = _load();

    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  /// APIからチャット履歴と自身のEmailを取得する
  Future<_ChatData> _load() async {
    // 自身のEmailを取得（自分/相手の判定に使う）
    final myEmail = (await _service.myAddress()) ?? '';

    // GmailServiceに新しく実装する関数を呼び出す
    final messages = await _service.fetchMessagesByThread(widget.threadId);

    // 取得したデータをまとめて返す
    return _ChatData(myEmail: myEmail, messages: messages);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 送信処理
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messageToSend = _controller.text;
    _controller.clear();

    try {
      // ★★★ 修正・追加箇所 ① ★★★
      // initStateで非同期にロードしたチャットデータをここで取得します。
      final chatData = await _future;
      final myEmail = chatData.myEmail;
      final messages = chatData.messages;

      // ★★★ 修正・追加箇所 ② ★★★
      // メッセージ履歴から相手のメールアドレスを特定するためのロジックです。
      String? recipientEmail;
      // メッセージリストを後ろから（新しいものから）順番に確認します。
      for (final msg in messages.reversed) {
        final fromEmail = (msg['fromEmail'] ?? '').toString().toLowerCase();
        // 送信者(fromEmail)が空でなく、かつ自分のアドレスでなければ、それが相手のアドレスです。
        if (fromEmail.isNotEmpty && fromEmail != myEmail.toLowerCase()) {
          recipientEmail = fromEmail; // 相手のアドレスを保存
          print("found!");
          print("recipientEmail:   ");
          print(recipientEmail);
          break; // 相手が見つかったのでループを抜けます。
        }
      }

      // ★★★ 修正・追加箇所 ③ ★★★
      // ループを抜けても相手が見つからなかった場合（例：自分しかいないスレッド）はエラーとします。
      if (recipientEmail == null) {
        throw Exception('返信相手を特定できませんでした。');
      }

      // 認証情報の取得
      final currentUser = await _googleSignIn.signInSilently();
      if (currentUser == null) throw Exception('ログインしていません');
      final authHeaders = await currentUser.authHeaders;

      // TODO: 件名も動的に設定するのが望ましい
      const subject = 'Re: Chat';

      final rawMessage = _sendservice.createMimeMessage(
        // ★★★ 修正・追加箇所 ④ ★★★
        // ハードコードされていた宛先を、上で特定した動的なアドレスに変更します。
        to: recipientEmail,
        from: currentUser.email,
        subject: subject,
        body: messageToSend,
      );

      final success = await _sendservice.sendEmail(
        authHeaders: authHeaders,
        rawMessage: rawMessage,
      );

      if (success) {
        // 送信成功後、チャットをリロード
        setState(() {
          _future = _load();
        });
      } else {
        throw Exception('APIでのメール送信に失敗しました');
      }
    } catch (e) {
      print('送信エラー: $e');
      if (mounted) {
        _controller.text = messageToSend;
        ScaffoldMessenger.of(context).showSnackBar(
          // ★★★ 修正・追加箇所 ⑤ ★★★
          // 送信失敗時に、より具体的なエラー内容を画面に表示します。
          SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _scrollToBottom({bool animate = true}) async {
    // WidgetsBinding ensures the layout is complete before scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollCtrl.hasClients) return;
      await Future.delayed(const Duration(milliseconds: 50));
      if (!_scrollCtrl.hasClients) return;

      final pos = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(pos, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(pos);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('スレッド ${widget.threadId}'), // タイトルは適宜変更
        centerTitle: true,
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<_ChatData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('エラー: ${snap.error}'));
                }
                if (!snap.hasData || snap.data!.messages.isEmpty) {
                  return const Center(child: Text('メッセージがありません'));
                }

                final data = snap.data!;
                final messages = data.messages;

                // 初回ビルド後 or データ更新後に一番下にスクロール
                _scrollToBottom(animate: false);

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final prev = index > 0 ? messages[index - 1] : null;
                    final next = index < messages.length - 1 ? messages[index + 1] : null;

                    final fromEmail = (msg['fromEmail'] ?? '').toString().toLowerCase();
                    final isMe = fromEmail == data.myEmail.toLowerCase();

                    final showTime = next == null ||
                        (next['fromEmail'] ?? '').toString().toLowerCase() != fromEmail ||
                        !_isSameMinute(next['timeDt'] as DateTime?, msg['timeDt'] as DateTime?);

                    final compactWithPrev = prev != null &&
                        (prev['fromEmail'] ?? '').toString().toLowerCase() == fromEmail &&
                        _isSameMinute(prev['timeDt'] as DateTime?, msg['timeDt'] as DateTime?);

                    return ChatBubble(
                      text: (msg['snippet'] ?? '').toString(),
                      time: (msg['timeDt'] as DateTime?) ?? DateTime.now(),
                      isMe: isMe,
                      showTime: showTime,
                      compact: compactWithPrev,
                    );
                  },
                );
              },
            ),
          ),
          // ---- 入力コンポーザー ----
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline)),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _hasText ? _handleSend : null,
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameMinute(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day && a.hour == b.hour && a.minute == b.minute;
  }
}