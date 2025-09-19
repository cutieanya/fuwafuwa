// chat_beta_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fuwafuwa/features/chat/views/person_chat_screen.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';
import 'pull_down_reveal.dart';

// ----------------- モデル -----------------
class Chat {
  final String threadId;
  final String name;
  final String lastMessage;
  final String time;
  final String avatarUrl;
  final String senderEmail;
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
  final _service = GmailService();
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  // 行末の表示領域を固定してリレイアウトを抑える
  static const double _kTrailingWidth = 92.0;

  String? _activeAccountEmail; // null = All
  bool _isEditMode = false;
  final Set<String> _selectedThreadIds = {};
  final Map<String, DateTime?> _hiddenSnapshotByThread = {};
  final Map<String, Chat> _lastChatById = {};
  final Map<String, DateTime?> _lastTimeByThread = {};

  // ===== Futureキャッシュ（無駄なリロード抑制） =====
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
  }

  Future<void> _bootstrapSignIn() async {
    try {
      final acc = await _gsi.signInSilently();
      if (!mounted) return;
      _activeAccountEmail = acc?.email.toLowerCase();
      await _refreshServiceAuth(); // ★ 認証同期
      setState(() {});
    } catch (_) {
      // 無視（Allで動かす）
    }
  }

  // ★ GmailService の認証を現在の GoogleSignIn ユーザーで更新
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

  // ---------- Filters ----------
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

  // ---------- Linked Accounts ----------
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

  /// アカウント切替（signOutしない / 認証更新する）
  Future<void> _switchToAccount(String? email) async {
    setState(() {
      _activeAccountEmail = email; // null = All
      _isEditMode = false;
      _selectedThreadIds.clear();
      _chatsFutureKey = ''; // 条件変わるのでキャッシュ無効化
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

    await _refreshServiceAuth(); // ここが肝
  }

  // ---------- Gmail 取得 ----------
  Future<List<Map<String, dynamic>>> _loadChatsFor(Set<String> senders) async {
    if (senders.isEmpty) return const <Map<String, dynamic>>[];
    final list = await _service.fetchThreadsBySenders(
      senders: senders.toList(),
      newerThan: '30d',
      maxResults: 20,
      limit: 200,
    );
    return _dedupBySender(list);
  }

  Future<List<Map<String, dynamic>>> _loadChatsUnified(
    Set<String> senders,
    List<_LinkedAccount> _linked,
  ) async {
    return _loadChatsFor(senders); // 将来：複数アカウント横断
  }

  Future<Map<String, int>> _loadUnreadCounts(Set<String> senders) {
    if (senders.isEmpty) return Future.value(<String, int>{});
    return _service.countUnreadBySenders(
      senders.toList(),
      newerThan: '365d',
      pageSize: 50,
      capPerSender: 500,
    );
  }

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

      final shouldReplace =
          (current == null) ||
          (newTime != null && (curTime == null || newTime.isAfter(curTime)));

      if (shouldReplace) {
        m['fromEmail'] = key;
        bySender[key] = m;
      }
    }
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

  // ---------- UIユーティリティ ----------
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  // 送信元の未読を一括既読（スナックバーは出さない）
  Future<int> _markSenderAllRead(String senderEmail) async {
    final q = 'from:${senderEmail.toLowerCase()} is:unread';
    final n = await _service.markReadByQuery(q);
    return n;
  }

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

  Widget _avatarWithBadge(String avatarUrl, int unread) {
    return Stack(
      children: [
        CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
        if (unread > 0)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

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
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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

  // ---------- 編集モード ----------
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedThreadIds.clear();
    });
  }

  Future<void> _deleteSelectedFromView() async {
    for (final tid in _selectedThreadIds) {
      _hiddenSnapshotByThread[tid] = _lastTimeByThread[tid];
    }
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  Future<void> _markSelectedRead() async {
    if (_selectedThreadIds.isEmpty) return;
    final emails = <String>{};
    for (final tid in _selectedThreadIds) {
      final chat = _lastChatById[tid];
      if (chat != null && chat.senderEmail.isNotEmpty) {
        emails.add(chat.senderEmail.toLowerCase());
      }
    }
    for (final e in emails) {
      await _markSenderAllRead(e);
    }
    _invalidateUnreadCache(); // 未読数を即更新
    setState(() {
      _selectedThreadIds.clear();
    });
  }

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
                        // ヘッダー
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

                        // 検索ボタン
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {},
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

                        // リスト
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

                                    return FutureBuilder<Map<String, int>>(
                                      future: _unreadFuture,
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
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              tileColor: cs.surfaceVariant,
                                              leading: _avatarWithBadge(
                                                chat.avatarUrl,
                                                unread,
                                              ),
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
                                              // ★ 固定幅 + AnimatedSwitcher で切替
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
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 6,
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
                                              // 編集モード中は Slidable 無効
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                child: tile,
                                              );
                                            }

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
                                                        _invalidateUnreadCache();
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

          // ===== 画面下の編集アクションバー（常に置いてアニメで出し入れ） =====
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
                          // 削除（一覧から一時的に隠す）
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
                          // 既読（通知なし / 黒角丸ボタン）
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

// ----------------- サブウィジェット -----------------
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
