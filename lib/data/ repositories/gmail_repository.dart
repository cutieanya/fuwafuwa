// lib/data/repositories/gmail_repository_http.dart
import 'package:drift/drift.dart';
import '../local_db/local_db.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';

class GmailRepositoryHttp {
  final LocalDb db;
  final GmailService svc;

  GmailRepositoryHttp({required this.db, required this.svc});

  /// INBOXをクエリでバックフィル（例: 'in:inbox newer_than:30d'）
  Future<void> backfillInbox({String? query, int limit = 100}) async {
    final myEmail = (await svc.myAddress())?.toLowerCase() ?? '';
    final threads = await svc.fetchThreads(
      query: query,
      maxResults: 50,
      limit: limit,
    );

    for (final t in threads) {
      final threadId = (t['threadId'] ?? t['id'] ?? '').toString();
      if (threadId.isEmpty) continue;

      final lastDt = t['timeDt'] as DateTime?;
      final subject = (t['subject'] ?? '').toString();
      final snippet = (t['snippet'] ?? '').toString();
      final fromNameOrAddr = (t['from']?.toString()) ?? '';

      // Threads upsert（件名・最終日時を反映）
      await db.upsertThread(
        ThreadsCompanion.insert(
          id: threadId,
          snippet: Value(snippet),
          lastMessageDate: Value(lastDt),
          participantsCache: Value(fromNameOrAddr),
          historyId: const Value(null), // 差分同期は別途
          subjectLatest: Value(subject.isEmpty ? null : subject),
          messageCount: const Value(0), // 後で hydrateThread で更新
        ),
      );

      // スレッド内の全メッセージを取得して保存
      await hydrateThread(threadId: threadId, myEmail: myEmail);
    }
  }

  /// スレッド内メッセージをDBに保存（direction / index / 件数も更新）
  Future<void> hydrateThread({
    required String threadId,
    required String myEmail,
  }) async {
    final full = await svc.fetchMessagesByThread(threadId);
    final msgs =
        (full['messages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (msgs.isEmpty) return;

    // 昇順（古い→新しい）に並べ替え
    msgs.sort((a, b) {
      final da = a['timeDt'] as DateTime?;
      final dbb = b['timeDt'] as DateTime?;
      if (da == null && dbb == null) return 0;
      if (da == null) return 1;
      if (dbb == null) return -1;
      return da.compareTo(dbb);
    });

    final latest = msgs.last;
    final latestSubject = (latest['subject'] ?? '').toString();

    // 既存件数を見て indexInThread の起点にする
    var count = await _countMessagesInThread(threadId);

    for (final m in msgs) {
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final dt = m['timeDt'] as DateTime?;
      final fromEmail = ((m['fromEmail'] ?? '') as String).toLowerCase();
      final subject = (m['subject'] ?? '').toString();
      final snippet = (m['snippet'] ?? '').toString();

      // 送受信の方向：From が自分なら outgoing(2)、そうでなければ incoming(1)
      final isOutgoing = myEmail.isNotEmpty && fromEmail == myEmail;
      final direction = isOutgoing ? 2 : 1;

      // 相手メール（受信なら from、送信なら To の先頭（現状null））
      String? counterpartEmail;
      if (!isOutgoing) {
        counterpartEmail = fromEmail.isNotEmpty ? fromEmail : null;
      } else {
        counterpartEmail = null;
      }

      await db.upsertMessage(
        MessagesCompanion.insert(
          id: id,
          threadId: threadId,
          internalDate: dt ?? DateTime.now(),
          from: Value(fromEmail.isNotEmpty ? fromEmail : null),
          to: const Value(null),
          ccCsv: const Value(null),
          bccCsv: const Value(null),
          subject: Value(subject.isEmpty ? null : subject),
          snippet: Value(snippet),
          bodyPlain: const Value(null),
          bodyHtml: const Value(null),
          labelIdsCsv: const Value(null),
          historyId: const Value(null),
          isUnread: const Value(true),
          hasAttachments: const Value(false),
          direction: Value(direction),
          indexInThread: Value(count),
          counterpartEmail: Value(counterpartEmail),
        ),
      );
      count += 1;
    }

    // スレッドのメタを更新
    await (db.update(db.threads)..where((t) => t.id.equals(threadId))).write(
      ThreadsCompanion(
        subjectLatest: Value(latestSubject.isEmpty ? null : latestSubject),
        messageCount: Value(count),
        lastMessageDate: Value(latest['timeDt'] as DateTime?),
      ),
    );
  }

  /// 既存スレッド内メッセージ件数を取得（indexInThread連番の起点に使用）
  Future<int> _countMessagesInThread(String threadId) async {
    final row =
        await (db.selectOnly(db.messages)
              ..addColumns([db.messages.id.count()])
              ..where(db.messages.threadId.equals(threadId)))
            .getSingle();
    return row.read<int>(db.messages.id.count()) ?? 0;
  }
}
