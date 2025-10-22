// chat_beta_screen.dart
//
// 目的：指定送信元の Gmail スレッドを“人ごと一覧”で表示する画面。
// - 上段：アカウント切替バー（PullDownReveal の背面）
// - 下段：メール一覧（スレッドの最新メッセージ基準、送信元ごとに 1 行）
// - 右側のトレーリングには 日時 + 未読件数バッジ（アイコン横のバッジは出さない）
// - 編集モードではチェックボックスを表示、下部に一括操作バーをスライド表示。
// - 既読操作後は未読キャッシュを無効化して再取得（UI を即更新）
//
// 補足：UI の「BOTTOM OVERFLOWED ～」回避のため、トレーリングは固定幅にし、
//       mainAxisSize を min に、ListTile に minVerticalPadding を与えています。

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fuwafuwa/features/chat/views/person_chat_screen.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';
import 'pull_down_reveal.dart';

// ----------------- モデル -----------------

/// 一覧 1 行分の最終メッセージ情報（送信元ごとに最新のみ）
class Chat {
  final String threadId; // スレッドID（画面遷移や重複排除に使用）
  final String name; // 表示名（From の表示名）
  final String lastMessage; // スニペット（本文冒頭）
  final String time; // 表示用の時刻文字列（例 2025/9/19 19:11）
  final String avatarUrl; // アバター画像URL（今はプレースホルダ固定）
  final String senderEmail; // 左右判定/既読対象に使う From のメールアドレス
  Chat({
    required this.threadId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
    required this.senderEmail,
  });
}

/// 連携済み Google アカウント（Firestore に保存）
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
  // Gmail REST を直接叩くサービス（google_sign_in のトークンを渡す）
  final _service = GmailService();

  // 画面側でも Google Sign-In を持っておき、アカウント切替などに使用
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  // ------ レイアウト調整系 ------

  /// トレーリング領域の固定幅
  /// - AnimatedSwitcher で情報とチェックボックス切替時のレイアウト揺れ防止
  /// - 未読チップのオーバーフローも出にくくなる
  static const double _kTrailingWidth = 96.0;

  // ------ 画面状態 ------

  String? _activeAccountEmail; // null = All（将来的にアカウント横断用）
  bool _isEditMode = false; // 編集モード（チェック表示 & 下部アクションバー）
  final Set<String> _selectedThreadIds = {}; // 編集モードの選択セット

  /// 一時的な「一覧からの非表示スナップショット」
  /// - 指定スレッドの最新時刻を記録し、以後その時刻より古いメッセージは隠す
  final Map<String, DateTime?> _hiddenSnapshotByThread = {};

  /// スレッドID → 最後に描画した Chat データ（既読一括時の送信元取得などで使用）
  final Map<String, Chat> _lastChatById = {};

  /// スレッドID → 最新メッセージの DateTime（_hiddenSnapshot 判定用）
  final Map<String, DateTime?> _lastTimeByThread = {};

  // ------ 取得キャッシュ（不要な再ロード抑制） ------

  Future<List<Map<String, dynamic>>>? _chatsFuture;
  String _chatsFutureKey = ''; // キーが変わったら Future を作り直す
  Future<Map<String, int>>? _unreadFuture;
  String _unreadFutureKey = '';

  /// Set を安定化させるためのキー文字列化（差分検知用）
  String _sendersKey(Set<String> s) {
    final l = s.toList()..sort();
    return l.join(',');
  }

  /// 条件が変わったときだけ Future を差し替える
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

  /// 未読バッジだけ速く更新したいときに呼ぶ（既読操作後など）
  void _invalidateUnreadCache() {
    _unreadFutureKey = '';
  }

  // ---------- 起動時：サイレントサインイン ----------

  @override
  void initState() {
    super.initState();
    _bootstrapSignIn();
  }

  /// 可能なら無操作でサインイン → サービス側の認証ヘッダも同期
  Future<void> _bootstrapSignIn() async {
    try {
      final acc = await _gsi.signInSilently();
      if (!mounted) return;
      _activeAccountEmail = acc?.email.toLowerCase();
      await _refreshServiceAuth(); // 認証同期（GmailService に Bearer を渡す）
      setState(() {});
    } catch (_) {
      // サイレント失敗は無視（All として動作させる）
    }
  }

  /// GmailService に現在のアクセストークンを渡す
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

  // ---------- Firestore パス（ユーザー毎の設定保存先） ----------

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

  /// 表示許可の送信元アドレス集合を購読
  Stream<Set<String>> _streamAllowedSenders() {
    return _filtersDoc.snapshots().map((snap) {
      final list =
          (snap.data()?['allowedSenders'] as List?)?.cast<String>() ??
          const <String>[];
      return list.map((e) => e.toLowerCase()).toSet();
    });
  }

  /// 送信元アドレスを 1 件追加
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

  /// 送信元アドレスを 1 件削除
  Future<void> _removeAllowedSender(String email) async {
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayRemove([email.toLowerCase()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Linked Accounts（複数アカウント連携） ----------

  /// 連携済みアカウントのリストを購読
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

  /// Google アカウントを 1 件追加（サインイン成功で Firestore に保存）
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
      await _refreshServiceAuth(); // Bearer 反映
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

  /// アカウント切替（signOut しない。必要なら signIn を促す）
  Future<void> _switchToAccount(String? email) async {
    // まずローカル状態とキャッシュキーを更新
    setState(() {
      _activeAccountEmail = email; // null = All
      _isEditMode = false;
      _selectedThreadIds.clear();
      _chatsFutureKey = ''; // 条件が変わるので invalidate
      _unreadFutureKey = '';
    });

    if (email == null) return; // All の場合はここで終わり

    // 現在のアカウントが違う場合はサインイン（ユーザーにアカウント選択 UI が出る）
    final cur = await _gsi.signInSilently();
    if (!(cur != null && cur.email.toLowerCase() == email.toLowerCase())) {
      final acc = await _gsi.signIn();
      if (acc == null) return;
      if (!mounted) return;
      // 要求と違うメールでサインインされた場合のフォールバック
      if (acc.email.toLowerCase() != email.toLowerCase()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('選択と異なるため、${acc.email} を使用します')));
        setState(() => _activeAccountEmail = acc.email.toLowerCase());
      }
    }

    // サービス側のヘッダを更新
    await _refreshServiceAuth();
  }

  // ---------- Gmail 取得（サービス層呼び出し） ----------

  /// 指定送信元 set にマッチするスレッドの「最新メッセージ」を取得 → 送信元で 1 行化
  Future<List<Map<String, dynamic>>> _loadChatsFor(Set<String> senders) async {
    if (senders.isEmpty) return const <Map<String, dynamic>>[];
    final list = await _service.fetchThreadsBySenders(
      senders: senders.toList(),
      newerThan: '30d', // 直近 30 日に限定（クエリを軽量化）
      maxResults: 20,
      limit: 200,
    );
    return _dedupBySender(list);
  }

  /// 将来は複数アカウント横断をここで統合。今は単一アカウントと同じ。
  Future<List<Map<String, dynamic>>> _loadChatsUnified(
    Set<String> senders,
    List<_LinkedAccount> _linked,
  ) async {
    return _loadChatsFor(senders);
  }

  /// 複数送信元の未読件数まとめて取得（UI の右側バッジ用）
  Future<Map<String, int>> _loadUnreadCounts(Set<String> senders) {
    if (senders.isEmpty) return Future.value(<String, int>{});
    return _service.countUnreadBySenders(
      senders.toList(),
      newerThan: '365d',
      pageSize: 50,
      capPerSender: 500, // 99+ のように丸める上限
    );
  }

  /// 同一送信元の最新だけを残す（人ごと一覧にしたいので）
  List<Map<String, dynamic>> _dedupBySender(List<Map<String, dynamic>> raw) {
    final bySender = <String, Map<String, dynamic>>{};
    for (final m in raw) {
      final email = ((m['fromEmail'] ?? '') as String).toLowerCase();
      final fallbackEmail = email.isNotEmpty
          ? email
          : _extractEmail((m['from'] ?? m['counterpart'] ?? '').toString()) ??
                '';
      final key = fallbackEmail;
      if (key.isEmpty) continue;

      final current = bySender[key];
      final newTime = m['timeDt'] is DateTime ? m['timeDt'] as DateTime : null;
      final curTime = (current != null && current['timeDt'] is DateTime)
          ? current['timeDt'] as DateTime
          : null;

      // より新しいものを残す
      final shouldReplace =
          (current == null) ||
          (newTime != null && (curTime == null || newTime.isAfter(curTime)));

      if (shouldReplace) {
        m['fromEmail'] = key; // 正規化したメールを入れておく
        bySender[key] = m;
      }
    }
    // 新しい順に並べ替え
    final list = bySender.values.toList();
    list.sort((a, b) {
      final da = a['timeDt'] as DateTime?;
      final db = b['timeDt'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return list;
  }

  // ---------- UI ユーティリティ ----------

  /// "表示名 <addr@x>" / "addr@x" からメールだけ抜き出す
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  /// 指定送信元の未読を一括で既読（Gmail batchModify）→ 件数を返す
  Future<int> _markSenderAllRead(String senderEmail) async {
    final q = 'from:${senderEmail.toLowerCase()} is:unread';
    final n = await _service.markReadByQuery(q);
    return n;
  }

  /// サービスの Map 形式を画面用の Chat へ整形
  Chat _mapToChat(Map<String, dynamic> m) {
    final threadId = (m['threadId'] ?? m['id'] ?? '').toString();
    final name = (m['counterpart'] ?? m['from'] ?? '(unknown)').toString();
    final lastMessage = (m['lastMessage'] ?? m['snippet'] ?? '(No message)')
        .toString();
    final time = (m['time'] ?? '').toString();
    final senderEmail = (m['fromEmail'] ?? _extractEmail(name) ?? '')
        .toString();
    const avatar = 'https://placehold.jp/150x150.png';
    return Chat(
      threadId: threadId,
      name: name,
      lastMessage: lastMessage,
      time: time,
      avatarUrl: avatar,
      senderEmail: senderEmail,
    );
  }

  /// バッジ無しのアバター（左側）
  Widget _avatar(String avatarUrl) {
    return CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl));
  }

  /// 右側の未読チップ（小さめ・行間詰めでオーバーフロー回避）
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

  /// FirebaseAuth の現在ユーザーを連携リストに混ぜるための簡易変換
  _LinkedAccount? _currentUserAsLinked() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || (u.email ?? '').isEmpty) return null;
    return _LinkedAccount(
      email: (u.email ?? '').toLowerCase(),
      displayName: u.displayName ?? '',
      photoUrl: u.photoURL ?? '',
    );
  }

  // ---------- 編集モード ----------

  /// 右上ボタンで編集モード切替
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedThreadIds.clear();
    });
  }

  /// 選択したスレッドを“一覧から一時非表示”にする（データ削除ではない）
  Future<void> _deleteSelectedFromView() async {
    for (final tid in _selectedThreadIds) {
      _hiddenSnapshotByThread[tid] = _lastTimeByThread[tid];
    }
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  /// 選択したスレッドの送信元ごとに未読を一括既読
  Future<void> _markSelectedRead() async {
    if (_selectedThreadIds.isEmpty) return;
    final emails = <String>{};
    for (final tid in _selectedThreadIds) {
      final chat = _lastChatById[tid];
      if (chat != null && chat.senderEmail.isNotEmpty) {
        emails.add(chat.senderEmail.toLowerCase());
      }
    }
    // 送信元単位で既読化（API の呼び出し回数は送信元数分）
    for (final e in emails) {
      await _markSenderAllRead(e);
    }
    // 未読バッジをすぐ更新させる
    _invalidateUnreadCache();
    setState(() {
      _selectedThreadIds.clear();
    });
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
          // ===== 1. PullDownReveal（背面バー + 前面スクロール） =====
          Column(
            children: [
              Expanded(
                child: PullDownReveal(
                  minChildSize: 0.8, // つまみを引っ張ると 0.8 まで縮む
                  handle: false, // ハンドル非表示（デザイン都合）
                  // 背面：アカウント切替バー
                  backBar: _AccountsBar(
                    streamLinkedAccounts: _streamLinkedAccounts(),
                    activeAccountEmail: _activeAccountEmail,
                    switchToAccount: _switchToAccount,
                    linkGoogleAccount: _linkGoogleAccount,
                    currentUser: currentAsLinked,
                  ),
                  // 前面：メール一覧
                  frontBuilder: (scroll) {
                    return CustomScrollView(
                      controller: scroll,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // --- ヘッダー（タイトル + 編集ボタン） ---
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
                                  // 編集/完了 トグル
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

                        // --- 検索ボタン（ダミー） ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {}, // TODO: 検索画面へ
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

                        // --- リスト本体 ---
                        StreamBuilder<List<_LinkedAccount>>(
                          stream: _streamLinkedAccounts(),
                          builder: (context, accSnap) {
                            final linked =
                                accSnap.data ?? const <_LinkedAccount>[];
                            return StreamBuilder<Set<String>>(
                              stream: _streamAllowedSenders(),
                              builder: (context, snapshot) {
                                // フィルタ未設定時の空状態
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const SliverFillRemaining(
                                    child: Center(
                                      child: Text('表示したい送信元アドレスを追加してください'),
                                    ),
                                  );
                                }
                                final allowedSenders = snapshot.data!;
                                _ensureFutures(
                                  allowedSenders,
                                  linked,
                                ); // Future をセット/再利用

                                return FutureBuilder<
                                  List<Map<String, dynamic>>
                                >(
                                  future: _chatsFuture,
                                  builder: (context, futureSnapshot) {
                                    // ローディング
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
                                    // 取得失敗
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

                                    // 一時非表示ロジックのための準備
                                    _lastChatById.clear();
                                    _lastTimeByThread.clear();

                                    // 非表示対象を除外
                                    final visibleRaw = <Map<String, dynamic>>[];
                                    for (final m in chatsRaw) {
                                      final threadId =
                                          (m['threadId'] ?? m['id'] ?? '')
                                              .toString();
                                      final timeDt = m['timeDt'] is DateTime
                                          ? m['timeDt'] as DateTime
                                          : null;
                                      final hiddenAt =
                                          _hiddenSnapshotByThread[threadId];
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

                                    // 画面用モデルへ変換
                                    final chatList = visibleRaw
                                        .map((e) => _mapToChat(e))
                                        .toList();
                                    for (
                                      var i = 0;
                                      i < visibleRaw.length;
                                      i++
                                    ) {
                                      final m = visibleRaw[i];
                                      final tid =
                                          (m['threadId'] ?? m['id'] ?? '')
                                              .toString();
                                      final dt = m['timeDt'] is DateTime
                                          ? m['timeDt'] as DateTime
                                          : null;
                                      _lastTimeByThread[tid] = dt;
                                      _lastChatById[tid] = chatList[i];
                                    }

                                    // 未読件数の Future
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

                                            // 1 行分
                                            final tile = ListTile(
                                              // ▼▼▼ ここがオーバーフロー対策の肝 ▼▼▼
                                              minVerticalPadding:
                                                  10, // タイル上下に余裕を持たせる
                                              // contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // 古い Flutter ならこっち
                                              // ▲▲▲
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

                                              // 右端（固定幅）: 編集モード ↔ 情報 表示切替
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
                                                  // 切替時に高さがズレないよう Stack で重ねる
                                                  layoutBuilder:
                                                      (
                                                        currentChild,
                                                        previousChildren,
                                                      ) {
                                                        return Stack(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          children: <Widget>[
                                                            ...previousChildren,
                                                            if (currentChild !=
                                                                null)
                                                              currentChild,
                                                          ],
                                                        );
                                                      },
                                                  child: _isEditMode
                                                      // 編集中：チェックボックス
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
                                                      // 通常：時刻 + 未読チップ
                                                      : Column(
                                                          key: ValueKey(
                                                            'info_${chat.threadId}',
                                                          ),
                                                          mainAxisSize: MainAxisSize
                                                              .min, // ← 高さを必要最小限に
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
                                              // タップ：編集中は選択トグル、通常はトーク画面へ
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

                                            // 編集モード中はスワイプ無効
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

                                            // 通常時はスワイプで「既読」
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
                                                        await _markSenderAllRead(
                                                          chat.senderEmail,
                                                        );
                                                        _invalidateUnreadCache(); // バッジ即更新
                                                        setState(() {});
                                                      },
                                                      backgroundColor:
                                                          Colors.black,
                                                      foregroundColor:
                                                          Colors.white,
                                                      icon: Icons
                                                          .mark_email_read_outlined,
                                                      label: '既読',
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

                        // 下部タブ分の余白（デバイスのセーフエリアも考慮）
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

          // ===== 2. 画面下の編集アクションバー（常に配置してアニメで入れ替え） =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                ignoring: !_isEditMode, // 非表示時はタップを無効化
                child: AnimatedSlide(
                  offset: _isEditMode
                      ? Offset.zero
                      : const Offset(0, 1), // 下にスライドアウト
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
                          // 削除（= 一覧から一時的に隠す）
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
                                      await _deleteSelectedFromView();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('一覧から非表示にしました'),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.delete_outline),
                              label: Text('削除 (${_selectedThreadIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 既読（= 送信元ごとに一括既読）
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
                // 現在ログイン中のアカウントが Firestore の linked にない場合は先頭に表示
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
