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
  final String subject;
  final String lastMessageId;
  _ChatData({
    required this.myEmail,
    required this.messages,
    required this.subject,
    required this.lastMessageId,
  });
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
    // 自身のEmailを取得
    final myEmail = (await _service.myAddress()) ?? '';

    // 1. Mapとしてデータを受け取る
    final threadData = await _service.fetchMessagesByThread(widget.threadId);

    // 2. Mapから各データを取り出す
    final messages = (threadData['messages'] as List? ?? []).cast<Map<String, dynamic>>();
    final subject = threadData['subject'] as String? ?? '';
    final lastMessageId = threadData['lastMessageIdHeader'] as String? ?? '';

    // 3. _ChatDataにすべての情報を渡す
    return _ChatData(
      myEmail: myEmail,
      messages: messages,
      subject: subject,
      lastMessageId: lastMessageId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 送信処理
  // [修正後]
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messageToSend = _controller.text;
    _controller.clear();

    try {
      final chatData = await _future;
      final myEmail = chatData.myEmail;
      final messages = chatData.messages;

      // (相手のメールアドレスを特定するロジックはそのまま)
      String? recipientEmail;
      for (final msg in messages.reversed) {
        final fromEmail = (msg['fromEmail'] ?? '').toString().toLowerCase();
        if (fromEmail.isNotEmpty && fromEmail != myEmail.toLowerCase()) {
          recipientEmail = fromEmail;
          break;
        }
      }

      if (recipientEmail == null) {
        throw Exception('返信相手を特定できませんでした。');
      }

      final currentUser = await _googleSignIn.signInSilently();
      if (currentUser == null) throw Exception('ログインしていません');
      final authHeaders = await currentUser.authHeaders;

      // ★★★ 1. 件名を動的に設定 ★★★
      // 元の件名に "Re: " がついていなければ追加する
      final subject = chatData.subject.toLowerCase().startsWith('re: ')
          ? chatData.subject
          : 'Re: ${chatData.subject}';

      // (もしcreateMimeMessageを修正した場合、ここでヘッダー情報を渡す)
      final rawMessage = _sendservice.createMimeMessage(
        to: recipientEmail,
        from: currentUser.email,
        subject: subject,
        body: messageToSend,
        // inReplyTo: chatData.lastMessageId, // 必要に応じて
      );

      final success = await _sendservice.sendEmail(
        authHeaders: authHeaders,
        rawMessage: rawMessage,
        threadId: widget.threadId, // ★★★ 2. ここでthreadIdを渡す！ ★★★
      );

      if (success) {
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