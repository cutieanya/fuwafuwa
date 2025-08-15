import 'package:flutter/material.dart';
import 'chat_bubble.dart';

/// チャット画面（スレッドごと）
class ChatScreen extends StatefulWidget {
  final String threadId; // スレッドID（ダミーデータの分岐に使用）
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// 画面内で使うメッセージ配列（最小構成）
  /// { text: String, time: DateTime, isMe: bool }
  final List<Map<String, dynamic>> _messages = [];

  /// 入力欄
  final TextEditingController _controller = TextEditingController();

  /// メッセージリストのスクロール制御（送信後に最下部へ移動させる）
  final ScrollController _scrollCtrl = ScrollController();

  /// 入力有無で送信ボタンの有効/無効を切り替える
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    // ---- ダミーの初期メッセージ（スレッドIDごとに1通だけ） ----
    final seedByThread = <String, String>{
      '0': '今日の進捗どう？',
      '1': '例の件、承知しました。',
      '2': '次の勉強会は来週です！',
      '3': 'すずはです',
      '4': '中田です',
      '5': 'ほのかです',
      '6': 'もりこです',
      '7': 'もりこです',
    };
    final seedText = seedByThread[widget.threadId];
    if (seedText != null) {
      _messages.add({
        'text': seedText,
        'time': DateTime(2024, 8, 7, 17, 2),
        'isMe': false,
      });
    }
    // ---- ここまで初期メッセージ ----

    // 入力欄のテキスト変化で送信ボタンの活性状態を更新
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });

    // 初回レンダー完了後、最下部へスクロール（古い履歴がある想定）
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 送信処理：メッセージ配列に追加→入力欄クリア→最下部へスクロール
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'time': DateTime.now(), 'isMe': true});
      _controller.clear();
    });

    // レイアウト更新後にスクロール（直後だと位置が確定していないことがある）
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// 最下部へスクロール（Web/デスクトップでも安定するよう軽く待つ）
  Future<void> _scrollToBottom({bool animate = true}) async {
    if (!_scrollCtrl.hasClients) return;
    await Future.delayed(const Duration(milliseconds: 16)); // 1フレーム待機
    if (!_scrollCtrl.hasClients) return;

    final pos = _scrollCtrl.position.maxScrollExtent;
    if (animate) {
      try {
        await _scrollCtrl.animateTo(
          pos,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } catch (_) {
        _scrollCtrl.jumpTo(pos);
      }
    } else {
      _scrollCtrl.jumpTo(pos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 表示用：時刻の古い順に並べ替え（リスト本体は触らない）
    final sortedMessages = [..._messages]
      ..sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    return Scaffold(
      // 画面の地色（明るめ）
      backgroundColor: cs.surface,

      // 上部バーは一段濃いトーンにして背景と差別化
      appBar: AppBar(
        title: Text('スレッド ${widget.threadId}'),
        centerTitle: true,
        backgroundColor: cs.surfaceContainerHighest, // ← 濃い面
        foregroundColor: cs.onSurface,               // ← 文字/アイコン色
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      body: Column(
        children: [
          // ---- メッセージリスト（上から下へ時系列） ----
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: sortedMessages.length,
              itemBuilder: (context, index) {
                final msg  = sortedMessages[index];
                final prev = index > 0 ? sortedMessages[index - 1] : null;
                final next = index < sortedMessages.length - 1
                    ? sortedMessages[index + 1]
                    : null;

                // 同じ送信者&同じ“分”であれば、最後の1件だけ時刻を表示
                final showTime = next == null ||
                    next['isMe'] != msg['isMe'] ||
                    !_isSameMinute(next['time'] as DateTime, msg['time'] as DateTime);

                // 連投の間隔（上側／下側）を詰めるためのフラグ
                final compactWithPrev = prev != null &&
                    prev['isMe'] == msg['isMe'] &&
                    _isSameMinute(prev['time'] as DateTime, msg['time'] as DateTime);

                final compactWithNext = next != null &&
                    next['isMe'] == msg['isMe'] &&
                    _isSameMinute(next['time'] as DateTime, msg['time'] as DateTime);

                return ChatBubble(
                  text: msg['text'] as String,
                  time: msg['time'] as DateTime,
                  isMe: msg['isMe'] as bool,
                  showTime: showTime,            // ← 最後だけ時刻
                  compact: compactWithPrev,      // ← 上を詰める
                  compactBelow: compactWithNext, // ← 下を詰める
                );
              },
            ),
          ),

          // ---- 入力コンポーザー（添付ボタン + テキスト + 送信）----
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  // 未来の添付用プレースホルダー
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add',
                  ),
                  // 入力欄（丸く・やや濃い面の上）
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
                        textInputAction: TextInputAction.newline,
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
                  // 送信ボタン（入力ありで有効）
                  AnimatedScale(
                    scale: _hasText ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 120),
                    child: FloatingActionButton.small(
                      onPressed: _hasText ? _handleSend : null,
                      child: const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// “同じ分かどうか”だけを見て連投判定に使う（例：02:37 と 02:37 は同一）
  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }
}
