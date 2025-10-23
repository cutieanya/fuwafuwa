// lib/features/chat/views/chat_beta_screen.dart
//
// 目的：指定送信元（人）ごとに、ローカルDBに同期済みのGmailデータを一覧表示。
// - 上段：アカウント切替バー（PullDownReveal の背面）※将来複数アカウント対応用に残しつつ、今はDB駆動
// - 下段：人ごと最新メッセージ1行＋未読バッジ（DB集計）
// - スワイプ：一覧から非表示（UIだけ消す。DB/Gmailは変更しない）
//
// 必要カラム：messages.counterpart_email / is_unread / direction / internal_date / subject / snippet

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Driftの集計(count/max)を使うので、FlutterのColumnと衝突しないように hide Column
import 'package:drift/drift.dart' hide Column;

import 'package:fuwafuwa/features/chat/views/person_chat_screen.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';
import 'pull_down_reveal.dart';

// ★ ローカルDB・リポジトリ
import 'package:fuwafuwa/data/local_db/local_db.dart';
import 'package:fuwafuwa/data/repositories/gmail_repository.dart';

// ----------------- モデル -----------------

class Chat {
  final String threadId; // ここでは senderEmail をキーとして流用
  final String name; // 表示名（メールアドレスをそのままでもOK）
  final String lastMessage; // スニペット（本文冒頭）
  final String time; // 表示用の時刻文字列（例 2025/09/19 19:11）
  final String avatarUrl; // アバター画像URL（今はプレースホルダ）
  final String senderEmail; // 送信元（相手）メール
  Chat({
    required this.threadId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
    required this.senderEmail,
  });
}

class _LinkedAccount {
  final String email;
  final String displayName;
  final String photoUrl;
  const _LinkedAccount({
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });
}

// -------------- 画面本体 -----------------

class ChatBetaScreen extends StatefulWidget {
  const ChatBetaScreen({super.key});
  @override
  State<ChatBetaScreen> createState() => _ChatBetaScreenState();
}

class _ChatBetaScreenState extends State<ChatBetaScreen> {
  // Gmail REST（操作系で使用。一覧はDBから読む）
  final _service = GmailService();

  // アカウント切替UI用（将来の複数アカウント対応に継続使用）
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  // ------ レイアウト調整系 ------
  static const double _kTrailingWidth = 96.0;

  // ------ 画面状態 ------
  String? _activeAccountEmail; // null = All（現状は単一アカウント想定でも保持）
  bool _isEditMode = false;
  final Set<String> _selectedThreadIds = {}; // ここでは senderEmail を入れる

  final Map<String, DateTime?> _hiddenSnapshotByThread = {}; // 非表示スナップショット
  final Map<String, Chat> _lastChatById = {};
  final Map<String, DateTime?> _lastTimeByThread = {};

  // ------ 取得キャッシュ（不要な再ロード抑制） ------
  Future<List<Map<String, dynamic>>>? _chatsFuture;
  String _chatsFutureKey = '';
  Future<Map<String, int>>? _unreadFuture;
  String _unreadFutureKey = '';

  String _sendersKey(Set<String> s) {
    final l = s.toList()..sort();
    return l.join(',');
  }

  void _ensureFutures(Set<String> senders, List<_LinkedAccount> linked) {
    final chatsKey = '${_activeAccountEmail ?? "all"}|${_sendersKey(senders)}';
    if (_chatsFutureKey != chatsKey) {
      _chatsFuture = _loadChatsUnified(senders, linked);
      _chatsFutureKey = chatsKey;
    }
    final unreadKey = _sendersKey(senders);
    if (_unreadFutureKey != unreadKey) {
      _unreadFuture = _loadUnreadCounts(senders);
      _unreadFutureKey = unreadKey;
    }
  }

  void _invalidateUnreadCache() {
    _unreadFutureKey = '';
  }

  // ---------- 起動時：サイレントサインイン ----------
  @override
  void initState() {
    super.initState();
    _bootstrapSignIn();

    // 起動時の一時修復：counterpart_email を from で埋める（冪等）
    _fixCounterpartEmail();
  }

  Future<void> _bootstrapSignIn() async {
    try {
      final acc = await _gsi.signInSilently();
      if (!mounted) return;
      _activeAccountEmail = acc?.email.toLowerCase();
      await _refreshServiceAuth();
      setState(() {});
    } catch (_) {
      // no-op
    }
  }

  Future<void> _refreshServiceAuth() async {
    try {
      final headers = await _gsi.currentUser?.authHeaders;
      if (headers != null) {
        await _service.refreshAuthHeaders(headers);
      }
    } catch (_) {
      /* ignore */
    }
  }

  // ---------- Firestore パス ----------
  DocumentReference<Map<String, dynamic>> get _filtersDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('未ログインです。ログイン後に再度お試しください。');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('filters');
  }

  DocumentReference<Map<String, dynamic>> get _accountsDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('未ログインです。ログイン後に再度お試しください。');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('accounts');
  }

  // ---------- Filters（表示対象送信元の管理） ----------
  Stream<Set<String>> _streamAllowedSenders() {
    return _filtersDoc.snapshots().map((snap) {
      final list =
          (snap.data()?['allowedSenders'] as List?)?.cast<String>() ??
          const <String>[];
      return list.map((e) => e.toLowerCase()).toSet();
    });
  }

  Future<void> _addAllowedSender(String emailRaw) async {
    final email = _extractEmail(emailRaw.trim());
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスの形式が正しくありません')));
      return;
    }
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayUnion([email]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeAllowedSender(String email) async {
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayRemove([email.toLowerCase()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Linked Accounts（UI用） ----------
  Stream<List<_LinkedAccount>> _streamLinkedAccounts() {
    return _accountsDoc.snapshots().map((snap) {
      final raw = (snap.data()?['linked'] as List?) ?? const [];
      return raw
          .map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _LinkedAccount(
              email: (m['email'] ?? '').toString().toLowerCase(),
              displayName: (m['displayName'] ?? '').toString(),
              photoUrl: (m['photoUrl'] ?? '').toString(),
            );
          })
          .where((a) => a.email.isNotEmpty)
          .toList();
    });
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final account = await _gsi.signIn();
      if (account == null) return;
      await _accountsDoc.set({
        'linked': FieldValue.arrayUnion([
          {
            'email': account.email.toLowerCase(),
            'displayName': account.displayName,
            'photoUrl': account.photoUrl,
            'linkedAt': FieldValue.serverTimestamp(),
          },
        ]),
      }, SetOptions(merge: true));
      await _refreshServiceAuth();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アカウントを追加しました：${account.email}')));
      setState(() => _activeAccountEmail ??= account.email.toLowerCase());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('追加に失敗: $e')));
    }
  }

  Future<void> _switchToAccount(String? email) async {
    setState(() {
      _activeAccountEmail = email; // null = All
      _isEditMode = false;
      _selectedThreadIds.clear();
      _chatsFutureKey = '';
      _unreadFutureKey = '';
    });
    if (email == null) return;

    final cur = await _gsi.signInSilently();
    if (!(cur != null && cur.email.toLowerCase() == email.toLowerCase())) {
      final acc = await _gsi.signIn();
      if (acc == null) return;
      if (!mounted) return;
      if (acc.email.toLowerCase() != email.toLowerCase()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('選択と異なるため、${acc.email} を使用します')));
        setState(() => _activeAccountEmail = acc.email.toLowerCase());
      }
    }
    await _refreshServiceAuth();
  }

  // ---------- DBから人ごと最新一覧を取得 ----------
  Future<List<Map<String, dynamic>>> _loadChatsForDb() async {
    final db = LocalDb.instance;
    final m = db.messages;

    // counterpart_email ごとに最新日時を取り、その行の subject/snippet をざっくり拾う
    final maxDt = m.internalDate.max();

    final q = db.selectOnly(m)
      ..addColumns([m.counterpartEmail, maxDt, m.subject, m.snippet])
      ..where(m.counterpartEmail.isNotNull())
      ..groupBy([m.counterpartEmail])
      ..orderBy([OrderingTerm.desc(maxDt)]);

    final rows = await q.get();

    return rows.map((r) {
      final email = r.read(m.counterpartEmail)!;
      final dt = r.read(maxDt);
      final subject = r.read(m.subject) ?? '';
      final snippet = r.read(m.snippet) ?? '';
      return {
        'id': email,
        'threadId': email,
        'fromEmail': email,
        'subject': subject,
        'snippet': snippet,
        'timeDt': dt,
        'time': _formatTime(dt),
        'from': email,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadChatsUnified(
    Set<String> allowedSenders,
    List<_LinkedAccount> _linked,
  ) async {
    final list = await _loadChatsForDb();
    if (allowedSenders.isEmpty) return list;
    final setLower = allowedSenders.map((e) => e.toLowerCase()).toSet();
    return list
        .where(
          (m) =>
              (m['fromEmail'] as String?)?.toLowerCase() != null &&
              setLower.contains((m['fromEmail'] as String).toLowerCase()),
        )
        .toList();
  }

  // ---------- DBから未読数を集計 ----------
  Future<Map<String, int>> _loadUnreadCounts(Set<String> _senders) async {
    final db = LocalDb.instance;
    final m = db.messages;
    final cnt = m.id.count();

    final q = db.selectOnly(m)
      ..addColumns([m.counterpartEmail, cnt])
      ..where(m.isUnread.equals(true) & m.direction.equals(1))
      ..groupBy([m.counterpartEmail]);

    final rows = await q.get();

    final map = <String, int>{};
    for (final r in rows) {
      final email = r.read(m.counterpartEmail);
      final n = r.read(cnt) ?? 0;
      if (email != null) map[email.toLowerCase()] = n;
    }

    if (_senders.isNotEmpty) {
      final setLower = _senders.map((e) => e.toLowerCase()).toSet();
      map.removeWhere((k, _) => !setLower.contains(k));
    }
    return map;
  }

  // ---------- UIユーティリティ ----------
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  Chat _mapToChat(Map<String, dynamic> m) {
    final email = (m['fromEmail'] ?? '') as String;
    final name = email.isEmpty ? '(unknown)' : email;
    final lastMessage = (m['snippet'] ?? m['subject'] ?? '(No message)')
        .toString();
    final time = (m['time'] ?? '').toString();
    const avatar = 'https://placehold.jp/150x150.png';
    return Chat(
      threadId: email,
      name: name,
      lastMessage: lastMessage,
      time: time,
      avatarUrl: avatar,
      senderEmail: email,
    );
  }

  Widget _avatar(String url) =>
      CircleAvatar(radius: 24, backgroundImage: NetworkImage(url));

  Widget _unreadChip(int unread) {
    if (unread <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        unread > 99 ? '99+' : unread.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------- 編集モード ----------
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedThreadIds.clear();
    });
  }

  // ====== 非表示（隠す） ======
  Future<void> _deleteSelectedFromView() async {
    for (final tid in _selectedThreadIds) {
      _hiddenSnapshotByThread[tid] = _lastTimeByThread[tid];
    }
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  // 1件だけ一覧から非表示にする（スワイプ用）
  void _hideOne(String threadId) {
    _hiddenSnapshotByThread[threadId] = _lastTimeByThread[threadId];
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('一覧から非表示にしました')));
  }

  // ====== ローカルDB削除 ======
  Future<void> _deleteLocalBySender(String email) async {
    final e = email.toLowerCase();
    // messages から削除
    await LocalDb.instance.customStatement(
      'DELETE FROM messages WHERE LOWER(counterpart_email) = ?;',
      [e],
    );
    // 参照が無くなった threads を掃除
    await LocalDb.instance.customStatement(
      'DELETE FROM threads WHERE id NOT IN (SELECT DISTINCT thread_id FROM messages);',
    );
  }

  Future<void> _deleteSelectedLocally() async {
    if (_selectedThreadIds.isEmpty) return;
    for (final email in _selectedThreadIds) {
      await _deleteLocalBySender(email);
    }
    _invalidateUnreadCache();
    setState(() {
      _selectedThreadIds.clear();
      _chatsFutureKey = ''; // 再読込
      _unreadFutureKey = '';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ローカルDBから削除しました')));
  }

  // ====== 一括既読（編集バーのボタンからのみ。スワイプは非表示動作） ======
  Future<void> _markSelectedRead() async {
    if (_selectedThreadIds.isEmpty) return;

    // 1) Gmail APIで一括既読（送信元単位）
    for (final email in _selectedThreadIds) {
      final q = 'from:${email.toLowerCase()} is:unread';
      await _service.markReadByQuery(q);
    }

    // 2) DB も既読にしてUI即時反映
    final db = LocalDb.instance;
    for (final email in _selectedThreadIds) {
      await (db.update(db.messages)
            ..where((m) => m.counterpartEmail.equals(email))
            ..where((m) => m.direction.equals(1)) // 受信のみ
            ..where((m) => m.isUnread.equals(true)))
          .write(const MessagesCompanion(isUnread: Value(false)));
    }

    _invalidateUnreadCache();
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  // ---------- デバッグ/修復 ----------
  Future<void> _debugPrintMessagesCount() async {
    final db = LocalDb.instance;
    final m = db.messages;
    final cnt = m.id.count();

    final rows =
        await (db.selectOnly(m)
              ..addColumns([m.counterpartEmail, cnt])
              ..groupBy([m.counterpartEmail]))
            .get();

    debugPrint('==== counterpartEmail counts ====');
    for (final r in rows) {
      debugPrint('counterpart=${r.read(m.counterpartEmail)} : ${r.read(cnt)}');
    }
  }

  // counterpart_email を from で埋める（冪等）
  Future<void> _fixCounterpartEmail() async {
    await LocalDb.instance.customStatement('''
      UPDATE messages
      SET counterpart_email = LOWER("from")
      WHERE counterpart_email IS NULL
        AND "from" IS NOT NULL;
    ''');
    debugPrint('✅ counterpart_email updated (no direction filter)');
  }

  // ダミー a@x 行を安全に削除（パラメータバインド）
  Future<void> _wipeDummyMessages({String needle = 'a@x'}) async {
    final n = needle.toLowerCase();
    await LocalDb.instance.customStatement(
      'DELETE FROM messages '
      'WHERE LOWER("from") LIKE ? OR LOWER(counterpart_email) = ?;',
      ['%$n%', n],
    );
    await LocalDb.instance.customStatement(
      'DELETE FROM threads WHERE id NOT IN (SELECT DISTINCT thread_id FROM messages);',
    );
    debugPrint('✅ wiped dummy messages for $n');
  }

  // Firestoreの allowedSenders をクエリに埋めてバックフィル
  Future<void> _syncAllowedSendersInbox() async {
    try {
      final allowed = await _streamAllowedSenders().first;
      debugPrint('allowedSenders: $allowed');

      if (allowed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('allowedSenders が空です')));
        return;
      }

      // Gmail検索クエリを構築：in:inbox newer_than:30d (from:a OR from:b)
      final parts = allowed.map((e) => 'from:${e.toLowerCase()}').join(' OR ');
      final query = 'in:inbox newer_than:30d ($parts)';
      debugPrint('fetchThreads query = $query');

      final repo = GmailRepositoryHttp(db: LocalDb.instance, svc: _service);
      await repo.backfillInbox(query: query, limit: 200);

      // DBの状態を軽く出しておく
      await _diagAll();
      await _debugPrintMessagesCount();

      if (!mounted) return;
      // ★ ここで出していた「同期が完了しました」の SnackBar を削除
      setState(() {
        _chatsFutureKey = '';
        _unreadFutureKey = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同期に失敗: $e')));
    }
  }

  Future<void> _diagAll() async {
    // 方向カウント
    final rowsDir = await LocalDb.instance
        .customSelect(
          'SELECT direction, COUNT(*) AS c FROM messages GROUP BY direction;',
        )
        .get();
    debugPrint('==== direction counts ====');
    for (final r in rowsDir) {
      debugPrint('direction=${r.data['direction']} : ${r.data['c']}');
    }

    // NULL フィールド
    final rowsNull = await LocalDb.instance.customSelect('''
      SELECT
        SUM(CASE WHEN "from" IS NULL THEN 1 ELSE 0 END) AS null_from,
        SUM(CASE WHEN counterpart_email IS NULL THEN 1 ELSE 0 END) AS null_counter
      FROM messages;
    ''').get();
    final rn = rowsNull.first.data;
    debugPrint('==== null field counts ====');
    debugPrint(
      'from IS NULL: ${rn['null_from']}, counterpart_email IS NULL: ${rn['null_counter']}',
    );

    // 先頭20件
    final rowsPeek = await LocalDb.instance.customSelect('''
      SELECT id, direction, "from", counterpart_email, internal_date
      FROM messages
      ORDER BY internal_date DESC
      LIMIT 20;
    ''').get();
    debugPrint('==== peek messages ====');
    for (final r in rowsPeek) {
      debugPrint(r.data.toString());
    }

    // DB 内に存在する counterpart_email の一覧
    final rowsList = await LocalDb.instance.customSelect('''
      SELECT LOWER(counterpart_email) AS ce
      FROM messages
      WHERE counterpart_email IS NOT NULL
      GROUP BY ce
      ORDER BY ce;
    ''').get();
    final emails = rowsList.map((e) => e.data['ce']).toList();
    debugPrint('DB counterpart emails: $emails');
  }

  // ---------- ビルド ----------
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;
    final currentAsLinked = _currentUserAsLinked();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PullDownReveal(
                  minChildSize: 0.8,
                  handle: false,
                  backBar: _AccountsBar(
                    streamLinkedAccounts: _streamLinkedAccounts(),
                    activeAccountEmail: _activeAccountEmail,
                    switchToAccount: _switchToAccount,
                    linkGoogleAccount: _linkGoogleAccount,
                    currentUser: currentAsLinked,
                  ),
                  frontBuilder: (scroll) {
                    return CustomScrollView(
                      controller: scroll,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                              child: Row(
                                children: [
                                  const Text(
                                    'Chat',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  // ★ デバッグボタン群
                                  IconButton(
                                    icon: const Icon(Icons.cleaning_services),
                                    color: Colors.black,
                                    tooltip: 'ダミー a@x を削除',
                                    onPressed: () async {
                                      await _wipeDummyMessages(needle: 'a@x');
                                      await _diagAll();
                                      await _debugPrintMessagesCount();
                                      setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.sync),
                                    color: Colors.black,
                                    tooltip: 'allowedSenders を同期',
                                    onPressed: () async {
                                      await _syncAllowedSendersInbox();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.rule),
                                    color: Colors.black,
                                    tooltip: 'DB 状態ダンプ',
                                    onPressed: () async {
                                      await _diagAll();
                                      await _debugPrintMessagesCount();
                                    },
                                  ),
                                  // 既存の編集トグル
                                  InkWell(
                                    onTap: _toggleEditMode,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, anim) =>
                                            ScaleTransition(
                                              scale: anim,
                                              child: child,
                                            ),
                                        child: Icon(
                                          _isEditMode
                                              ? Icons.close
                                              : Icons.edit_outlined,
                                          key: ValueKey(_isEditMode),
                                          size: 30,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ダミーの検索ボタン
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {}, // TODO
                                icon: const Icon(Icons.search),
                                label: const Text('Search'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                  ),
                                  foregroundColor: Colors.black87,
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // リスト本体
                        StreamBuilder<List<_LinkedAccount>>(
                          stream: _streamLinkedAccounts(),
                          builder: (context, accSnap) {
                            final linked =
                                accSnap.data ?? const <_LinkedAccount>[];
                            return StreamBuilder<Set<String>>(
                              stream: _streamAllowedSenders(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const SliverFillRemaining(
                                    child: Center(
                                      child: Text('表示したい送信元アドレスを追加してください'),
                                    ),
                                  );
                                }
                                final allowedSenders = snapshot.data!;
                                _ensureFutures(allowedSenders, linked);

                                return FutureBuilder<
                                  List<Map<String, dynamic>>
                                >(
                                  future: _chatsFuture,
                                  builder: (context, futureSnapshot) {
                                    if (futureSnapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        futureSnapshot.connectionState ==
                                            ConnectionState.none) {
                                      return const SliverFillRemaining(
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    if (futureSnapshot.hasError) {
                                      return SliverFillRemaining(
                                        child: Center(
                                          child: Text(
                                            'Error: ${futureSnapshot.error}',
                                          ),
                                        ),
                                      );
                                    }

                                    final chatsRaw = futureSnapshot.data ?? [];
                                    if (chatsRaw.isEmpty) {
                                      return const SliverFillRemaining(
                                        child: Center(
                                          child: Text('一致するスレッドがありません'),
                                        ),
                                      );
                                    }

                                    _lastChatById.clear();
                                    _lastTimeByThread.clear();

                                    // 非表示対象を除外
                                    final visibleRaw = <Map<String, dynamic>>[];
                                    for (final m in chatsRaw) {
                                      final id =
                                          (m['threadId'] ?? m['id'] ?? '')
                                              .toString();
                                      final timeDt = m['timeDt'] as DateTime?;
                                      final hiddenAt =
                                          _hiddenSnapshotByThread[id];
                                      final shouldHide =
                                          (hiddenAt != null) &&
                                          (timeDt == null ||
                                              !timeDt.isAfter(hiddenAt));
                                      if (!shouldHide) visibleRaw.add(m);
                                    }

                                    if (visibleRaw.isEmpty) {
                                      return const SliverFillRemaining(
                                        child: Center(
                                          child: Text('表示項目はありません'),
                                        ),
                                      );
                                    }

                                    final chatList = visibleRaw
                                        .map((e) => _mapToChat(e))
                                        .toList();

                                    for (
                                      var i = 0;
                                      i < visibleRaw.length;
                                      i++
                                    ) {
                                      final m = visibleRaw[i];
                                      final id =
                                          (m['threadId'] ?? m['id'] ?? '')
                                              .toString();
                                      final dt = m['timeDt'] as DateTime?;
                                      _lastTimeByThread[id] = dt;
                                      _lastChatById[id] = chatList[i];
                                    }

                                    return FutureBuilder<Map<String, int>>(
                                      future:
                                          _unreadFuture ??
                                          Future.value(const <String, int>{}),
                                      builder: (context, usnap) {
                                        final unreadMap =
                                            usnap.data ?? const <String, int>{};

                                        return SliverList(
                                          delegate: SliverChildBuilderDelegate((
                                            context,
                                            index,
                                          ) {
                                            final chat = chatList[index];
                                            final unread =
                                                unreadMap[chat.senderEmail
                                                    .toLowerCase()] ??
                                                0;
                                            final selected = _selectedThreadIds
                                                .contains(chat.threadId);

                                            final tile = ListTile(
                                              minVerticalPadding: 10,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              tileColor: cs.surfaceVariant,
                                              leading: _avatar(chat.avatarUrl),
                                              title: Text(
                                                chat.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                chat.lastMessage,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: SizedBox(
                                                width: _kTrailingWidth,
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 150,
                                                  ),
                                                  switchInCurve:
                                                      Curves.easeOutCubic,
                                                  switchOutCurve:
                                                      Curves.easeInCubic,
                                                  layoutBuilder:
                                                      (
                                                        currentChild,
                                                        previousChildren,
                                                      ) => Stack(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        children: <Widget>[
                                                          ...previousChildren,
                                                          if (currentChild !=
                                                              null)
                                                            currentChild,
                                                        ],
                                                      ),
                                                  child: _isEditMode
                                                      ? Align(
                                                          key: ValueKey(
                                                            'cb_${chat.threadId}',
                                                          ),
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Checkbox(
                                                            value: selected,
                                                            onChanged: (v) {
                                                              setState(() {
                                                                if (v == true) {
                                                                  _selectedThreadIds
                                                                      .add(
                                                                        chat.threadId,
                                                                      );
                                                                } else {
                                                                  _selectedThreadIds
                                                                      .remove(
                                                                        chat.threadId,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                            checkColor:
                                                                Colors.black,
                                                            fillColor:
                                                                MaterialStateProperty.all(
                                                                  Colors.white,
                                                                ),
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .black,
                                                                  width: 2,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                      : Column(
                                                          key: ValueKey(
                                                            'info_${chat.threadId}',
                                                          ),
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Text(
                                                              chat.time,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    height: 1.0,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            _unreadChip(unread),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                              onTap: _isEditMode
                                                  ? () {
                                                      setState(() {
                                                        if (selected) {
                                                          _selectedThreadIds
                                                              .remove(
                                                                chat.threadId,
                                                              );
                                                        } else {
                                                          _selectedThreadIds
                                                              .add(
                                                                chat.threadId,
                                                              );
                                                        }
                                                      });
                                                    }
                                                  : () {
                                                      if (chat
                                                          .senderEmail
                                                          .isEmpty)
                                                        return;
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PersonChatScreen(
                                                                senderEmail: chat
                                                                    .senderEmail,
                                                                title:
                                                                    chat.name,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                            );

                                            if (_isEditMode) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                child: tile,
                                              );
                                            }

                                            // 通常時はスワイプで「一覧から非表示」
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              child: Slidable(
                                                key: ValueKey(chat.threadId),
                                                endActionPane: ActionPane(
                                                  motion: const ScrollMotion(),
                                                  children: [
                                                    SlidableAction(
                                                      onPressed: (_) async {
                                                        _hideOne(chat.threadId);
                                                      },
                                                      backgroundColor:
                                                          Colors.black,
                                                      foregroundColor:
                                                          Colors.white,
                                                      icon: Icons
                                                          .visibility_off_outlined,
                                                      label: '非表示',
                                                    ),
                                                  ],
                                                ),
                                                child: tile,
                                              ),
                                            );
                                          }, childCount: chatList.length),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        // 下部タブ分の余白
                        SliverToBoxAdapter(
                          child: SizedBox(height: bottomPad + 72),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // ===== 画面下の編集アクションバー =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                ignoring: !_isEditMode,
                child: AnimatedSlide(
                  offset: _isEditMode ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _isEditMode ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 削除アクション（選択式メニュー表示）
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                              onPressed: _selectedThreadIds.isEmpty
                                  ? null
                                  : () async {
                                      // 選択肢ボトムシート
                                      if (!mounted) return;
                                      final action =
                                          await showModalBottomSheet<
                                            _DeleteAction
                                          >(
                                            context: context,
                                            showDragHandle: true,
                                            builder: (ctx) => _DeleteMenu(
                                              count: _selectedThreadIds.length,
                                            ),
                                          );
                                      if (action == null) return;

                                      switch (action) {
                                        case _DeleteAction.hide:
                                          await _deleteSelectedFromView();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('一覧から非表示にしました'),
                                            ),
                                          );
                                          break;
                                        case _DeleteAction.local:
                                          await _deleteSelectedLocally();
                                          break;
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline),
                              label: Text('削除 (${_selectedThreadIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 一括既読（DB/Gmailを更新）
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                              onPressed: _selectedThreadIds.isEmpty
                                  ? null
                                  : () async => _markSelectedRead(),
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: Text('既読 (${_selectedThreadIds.length})'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _LinkedAccount? _currentUserAsLinked() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || (u.email ?? '').isEmpty) return null;
    return _LinkedAccount(
      email: (u.email ?? '').toLowerCase(),
      displayName: u.displayName ?? '',
      photoUrl: u.photoURL ?? '',
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

// ----------------- サブ部品：削除メニュー -----------------

enum _DeleteAction { hide, local }

class _DeleteMenu extends StatelessWidget {
  final int count;
  const _DeleteMenu({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text('一覧から非表示（$count 件）'),
              subtitle: const Text('現在の最新時刻までを隠します。新着は再表示されます。'),
              onTap: () => Navigator.pop(context, _DeleteAction.hide),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text('ローカルDBから削除（$count 件）'),
              subtitle: const Text('端末内の保存データを消します。Gmail本体は消しません。'),
              onTap: () => Navigator.pop(context, _DeleteAction.local),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ----------------- サブウィジェット（アカウント切替バー） -----------------

class _AllButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final bool dark;
  const _AllButton({
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = dark
        ? (selected ? Colors.white : Colors.white54)
        : (selected ? Colors.black : Colors.black26);
    final fg = dark
        ? (selected ? Colors.black : Colors.white)
        : (selected ? Colors.white : Colors.black87);
    final bg = dark
        ? (selected ? Colors.white : Colors.black)
        : (selected ? Colors.black : Colors.white);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Text(
            'All',
            style: TextStyle(fontWeight: FontWeight.bold, color: fg),
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final _LinkedAccount account;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;
  const _AccountAvatar({
    required this.account,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = dark
        ? (selected ? Colors.white : Colors.white54)
        : (selected ? Colors.black : Colors.black26);
    final textColor = dark ? Colors.white : Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundImage: (account.photoUrl.isNotEmpty)
              ? NetworkImage(account.photoUrl)
              : null,
          backgroundColor: dark ? Colors.white10 : null,
          child: (account.photoUrl.isEmpty)
              ? Text(
                  account.email.isNotEmpty
                      ? account.email[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _AddAccountButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool dark;
  const _AddAccountButton({required this.onTap, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Colors.black : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: ShapeDecoration(color: bg, shape: const CircleBorder()),
          child: const Icon(Icons.add_circle, size: 48, color: Colors.white),
        ),
      ),
    );
  }
}

class _AccountsBar extends StatelessWidget {
  final Stream<List<_LinkedAccount>> streamLinkedAccounts;
  final String? activeAccountEmail; // null = All
  final Future<void> Function(String?) switchToAccount;
  final Future<void> Function() linkGoogleAccount;
  final _LinkedAccount? currentUser;

  const _AccountsBar({
    required this.streamLinkedAccounts,
    required this.activeAccountEmail,
    required this.switchToAccount,
    required this.linkGoogleAccount,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Linked Accounts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<_LinkedAccount>>(
              stream: streamLinkedAccounts,
              builder: (context, snapshot) {
                final fetched = snapshot.data ?? const <_LinkedAccount>[];
                final accounts = <_LinkedAccount>[
                  if (currentUser != null &&
                      !fetched.any(
                        (a) =>
                            a.email.toLowerCase() ==
                            currentUser!.email.toLowerCase(),
                      ))
                    currentUser!,
                  ...fetched,
                ];

                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _AllButton(
                          selected: activeAccountEmail == null,
                          onTap: () => switchToAccount(null),
                          dark: true,
                        ),
                        const SizedBox(width: 12),
                        ...accounts.map((a) {
                          final isSelected =
                              activeAccountEmail != null &&
                              a.email.toLowerCase() ==
                                  activeAccountEmail!.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _AccountAvatar(
                              account: a,
                              selected: isSelected,
                              onTap: () => switchToAccount(a.email),
                              dark: true,
                            ),
                          );
                        }),
                        _AddAccountButton(onTap: linkGoogleAccount, dark: true),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
