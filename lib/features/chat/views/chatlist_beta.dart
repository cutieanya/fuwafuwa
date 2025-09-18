// chat_beta_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fuwafuwa/features/chat/views/person_chat_screen.dart'; // 必要に応じてパスを修正
import 'package:fuwafuwa/features/chat/services/gmail_service.dart'; // GmailService のインポート
import 'package:fuwafuwa/features/auth/view/lobby_page.dart'; // LobbyPage のインポート
import 'pull_down_reveal.dart';

// --- データのモデルクラス（元のファイルから） ---
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

// --- StatefulWidget に変更 ---
class ChatBetaScreen extends StatefulWidget {
  const ChatBetaScreen({super.key});

  @override
  State<ChatBetaScreen> createState() => _ChatBetaScreenState();
}

class _ChatBetaScreenState extends State<ChatBetaScreen> {
  final _service = GmailService();
  final _addrController = TextEditingController();

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  String? _activeAccountEmail;

  // ===== Firestore パス =====
  DocumentReference<Map<String, dynamic>> get _filtersDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // 実際にはログインページに遷移させるべきですが、今回はエラーを投げます
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

  Future<void> _markSenderAllRead(String senderEmail) async {
    final q = 'from:${senderEmail.toLowerCase()} is:unread';
    final n = await _service.markReadByQuery(q);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$n 件を既読にしました')));
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
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
              ),
              frontBuilder: (scroll) {
                return CustomScrollView(
                  controller: scroll,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ヘッダー：左「Chat」右「Edit」(黒丸ボタン)
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
                              Tooltip(
                                message: 'Edit',
                                child: InkWell(
                                  onTap: () {},
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.edit_outlined,
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
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
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
                    // チャットリスト
                    StreamBuilder<Set<String>>(
                      stream: _streamAllowedSenders(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SliverFillRemaining(
                            child: Center(child: Text('表示したい送信元アドレスを追加してください')),
                          );
                        }
                        final allowedSenders = snapshot.data!;

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadChatsFor(allowedSenders),
                          builder: (context, futureSnapshot) {
                            if (futureSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SliverFillRemaining(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (futureSnapshot.hasError) {
                              return SliverFillRemaining(
                                child: Center(
                                  child: Text('Error: ${futureSnapshot.error}'),
                                ),
                              );
                            }

                            final chatsRaw = futureSnapshot.data ?? [];
                            if (chatsRaw.isEmpty) {
                              return const SliverFillRemaining(
                                child: Center(child: Text('一致するスレッドがありません')),
                              );
                            }
                            final senderToLatest =
                                <String, Map<String, dynamic>>{};
                            for (final m in chatsRaw) {
                              final email = ((m['fromEmail'] ?? '') as String)
                                  .toLowerCase();
                              if (email.isNotEmpty) senderToLatest[email] = m;
                            }
                            return FutureBuilder<Map<String, int>>(
                              future: _loadUnreadCounts(allowedSenders),
                              builder: (context, usnap) {
                                final unreadMap =
                                    usnap.data ?? const <String, int>{};
                                final chatList = senderToLatest.values
                                    .map(_mapToChat)
                                    .toList();
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
                                    return Slidable(
                                      key: ValueKey(chat.threadId),
                                      endActionPane: ActionPane(
                                        motion: const ScrollMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) async {
                                              await _markSenderAllRead(
                                                chat.senderEmail,
                                              );
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${chat.name} を既読にしました',
                                                  ),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              chat.time,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _unreadChip(unread),
                                          ],
                                        ),
                                        onTap: () {
                                          if (chat.senderEmail.isEmpty) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PersonChatScreen(
                                                senderEmail: chat.senderEmail,
                                                title: chat.name,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }, childCount: chatList.length),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad + 72)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- サブウィジェット群（元のファイルから移植） ---
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
    final border = dark ? Colors.white54 : Colors.black26;
    final fg = dark ? Colors.white : Colors.black87;
    final bg = dark ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: ShapeDecoration(
            color: bg,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.transparent),
            ),
          ),
          child: Icon(Icons.add_circle, size: 48, color: Colors.white),
        ),
      ),
    );
  }
}

class _AccountsBar extends StatelessWidget {
  final Stream<List<_LinkedAccount>> streamLinkedAccounts;
  final String? activeAccountEmail;
  final Future<void> Function(String?) switchToAccount;
  final Future<void> Function() linkGoogleAccount;

  const _AccountsBar({
    required this.streamLinkedAccounts,
    required this.activeAccountEmail,
    required this.switchToAccount,
    required this.linkGoogleAccount,
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
                final accounts = snapshot.data ?? [];
                return SizedBox(
                  width: MediaQuery.of(context).size.width, // ★★★ この行を追加 ★★★
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // _AllChip を _AllButton に置き換え
                        _AllButton(
                          selected: activeAccountEmail == null,
                          onTap: () => switchToAccount(null),
                          dark: true,
                        ),
                        const SizedBox(width: 12),
                        ...accounts.map((a) {
                          final isSelected =
                              (a.email.toLowerCase() ==
                              (activeAccountEmail ?? '').toLowerCase());
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _AccountAvatar(
                              account: a,
                              selected: isSelected,
                              onTap: () => switchToAccount(a.email),
                              dark: true,
                            ),
                          );
                        }).toList(),
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
