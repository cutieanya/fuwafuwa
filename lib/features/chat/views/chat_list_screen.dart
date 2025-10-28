// lib/features/chat/views/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fuwafuwa/features/chat/services/gmail_service.dart';
import 'package:fuwafuwa/features/chat/services/gmail_send_service.dart';
import 'package:fuwafuwa/features/chat/views/compose_email_screen.dart';
import '../../auth/view/lobby_page.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const double _accountsBarHeight = 74;
  static const double _revealDistance = 120;

  final _service = GmailService();
  final _addrController = TextEditingController();

  // 送信ユーティリティ
  final GmailSendService _sendSvc = GmailSendService();

  // GoogleSignIn（アカウント追加/切替）
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/gmail.send',
    ],
  );

  String? _activeAccountEmail;

  double _revealT = 0.0;
  double _pullAccum = 0.0;

  DocumentReference<Map<String, dynamic>> get _filtersDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('未ログインです。LobbyPage からログインしてから遷移してください。');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('filters');
  }

  DocumentReference<Map<String, dynamic>> get _accountsDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('未ログインです。LobbyPage からログインしてから遷移してください。');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('accounts');
  }

  @override
  void dispose() {
    _addrController.dispose();
    super.dispose();
  }

  // ---------- Firestore (filters) ----------
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

  // ---------- Firestore (linked Google accounts) ----------
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

      setState(() => _activeAccountEmail = account.email.toLowerCase());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アカウントを追加しました：${account.email}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('追加に失敗: $e')));
    }
  }

  Future<void> _switchToAccount(String? email) async {
    setState(() => _activeAccountEmail = email);
    if (email == null) return;

    try {
      await _gsi.signOut();
      final account = await _gsi.signIn();
      if (account == null) return;
      if (account.email.toLowerCase() != email.toLowerCase()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選択と異なるため、${account.email} を使用します')),
        );
        setState(() => _activeAccountEmail = account.email.toLowerCase());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切替に失敗: $e')));
    }
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
      final da = a['timeDt'] is DateTime ? a['timeDt'] as DateTime : null;
      final db = b['timeDt'] is DateTime ? b['timeDt'] as DateTime : null;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return list;
  }

  // ---------- UI ユーティリティ ----------
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  Future<void> _showAddSenderDialog() async {
    _addrController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('表示する送信元アドレスを追加'),
        content: TextField(
          controller: _addrController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: user@example.com'),
          onSubmitted: (_) => Navigator.of(context).pop(_addrController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_addrController.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _addAllowedSender(result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('送信元を追加しました')));
    }
  }

  Future<void> _markSenderAllRead(String senderEmail) async {
    final q = 'from:${senderEmail.toLowerCase()} is:unread';
    final n = await _service.markReadByQuery(q);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$n 件を既読にしました')));
    setState(() {});
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification) {
      if (n.metrics.pixels <= 0) {
        final add = n.overscroll.abs();
        _pullAccum += add;
      }
    } else if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels > 0 || (n.scrollDelta ?? 0) > 0) {
        _pullAccum = 0.0;
      }
    } else if (n is ScrollEndNotification) {
      if (_pullAccum < _revealDistance * 0.3) {
        _pullAccum = 0.0;
      }
    }

    final t = (_pullAccum / _revealDistance).clamp(0.0, 1.0);
    if (t != _revealT) {
      setState(() => _revealT = t);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSenderDialog,
        label: const Text('送信元追加'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              SliverAppBar(
                title: const Text('チャット'),
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.home),
                    tooltip: 'ロビーへ戻る',
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LobbyPage()),
                      );
                    },
                  ),
                ],
              ),
            ],
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: _buildBody(cs),
            ),
          ),

          // 黒いアカウントバー
          Positioned(
            left: 0,
            right: 0,
            top: topInset + kToolbarHeight - _accountsBarHeight,
            height: _accountsBarHeight,
            child: IgnorePointer(
              ignoring: _revealT < 0.85,
              child: AnimatedOpacity(
                opacity: _revealT,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Transform.translate(
                  offset: Offset(0, (1 - _revealT) * 14),
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    alignment: Alignment.centerLeft,
                    child: StreamBuilder<List<_LinkedAccount>>(
                      stream: _streamLinkedAccounts(),
                      builder: (context, snap) {
                        final accounts = snap.data ?? const <_LinkedAccount>[];
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _AllChip(
                                selected: _activeAccountEmail == null,
                                onTap: () => _switchToAccount(null),
                                dark: true,
                              ),
                              const SizedBox(width: 8),
                              ...accounts.map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _AccountAvatar(
                                    account: a,
                                    selected:
                                        _activeAccountEmail?.toLowerCase() ==
                                        a.email.toLowerCase(),
                                    onTap: () => _switchToAccount(a.email),
                                    dark: true,
                                  ),
                                ),
                              ),
                              _AddAccountButton(
                                onTap: _linkGoogleAccount,
                                dark: true,
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildBody(ColorScheme cs) {
    return StreamBuilder<Set<String>>(
      stream: _streamAllowedSenders(),
      builder: (context, snap) {
        final allowed = snap.data ?? const <String>{};

        if (allowed.isEmpty) {
          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: const [
              SizedBox(height: 160),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('右下の「＋」から表示したい送信元を追加してください'),
                ),
              ),
              SizedBox(height: 600),
            ],
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadChatsFor(allowed),
          builder: (context, fsnap) {
            if (fsnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (fsnap.hasError) {
              return Center(child: Text('Error: ${fsnap.error}'));
            }

            final chatsRaw = fsnap.data ?? const <Map<String, dynamic>>[];
            if (chatsRaw.isEmpty) {
              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('一致するスレッドがありません')),
                  SizedBox(height: 600),
                ],
              );
            }

            final senderToLatest = <String, Map<String, dynamic>>{};
            for (final m in chatsRaw) {
              final email = ((m['fromEmail'] ?? '') as String).toLowerCase();
              if (email.isNotEmpty) senderToLatest[email] = m;
            }

            return FutureBuilder<Map<String, int>>(
              future: _loadUnreadCounts(allowed),
              builder: (context, usnap) {
                final unreadMap = usnap.data ?? const <String, int>{};
                final chatList = senderToLatest.values.map(_mapToChat).toList();

                return ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: chatList.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final chat = chatList[index];
                    final unread =
                        unreadMap[chat.senderEmail.toLowerCase()] ?? 0;

                    return Slidable(
                      key: ValueKey(chat.threadId),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              await _markSenderAllRead(chat.senderEmail);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${chat.name} を既読にしました'),
                                ),
                              );
                              setState(() {});
                            },
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            icon: Icons.mark_email_read,
                            label: '既読',
                          ),
                        ],
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: cs.surfaceContainerHighest,
                        leading: _avatarWithBadge(chat.avatarUrl, unread),
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
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              chat.time,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            _unreadChip(unread),
                          ],
                        ),
                        onTap: () async {
                          if (chat.senderEmail.isEmpty) return;

                          var account =
                              _gsi.currentUser ?? await _gsi.signInSilently();
                          account ??= await _gsi.signIn();
                          if (account == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Googleアカウントにサインインしてください'),
                              ),
                            );
                            return;
                          }
                          final headers = await account.authHeaders;
                          final fromAddress = account.email;

                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComposeEmailScreen(
                                initialTo: chat.senderEmail,
                                initialFrom: fromAddress,
                                authHeaders: headers,
                                sendSvc: _sendSvc,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Map -> Chat 表示モデル
  _Chat _mapToChat(Map<String, dynamic> m) {
    final threadId = (m['threadId'] ?? m['id'] ?? '').toString();
    final name = (m['counterpart'] ?? m['from'] ?? '(unknown)').toString();
    final lastMessage = (m['lastMessage'] ?? m['snippet'] ?? '(No message)')
        .toString();
    final time = (m['time'] ?? '').toString();
    final senderEmail = (m['fromEmail'] ?? _extractEmail(name) ?? '')
        .toString();

    const avatar = 'https://placehold.jp/150x150.png';

    return _Chat(
      threadId: threadId,
      name: name,
      lastMessage: lastMessage,
      time: time,
      avatarUrl: avatar,
      senderEmail: senderEmail,
    );
  }

  // アバター＋未読バッジ
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

  // 未読チップ
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
}

// --- 表示モデル（private） ---
class _Chat {
  final String threadId;
  final String name;
  final String lastMessage;
  final String time;
  final String avatarUrl;
  final String senderEmail;

  _Chat({
    required this.threadId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
    required this.senderEmail,
  });
}

// ===== サブウィジェット =====
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

class _AllChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final bool dark; // 黒バー用スタイル
  const _AllChip({
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? (selected ? Colors.white : Colors.black)
        : (selected ? Colors.black : Colors.white);
    final fg = dark
        ? (selected ? Colors.black : Colors.white)
        : (selected ? Colors.white : Colors.black87);
    final border = dark ? Colors.white54 : Colors.black26;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? fg : border, width: 1),
          ),
        ),
        child: Text(
          'All',
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
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
    final border = dark ? Colors.white54 : Colors.black26;
    final fg = dark ? Colors.white : Colors.black87;
    final bg = dark ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            color: bg,
            shape: StadiumBorder(side: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 20, color: fg),
              const SizedBox(width: 6),
              Text(
                '追加',
                style: TextStyle(fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
