// lib/data/repositories/gmail_repository.dart
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:drift/drift.dart';

import '../local_db/local_db.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';

class GmailRepositoryHttp {
  final LocalDb db;
  final GmailService svc;

  GmailRepositoryHttp({required this.db, required this.svc});

  /// INBOX をクエリでバックフィル
  Future<void> backfillInbox({
    String? query,
    int limit = 100,
    Set<String> allowedSenders = const {},
  }) async {
    final myEmail = (await svc.myAddress())?.toLowerCase() ?? '';
    debugPrint(
      'backfillInbox: myEmail=$myEmail, limit=$limit, '
      'allowedSenders=${allowedSenders.isEmpty ? '(none)' : allowedSenders.toString()}, '
      'query="${query ?? '(null)'}"',
    );

    final threads = await svc.fetchThreads(
      query: query,
      maxResults: 50,
      limit: limit,
    );

    debugPrint('backfillInbox: fetched threads = ${threads.length}');

    var savedThreads = 0;
    var idx = 0;
    for (final t in threads) {
      idx++;
      final threadId = _readThreadId(t);
      if (threadId.isEmpty) {
        debugPrint(
          'backfillInbox: [#$idx] skip thread (no id). keys=${t.keys.toList()}',
        );
        continue;
      }

      final lastDt = _readDateTime(t, 'timeDt');
      final subject = _readSubject(t);
      final snippet = (t['snippet'] ?? '').toString();
      final fromNameOrAddr =
          (t['from']?.toString()) ?? (t['fromEmail']?.toString() ?? '');

      await db.upsertThread(
        ThreadsCompanion.insert(
          id: threadId,
          snippet: Value(snippet),
          lastMessageDate: Value(lastDt),
          participantsCache: Value(fromNameOrAddr),
          historyId: const Value(null),
          subjectLatest: Value(subject.isEmpty ? null : subject),
          messageCount: const Value(0),
        ),
      );

      final savedCount = await hydrateThread(
        threadId: threadId,
        myEmail: myEmail,
        allowedSenders: allowedSenders,
      );

      debugPrint(
        'backfillInbox: thread=$threadId savedMessages=$savedCount (subject="${subject.replaceAll('\n', ' ')}")',
      );
      if (savedCount > 0) savedThreads += 1;
    }

    debugPrint(
      'backfillInbox: done. threads=${threads.length}, threadsWithSavedMessages=$savedThreads',
    );
  }

  /// スレッド内メッセージ保存。戻り値=保存件数
  Future<int> hydrateThread({
    required String threadId,
    required String myEmail,
    Set<String> allowedSenders = const {},
  }) async {
    final full = await svc.fetchMessagesByThread(threadId);
    final msgs =
        (full['messages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    debugPrint('hydrateThread($threadId): fetched messages=${msgs.length}');
    if (msgs.isEmpty) return 0;

    // 昇順
    msgs.sort((a, b) {
      final da = _readDateTime(a, 'timeDt');
      final dbb = _readDateTime(b, 'timeDt');
      if (da == null && dbb == null) return 0;
      if (da == null) return 1;
      if (dbb == null) return -1;
      return da.compareTo(dbb);
    });

    final allowedLower = allowedSenders.map((e) => e.toLowerCase()).toSet();
    var count = await _countMessagesInThread(threadId);

    Map<String, dynamic>? latest;
    String latestSubject = '';
    int saved = 0,
        skippedNoCounterpart = 0,
        skippedNotWhitelisted = 0,
        synthesized = 0;

    var i = 0;
    for (final m in msgs) {
      i++;
      var id = _readMessageId(m);

      final dt = _readDateTime(m, 'timeDt') ?? DateTime.now();
      final fromEmail = _readFromEmail(m);
      final subject = _readSubject(m);
      final snippet = (m['snippet'] ?? '').toString();

      // ★ id が無い実装に対応：threadId+内容から安定IDを合成
      if (id.isEmpty) {
        id = _synthMessageId(
          threadId: threadId,
          time: dt,
          fromEmail: fromEmail,
          subject: subject,
          snippet: snippet,
        );
        synthesized++;
        if (i <= 5) {
          debugPrint(
            'hydrateThread($threadId): synthesized id="$id" for message keys=${m.keys.toList()}',
          );
        }
      }

      final isOutgoing = myEmail.isNotEmpty && fromEmail == myEmail;
      final direction = isOutgoing ? 2 : 1;

      final counterpartEmail = _readCounterpartEmail(m, isOutgoing);
      if (counterpartEmail == null || counterpartEmail.isEmpty) {
        skippedNoCounterpart++;
        continue;
      }
      if (allowedLower.isNotEmpty && !allowedLower.contains(counterpartEmail)) {
        skippedNotWhitelisted++;
        continue;
      }

      await db.upsertMessage(
        MessagesCompanion.insert(
          id: id,
          threadId: threadId,
          internalDate: dt,
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
      saved += 1;

      if (latest == null ||
          (dt.isAfter(
            _readDateTime(latest, 'timeDt') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ))) {
        latest = m;
        latestSubject = subject;
      }
    }

    if (latest != null) {
      await (db.update(db.threads)..where((t) => t.id.equals(threadId))).write(
        ThreadsCompanion(
          subjectLatest: Value(latestSubject.isEmpty ? null : latestSubject),
          messageCount: Value(count),
          lastMessageDate: Value(_readDateTime(latest, 'timeDt')),
        ),
      );
    }

    debugPrint(
      'hydrateThread($threadId): saved=$saved, synthesizedId=$synthesized, '
      'skippedNoCounterpart=$skippedNoCounterpart, skippedNotWhitelisted=$skippedNotWhitelisted',
    );
    return saved;
  }

  Future<int> _countMessagesInThread(String threadId) async {
    final row =
        await (db.selectOnly(db.messages)
              ..addColumns([db.messages.id.count()])
              ..where(db.messages.threadId.equals(threadId)))
            .getSingle();
    return row.read<int>(db.messages.id.count()) ?? 0;
  }

  // ---------- robust readers ----------

  String _readThreadId(Map<String, dynamic> t) {
    return (t['threadId'] ?? t['id'] ?? t['gmailThreadId'] ?? '').toString();
  }

  String _readMessageId(Map<String, dynamic> m) {
    return (m['id'] ??
            m['messageId'] ??
            m['msgId'] ??
            m['gmailId'] ??
            m['rfc822MsgId'] ??
            '')
        .toString();
  }

  DateTime? _readDateTime(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is DateTime) return v;
    if (v is int) {
      if (v > 1000000000000)
        return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
    }
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return null;
  }

  String _readSubject(Map<String, dynamic> m) {
    return (m['subject'] ?? m['headersSubject'] ?? m['payloadSubject'] ?? '')
        .toString();
  }

  String _readFromEmail(Map<String, dynamic> m) {
    final raw = (m['fromEmail'] ?? m['from'] ?? '').toString();
    return _normalizeEmail(raw);
  }

  String? _readCounterpartEmail(Map<String, dynamic> m, bool isOutgoing) {
    if (!isOutgoing) {
      final fromEmail = _readFromEmail(m);
      return fromEmail.isEmpty ? null : fromEmail;
    } else {
      final toList = _readToEmails(m);
      if (toList.isNotEmpty) return _normalizeEmail(toList.first);
      final toRaw = (m['to'] ?? '').toString();
      final norm = _normalizeEmail(toRaw);
      return norm.isEmpty ? null : norm;
    }
  }

  List<String> _readToEmails(Map<String, dynamic> m) {
    final v = m['toEmails'];
    if (v is List) {
      return v
          .map((e) => _normalizeEmail(e.toString()))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final toRaw = (m['to'] ?? '').toString();
    if (toRaw.isEmpty) return const [];
    return toRaw
        .split(',')
        .map((s) => _normalizeEmail(s))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _normalizeEmail(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final match = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(s);
    return (match?.group(1) ?? '').toLowerCase();
  }

  // ---------- 合成ID ----------

  String _synthMessageId({
    required String threadId,
    required DateTime time,
    required String fromEmail,
    required String subject,
    required String snippet,
  }) {
    final base =
        '$threadId|${time.millisecondsSinceEpoch}|$fromEmail|$subject|$snippet';
    final h = base.hashCode;
    return 'syn_${threadId}_${time.millisecondsSinceEpoch}_${h.abs()}';
    //            ^^^^^^^  ← 末尾にアンダースコア無しの "threadId" を使用
  }
}
