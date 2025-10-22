// lib/ui/thread_page.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:fuwafuwa/data/local_db/local_db.dart'; // ← パッケージ名に合わせて

class ThreadPage extends StatelessWidget {
  final String threadId;
  const ThreadPage({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    final db = LocalDb.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: StreamBuilder<List<Message>>(
        stream: db.watchMessagesInThreadAsc(threadId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final msgs = snapshot.data!;
          if (msgs.isEmpty) {
            return const Center(child: Text('No messages'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              final isMine = m.direction == 2; // 2=outgoing(自分)
              return _ChatBubble(
                isMine: isMine,
                subject: m.subject,
                text: m.snippet ?? '',
                timestamp: m.internalDate,
                hasAttachments: m.hasAttachments,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isMine;
  final String? subject;
  final String text;
  final DateTime timestamp;
  final bool hasAttachments;

  const _ChatBubble({
    required this.isMine,
    required this.subject,
    required this.text,
    required this.timestamp,
    required this.hasAttachments,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign = isMine ? MainAxisAlignment.end : MainAxisAlignment.start;

    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor = isMine
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: rowAlign,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if ((subject ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              subject!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.9),
                                  ),
                            ),
                          ),
                        Text(
                          text.isEmpty ? '(no preview)' : text,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAttachments)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.attachment,
                                  size: 14,
                                  color: textColor.withOpacity(0.8),
                                ),
                              ),
                            Text(
                              _formatTime(timestamp),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: textColor.withOpacity(0.8),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}
