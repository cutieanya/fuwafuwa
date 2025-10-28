// lib/features/chat/views/person_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value; // drift の型だけ使う
import 'package:fuwafuwa/data/local_db/local_db.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fuwafuwa/features/chat/services/gmail_send_service.dart';
import 'package:fuwafuwa/features/chat/views/compose_email_screen.dart';
import 'email_detail_screen.dart';

class PersonChatScreen extends StatefulWidget {
  final String senderEmail; // counterpart_email（相手）
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
  final _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );
  final _sendSvc = GmailSendService();

  final _subjectCtrl = TextEditingController(); // ← 件名
  final _quickCtrl = TextEditingController(); // ← 本文
  bool _sendingQuick = false;

  Future<List<Map<String, dynamic>>> _loadMessages() async {
    final db = LocalDb.instance;
    final m = db.messages;

    final q = db.select(m)
      ..where((row) => row.counterpartEmail.equals(widget.senderEmail))
      ..orderBy([(row) => OrderingTerm.asc(row.internalDate)]);

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
    final db = LocalDb.instance;
    await (db.update(db.messages)
          ..where((t) => t.counterpartEmail.equals(widget.senderEmail))
          ..where((t) => t.direction.equals(1))
          ..where((t) => t.isUnread.equals(true)))
        .write(const MessagesCompanion(isUnread: Value(false)));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _markThreadReadLocally();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _quickCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final acc = await _gsi.signInSilently() ?? await _gsi.signIn();
    if (acc == null) {
      throw Exception('Google へのサインインが必要です');
    }
    final headers = await acc.authHeaders;
    if (headers['Authorization'] == null) {
      throw Exception('Authorization ヘッダが取得できませんでした');
    }
    return headers;
  }

  Future<String> _myAddress() async {
    final acc =
        _gsi.currentUser ?? await _gsi.signInSilently() ?? await _gsi.signIn();
    if (acc == null) throw Exception('Google へのサインインが必要です');
    return acc.email.toLowerCase();
  }

  Future<void> _sendQuick() async {
    final subject = _subjectCtrl.text.trim();
    final body = _quickCtrl.text.trim();

    // 件名・本文どちらかは必須（両方空は送らない）
    if (subject.isEmpty && body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('件名またはメッセージを入力してください')));
      return;
    }

    setState(() => _sendingQuick = true);
    try {
      final headers = await _getAuthHeaders();
      final from = await _myAddress();

      final raw = _sendSvc.buildMimeMessage(
        to: widget.senderEmail,
        from: from,
        subject: subject,
        textBody: body.isEmpty ? '(本文なし)' : body,
      );

      await _sendSvc.sendEmail(authHeaders: headers, rawMessage: raw);

      if (!mounted) return;
      _subjectCtrl.clear();
      _quickCtrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('送信しました')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送信に失敗: $e')));
    } finally {
      if (mounted) setState(() => _sendingQuick = false);
    }
  }

  Future<void> _openComposer() async {
    final headers = await _getAuthHeaders();
    final from = await _myAddress();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposeEmailScreen(
          initialTo: widget.senderEmail,
          initialFrom: from,
          // ※ ComposeEmailScreen に initialSubject / initialBody が無いので渡さない
          authHeaders: headers,
          sendSvc: _sendSvc,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? widget.senderEmail : widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                              color: isIncoming
                                  ? Colors.black54
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    );

                    final bubble = _SpeechBubble(
                      isIncoming: isIncoming,
                      backgroundColor: isIncoming
                          ? cs.surfaceVariant
                          : Colors.black,
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
                                const SizedBox(width: 32),
                              ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // クイック送信欄（件名＋本文）
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_full),
                    tooltip: '拡大（件名/CC/BCC）',
                    onPressed: _openComposer,
                  ),
                  const SizedBox(width: 4),
                  // 入力エリア（縦に「件名」「メッセージ」）
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 件名
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '件名：',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _subjectCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '件名を入力',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.transparent,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // メッセージ
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'メッセージ：',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: TextField(
                            controller: _quickCtrl,
                            maxLines: null,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'メッセージを入力',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sendingQuick ? null : _sendQuick,
                    icon: _sendingQuick
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('送信'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
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

/// 吹き出しウィジェット
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
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height * 0.5);
      path.lineTo(size.width, size.height);
    } else {
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
