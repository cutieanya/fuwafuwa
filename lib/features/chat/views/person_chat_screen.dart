import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value; // drift の型
import 'package:fuwafuwa/data/local_db/local_db.dart';
import 'email_detail_screen.dart';

class PersonChatScreen extends StatefulWidget {
  final String senderEmail; // counterpart_email
  final String title;
  const PersonChatScreen({
    super.key,
    required this.senderEmail,
    required this.title,
  });

  @override
  State<PersonChatScreen> createState() => _PersonChatScreenState();
}

class _PersonChatScreenState extends State<PersonChatScreen> {
  Future<List<Map<String, dynamic>>> _loadMessages() async {
    final db = LocalDb.instance;
    final m = db.messages;

    final q = db.select(m)
      ..where((row) => row.counterpartEmail.equals(widget.senderEmail))
      ..orderBy([(row) => OrderingTerm.asc(row.internalDate)]); // 古い→新しい

    final rows = await q.get();
    return rows.map((r) {
      return {
        'id': r.id,
        'direction': r.direction, // 1:incoming, 2:outgoing
        'internalDate': r.internalDate,
        'subject': r.subject ?? '',
        'snippet': r.snippet ?? '',
        'from': r.from ?? '',
        'counterpart': r.counterpartEmail ?? '',
        'isUnread': r.isUnread,
        'bodyPlain': r.bodyPlain,
        'bodyHtml': r.bodyHtml,
      };
    }).toList();
  }

  Future<void> _markThreadReadLocally() async {
    // 画面を開いたら受信の未読をローカルだけ既読に
    final db = LocalDb.instance;
    await (db.update(db.messages)
          ..where((t) => t.counterpartEmail.equals(widget.senderEmail))
          ..where((t) => t.direction.equals(1))
          ..where((t) => t.isUnread.equals(true)))
        .write(const MessagesCompanion(isUnread: Value(false)));
    setState(() {}); // 画面更新
  }

  @override
  void initState() {
    super.initState();
    _markThreadReadLocally();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? widget.senderEmail : widget.title),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadMessages(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting ||
              snap.connectionState == ConnectionState.none) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('メッセージはありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              final isIncoming = (m['direction'] as int?) == 1;
              final subject = (m['subject'] as String?)?.trim() ?? '';
              final snippet = (m['snippet'] as String?)?.trim() ?? '';
              final time = _formatTime(m['internalDate'] as DateTime?);
              final msgId = (m['id'] as String?) ?? '';

              // 吹き出しの本文（件名＋数行スニペット）
              final textWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subject.isNotEmpty)
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isIncoming ? Colors.black : Colors.white,
                      ),
                    ),
                  if (subject.isNotEmpty) const SizedBox(height: 4),
                  Text(
                    snippet.isEmpty ? '(本文スニペットなし)' : snippet,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isIncoming ? Colors.black87 : Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isIncoming ? Colors.black54 : Colors.white70,
                      ),
                    ),
                  ),
                ],
              );

              final bubble = _SpeechBubble(
                isIncoming: isIncoming,
                backgroundColor: isIncoming ? cs.surfaceVariant : Colors.black,
                child: textWidget,
                onTap: () {
                  if (msgId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailDetailScreen(messageId: msgId),
                    ),
                  );
                },
              );

              // 相手からのメッセージには左に丸アイコン（簡易イニシャル）
              final avatar = isIncoming
                  ? _MiniAvatar(email: widget.senderEmail)
                  : const SizedBox(width: 32);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: isIncoming
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  children: isIncoming
                      ? [
                          avatar,
                          const SizedBox(width: 8),
                          Flexible(child: bubble),
                          const SizedBox(width: 40),
                        ]
                      : [
                          const SizedBox(width: 40),
                          Flexible(child: bubble),
                          const SizedBox(width: 8),
                          const SizedBox(width: 32), // 送信側はアバター空き
                        ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}

/// 小さめのアバター（イニシャル表示）
class _MiniAvatar extends StatelessWidget {
  final String email;
  const _MiniAvatar({required this.email});

  @override
  Widget build(BuildContext context) {
    final letter = (email.isNotEmpty ? email[0] : '?').toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// 吹き出しウィジェット（左右でしっぽの向きが変わる）
class _SpeechBubble extends StatelessWidget {
  final bool isIncoming;
  final Color backgroundColor;
  final Widget child;
  final VoidCallback? onTap;

  const _SpeechBubble({
    required this.isIncoming,
    required this.backgroundColor,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isIncoming
          ? const Radius.circular(4)
          : const Radius.circular(16),
      bottomRight: isIncoming
          ? const Radius.circular(16)
          : const Radius.circular(4),
    );

    // しっぽ（三角形）は CustomPaint で描く
    final tail = CustomPaint(
      painter: _BubbleTailPainter(color: backgroundColor, isLeft: isIncoming),
      size: const Size(10, 10),
    );

    final bubbleCore = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: radius),
      child: child,
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubbleCore,
          Positioned(
            bottom: 2,
            left: isIncoming ? -6 : null,
            right: isIncoming ? null : -6,
            child: tail,
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  _BubbleTailPainter({required this.color, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isLeft) {
      // 左しっぽ（←）
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height * 0.5);
      path.lineTo(size.width, size.height);
    } else {
      // 右しっぽ（→）
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height * 0.5);
      path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLeft != isLeft;
  }
}
