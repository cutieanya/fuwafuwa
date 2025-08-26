// person_chat_screen.dart
import 'package:flutter/material.dart';
import 'gmail_service.dart';
import 'chat_bubble.dart'; // 既存のバブルWidget

class PersonChatScreen extends StatefulWidget {
  final String senderEmail;
  final String? title; // 任意で表示名を渡せる

  const PersonChatScreen({super.key, required this.senderEmail, this.title});

  @override
  State<PersonChatScreen> createState() => _PersonChatScreenState();
}

class _PersonChatScreenState extends State<PersonChatScreen> {
  final _service = GmailService();
  late Future<_TalkData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TalkData> _load() async {
    final my = (await _service.myAddress()) ?? '';
    final msgs = await _service.fetchMessagesBySender(
      widget.senderEmail,
      newerThan: '6m',
    );
    return _TalkData(myEmail: my, messages: msgs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.title ?? widget.senderEmail),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: FutureBuilder<_TalkData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data!;
          final list = data.messages;

          if (list.isEmpty) {
            return const Center(child: Text('この相手とのメッセージはありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              final text = (m['snippet'] ?? '')
                  .toString(); // ここでは snippet を吹き出しに
              final time = (m['timeDt'] as DateTime?) ?? DateTime.now();
              final fromEmail = (m['fromEmail'] ?? '').toString().toLowerCase();
              final isMe = fromEmail == data.myEmail.toLowerCase();

              // 同じ分でまとまりの最後だけ時刻表示
              final next = i < list.length - 1 ? list[i + 1] : null;
              final nextSame =
                  next != null &&
                  (next['fromEmail'] ?? '').toString().toLowerCase() ==
                      fromEmail &&
                  _isSameMinute(next['timeDt'] as DateTime?, time);
              final showTime = !nextSame;

              // 連投の詰め
              final prev = i > 0 ? list[i - 1] : null;
              final prevSame =
                  prev != null &&
                  (prev['fromEmail'] ?? '').toString().toLowerCase() ==
                      fromEmail &&
                  _isSameMinute(prev['timeDt'] as DateTime?, time);

              return ChatBubble(
                text: text,
                time: time,
                isMe: isMe,
                showTime: showTime,
                compact: prevSame,
                compactBelow: nextSame,
              );
            },
          );
        },
      ),
    );
  }

  bool _isSameMinute(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }
}

class _TalkData {
  final String myEmail;
  final List<Map<String, dynamic>> messages;
  _TalkData({required this.myEmail, required this.messages});
}
