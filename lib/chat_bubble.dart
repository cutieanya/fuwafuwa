import 'package:flutter/material.dart';

/// 1メッセージの吹き出し
/// - text: 本文
/// - time: 送信時刻
/// - isMe: 自分の送信か
/// - showTime: この気泡の下に時刻を出すか（同分連投の“最後だけ”trueにする想定）
/// - compact / compactBelow: 直前/直後が同分連投なら縦の余白を詰めるためのフラグ
class ChatBubble extends StatelessWidget {
  final String text;
  final DateTime time;
  final bool isMe;
  final bool showTime;
  final bool compact;
  final bool compactBelow;

  const ChatBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.showTime = true,
    this.compact = false,
    this.compactBelow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 配色：自分＝primary面/白文字、相手＝薄い面/濃い文字
    final bg = isMe ? cs.primary : cs.surfaceContainerHighest;
    final fg = isMe ? cs.onPrimary : cs.onSurface;

    // 時刻などのメタ情報
    final metaStyle = Theme.of(context)
        .textTheme
        .labelSmall!
        .copyWith(color: cs.outline, height: 1.1);

    // 横幅は画面の70%まで（長文で伸びすぎないように）
    final maxW = MediaQuery.of(context).size.width * 0.7;

    // 吹き出し本体（丸角のみ。尾っぽは使わない）
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 16 : 4),
            topRight: Radius.circular(isMe ? 4 : 16),
            bottomLeft: Radius.circular(isMe ? 16 : 20),
            bottomRight: Radius.circular(isMe ? 20 : 16),
          ),
          // 送信側だけほんのり影（立体感）
          boxShadow: isMe
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: DefaultTextStyle(
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: fg, height: 1.3, letterSpacing: -0.1),
            child: Text(text),
          ),
        ),
      ),
    );

    // 送受で左右に寄せる
    final row = Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Flexible(child: bubble)],
    );

    // 外側の余白：
    //  - compact: 直前が同分連投なら上を詰める
    //  - compactBelow: 直後が同分連投なら下を詰める
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMe ? 48 : 12,                      // 左（相手側は広めに空ける）
        compact ? 1 : 6,                     // 上：連投時は1px、通常は6px
        isMe ? 12 : 48,                      // 右
        showTime ? 4 : (compactBelow ? 1 : 4), // 下：時刻が無ければ連投時だけ詰める
      ),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          row,
          if (showTime) ...[
            const SizedBox(height: 3),
            Text(_fmt(time), style: metaStyle),
          ],
        ],
      ),
    );
  }

  // hh:mm 表示
  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
