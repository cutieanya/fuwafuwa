import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value; // ★ 追加：driftの型
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
    // この画面を開いたら受信の未読をローカルだけ既読に
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

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = list[i];
              final isIncoming = (m['direction'] as int?) == 1;
              final subject = (m['subject'] as String?)?.trim() ?? '';
              final snippet = (m['snippet'] as String?)?.trim() ?? '';
              final time = _formatTime(m['internalDate'] as DateTime?);

              final bubble = Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isIncoming ? cs.surfaceVariant : cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
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
                ),
              );

              return Row(
                mainAxisAlignment: isIncoming
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        final id = (m['id'] as String?) ?? '';
                        if (id.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmailDetailScreen(messageId: id),
                          ),
                        );
                      },
                      child: bubble,
                    ),
                  ),
                ],
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
